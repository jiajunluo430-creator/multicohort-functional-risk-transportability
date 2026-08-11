#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, width = 240)
d2_r_lib <- Sys.getenv("D2_R_LIB", unset = "")
if (nzchar(d2_r_lib)) .libPaths(c(d2_r_lib, .libPaths()))
suppressPackageStartupMessages(library(data.table))

root <- Sys.getenv("D2_PROJECT_ROOT", unset = normalizePath(".", winslash = "/", mustWork = FALSE))
data_path <- file.path(root, "02_derived", "reviewer_revision_v21", "strict9_two_wave_riskset_primary_2to3y.rds")
v22_dir <- file.path(root, "03_results", "15_submission_upgrade_v22", "01_robustness")
out_dir <- file.path(root, "03_results", "16_submission_upgrade_v23", "01_hrs_person_equal_dca")
log_dir <- file.path(root, "07_logs")
for (path in c(out_dir, log_dir)) dir.create(path, recursive = TRUE, showWarnings = FALSE)
stamp <- format(Sys.time(), "%Y%m%dT%H%M%S", tz = "America/Chicago")
sink(file.path(log_dir, paste0("80_v23_prepare_hrs_person_equal_predictions_", stamp, ".log")), split = TRUE)
on.exit(sink(), add = TRUE)

clip <- function(p) pmin(pmax(as.numeric(p), 1e-6), 1 - 1e-6)

auc_rank <- function(y, p) {
  keep <- !is.na(y) & is.finite(p)
  y <- as.integer(y[keep]); p <- as.numeric(p[keep])
  if (sum(y == 1) == 0 || sum(y == 0) == 0) return(NA_real_)
  ord <- order(p, y); y <- y[ord]; p <- p[ord]
  group <- cumsum(c(TRUE, diff(p) != 0))
  positive <- rowsum(as.numeric(y == 1), group, reorder = FALSE)[, 1]
  negative <- rowsum(as.numeric(y == 0), group, reorder = FALSE)[, 1]
  sum(positive * (cumsum(negative) - negative + 0.5 * negative)) / (sum(positive) * sum(negative))
}

calibration_irls <- function(y, p) {
  lp <- qlogis(clip(p)); intercept <- 0
  for (iteration in seq_len(80L)) {
    mu <- plogis(pmin(pmax(lp + intercept, -30), 30))
    denominator <- sum(mu * (1 - mu))
    step <- sum(y - mu) / denominator
    intercept <- intercept + step
    if (!is.finite(step) || abs(step) < 1e-10) break
  }
  beta <- c(0, 1)
  for (iteration in seq_len(100L)) {
    eta <- pmin(pmax(beta[1] + beta[2] * lp, -30), 30)
    mu <- plogis(eta); variance <- mu * (1 - mu)
    hessian <- matrix(c(sum(variance), sum(variance * lp), sum(variance * lp), sum(variance * lp * lp)), 2, 2)
    score <- c(sum(y - mu), sum((y - mu) * lp))
    step <- solve(hessian, score)
    beta <- beta + step
    if (max(abs(step)) < 1e-10) break
  }
  c(citl = intercept, slope = beta[2])
}

d <- as.data.table(readRDS(data_path))
d[, age10 := age / 10]
target <- d[cohort == "HRS" & outcome_observed == 1 & !is.na(strict9_event)]
setorder(target, person_id, landmark_year, landmark_wave, outcome_year)

prep <- fread(file.path(v22_dir, "v22_weighting_M2_preprocessing.csv"))[
  heldout == "HRS" & model == "M1" & development_weighting == "person_equal"
]
coef_dt <- fread(file.path(v22_dir, "v22_weighting_M2_coefficients.csv"))[
  heldout == "HRS" & model == "M1" & development_weighting == "person_equal"
]
if (nrow(prep) != 10L || nrow(coef_dt) < 11L) stop("Incomplete saved preprocessing or coefficient rows")

x <- copy(target[, prep$feature, with = FALSE])
for (i in seq_len(nrow(prep))) {
  variable <- prep$feature[i]
  missing <- is.na(x[[variable]])
  if (isTRUE(prep$missing_indicator[i])) x[, (paste0("miss_", variable)) := as.numeric(missing)]
  if (any(missing)) set(x, which(missing), variable, prep$training_median[i])
}

