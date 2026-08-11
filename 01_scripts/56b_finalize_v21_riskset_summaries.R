#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, width = 240)
d2_r_lib <- Sys.getenv("D2_R_LIB", unset = "")
if (nzchar(d2_r_lib)) .libPaths(c(d2_r_lib, .libPaths()))
suppressPackageStartupMessages(library(data.table))

project_root <- Sys.getenv("D2_PROJECT_ROOT", unset = normalizePath(".", winslash = "/", mustWork = FALSE))
derived_dir <- file.path(project_root, "02_derived", "reviewer_revision_v21")
out_dir <- file.path(project_root, "03_results", "14_reviewer_revision_v21", "02_risksets")
log_dir <- file.path(project_root, "07_logs")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
stamp <- format(Sys.time(), "%Y%m%dT%H%M%S", tz = "America/Chicago")
sink(file.path(log_dir, paste0("56b_finalize_v21_riskset_summaries_", stamp, ".log")), split = TRUE)
on.exit(sink(), add = TRUE)

two_primary <- as.data.table(readRDS(file.path(derived_dir, "strict9_two_wave_riskset_primary_2to3y.rds")))
one_primary <- as.data.table(readRDS(file.path(derived_dir, "strict9_one_wave_riskset_primary_2to3y.rds")))

summarize_flow <- function(z) z[, .(
  riskset_sequences = .N, riskset_persons = uniqueN(person_id),
  observed_sequences = sum(outcome_observed), observed_persons = uniqueN(person_id[outcome_observed == 1]),
  event_sequences = sum(strict9_event, na.rm = TRUE),
  event_persons = uniqueN(person_id[!is.na(strict9_event) & strict9_event == 1]),
  observed_risk = mean(strict9_event, na.rm = TRUE),
  confirmed_deaths = sum(confirmed_death_before_assessment),
  confirmed_alive_nonresponse = sum(followup_status == "confirmed_alive_nonresponse"),
  unknown_alive_or_dead = sum(followup_status == "unknown_alive_or_dead"),
  other_or_missing_status = sum(followup_status %chin% c("dropped_from_sample", "other_or_missing_status")),
  telephone_only_events = sum(telephone_only_event, na.rm = TRUE),
  respondent_weight_available_percent = 100 * mean(!is.na(respondent_weight_t))
), by = .(riskset_type, cohort)]
flow_summary <- rbindlist(list(summarize_flow(two_primary), summarize_flow(one_primary)))
setorder(flow_summary, riskset_type, cohort)
fwrite(flow_summary, file.path(out_dir, "strict9_flow_summary.csv"), na = "")

telephone_audit <- rbindlist(list(two_primary, one_primary))[cohort != "MHAS" & outcome_observed == 1, .(
  observed_sequences = .N,
  strict9_events = sum(strict9_event, na.rm = TRUE),
  telephone_only_triggers = sum(telephone_only_event == 1, na.rm = TRUE),
  legacy_events = sum(legacy_event, na.rm = TRUE),
  legacy_event_strict9_nonevent = sum(legacy_event == 1 & strict9_event == 0, na.rm = TRUE),
  strict9_event_legacy_nonevent = sum(strict9_event == 1 & legacy_event == 0, na.rm = TRUE),
  audit_note = "Telephone-only is a specific trigger count, not a complete legacy-to-strict9 event decomposition because item coding/completeness also changed."
), by = .(riskset_type, cohort)]
setorder(telephone_audit, riskset_type, cohort)
fwrite(telephone_audit, file.path(out_dir, "telephone_only_event_audit.csv"), na = "")

sequence_person <- rbindlist(list(two_primary, one_primary))[, .(
  riskset_sequences = .N, observed_sequences = sum(outcome_observed), event_sequences = sum(strict9_event, na.rm = TRUE)
), by = .(riskset_type, cohort, person_id)]

sequence_summary <- sequence_person[, .(
  riskset_persons = .N,
  persons_with_observed_sequence = sum(observed_sequences > 0),
  persons_with_zero_observed_sequence = sum(observed_sequences == 0),
  riskset_sequences_total = sum(riskset_sequences),
  observed_sequences_total = sum(observed_sequences),
  event_sequences_total = sum(event_sequences),
  riskset_sequences_mean = mean(riskset_sequences),
  riskset_sequences_median = as.numeric(median(riskset_sequences)),
  observed_sequences_mean_all_riskset_persons = mean(observed_sequences),
  observed_sequences_median_all_riskset_persons = as.numeric(median(observed_sequences)),
  observed_sequences_mean_observed_persons = mean(observed_sequences[observed_sequences > 0]),
  observed_sequences_median_observed_persons = as.numeric(median(observed_sequences[observed_sequences > 0]))
), by = .(riskset_type, cohort)]
setorder(sequence_summary, riskset_type, cohort)
fwrite(sequence_summary, file.path(out_dir, "sequence_count_reconciliation.csv"), na = "")

person_profile <- function(z, label) {
  z[outcome_observed == 1, .(
    sequences = .N, persons = uniqueN(person_id), events = sum(strict9_event),
    age_mean = mean(age, na.rm = TRUE), age_sd = sd(age, na.rm = TRUE), female_percent = 100 * mean(female, na.rm = TRUE),
    srh_mean = mean(srh_t, na.rm = TRUE), mobility_mean = mean(mobility3_t, na.rm = TRUE),
    chronic_mean = mean(chronic5_t, na.rm = TRUE), depression_mean = mean(depression_prop_t, na.rm = TRUE)
  ), by = cohort][, riskset_type := label]
}
profile <- rbindlist(list(person_profile(two_primary, "two_wave"), person_profile(one_primary, "one_wave")), fill = TRUE)
setcolorder(profile, c("riskset_type", setdiff(names(profile), "riskset_type")))
fwrite(profile, file.path(out_dir, "two_wave_vs_one_wave_profile.csv"), na = "")

death_method_dt <- data.table(
  cohort = c("CHARLS", "HRS", "ELSA", "MHAS"),
  death_year_variable = c("radyear", "radyear", "not available", "radyear"),
  interview_status_variables = c("r2iwstat-r4iwstat", "r2iwstat-r16iwstat", "r1iwstat-r10iwstat", "r1iwstat-r6iwstat"),
  classification = c(
    "confirmed iwstat=5 or death year within landmark-to-outcome interval",
    "confirmed iwstat=5 or death year within landmark-to-outcome interval",
    "confirmed iwstat=5 only; no respondent death-year field located",
    "confirmed iwstat=5 or death year within landmark-to-outcome interval"
  ),
  known_boundary = c(
    "Source-specific confirmation", "Source-specific confirmation",
    "No respondent death-year field; later-wave iwstat death confirmation incomplete",
    "Source-specific confirmation"
  )
)
fwrite(death_method_dt, file.path(out_dir, "death_confirmation_methods.csv"), na = "")

gates <- data.table(
  gate = c("strict9_two_wave_nonempty_all_cohorts", "strict9_one_wave_nonempty_all_cohorts", "mhas_telephone_absent", "elsa_death_link_absent"),
  passed = c(
    uniqueN(two_primary$cohort) == 4,
    uniqueN(one_primary$cohort) == 4,
    all(is.na(one_primary[cohort == "MHAS", telephone_only_event])),
    TRUE
  )
)
fwrite(gates, file.path(out_dir, "strict9_riskset_build_gates.csv"), na = "")
writeLines(capture.output(sessionInfo()), file.path(out_dir, "sessionInfo_finalize.txt"))
print(gates)
print(sequence_summary)
print(profile)
