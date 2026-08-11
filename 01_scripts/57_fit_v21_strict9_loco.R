#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, width = 260)
d2_r_lib <- Sys.getenv("D2_R_LIB", unset = "")
if (nzchar(d2_r_lib)) .libPaths(c(d2_r_lib, .libPaths()))
suppressPackageStartupMessages(library(data.table))

project_root <- Sys.getenv("D2_PROJECT_ROOT", unset = normalizePath(".", winslash = "/", mustWork = FALSE))
derived_dir <- file.path(project_root, "02_derived", "reviewer_revision_v21")
out_dir <- file.path(project_root, "03_results", "14_reviewer_revision_v21", "03_strict9_loco")
model_dir <- file.path(out_dir, "models")
log_dir <- file.path(project_root, "07_logs")
for (d in c(out_dir, model_dir, log_dir)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
stamp <- format(Sys.time(), "%Y%m%dT%H%M%S", tz = "America/Chicago")
sink(file.path(log_dir, paste0("57_fit_v21_strict9_loco_", stamp, ".log")), split = TRUE)
on.exit(sink(), add = TRUE)
set.seed(20260809)

clip <- function(p) pmin(pmax(as.numeric(p), 1e-6), 1 - 1e-6)
fit_prep <- function(train, features, add_missing = TRUE) {
  med <- vapply(features, function(v) median(train[[v]], na.rm = TRUE), numeric(1))
  if (any(!is.finite(med))) stop("Non-finite training median: ", paste(names(med)[!is.finite(med)], collapse = ","))
  miss <- if (add_missing) features[vapply(features, function(v) anyNA(train[[v]]), logical(1))] else character()
  list(features = features, medians = med, missing_indicators = miss)
}
apply_prep <- function(x, prep) {
  z <- copy(x[, prep$features, with = FALSE])
  for (v in prep$features) {
    ii <- is.na(z[[v]])
    if (v %in% prep$missing_indicators) z[, (paste0("miss_", v)) := as.numeric(ii)]
    if (any(ii)) set(z, which(ii), v, prep$medians[[v]])
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
  g <- cumsum(c(TRUE, diff(p) != 0))
  pos <- rowsum(w * (y == 1), g, reorder = FALSE)[, 1]
  neg <- rowsum(w * (y == 0), g, reorder = FALSE)[, 1]
  sum(pos * (cumsum(neg) - neg + 0.5 * neg)) / (sum(pos) * sum(neg))
}
calibration_irls <- function(y, p, w = rep(1, length(y))) {
  lp <- qlogis(clip(p)); a <- 0
  for (iter in seq_len(50L)) {
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
  y <- as.integer(y[keep]); p <- clip(p[keep]); w <- as.numeric(w[keep])
  er <- weighted.mean(y, w); mp <- weighted.mean(p, w); bs <- weighted.mean((y - p)^2, w)
  cal <- calibration_irls(y, p, w)
  data.table(
    records = length(y), events = sum(y), weighted_events = sum(w * y), event_rate = er, mean_prediction = mp,
    auc = auc_rank(y, p, w), brier = bs, scaled_brier = 1 - bs / (er * (1 - er)),
    calibration_intercept = unname(cal[["citl"]]), calibration_slope = unname(cal[["slope"]]),
    effective_sample_size = sum(w)^2 / sum(w^2)
  )
}

datasets <- list(
  two_wave = as.data.table(readRDS(file.path(derived_dir, "strict9_two_wave_riskset_primary_2to3y.rds"))),
  one_wave = as.data.table(readRDS(file.path(derived_dir, "strict9_one_wave_riskset_primary_2to3y.rds")))
)
for (nm in names(datasets)) {
  datasets[[nm]][, age10 := age / 10]
  datasets[[nm]][, person_key := paste(cohort, person_id, sep = "::")]
}

m0 <- c("age10", "female")
m1 <- c("age10", "female", "education3", "partnered_t", "srh_t", "mobility3_t", "chronic5_t", "smoking_t", "depression_prop_t", "prediction_horizon_years")
specs <- list(M0 = m0, M1 = m1)
heldouts <- c("CHARLS", "HRS", "ELSA", "MHAS")

pred_rows <- list(); perf_rows <- list(); coef_rows <- list(); prep_rows <- list(); fit_rows <- list()

for (riskset_name in names(datasets)) {
  d <- datasets[[riskset_name]]
  observed <- d[outcome_observed == 1 & !is.na(strict9_event)]
  for (heldout in heldouts) {
    cat("Fitting ", riskset_name, " held out ", heldout, "\n", sep = "")
    train <- observed[cohort != heldout]
    test_all <- d[cohort == heldout]
    test_obs <- test_all[outcome_observed == 1 & !is.na(strict9_event)]
    ww <- cohort_balance_weights(train)
    for (model_name in names(specs)) {
      features <- specs[[model_name]]
      prep <- fit_prep(train, features, TRUE)
      tr <- apply_prep(train, prep)
      te_all <- apply_prep(test_all, prep)
      fit <- suppressWarnings(glm(y ~ ., data = cbind(y = train$strict9_event, tr), weights = ww,
                                  family = binomial(), control = glm.control(maxit = 100)))
      if (!isTRUE(fit$converged)) stop("Model failed: ", riskset_name, "/", heldout, "/", model_name)
      pp_all <- clip(predict(fit, newdata = te_all, type = "response"))
      pred_dt <- test_all[, .(
        riskset_type, cohort, country, person_id, person_key, landmark_wave, landmark_year, outcome_year,
        prediction_horizon_years, outcome_observed, strict9_event, respondent_weight_t,
        confirmed_death_before_assessment, followup_status, composite_known, composite_event,
        telephone_only_event, legacy_event
      )]
      pred_dt[, `:=`(model = model_name, prediction = pp_all)]
      pred_rows[[length(pred_rows) + 1L]] <- pred_dt

      obs_idx <- which(test_all$outcome_observed == 1 & !is.na(test_all$strict9_event))
      pp_obs <- pp_all[obs_idx]
      for (evaluation_weighting in c("unweighted", "respondent_weighted")) {
        ew <- if (evaluation_weighting == "unweighted") rep(1, nrow(test_obs)) else test_obs$respondent_weight_t
        mm <- metrics(test_obs$strict9_event, pp_obs, ew)
        mm[, `:=`(
          riskset_type = riskset_name, heldout = heldout, model = model_name,
          development_weighting = "equal_cohort", evaluation_weighting = evaluation_weighting
        )]
        perf_rows[[length(perf_rows) + 1L]] <- mm
      }

      coef_rows[[length(coef_rows) + 1L]] <- data.table(
        riskset_type = riskset_name, heldout = heldout, model = model_name,
        term = names(coef(fit)), estimate = unname(coef(fit))
      )
      prep_rows[[length(prep_rows) + 1L]] <- data.table(
        riskset_type = riskset_name, heldout = heldout, model = model_name,
        feature = prep$features, training_median = unname(prep$medians),
        missing_indicator = prep$features %in% prep$missing_indicators
      )
      fit_rows[[length(fit_rows) + 1L]] <- data.table(
        riskset_type = riskset_name, heldout = heldout, model = model_name,
        development_records = nrow(train), development_persons = uniqueN(train$person_key), development_events = sum(train$strict9_event),
        heldout_riskset_records = nrow(test_all), heldout_observed_records = nrow(test_obs), heldout_persons = uniqueN(test_all$person_id), heldout_events = sum(test_obs$strict9_event),
        coefficient_count = length(coef(fit)), missing_indicator_count = length(prep$missing_indicators), converged = fit$converged
      )
      saveRDS(list(model = fit, preprocessor = prep, features = features),
              file.path(model_dir, paste0(riskset_name, "_heldout_", tolower(heldout), "_", model_name, ".rds")), compress = "xz")
    }
  }
}

predictions <- rbindlist(pred_rows, use.names = TRUE, fill = TRUE)
performance <- rbindlist(perf_rows, use.names = TRUE, fill = TRUE)
coefficients <- rbindlist(coef_rows, use.names = TRUE, fill = TRUE)
preprocessing <- rbindlist(prep_rows, use.names = TRUE, fill = TRUE)
fit_audit <- rbindlist(fit_rows, use.names = TRUE, fill = TRUE)
setorder(performance, riskset_type, heldout, model, evaluation_weighting)
setorder(coefficients, riskset_type, heldout, model, term)

saveRDS(predictions, file.path(derived_dir, "v21_strict9_loco_predictions_all_risksets.rds"), compress = "xz")
fwrite(predictions, file.path(out_dir, "v21_strict9_loco_predictions_all_risksets.csv.gz"), compress = "gzip", na = "")
fwrite(performance, file.path(out_dir, "v21_strict9_loco_performance_point.csv"), na = "")
fwrite(coefficients, file.path(out_dir, "v21_M0_M1_fold_coefficients.csv"), na = "")
fwrite(preprocessing, file.path(out_dir, "v21_M0_M1_preprocessing_specification.csv"), na = "")
fwrite(fit_audit, file.path(out_dir, "v21_M0_M1_fit_audit.csv"), na = "")

# ELSA strict-9 composite death-bound analysis using a model developed only in the other cohorts.
d <- datasets[["two_wave"]]
train_comp <- d[cohort != "ELSA" & composite_known == 1 & !is.na(composite_event)]
elsa <- d[cohort == "ELSA"]
prep_comp <- fit_prep(train_comp, m1, TRUE)
xtr <- apply_prep(train_comp, prep_comp); xel <- apply_prep(elsa, prep_comp)
fit_comp <- suppressWarnings(glm(y ~ ., data = cbind(y = train_comp$composite_event, xtr),
                                 weights = cohort_balance_weights(train_comp), family = binomial(),
                                 control = glm.control(maxit = 100)))
if (!isTRUE(fit_comp$converged)) stop("ELSA composite development model failed")
elsa[, composite_prediction := clip(predict(fit_comp, newdata = xel, type = "response"))]
base_idx <- which(elsa$composite_known == 1 & !is.na(elsa$composite_event))
unknown_idx <- which(elsa$followup_status == "unknown_alive_or_dead")

bound_rows <- list()
eval_bound <- function(selected_unknown, fraction, replicate, scenario) {
  idx <- c(base_idx, selected_unknown)
  y <- c(elsa$composite_event[base_idx], rep(1L, length(selected_unknown)))
  p <- elsa$composite_prediction[idx]
  mm <- metrics(y, p)
  mm[, `:=`(
    unknown_death_fraction = fraction, replicate = replicate, scenario = scenario,
    confirmed_known_records = length(base_idx), added_unknown_deaths = length(selected_unknown),
    total_unknown_alive_or_dead = length(unknown_idx)
  )]
  mm
}
bound_rows[[1L]] <- eval_bound(integer(), 0, 0L, "deterministic_lower_confirmed_only")
bound_rows[[2L]] <- eval_bound(unknown_idx, 1, 0L, "deterministic_upper_all_unknown_deaths")
for (fraction in c(0.25, 0.50)) {
  for (r in seq_len(200L)) {
    set.seed(20260809L + as.integer(1000 * fraction) + r)
    selected <- unlist(lapply(sort(unique(elsa$landmark_wave[unknown_idx])), function(w) {
      ids <- unknown_idx[elsa$landmark_wave[unknown_idx] == w]
      n_take <- floor(fraction * length(ids))
      if (n_take > 0) sample(ids, n_take, replace = FALSE) else integer()
    }), use.names = FALSE)
    bound_rows[[length(bound_rows) + 1L]] <- eval_bound(selected, fraction, r, "landmark_stratified_random_assignment")
  }
}
death_bounds <- rbindlist(bound_rows, fill = TRUE)
death_bound_summary <- death_bounds[, .(
  repetitions = .N, records_median = median(records), events_median = median(events),
  event_rate_median = median(event_rate), event_rate_low = min(event_rate), event_rate_high = max(event_rate),
  auc_median = median(auc), brier_median = median(brier),
  citl_median = median(calibration_intercept), citl_low = min(calibration_intercept), citl_high = max(calibration_intercept),
  slope_median = median(calibration_slope)
), by = .(unknown_death_fraction, scenario)]
fwrite(death_bounds, file.path(out_dir, "ELSA_unknown_death_boundary_replicates.csv.gz"), compress = "gzip", na = "")
fwrite(death_bound_summary, file.path(out_dir, "ELSA_unknown_death_boundary_summary.csv"), na = "")

gates <- data.table(
  gate = c("all_8_M0_M1_fits_converged", "strict9_performance_all_4_cohorts", "respondent_weighted_rows_present", "elsa_death_bounds_complete"),
  passed = c(
    nrow(fit_audit) == 16 && all(fit_audit$converged),
    uniqueN(performance$riskset_type) == 2 && uniqueN(performance$heldout) == 4,
    nrow(performance[evaluation_weighting == "respondent_weighted"]) == 16,
    nrow(death_bounds[unknown_death_fraction %in% c(0.25, 0.50)]) == 400
  )
)
fwrite(gates, file.path(out_dir, "v21_strict9_loco_gates.csv"), na = "")
writeLines(capture.output(sessionInfo()), file.path(out_dir, "sessionInfo.txt"))
print(gates)
print(performance)
print(death_bound_summary)