mm <- model.matrix(~ ., data = as.data.frame(x, check.names = FALSE))
beta <- setNames(coef_dt$estimate, coef_dt$term)
if (!setequal(colnames(mm), names(beta))) {
  stop("Model-matrix/coefficient mismatch. Matrix only: ", paste(setdiff(colnames(mm), names(beta)), collapse = ","),
       "; coefficients only: ", paste(setdiff(names(beta), colnames(mm)), collapse = ","))
}
linear_predictor <- drop(mm[, names(beta), drop = FALSE] %*% as.numeric(beta))
prediction <- clip(plogis(linear_predictor))
matrix_diagnostic <- data.table(
  term = names(beta), coefficient = as.numeric(beta),
  matrix_mean = colMeans(mm[, names(beta), drop = FALSE]),
  matrix_sd = apply(mm[, names(beta), drop = FALSE], 2, sd)
)
linear_diagnostic <- data.table(
  statistic = c("minimum", "mean", "median", "maximum", "mean_plogis"),
  value = c(min(linear_predictor), mean(linear_predictor), median(linear_predictor), max(linear_predictor), mean(plogis(linear_predictor)))
)

calibration <- calibration_irls(target$strict9_event, prediction)
point <- data.table(
  cohort = "HRS", model = "M1", development_weighting = "person_equal",
  records = nrow(target), persons = uniqueN(target$person_id), events = sum(target$strict9_event),
  observed_risk = mean(target$strict9_event), mean_prediction = mean(prediction),
  observed_minus_predicted_pp = 100 * (mean(target$strict9_event) - mean(prediction)),
  auc = auc_rank(target$strict9_event, prediction),
  brier = mean((target$strict9_event - prediction)^2),
  calibration_intercept = unname(calibration[["citl"]]), calibration_slope = unname(calibration[["slope"]])
)

reference <- fread(file.path(v22_dir, "v22_development_weighting_M1_point.csv"))[
  heldout == "HRS" & model == "M1" & development_weighting == "person_equal"
]
comparisons <- c(
  records = point$records == reference$records,
  events = point$events == reference$events,
  observed_risk = abs(point$observed_risk - reference$observed_risk) < 1e-12,
  mean_prediction = abs(point$mean_prediction - reference$mean_prediction) < 1e-12,
  gap = abs(point$observed_minus_predicted_pp - reference$observed_minus_predicted_pp) < 1e-10,
  auc = abs(point$auc - reference$auc) < 1e-12,
  brier = abs(point$brier - reference$brier) < 1e-12,
  citl = abs(point$calibration_intercept - reference$calibration_intercept) < 1e-10,
  slope = abs(point$calibration_slope - reference$calibration_slope) < 1e-10
)
gates <- data.table(gate = names(comparisons), passed = as.logical(comparisons))
comparison_details <- data.table(
  metric = c("observed_risk", "mean_prediction", "observed_minus_predicted_pp", "auc", "brier", "calibration_intercept", "calibration_slope"),
  reconstructed = c(point$observed_risk, point$mean_prediction, point$observed_minus_predicted_pp, point$auc, point$brier, point$calibration_intercept, point$calibration_slope),
  v22_reference = c(reference$observed_risk, reference$mean_prediction, reference$observed_minus_predicted_pp, reference$auc, reference$brier, reference$calibration_intercept, reference$calibration_slope)
)
comparison_details[, absolute_difference := abs(reconstructed - v22_reference)]

predictions <- target[, .(
  riskset_type, cohort, person_id = as.character(person_id), landmark_wave, landmark_year, outcome_year,
  outcome_observed, strict9_event
)]
predictions[, `:=`(model = "M1", development_weighting = "person_equal", prediction = prediction)]

fwrite(predictions, file.path(out_dir, "v23_HRS_person_equal_M1_predictions.csv.gz"), compress = "gzip", na = "")
fwrite(point, file.path(out_dir, "v23_HRS_person_equal_M1_point_reproduction.csv"), na = "")
fwrite(gates, file.path(out_dir, "v23_HRS_person_equal_prediction_gates.csv"), na = "")
fwrite(comparison_details, file.path(out_dir, "v23_HRS_person_equal_prediction_reproduction_differences.csv"), na = "")
fwrite(matrix_diagnostic, file.path(out_dir, "v23_HRS_person_equal_model_matrix_diagnostic.csv"), na = "")
fwrite(linear_diagnostic, file.path(out_dir, "v23_HRS_person_equal_linear_predictor_diagnostic.csv"), na = "")
writeLines(capture.output(sessionInfo()), file.path(out_dir, "sessionInfo_R.txt"))

print(point)
print(comparison_details)
print(matrix_diagnostic)
print(linear_diagnostic)
print(gates)
if (!all(gates$passed)) stop("Saved-model prediction reproduction failed: ", paste(gates[passed == FALSE, gate], collapse = ","))
cat("Completed: ", format(Sys.time(), tz = "America/Chicago"), "\n", sep = "")
