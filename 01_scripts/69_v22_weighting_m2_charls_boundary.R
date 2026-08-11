#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, width = 260)
d2_r_lib <- Sys.getenv("D2_R_LIB", unset = "")
if (nzchar(d2_r_lib)) .libPaths(c(d2_r_lib, .libPaths()))
suppressPackageStartupMessages(library(data.table))

project_root <- Sys.getenv("D2_PROJECT_ROOT", unset = normalizePath(".", winslash = "/", mustWork = FALSE))
data_path <- file.path(project_root, "02_derived", "reviewer_revision_v21", "strict9_two_wave_riskset_primary_2to3y.rds")
v21_dir <- file.path(project_root, "03_results", "14_reviewer_revision_v21", "03_strict9_loco")
out_dir <- file.path(project_root, "03_results", "15_submission_upgrade_v22", "01_robustness")
log_dir <- file.path(project_root, "07_logs")
for (path in c(out_dir, log_dir)) dir.create(path, recursive = TRUE, showWarnings = FALSE)
stamp <- format(Sys.time(), "%Y%m%dT%H%M%S", tz = "America/Chicago")
sink(file.path(log_dir, paste0("69_v22_weighting_m2_charls_boundary_", stamp, ".log")), split = TRUE)
on.exit(sink(), add = TRUE)
set.seed(20260810L)

clip <- function(p) pmin(pmax(as.numeric(p), 1e-6), 1 - 1e-6)

fit_prep <- function(train, features, add_missing = TRUE) {
  medians <- vapply(features, function(v) median(train[[v]], na.rm = TRUE), numeric(1))
  if (any(!is.finite(medians))) stop("Non-finite training median: ", paste(names(medians)[!is.finite(medians)], collapse = ","))
  missing_indicators <- if (add_missing) features[vapply(features, function(v) anyNA(train[[v]]), logical(1))] else character()
  list(features = features, medians = medians, missing_indicators = missing_indicators)
}

apply_prep <- function(x, prep) {
  z <- copy(x[, prep$features, with = FALSE])
  for (v in prep$features) {
    missing <- is.na(z[[v]])
    if (v %in% prep$missing_indicators) z[, (paste0("miss_", v)) := as.numeric(missing)]
    if (any(missing)) set(z, which(missing), v, prep$medians[[v]])
  }
  as.data.frame(z, check.names = FALSE)
}

equal_cohort_weights <- function(x) {
  by_cohort <- x[, .N, by = cohort]
  by_cohort[, weight := nrow(x) / (uniqueN(x$cohort) * N)]
  setNames(by_cohort$weight, by_cohort$cohort)[x$cohort]
}

person_equal_weights <- function(x) {
  indexed <- x[, .(row_id = .I, weight = 1 / .N), by = .(cohort, person_id)][order(row_id)]
  indexed$weight / mean(indexed$weight)
}

development_weights <- function(x, scheme) {
  switch(scheme,
    equal_cohort = equal_cohort_weights(x),
    sequence_weighted = rep(1, nrow(x)),
    person_equal = person_equal_weights(x),
    stop("Unknown development weighting: ", scheme)
  )
}

auc_rank <- function(y, p, w = rep(1, length(y))) {
  keep <- !is.na(y) & is.finite(p) & is.finite(w) & w > 0
  y <- as.integer(y[keep]); p <- as.numeric(p[keep]); w <- as.numeric(w[keep])
  if (sum(w[y == 1]) <= 0 || sum(w[y == 0]) <= 0) return(NA_real_)
  ord <- order(p, y); y <- y[ord]; p <- p[ord]; w <- w[ord]
  group <- cumsum(c(TRUE, diff(p) != 0))
  positive <- rowsum(w * (y == 1), group, reorder = FALSE)[, 1]
  negative <- rowsum(w * (y == 0), group, reorder = FALSE)[, 1]
  sum(positive * (cumsum(negative) - negative + 0.5 * negative)) / (sum(positive) * sum(negative))
}

