#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, width = 280)
d2_r_lib <- Sys.getenv("D2_R_LIB", unset = "")
if (nzchar(d2_r_lib)) .libPaths(c(d2_r_lib, .libPaths()))
suppressPackageStartupMessages(library(data.table))

project_root <- Sys.getenv("D2_PROJECT_ROOT", unset = normalizePath(".", winslash = "/", mustWork = FALSE))
data_path <- file.path(project_root, "02_derived", "reviewer_revision_v21", "strict9_two_wave_riskset_all_intervals.rds")
model_dir <- file.path(project_root, "03_results", "14_reviewer_revision_v21", "03_strict9_loco", "models")
out_dir <- file.path(project_root, "03_results", "14_reviewer_revision_v21", "08_temporal_all_windows")
log_dir <- file.path(project_root, "07_logs")
for (d in c(out_dir, log_dir)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
stamp <- format(Sys.time(), "%Y%m%dT%H%M%S", tz = "America/Chicago")
sink(file.path(log_dir, paste0("62_temporal_all_windows_v21_strict9_", stamp, ".log")), split = TRUE)
on.exit(sink(), add = TRUE)

clip <- function(p) pmin(pmax(as.numeric(p), 1e-6), 1 - 1e-6)
apply_prep <- function(x, prep) {
  z <- copy(x[, prep$features, with = FALSE])
  for (v in prep$features) {
    miss <- is.na(z[[v]])
    if (v %in% prep$missing_indicators) z[, (paste0("miss_", v)) := as.numeric(miss)]
    if (any(miss)) set(z, which(miss), v, prep$medians[[v]])
  }
  as.data.frame(z, check.names = FALSE)
}
auc_rank <- function(y, p, w = rep(1, length(y))) {
  keep <- !is.na(y) & is.finite(p) & is.finite(w) & w > 0
  y <- as.integer(y[keep]); p <- as.numeric(p[keep]); w <- as.numeric(w[keep])
  if (sum(w[y == 1]) <= 0 || sum(w[y == 0]) <= 0) return(NA_real_)
  ord <- order(p, y); y <- y[ord]; p <- p[ord]; w <- w[ord]
  g <- cumsum(c(TRUE, diff(p) != 0)); pos <- rowsum(w * (y == 1), g, reorder = FALSE)[, 1]; neg <- rowsum(w * (y == 0), g, reorder = FALSE)[, 1]
  sum(pos * (cumsum(neg) - neg + 0.5 * neg)) / (sum(pos) * sum(neg))
}
calibration_irls <- function(y, p, w = rep(1, length(y))) {
  lp <- qlogis(clip(p)); a <- 0
  for (iter in seq_len(60L)) {
    mu <- plogis(pmin(pmax(lp + a, -30), 30)); den <- sum(w * mu * (1 - mu))
    if (!is.finite(den) || den < 1e-12) return(c(citl = NA_real_, slope = NA_real_))
    step <- sum(w * (y - mu)) / den; a <- a + step
    if (abs(step) < 1e-8) break
  }
  beta <- c(0, 1)
  for (iter in seq_len(80L)) {
    eta <- pmin(pmax(beta[1] + beta[2] * lp, -30), 30); mu <- plogis(eta); v <- w * mu * (1 - mu)
    H <- matrix(c(sum(v), sum(v * lp), sum(v * lp), sum(v * lp * lp)), 2, 2)
    score <- c(sum(w * (y - mu)), sum(w * (y - mu) * lp))
    step <- tryCatch(solve(H, score), error = function(e) c(NA_real_, NA_real_))
    if (any(!is.finite(step))) return(c(citl = a, slope = NA_real_))
    beta <- beta + step
    if (max(abs(step)) < 1e-8) break
  }
  c(citl = a, slope = beta[2])
}
metrics <- function(y, p, w = rep(1, length(y))) {
  keep <- !is.na(y) & is.finite(p) & is.finite(w) & w > 0
  y <- as.integer(y[keep]); p <- clip(p[keep]); w <- as.numeric(w[keep]); sw <- sum(w); cal <- calibration_irls(y, p, w)
  data.table(records = length(y), events = sum(y), event_rate = sum(w * y) / sw, mean_prediction = sum(w * p) / sw,
             auc = auc_rank(y, p, w), brier = sum(w * (y - p)^2) / sw,
             calibration_intercept = unname(cal[["citl"]]), calibration_slope = unname(cal[["slope"]]))
}
fit_calibrator <- function(y, p, method) {
  lp <- qlogis(clip(p))
  if (length(unique(y)) < 2L) return(list(success = FALSE, intercept = NA_real_, slope = NA_real_))
  fit <- tryCatch({
    if (method == "intercept_only") suppressWarnings(glm(y ~ 1, offset = lp, family = binomial(), control = glm.control(maxit = 100)))
    else suppressWarnings(glm(y ~ lp, family = binomial(), control = glm.control(maxit = 100)))
  }, error = function(e) NULL)
  if (is.null(fit) || !isTRUE(fit$converged)) return(list(success = FALSE, intercept = NA_real_, slope = NA_real_))
  if (method == "intercept_only") pars <- c(intercept = unname(coef(fit)[1]), slope = 1)
  else pars <- c(intercept = unname(coef(fit)[1]), slope = unname(coef(fit)[2]))
  list(success = all(is.finite(pars)), intercept = pars[["intercept"]], slope = pars[["slope"]])
}

d <- as.data.table(readRDS(data_path))
d[, age10 := age / 10]
d[, person_key := paste(cohort, person_id, sep = "::")]
d[, interval_class := fcase(
  primary_horizon == 1, "primary_2to3_year",
  history_horizon_years > 3 & prediction_horizon_years <= 3, "extended_long_history_interval",
  prediction_horizon_years > 3, "extended_long_prediction_interval",
  default = "extended_other_nonprimary"
)]

pred_rows <- list(); audit_rows <- list()
for (cc in c("CHARLS", "HRS", "ELSA", "MHAS")) for (mm in c("M0", "M1")) {
  obj <- readRDS(file.path(model_dir, paste0("two_wave_heldout_", tolower(cc), "_", mm, ".rds")))
  z <- d[cohort == cc]
  x <- apply_prep(z, obj$preprocessor)
  pp <- clip(predict(obj$model, newdata = x, type = "response"))
  zz <- z[, .(cohort, country, person_id, person_key, prior_wave, landmark_wave, prior_year, landmark_year, outcome_year,
              history_horizon_years, prediction_horizon_years, primary_horizon, analysis_set, interval_class,
              outcome_observed, strict9_event, respondent_weight_t)]
  zz[, `:=`(model = mm, prediction = pp)]
  pred_rows[[length(pred_rows) + 1L]] <- zz
  audit_rows[[length(audit_rows) + 1L]] <- data.table(cohort = cc, model = mm, records = nrow(z), persons = uniqueN(z$person_id),
                                                     observed_records = sum(z$outcome_observed == 1 & !is.na(z$strict9_event)), prediction_complete = all(is.finite(pp)))
}
pred <- rbindlist(pred_rows); audit <- rbindlist(audit_rows)
obs <- pred[outcome_observed == 1 & !is.na(strict9_event)]

window_rows <- list(); overall_rows <- list()
for (weighting in c("unweighted", "respondent_weighted")) {
  for (ii in seq_len(nrow(unique(obs[, .(cohort, model, prior_wave, landmark_wave, prior_year, landmark_year, outcome_year,
                                          history_horizon_years, prediction_horizon_years, primary_horizon, interval_class)])))) {
    key <- unique(obs[, .(cohort, model, prior_wave, landmark_wave, prior_year, landmark_year, outcome_year,
                          history_horizon_years, prediction_horizon_years, primary_horizon, interval_class)])[ii]
    z <- obs[key, on = .(cohort, model, prior_wave, landmark_wave, prior_year, landmark_year, outcome_year,
                         history_horizon_years, prediction_horizon_years, primary_horizon, interval_class), nomatch = 0]
    w <- if (weighting == "unweighted") rep(1, nrow(z)) else z$respondent_weight_t
    mm <- metrics(z$strict9_event, z$prediction, w)
    window_rows[[length(window_rows) + 1L]] <- cbind(key, data.table(evaluation_weighting = weighting, persons = uniqueN(z$person_id)), mm)
  }
  for (cc in c("CHARLS", "HRS", "ELSA", "MHAS")) for (model_name in c("M0", "M1")) for (ic in c("primary_2to3_year", "extended_nonprimary_intervals", "all_available_intervals")) {
    z <- if (ic == "all_available_intervals") obs[cohort == cc & model == model_name] else if (ic == "extended_nonprimary_intervals") obs[cohort == cc & model == model_name & primary_horizon != 1] else obs[cohort == cc & model == model_name & primary_horizon == 1]
    if (!nrow(z)) next
    w <- if (weighting == "unweighted") rep(1, nrow(z)) else z$respondent_weight_t
    mm <- metrics(z$strict9_event, z$prediction, w)
    overall_rows[[length(overall_rows) + 1L]] <- cbind(data.table(cohort = cc, model = model_name, interval_scope = ic,
                                                                 evaluation_weighting = weighting, persons = uniqueN(z$person_id)), mm)
  }
}
window_perf <- rbindlist(window_rows); overall_perf <- rbindlist(overall_rows)

temporal_rows <- list(); unavailable_rows <- list()
for (cc in c("CHARLS", "HRS", "ELSA", "MHAS")) for (model_name in c("M0", "M1")) {
  z <- obs[cohort == cc & model == model_name]
  windows <- sort(unique(z$landmark_year))
  if (length(windows) < 2L) {
    unavailable_rows[[length(unavailable_rows) + 1L]] <- data.table(cohort = cc, model = model_name, reason = "Only one strict-nine two-wave prediction window")
    next
  }
  for (eval_year in windows[-1]) {
    cal <- z[landmark_year < eval_year]; ev <- z[landmark_year == eval_year]
    raw <- metrics(ev$strict9_event, ev$prediction)
    raw_auc <- raw$auc
    for (method in c("none", "intercept_only", "intercept_and_slope")) {
      fit <- if (method == "none") list(success = TRUE, intercept = 0, slope = 1) else fit_calibrator(cal$strict9_event, cal$prediction, method)
      if (fit$success) {
        pp <- clip(plogis(fit$intercept + fit$slope * qlogis(clip(ev$prediction))))
        mm <- metrics(ev$strict9_event, pp)
        mm$auc <- if (fit$slope > 0) raw_auc else if (fit$slope < 0) 1 - raw_auc else 0.5
      } else {
        mm <- data.table(records = nrow(ev), events = sum(ev$strict9_event), event_rate = mean(ev$strict9_event), mean_prediction = NA_real_,
                         auc = NA_real_, brier = NA_real_, calibration_intercept = NA_real_, calibration_slope = NA_real_)
      }
      temporal_rows[[length(temporal_rows) + 1L]] <- cbind(data.table(
        cohort = cc, model = model_name, evaluation_landmark_year = eval_year, evaluation_outcome_year = unique(ev$outcome_year),
        evaluation_history_horizon_years = unique(ev$history_horizon_years), evaluation_horizon_years = unique(ev$prediction_horizon_years),
        evaluation_primary_horizon = unique(ev$primary_horizon), evaluation_interval_class = unique(ev$interval_class), method = method,
        calibration_records = nrow(cal), calibration_persons = uniqueN(cal$person_id), calibration_events = sum(cal$strict9_event),
        evaluation_records = nrow(ev), evaluation_persons = uniqueN(ev$person_id), evaluation_events = sum(ev$strict9_event),
        overlapping_persons = uniqueN(intersect(unique(cal$person_id), unique(ev$person_id))),
        fit_success = fit$success, fitted_intercept = fit$intercept, fitted_slope = fit$slope,
        raw_brier = raw$brier, raw_abs_citl = abs(raw$calibration_intercept), raw_abs_slope_error = abs(raw$calibration_slope - 1)
      ), mm)
    }
  }
}
temporal <- rbindlist(temporal_rows, fill = TRUE); unavailable <- rbindlist(unavailable_rows, fill = TRUE)
temporal[, `:=`(
  delta_brier_vs_raw = brier - raw_brier,
  delta_abs_citl_vs_raw = abs(calibration_intercept) - raw_abs_citl,
  delta_abs_slope_error_vs_raw = abs(calibration_slope - 1) - raw_abs_slope_error,
  automatic_update_worsened_brier = method != "none" & brier > raw_brier + 0.001,
  automatic_update_worsened_abs_citl = method != "none" & abs(calibration_intercept) > raw_abs_citl
)]

fwrite(pred, file.path(out_dir, "v21_strict9_all_window_predictions.csv.gz"), compress = "gzip", na = "")
fwrite(audit, file.path(out_dir, "v21_strict9_all_window_prediction_audit.csv"), na = "")
fwrite(window_perf, file.path(out_dir, "v21_strict9_raw_performance_by_window.csv"), na = "")
fwrite(overall_perf, file.path(out_dir, "v21_strict9_raw_performance_primary_vs_all_windows.csv"), na = "")
fwrite(temporal, file.path(out_dir, "v21_strict9_temporal_updating_all_windows.csv"), na = "")
fwrite(unavailable, file.path(out_dir, "v21_strict9_temporal_updating_unavailable.csv"), na = "")
gates <- data.table(
  gate = c("all_models_predict_all_windows", "long_MHAS_history_or_prediction_not_in_primary_scope", "raw_all_windows_reported", "temporal_update_worsening_flags_reported"),
  passed = c(all(audit$prediction_complete),
             all(d[history_horizon_years == 9 | prediction_horizon_years == 9]$primary_horizon != 1) &&
               !any(d[history_horizon_years == 9 | prediction_horizon_years == 9]$interval_class == "primary_2to3_year"),
             uniqueN(window_perf$cohort) == 4 && all(c("primary_2to3_year", "all_available_intervals") %in% overall_perf$interval_scope),
             all(c("automatic_update_worsened_brier", "automatic_update_worsened_abs_citl") %in% names(temporal)))
)
fwrite(gates, file.path(out_dir, "v21_strict9_temporal_all_windows_gates.csv"))
writeLines(capture.output(sessionInfo()), file.path(out_dir, "sessionInfo.txt"))
print(gates); print(overall_perf); print(temporal)
cat("Completed: ", format(Sys.time(), tz = "America/Chicago"), "\n", sep = "")
