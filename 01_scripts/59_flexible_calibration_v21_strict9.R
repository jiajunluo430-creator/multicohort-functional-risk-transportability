#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, width = 260)
d2_r_lib <- Sys.getenv("D2_R_LIB", unset = "")
if (nzchar(d2_r_lib)) .libPaths(c(d2_r_lib, .libPaths()))
suppressPackageStartupMessages({
  library(data.table)
  library(splines)
})

project_root <- Sys.getenv("D2_PROJECT_ROOT", unset = normalizePath(".", winslash = "/", mustWork = FALSE))
pred_path <- file.path(project_root, "02_derived", "reviewer_revision_v21", "v21_strict9_loco_predictions_all_risksets.rds")
out_dir <- file.path(project_root, "03_results", "14_reviewer_revision_v21", "05_flexible_calibration")
log_dir <- file.path(project_root, "07_logs")
for (d in c(out_dir, log_dir)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
stamp <- format(Sys.time(), "%Y%m%dT%H%M%S", tz = "America/Chicago")
sink(file.path(log_dir, paste0("59_flexible_calibration_v21_strict9_", stamp, ".log")), split = TRUE)
on.exit(sink(), add = TRUE)

zall <- as.data.table(readRDS(pred_path))[outcome_observed == 1 & !is.na(strict9_event)]
stopifnot(nrow(zall) > 0, all(zall$model %in% c("M0", "M1")))
clip <- function(p) pmin(pmax(as.numeric(p), 1e-6), 1 - 1e-6)

cluster_mean_ci <- function(y, cluster) {
  n <- length(y); mu <- mean(y); g <- uniqueN(cluster)
  if (g < 2L) return(c(lower = NA_real_, upper = NA_real_, se = NA_real_))
  s <- rowsum(y - mu, match(cluster, unique(cluster)), reorder = FALSE)[, 1]
  se <- sqrt((g / (g - 1)) * sum(s^2) / n^2)
  c(lower = max(0, mu - 1.96 * se), upper = min(1, mu + 1.96 * se), se = se)
}

calibration_metrics <- function(y, p) {
  p <- clip(p); lp <- qlogis(p)
  fit_i <- suppressWarnings(glm(y ~ 1, offset = lp, family = binomial(), control = glm.control(maxit = 100)))
  fit_s <- suppressWarnings(glm(y ~ lp, family = binomial(), control = glm.control(maxit = 100)))
  c(event_rate = mean(y), mean_prediction = mean(p), brier = mean((y - p)^2),
    calibration_intercept = unname(coef(fit_i)[1]), calibration_slope = unname(coef(fit_s)[2]))
}

bin_rows <- list(); curve_rows <- list(); audit_rows <- list(); oracle_rows <- list()

for (riskset in c("two_wave", "one_wave")) for (cc in c("CHARLS", "HRS", "ELSA", "MHAS")) for (mm in c("M0", "M1")) {
  z <- zall[riskset_type == riskset & cohort == cc & model == mm]
  if (!nrow(z)) next
  y <- as.integer(z$strict9_event); p <- clip(z$prediction); lp <- qlogis(p); id <- z$person_id

  bin <- pmin(10L, ceiling(frank(p, ties.method = "average") / length(p) * 10L))
  for (bb in sort(unique(bin))) {
    ii <- which(bin == bb); ci <- cluster_mean_ci(y[ii], id[ii])
    bin_rows[[length(bin_rows) + 1L]] <- data.table(
      riskset_type = riskset, heldout = cc, model = mm, bin = bb,
      records = length(ii), persons = uniqueN(id[ii]), events = sum(y[ii]),
      observed_risk = mean(y[ii]), observed_lower_95_cluster = ci[["lower"]], observed_upper_95_cluster = ci[["upper"]],
      mean_prediction = mean(p[ii]), min_prediction = min(p[ii]), max_prediction = max(p[ii])
    )
  }

  boundary <- range(lp)
  internal <- unique(as.numeric(quantile(lp, c(0.25, 0.50, 0.75), names = FALSE)))
  internal <- internal[internal > boundary[1] & internal < boundary[2]]
  if (length(internal) < 2L) stop("Insufficient unique spline knots: ", riskset, "/", cc, "/", mm)
  basis <- ns(lp, knots = internal, Boundary.knots = boundary, intercept = FALSE)
  X <- cbind(`(Intercept)` = 1, basis)
  fit <- suppressWarnings(glm.fit(x = X, y = y, family = binomial(), control = glm.control(maxit = 100)))
  if (!isTRUE(fit$converged) || any(!is.finite(fit$coefficients))) stop("Flexible calibration failed: ", riskset, "/", cc, "/", mm)
  mu <- clip(fit$fitted.values); w <- mu * (1 - mu)
  bread <- tryCatch(solve(crossprod(X, X * w)), error = function(e) NULL)
  if (is.null(bread)) stop("Singular flexible calibration bread: ", riskset, "/", cc, "/", mm)
  score <- X * (y - mu)
  cluster_score <- rowsum(score, match(id, unique(id)), reorder = FALSE)
  g <- nrow(cluster_score)
  meat <- crossprod(cluster_score) * g / (g - 1)
  vcov_cluster <- bread %*% meat %*% bread

  grid_p <- seq(quantile(p, 0.01), quantile(p, 0.99), length.out = 120L)
  grid_lp <- qlogis(grid_p)
  Xg <- cbind(1, predict(basis, grid_lp))
  eta <- as.numeric(Xg %*% fit$coefficients)
  se_eta <- sqrt(pmax(0, rowSums((Xg %*% vcov_cluster) * Xg)))
  curve_rows[[length(curve_rows) + 1L]] <- data.table(
    riskset_type = riskset, heldout = cc, model = mm, nominal_prediction = grid_p,
    flexible_observed_risk = plogis(eta), lower_95_cluster = plogis(eta - 1.96 * se_eta),
    upper_95_cluster = plogis(eta + 1.96 * se_eta)
  )
  audit_rows[[length(audit_rows) + 1L]] <- data.table(
    riskset_type = riskset, heldout = cc, model = mm, records = nrow(z), persons = uniqueN(id), events = sum(y),
    spline_df = ncol(X) - 1L, cluster_count = g, converged = fit$converged,
    prediction_p01 = quantile(p, 0.01), prediction_p99 = quantile(p, 0.99),
    min_fitted_risk = min(plogis(eta)), max_fitted_risk = max(plogis(eta))
  )

  raw <- calibration_metrics(y, p)
  p_int <- clip(plogis(lp + raw[["calibration_intercept"]]))
  fit_full <- suppressWarnings(glm(y ~ lp, family = binomial(), control = glm.control(maxit = 100)))
  p_full <- clip(predict(fit_full, type = "response"))
  for (method in c("raw_untouched", "target_intercept_oracle", "target_intercept_slope_oracle")) {
    pp <- switch(method, raw_untouched = p, target_intercept_oracle = p_int, target_intercept_slope_oracle = p_full)
    met <- calibration_metrics(y, pp)
    oracle_rows[[length(oracle_rows) + 1L]] <- data.table(
      riskset_type = riskset, heldout = cc, model = mm, method = method,
      records = nrow(z), persons = uniqueN(id), events = sum(y),
      event_rate = met[["event_rate"]], mean_prediction = met[["mean_prediction"]], brier = met[["brier"]],
      calibration_intercept = met[["calibration_intercept"]],
      calibration_slope = if (method == "target_intercept_oracle") NA_real_ else met[["calibration_slope"]],
      fitted_target_intercept = if (method == "raw_untouched") 0 else if (method == "target_intercept_oracle") raw[["calibration_intercept"]] else unname(coef(fit_full)[1]),
      fitted_target_slope = if (method == "target_intercept_slope_oracle") unname(coef(fit_full)[2]) else 1
    )
  }
}

bins <- rbindlist(bin_rows); curves <- rbindlist(curve_rows); audit <- rbindlist(audit_rows); oracle <- rbindlist(oracle_rows)
raw_ref <- oracle[method == "raw_untouched", .(riskset_type, heldout, model, raw_brier = brier)]
oracle <- merge(oracle, raw_ref, by = c("riskset_type", "heldout", "model"), all.x = TRUE, sort = FALSE)
oracle[, delta_brier_vs_raw := brier - raw_brier]

fwrite(bins, file.path(out_dir, "v21_strict9_calibration_bins_cluster_ci.csv"), na = "")
fwrite(curves, file.path(out_dir, "v21_strict9_flexible_calibration_curves_cluster_robust.csv"), na = "")
fwrite(audit, file.path(out_dir, "v21_strict9_flexible_calibration_fit_audit.csv"), na = "")
fwrite(oracle, file.path(out_dir, "v21_strict9_target_outcome_oracle_decomposition.csv"), na = "")
gates <- data.table(
  gate = c("all_16_curves_converged", "all_bins_have_records_events", "oracle_is_labeled_target_outcome"),
  passed = c(nrow(audit) == 16L && all(audit$converged), all(bins$records > 0 & bins$events >= 0), all(grepl("oracle|raw_untouched", oracle$method)))
)
fwrite(gates, file.path(out_dir, "v21_strict9_flexible_calibration_gates.csv"))
writeLines(capture.output(sessionInfo()), file.path(out_dir, "sessionInfo.txt"))
print(gates); print(audit)
cat("Completed: ", format(Sys.time(), tz = "America/Chicago"), "\n", sep = "")