calibration_irls <- function(y, p, w = rep(1, length(y))) {
  lp <- qlogis(clip(p)); intercept <- 0
  for (iteration in seq_len(50L)) {
    mu <- plogis(pmin(pmax(lp + intercept, -30), 30))
    denominator <- sum(w * mu * (1 - mu))
    if (!is.finite(denominator) || denominator < 1e-12) return(c(citl = NA_real_, slope = NA_real_))
    step <- sum(w * (y - mu)) / denominator
    intercept <- intercept + step
    if (abs(step) < 1e-8) break
  }
  beta <- c(0, 1)
  for (iteration in seq_len(80L)) {
    eta <- pmin(pmax(beta[1] + beta[2] * lp, -30), 30)
    mu <- plogis(eta); variance <- w * mu * (1 - mu)
    hessian <- matrix(c(sum(variance), sum(variance * lp), sum(variance * lp), sum(variance * lp * lp)), 2, 2)
    score <- c(sum(w * (y - mu)), sum(w * (y - mu) * lp))
    step <- tryCatch(solve(hessian, score), error = function(e) c(NA_real_, NA_real_))
    if (any(!is.finite(step))) return(c(citl = intercept, slope = NA_real_))
    beta <- beta + step
    if (max(abs(step)) < 1e-8) break
  }
  c(citl = intercept, slope = beta[2])
}

metrics <- function(y, p, w = rep(1, length(y))) {
  keep <- !is.na(y) & is.finite(p) & is.finite(w) & w > 0
  y <- as.integer(y[keep]); p <- clip(p[keep]); w <- as.numeric(w[keep])
  observed <- weighted.mean(y, w); predicted <- weighted.mean(p, w)
  calibration <- calibration_irls(y, p, w)
  data.table(
    records = length(y), events = sum(y), observed_risk = observed, mean_prediction = predicted,
    observed_minus_predicted_pp = 100 * (observed - predicted), auc = auc_rank(y, p, w),
    brier = weighted.mean((y - p)^2, w), calibration_intercept = unname(calibration[["citl"]]),
    calibration_slope = unname(calibration[["slope"]])
  )
}

d <- as.data.table(readRDS(data_path))
d[, `:=`(age10 = age / 10, person_key = paste(cohort, person_id, sep = "::"))]
observed <- d[outcome_observed == 1 & !is.na(strict9_event)]
heldouts <- c("CHARLS", "HRS", "ELSA", "MHAS")

m1 <- c("age10", "female", "education3", "partnered_t", "srh_t", "mobility3_t", "chronic5_t", "smoking_t", "depression_prop_t", "prediction_horizon_years")
m2h <- c(m1, "partnered_prev", "srh_prev", "mobility3_prev", "chronic5_prev", "depression_prop_prev")
m2s <- c("age10", "female", "prediction_horizon_years", "srh_t", "srh_prev", "mobility3_t", "mobility3_prev", "chronic5_t", "depression_prop_t", "depression_prop_prev")
specifications <- list(
  M1 = list(features = m1, add_missing = TRUE),
  M2H = list(features = m2h, add_missing = TRUE),
  M2S = list(features = m2s, add_missing = FALSE)
)

performance_rows <- list(); coefficient_rows <- list(); prep_rows <- list(); fit_rows <- list(); person_weight_rows <- list()

