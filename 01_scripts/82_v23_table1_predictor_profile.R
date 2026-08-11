#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, width = 240)
d2_r_lib <- Sys.getenv("D2_R_LIB", unset = "")
if (nzchar(d2_r_lib)) .libPaths(c(d2_r_lib, .libPaths()))
suppressPackageStartupMessages(library(data.table))

root <- Sys.getenv("D2_PROJECT_ROOT", unset = normalizePath(".", winslash = "/", mustWork = FALSE))
data_path <- file.path(root, "02_derived", "reviewer_revision_v21", "strict9_two_wave_riskset_primary_2to3y.rds")
flow_path <- file.path(root, "03_results", "14_reviewer_revision_v21", "02_risksets", "strict9_flow_summary.csv")
out_dir <- file.path(root, "03_results", "16_submission_upgrade_v23", "02_submission_tables", "main")
log_dir <- file.path(root, "07_logs")
for (path in c(out_dir, log_dir)) dir.create(path, recursive = TRUE, showWarnings = FALSE)
stamp <- format(Sys.time(), "%Y%m%dT%H%M%S", tz = "America/Chicago")
sink(file.path(log_dir, paste0("82_v23_table1_predictor_profile_", stamp, ".log")), split = TRUE)
on.exit(sink(), add = TRUE)

cohorts <- c("CHARLS", "ELSA", "HRS", "MHAS")
d <- as.data.table(readRDS(data_path))
observed <- d[outcome_observed == 1 & !is.na(strict9_event)]
setorder(observed, cohort, person_id, landmark_year, landmark_wave, outcome_year)
person <- observed[, .SD[1L], by = .(cohort, person_id)]

m1_predictors <- c("age", "female", "education3", "partnered_t", "srh_t", "mobility3_t", "chronic5_t", "smoking_t", "depression_prop_t", "prediction_horizon_years")
person[, any_M1_predictor_missing := as.integer(rowSums(is.na(.SD)) > 0), .SDcols = m1_predictors]

numeric_rows <- list()
add_numeric <- function(cohort, characteristic, statistic, value, denominator = NA_real_, missing = NA_real_) {
  numeric_rows[[length(numeric_rows) + 1L]] <<- data.table(
    cohort = cohort, characteristic = characteristic, statistic = statistic,
    value = as.numeric(value), denominator = as.numeric(denominator), missing = as.numeric(missing)
  )
}

for (cohort_name in cohorts) {
  z <- person[cohort == cohort_name]
  n <- nrow(z)
  add_numeric(cohort_name, "Participants, No.", "count", n, n, 0)
  add_numeric(cohort_name, "Age, mean (SD), y", "mean", mean(z$age, na.rm = TRUE), sum(!is.na(z$age)), sum(is.na(z$age)))
  add_numeric(cohort_name, "Age, mean (SD), y", "sd", sd(z$age, na.rm = TRUE), sum(!is.na(z$age)), sum(is.na(z$age)))

  for (specification in list(
    list(variable = "female", label = "Female, No. (%)", value = 1),
    list(variable = "education3", label = "Education: low, No. (%)", value = 1),
    list(variable = "education3", label = "Education: middle, No. (%)", value = 2),
    list(variable = "education3", label = "Education: high, No. (%)", value = 3),
    list(variable = "partnered_t", label = "Partnered, No. (%)", value = 1),
    list(variable = "smoking_t", label = "Current smoking, No. (%)", value = 1),
    list(variable = "any_M1_predictor_missing", label = "Any M1 predictor missing, No. (%)", value = 1),
    list(variable = "proxy_t", label = "Proxy interview, No. (%)", value = 1)
  )) {
    values <- z[[specification$variable]]
    denominator <- sum(!is.na(values)); count <- sum(values == specification$value, na.rm = TRUE)
    add_numeric(cohort_name, specification$label, "count", count, denominator, sum(is.na(values)))
    add_numeric(cohort_name, specification$label, "percent", if (denominator > 0) 100 * count / denominator else NA_real_, denominator, sum(is.na(values)))
  }

  for (specification in list(
    list(variable = "srh_t", label = "Self-rated health score, mean (SD)"),
    list(variable = "mobility3_t", label = "Mobility difficulty score, mean (SD)"),
    list(variable = "chronic5_t", label = "Chronic condition count, mean (SD)"),
    list(variable = "depression_prop_t", label = "Depression symptom proportion, mean (SD)")
  )) {
    values <- z[[specification$variable]]
    add_numeric(cohort_name, specification$label, "mean", mean(values, na.rm = TRUE), sum(!is.na(values)), sum(is.na(values)))
    add_numeric(cohort_name, specification$label, "sd", sd(values, na.rm = TRUE), sum(!is.na(values)), sum(is.na(values)))
  }

  values <- z$prediction_horizon_years
  add_numeric(cohort_name, "Prediction horizon, median (IQR), y", "median", median(values, na.rm = TRUE), sum(!is.na(values)), sum(is.na(values)))
  add_numeric(cohort_name, "Prediction horizon, median (IQR), y", "q25", quantile(values, 0.25, na.rm = TRUE, names = FALSE), sum(!is.na(values)), sum(is.na(values)))
  add_numeric(cohort_name, "Prediction horizon, median (IQR), y", "q75", quantile(values, 0.75, na.rm = TRUE, names = FALSE), sum(!is.na(values)), sum(is.na(values)))
}

