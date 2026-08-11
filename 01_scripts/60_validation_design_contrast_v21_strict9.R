#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, width = 260)
d2_r_lib <- Sys.getenv("D2_R_LIB", unset = "")
if (nzchar(d2_r_lib)) .libPaths(c(d2_r_lib, .libPaths()))
suppressPackageStartupMessages(library(data.table))

project_root <- Sys.getenv("D2_PROJECT_ROOT", unset = normalizePath(".", winslash = "/", mustWork = FALSE))
data_path <- file.path(project_root, "02_derived", "reviewer_revision_v21", "strict9_two_wave_riskset_primary_2to3y.rds")
loco_path <- file.path(project_root, "03_results", "14_reviewer_revision_v21", "03_strict9_loco", "v21_strict9_loco_performance_point.csv")
out_dir <- file.path(project_root, "03_results", "14_reviewer_revision_v21", "06_validation_design_contrast")
log_dir <- file.path(project_root, "07_logs")
for (d in c(out_dir, log_dir)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
stamp <- format(Sys.time(), "%Y%m%dT%H%M%S", tz = "America/Chicago")
sink(file.path(log_dir, paste0("60_validation_design_contrast_v21_strict9_", stamp, ".log")), split = TRUE)
on.exit(sink(), add = TRUE)

d <- as.data.table(readRDS(data_path))[outcome_observed == 1 & !is.na(strict9_event)]
d[, age10 := age / 10]
d[, person_key := paste(cohort, person_id, sep = "::")]

m0_features <- c("age10", "female")
m1_features <- c("age10", "female", "education3", "partnered_t", "srh_t", "mobility3_t", "chronic5_t", "smoking_t", "depression_prop_t", "prediction_horizon_years")

clip <- function(p) pmin(pmax(as.numeric(p), 1e-6), 1 - 1e-6)
fit_prep <- function(train, features) {
  medians <- vapply(features, function(v) median(train[[v]], na.rm = TRUE), numeric(1))
  if (any(!is.finite(medians))) stop("Non-finite split-development median")
  indicators <- features[vapply(features, function(v) anyNA(train[[v]]), logical(1))]
  list(features = features, medians = medians, missing_indicators = indicators)
}
apply_prep <- function(x, prep) {
  z <- copy(x[, prep$features, with = FALSE])
  for (v in prep$features) {
    miss <- is.na(z[[v]])
    if (v %in% prep$missing_indicators) z[, (paste0("miss_", v)) := as.numeric(miss)]
    if (any(miss)) set(z, which(miss), v, prep$medians[[v]])
  }
  as.data.frame(z, check.names = FALSE)
}
cohort_balance_weights <- function(x) {
  n_by <- x[, .N, by = cohort]
  n_by[, w := nrow(x) / (uniqueN(x$cohort) * N)]
  setNames(n_by$w, n_by$cohort)[x$cohort]
}
auc_rank <- function(y, p, w = rep(1, length(y))) {
  keep <- !is.na(y) & is.finite(p) & is.finite(w) & w > 0
  y <- as.integer(y[keep]); p <- as.numeric(p[keep]); w <- as.numeric(w[keep])
  if (sum(w[y == 1]) <= 0 || sum(w[y == 0]) <= 0) return(NA_real_)
  ord <- order(p, y); y <- y[ord]; p <- p[ord]; w <- w[ord]
  g <- cumsum(c(TRUE, diff(p) != 0)); pos <- rowsum(w * (y == 1), g, reorder = FALSE)[, 1]; neg <- rowsum(w * (y == 0), g, reorder = FALSE)[, 1]
  sum(pos * (cumsum(neg) - neg + 0.5 * neg)) / (sum(pos) * sum(neg))
}
calibration_irls <- function(y, p, w) {
  lp <- qlogis(clip(p)); a <- 0
  for (iter in seq_len(50L)) {
    mu <- plogis(pmin(pmax(lp + a, -30), 30)); den <- sum(w * mu * (1 - mu))
    if (!is.finite(den) || den < 1e-12) return(c(citl = NA_real_, slope = NA_real_))
    step <- sum(w * (y - mu)) / den; a <- a + step
    if (abs(step) < 1e-8) break
  }
  beta <- c(0, 1)
  for (iter in seq_len(80L)) {
    mu <- plogis(pmin(pmax(beta[1] + beta[2] * lp, -30), 30)); v <- w * mu * (1 - mu)
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
  p <- clip(p); w <- as.numeric(w); sw <- sum(w); cal <- calibration_irls(y, p, w)
  data.table(records = length(y), events = sum(y), event_rate = sum(w * y) / sw, mean_prediction = sum(w * p) / sw,
             auc = auc_rank(y, p, w), brier = sum(w * (y - p)^2) / sw,
             calibration_intercept = unname(cal[["citl"]]), calibration_slope = unname(cal[["slope"]]))
}

heldouts <- c("CHARLS", "HRS", "ELSA", "MHAS")
specs <- list(M0 = m0_features, M1 = m1_features)
R <- 100L
rows <- list(); fit_audit <- list()

for (r in seq_len(R)) {
  set.seed(20260809L + 60000L + r)
  train_keys <- unlist(lapply(heldouts, function(cc) {
    ids <- sort(unique(d[cohort == cc]$person_key)); sample(ids, floor(0.80 * length(ids)), replace = FALSE)
  }), use.names = FALSE)
  in_train <- d$person_key %chin% train_keys
  train <- d[in_train]; test <- d[!in_train]; ww <- cohort_balance_weights(train)
  for (model_name in names(specs)) {
    prep <- fit_prep(train, specs[[model_name]])
    xtr <- apply_prep(train, prep); xte <- apply_prep(test, prep)
    fit <- suppressWarnings(glm(y ~ ., data = cbind(y = train$strict9_event, xtr), weights = ww,
                                family = binomial(), control = glm.control(maxit = 100)))
    if (!isTRUE(fit$converged)) stop("Random-split model failed: replicate ", r, "/", model_name)
    pred <- data.table(cohort = test$cohort, person_id = test$person_id, y = test$strict9_event,
                       prediction = clip(predict(fit, newdata = xte, type = "response")))
    rows[[length(rows) + 1L]] <- metrics(pred$y, pred$prediction, cohort_balance_weights(pred))[
      , `:=`(replicate = r, model = model_name, evaluation_group = "POOLED_EQUAL_COHORT", evaluation_design = "person_level_random_split")]
    for (cc in heldouts) {
      zz <- pred[cohort == cc]
      rows[[length(rows) + 1L]] <- metrics(zz$y, zz$prediction)[
        , `:=`(replicate = r, model = model_name, evaluation_group = cc, evaluation_design = "person_level_random_split")]
    }
    fit_audit[[length(fit_audit) + 1L]] <- data.table(
      replicate = r, model = model_name, development_records = nrow(train), evaluation_records = nrow(test),
      development_persons = uniqueN(train$person_key), evaluation_persons = uniqueN(test$person_key),
      coefficient_count = length(coef(fit)), converged = fit$converged
    )
  }
  if (r %% 10L == 0L) cat("Completed random-split replicate ", r, "/", R, "\n", sep = "")
}

detail <- rbindlist(rows, use.names = TRUE); audit <- rbindlist(fit_audit)
summary_dt <- detail[, .(
  repetitions = .N, median_auc = median(auc), auc_lower_95 = quantile(auc, 0.025), auc_upper_95 = quantile(auc, 0.975),
  median_brier = median(brier), median_citl = median(calibration_intercept), median_abs_citl = median(abs(calibration_intercept)),
  citl_lower_95 = quantile(calibration_intercept, 0.025), citl_upper_95 = quantile(calibration_intercept, 0.975),
  median_slope = median(calibration_slope), median_abs_slope_error = median(abs(calibration_slope - 1)),
  slope_lower_95 = quantile(calibration_slope, 0.025), slope_upper_95 = quantile(calibration_slope, 0.975),
  proportion_joint_lenient = mean(abs(calibration_intercept) <= 0.20 & calibration_slope >= 0.80 & calibration_slope <= 1.20)
), by = .(model, evaluation_group)]

pooled <- detail[evaluation_group == "POOLED_EQUAL_COHORT", .(replicate, model, pooled_citl = calibration_intercept, pooled_slope = calibration_slope)]
country <- detail[evaluation_group != "POOLED_EQUAL_COHORT", .(
  any_country_lenient_failure = any(abs(calibration_intercept) > 0.20 | calibration_slope < 0.80 | calibration_slope > 1.20),
  maximum_country_abs_citl = max(abs(calibration_intercept)), maximum_country_abs_slope_error = max(abs(calibration_slope - 1)),
  countries_lenient_failure = sum(abs(calibration_intercept) > 0.20 | calibration_slope < 0.80 | calibration_slope > 1.20)
), by = .(replicate, model)]
concealment <- merge(pooled, country, by = c("replicate", "model"))
concealment[, pooled_joint_lenient_pass := abs(pooled_citl) <= 0.20 & pooled_slope >= 0.80 & pooled_slope <= 1.20]
concealment[, pooled_pass_conceals_country_failure := pooled_joint_lenient_pass & any_country_lenient_failure]
concealment_summary <- concealment[, .(
  pooled_joint_lenient_pass_rate = mean(pooled_joint_lenient_pass), any_country_lenient_failure_rate = mean(any_country_lenient_failure),
  concealment_rate_all_repetitions = mean(pooled_pass_conceals_country_failure),
  concealment_rate_given_pooled_pass = if (any(pooled_joint_lenient_pass)) mean(pooled_pass_conceals_country_failure[pooled_joint_lenient_pass]) else NA_real_,
  median_countries_failing_when_pooled_passes = if (any(pooled_joint_lenient_pass)) as.numeric(median(countries_lenient_failure[pooled_joint_lenient_pass])) else NA_real_,
  median_maximum_country_abs_citl = median(maximum_country_abs_citl), median_maximum_country_abs_slope_error = median(maximum_country_abs_slope_error)
), by = model]

loco <- fread(loco_path)[riskset_type == "two_wave" & evaluation_weighting == "unweighted", .(
  model, evaluation_group = heldout, loco_auc = auc, loco_brier = brier, loco_citl = calibration_intercept, loco_slope = calibration_slope
)]
design_contrast <- merge(summary_dt[evaluation_group != "POOLED_EQUAL_COHORT"], loco, by = c("model", "evaluation_group"), all.x = TRUE)
design_contrast[, `:=`(random_split_minus_loco_auc = median_auc - loco_auc,
                       random_split_minus_loco_abs_citl = median_abs_citl - abs(loco_citl),
                       random_split_minus_loco_abs_slope_error = median_abs_slope_error - abs(loco_slope - 1))]

fwrite(detail, file.path(out_dir, "v21_strict9_random_split_performance_100.csv.gz"), compress = "gzip")
fwrite(audit, file.path(out_dir, "v21_strict9_random_split_fit_audit.csv"))
fwrite(summary_dt, file.path(out_dir, "v21_strict9_random_split_performance_summary.csv"))
fwrite(concealment, file.path(out_dir, "v21_strict9_random_split_concealment_by_repetition.csv"))
fwrite(concealment_summary, file.path(out_dir, "v21_strict9_random_split_concealment_summary.csv"))
fwrite(design_contrast, file.path(out_dir, "v21_strict9_random_split_vs_loco.csv"))
gates <- data.table(gate = c("all_200_models_converged", "all_100_repetitions_present", "country_specific_and_pooled_reported"),
                    passed = c(nrow(audit) == 200L && all(audit$converged), uniqueN(detail$replicate) == 100L, all(c(heldouts, "POOLED_EQUAL_COHORT") %in% detail$evaluation_group)))
fwrite(gates, file.path(out_dir, "v21_strict9_random_split_gates.csv"))
writeLines(capture.output(sessionInfo()), file.path(out_dir, "sessionInfo.txt"))
print(gates); print(summary_dt); print(concealment_summary); print(design_contrast)
cat("Completed: ", format(Sys.time(), tz = "America/Chicago"), "\n", sep = "")