fit_and_evaluate <- function(train, test, heldout, model_name, scheme) {
  specification <- specifications[[model_name]]
  prep <- fit_prep(train, specification$features, specification$add_missing)
  x_train <- apply_prep(train, prep); x_test <- apply_prep(test, prep)
  weights <- development_weights(train, scheme)
  fit <- suppressWarnings(glm(y ~ ., data = cbind(y = train$strict9_event, x_train), weights = weights,
                              family = binomial(), control = glm.control(maxit = 100)))
  if (!isTRUE(fit$converged)) stop("Model failed: ", heldout, "/", model_name, "/", scheme)
  prediction <- clip(predict(fit, newdata = x_test, type = "response"))
  result <- metrics(test$strict9_event, prediction)
  result[, `:=`(heldout = heldout, model = model_name, development_weighting = scheme,
                heldout_persons = uniqueN(test$person_key), development_records = nrow(train),
                development_persons = uniqueN(train$person_key), development_events = sum(train$strict9_event))]
  performance_rows[[length(performance_rows) + 1L]] <<- result
  coefficient_rows[[length(coefficient_rows) + 1L]] <<- data.table(
    heldout = heldout, model = model_name, development_weighting = scheme,
    term = names(coef(fit)), estimate = unname(coef(fit))
  )
  prep_rows[[length(prep_rows) + 1L]] <<- data.table(
    heldout = heldout, model = model_name, development_weighting = scheme,
    feature = prep$features, training_median = unname(prep$medians),
    missing_indicator = prep$features %in% prep$missing_indicators
  )
  fit_rows[[length(fit_rows) + 1L]] <<- data.table(
    heldout = heldout, model = model_name, development_weighting = scheme,
    development_records = nrow(train), development_persons = uniqueN(train$person_key),
    development_events = sum(train$strict9_event), heldout_records = nrow(test),
    heldout_persons = uniqueN(test$person_key), heldout_events = sum(test$strict9_event),
    coefficient_count = length(coef(fit)), missing_indicator_count = length(prep$missing_indicators), converged = fit$converged
  )
}

for (heldout in heldouts) {
  train <- observed[cohort != heldout]
  test <- observed[cohort == heldout]
  cat("Held out ", heldout, "\n", sep = "")

  person_weights <- person_equal_weights(train)
  person_contributions <- data.table(person_key = train$person_key, weight = person_weights)[, .(total_weight = sum(weight)), by = person_key]
  person_weight_rows[[length(person_weight_rows) + 1L]] <- data.table(
    heldout = heldout, persons = nrow(person_contributions), min_total_weight = min(person_contributions$total_weight),
    median_total_weight = median(person_contributions$total_weight), max_total_weight = max(person_contributions$total_weight),
    max_minus_min = max(person_contributions$total_weight) - min(person_contributions$total_weight)
  )

  for (scheme in c("equal_cohort", "sequence_weighted", "person_equal")) fit_and_evaluate(train, test, heldout, "M1", scheme)
  for (model_name in c("M2H", "M2S")) fit_and_evaluate(train, test, heldout, model_name, "equal_cohort")
}

performance <- rbindlist(performance_rows, use.names = TRUE, fill = TRUE)
coefficients <- rbindlist(coefficient_rows, use.names = TRUE, fill = TRUE)
preprocessing <- rbindlist(prep_rows, use.names = TRUE, fill = TRUE)
fit_audit <- rbindlist(fit_rows, use.names = TRUE, fill = TRUE)
person_weight_audit <- rbindlist(person_weight_rows)

weighting <- performance[model == "M1"]
weighting_reference <- weighting[development_weighting == "equal_cohort", .(
  heldout, reference_auc = auc, reference_brier = brier, reference_abs_gap_pp = abs(observed_minus_predicted_pp),
  reference_abs_citl = abs(calibration_intercept), reference_abs_slope_error = abs(calibration_slope - 1)
)]
weighting_contrasts <- merge(weighting, weighting_reference, by = "heldout", all.x = TRUE)
weighting_contrasts[, `:=`(
  delta_auc_vs_equal_cohort = auc - reference_auc,
  delta_brier_vs_equal_cohort = brier - reference_brier,
  delta_abs_gap_pp_vs_equal_cohort = abs(observed_minus_predicted_pp) - reference_abs_gap_pp,
  delta_abs_citl_vs_equal_cohort = abs(calibration_intercept) - reference_abs_citl,
  delta_abs_slope_error_vs_equal_cohort = abs(calibration_slope - 1) - reference_abs_slope_error
)]