numeric <- rbindlist(numeric_rows)
fwrite(numeric, file.path(out_dir, "Table1_participant_predictor_profile_numeric_long.csv"), na = "")

fmt_count <- function(value) format(round(value), big.mark = ",", scientific = FALSE, trim = TRUE)
fmt_mean_sd <- function(mean_value, sd_value, digits = 1) {
  format_string <- paste0("%.", digits, "f (%.", digits, "f)")
  sprintf(format_string, mean_value, sd_value)
}
fmt_count_percent <- function(count, percent, denominator) {
  if (!is.finite(denominator) || denominator <= 0) return("NA")
  sprintf("%s (%.1f)", fmt_count(count), percent)
}
fmt_median_iqr <- function(median_value, q25, q75) sprintf("%.1f (%.1f-%.1f)", median_value, q25, q75)

get_values <- function(characteristic_input, statistic_input) {
  selected <- numeric[get("characteristic") == characteristic_input & get("statistic") == statistic_input]
  setNames(selected$value, selected$cohort)[cohorts]
}
get_denominators <- function(characteristic_input, statistic_input) {
  selected <- numeric[get("characteristic") == characteristic_input & get("statistic") == statistic_input]
  setNames(selected$denominator, selected$cohort)[cohorts]
}

display_rows <- list()
add_display <- function(characteristic, values) {
  row <- data.table(characteristic = characteristic)
  for (i in seq_along(cohorts)) row[, (cohorts[i]) := values[i]]
  display_rows[[length(display_rows) + 1L]] <<- row
}

add_display("Participants, No.", vapply(get_values("Participants, No.", "count"), fmt_count, character(1)))
add_display("Age, mean (SD), y", mapply(fmt_mean_sd, get_values("Age, mean (SD), y", "mean"), get_values("Age, mean (SD), y", "sd"), MoreArgs = list(digits = 1)))
for (label in c("Female, No. (%)", "Education: low, No. (%)", "Education: middle, No. (%)", "Education: high, No. (%)",
                "Partnered, No. (%)", "Current smoking, No. (%)", "Any M1 predictor missing, No. (%)", "Proxy interview, No. (%)")) {
  add_display(label, mapply(fmt_count_percent, get_values(label, "count"), get_values(label, "percent"), get_denominators(label, "count")))
}
for (label in c("Self-rated health score, mean (SD)", "Mobility difficulty score, mean (SD)",
                "Chronic condition count, mean (SD)")) {
  add_display(label, mapply(fmt_mean_sd, get_values(label, "mean"), get_values(label, "sd"), MoreArgs = list(digits = 1)))
}
label <- "Depression symptom proportion, mean (SD)"
add_display(label, mapply(fmt_mean_sd, get_values(label, "mean"), get_values(label, "sd"), MoreArgs = list(digits = 2)))
label <- "Prediction horizon, median (IQR), y"
add_display(label, mapply(fmt_median_iqr, get_values(label, "median"), get_values(label, "q25"), get_values(label, "q75")))

display <- rbindlist(display_rows, use.names = TRUE, fill = TRUE)
fwrite(display, file.path(out_dir, "Table1_participant_predictor_profile_display.csv"), na = "")

flow <- fread(flow_path)[riskset_type == "two_wave"]
gates <- data.table(
  gate = c(
    "one_earliest_observed_sequence_per_person", "all_four_cohorts", "person_count_matches_v21",
    "no_episode_flow_rows", "four_recast_continuous_predictors", "five_table_columns"
  ),
  passed = c(
    nrow(person) == uniqueN(observed, by = c("cohort", "person_id")),
    identical(sort(unique(person$cohort)), sort(cohorts)),
    nrow(person) == sum(flow$observed_persons),
    !any(grepl("sequence|episode|death|status", display$characteristic, ignore.case = TRUE)),
    sum(grepl("mean \\(SD\\)", display$characteristic)) == 5L,
    ncol(display) == 5L
  )
)
if (!all(gates$passed)) stop("Table 1 gates failed: ", paste(gates[passed == FALSE, gate], collapse = ","))
fwrite(gates, file.path(dirname(out_dir), "v23_table1_profile_gates.csv"), na = "")
writeLines(capture.output(sessionInfo()), file.path(dirname(out_dir), "sessionInfo_table1.txt"))
print(gates)
print(display)