complexity <- performance[development_weighting == "equal_cohort"]
complexity_reference <- complexity[model == "M1", .(
  heldout, reference_auc = auc, reference_brier = brier, reference_abs_gap_pp = abs(observed_minus_predicted_pp),
  reference_abs_citl = abs(calibration_intercept), reference_abs_slope_error = abs(calibration_slope - 1)
)]
complexity_contrasts <- merge(complexity, complexity_reference, by = "heldout", all.x = TRUE)
complexity_contrasts[, `:=`(
  delta_auc_vs_M1 = auc - reference_auc,
  delta_brier_vs_M1 = brier - reference_brier,
  delta_abs_gap_pp_vs_M1 = abs(observed_minus_predicted_pp) - reference_abs_gap_pp,
  delta_abs_citl_vs_M1 = abs(calibration_intercept) - reference_abs_citl,
  delta_abs_slope_error_vs_M1 = abs(calibration_slope - 1) - reference_abs_slope_error
)]

fwrite(weighting, file.path(out_dir, "v22_development_weighting_M1_point.csv"), na = "")
fwrite(weighting_contrasts, file.path(out_dir, "v22_development_weighting_M1_contrasts.csv"), na = "")
fwrite(complexity, file.path(out_dir, "v22_strict9_model_complexity_point.csv"), na = "")
fwrite(complexity_contrasts, file.path(out_dir, "v22_strict9_model_complexity_contrasts.csv"), na = "")
fwrite(coefficients, file.path(out_dir, "v22_weighting_M2_coefficients.csv"), na = "")
fwrite(preprocessing, file.path(out_dir, "v22_weighting_M2_preprocessing.csv"), na = "")
fwrite(fit_audit, file.path(out_dir, "v22_weighting_M2_fit_audit.csv"), na = "")
fwrite(person_weight_audit, file.path(out_dir, "v22_person_equal_contribution_audit.csv"), na = "")

# New CHARLS boundary only. Existing ELSA results are reused from v2.1.
target <- "CHARLS"
train_composite <- d[cohort != target & composite_known == 1 & !is.na(composite_event)]
target_data <- d[cohort == target]
prep_composite <- fit_prep(train_composite, m1, TRUE)
x_train_composite <- apply_prep(train_composite, prep_composite)
x_target <- apply_prep(target_data, prep_composite)
fit_composite <- suppressWarnings(glm(
  y ~ ., data = cbind(y = train_composite$composite_event, x_train_composite),
  weights = equal_cohort_weights(train_composite), family = binomial(), control = glm.control(maxit = 100)
))
if (!isTRUE(fit_composite$converged)) stop("CHARLS composite development model failed")
target_data[, composite_prediction := clip(predict(fit_composite, newdata = x_target, type = "response"))]
known_index <- which(target_data$composite_known == 1 & !is.na(target_data$composite_event))
unknown_index <- which(target_data$followup_status == "unknown_alive_or_dead")

boundary_rows <- list()
evaluate_boundary <- function(selected_unknown, fraction, replicate, scenario) {
  index <- c(known_index, selected_unknown)
  outcome <- c(target_data$composite_event[known_index], rep(1L, length(selected_unknown)))
  result <- metrics(outcome, target_data$composite_prediction[index])
  result[, `:=`(
    cohort = target, unknown_death_fraction = fraction, replicate = replicate, scenario = scenario,
    confirmed_known_records = length(known_index), added_unknown_deaths = length(selected_unknown),
    total_unknown_alive_or_dead = length(unknown_index)
  )]
  result
}

boundary_rows[[1L]] <- evaluate_boundary(integer(), 0, 0L, "deterministic_lower_confirmed_only")
boundary_rows[[2L]] <- evaluate_boundary(unknown_index, 1, 0L, "deterministic_upper_all_unknown_deaths")
for (fraction in c(0.25, 0.50)) {
  for (replicate in seq_len(200L)) {
    set.seed(20260810L + as.integer(1000 * fraction) + replicate)
    selected <- unlist(lapply(sort(unique(target_data$landmark_wave[unknown_index])), function(wave) {
      candidates <- unknown_index[target_data$landmark_wave[unknown_index] == wave]
      number <- floor(fraction * length(candidates))
      if (number > 0) sample(candidates, number, replace = FALSE) else integer()
    }), use.names = FALSE)
    boundary_rows[[length(boundary_rows) + 1L]] <- evaluate_boundary(selected, fraction, replicate, "landmark_stratified_random_assignment")
  }
}

charls_boundary <- rbindlist(boundary_rows, fill = TRUE)
charls_boundary_summary <- charls_boundary[, .(
  repetitions = .N, records_median = median(records), events_median = median(events),
  event_rate_median = median(observed_risk), event_rate_low = min(observed_risk), event_rate_high = max(observed_risk),
  mean_prediction_median = median(mean_prediction), observed_minus_predicted_pp_median = median(observed_minus_predicted_pp),
  auc_median = median(auc), brier_median = median(brier),
  citl_median = median(calibration_intercept), citl_low = min(calibration_intercept), citl_high = max(calibration_intercept),
  slope_median = median(calibration_slope), total_unknown_alive_or_dead = max(total_unknown_alive_or_dead)
), by = .(cohort, unknown_death_fraction, scenario)]

elsa_path <- file.path(v21_dir, "ELSA_unknown_death_boundary_summary.csv")
if (!file.exists(elsa_path)) stop("Existing ELSA boundary summary not found: ", elsa_path)
elsa_boundary_summary <- fread(elsa_path)
elsa_boundary_summary[, cohort := "ELSA"]
if (!"mean_prediction_median" %in% names(elsa_boundary_summary)) elsa_boundary_summary[, mean_prediction_median := NA_real_]
if (!"observed_minus_predicted_pp_median" %in% names(elsa_boundary_summary)) elsa_boundary_summary[, observed_minus_predicted_pp_median := NA_real_]
if (!"total_unknown_alive_or_dead" %in% names(elsa_boundary_summary)) elsa_boundary_summary[, total_unknown_alive_or_dead := NA_integer_]
combined_boundary_summary <- rbindlist(list(charls_boundary_summary, elsa_boundary_summary), use.names = TRUE, fill = TRUE)

fwrite(charls_boundary, file.path(out_dir, "CHARLS_unknown_death_boundary_replicates.csv.gz"), compress = "gzip", na = "")
fwrite(charls_boundary_summary, file.path(out_dir, "CHARLS_unknown_death_boundary_summary.csv"), na = "")
fwrite(combined_boundary_summary, file.path(out_dir, "v22_CHARLS_ELSA_unknown_death_boundary_summary.csv"), na = "")

gates <- data.table(
  gate = c(
    "three_weighting_schemes_four_holdouts", "three_models_four_holdouts_equal_cohort", "all_fits_converged",
    "person_equal_total_contribution_constant", "charls_unknown_status_present", "charls_boundary_200_reps_each_midpoint",
    "existing_elsa_boundary_reused"
  ),
  passed = c(
    nrow(weighting) == 12 && uniqueN(weighting$development_weighting) == 3 && uniqueN(weighting$heldout) == 4,
    nrow(complexity) == 12 && uniqueN(complexity$model) == 3 && uniqueN(complexity$heldout) == 4,
    all(fit_audit$converged),
    max(person_weight_audit$max_minus_min) < 1e-10,
    length(unknown_index) > 0,
    nrow(charls_boundary[unknown_death_fraction %in% c(0.25, 0.50)]) == 400,
    file.exists(elsa_path)
  )
)
fwrite(gates, file.path(out_dir, "v22_robustness_gates.csv"), na = "")

provenance <- c(
  paste0("input=", data_path),
  paste0("existing_elsa_summary=", elsa_path),
  "primary_population=strict9_two_wave_primary_2to3y_observed",
  "target_evaluation=unweighted",
  "M2_status=exploratory_transparency_only",
  "CHARLS_boundary_status=scenario_not_imputation"
)
writeLines(provenance, file.path(out_dir, "v22_robustness_provenance.txt"))
writeLines(capture.output(sessionInfo()), file.path(out_dir, "sessionInfo.txt"))

print(gates)
cat("\nDevelopment-weighting M1 results:\n"); print(weighting)
cat("\nStrict-outcome model-complexity results:\n"); print(complexity)
cat("\nCHARLS boundary summary:\n"); print(charls_boundary_summary)
cat("Completed: ", format(Sys.time(), tz = "America/Chicago"), "\n", sep = "")
