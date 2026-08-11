#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, width = 240)
d2_r_lib <- Sys.getenv("D2_R_LIB", unset = "")
if (nzchar(d2_r_lib)) .libPaths(c(d2_r_lib, .libPaths()))
suppressPackageStartupMessages({
  library(data.table)
  library(haven)
})

project_root <- Sys.getenv("D2_PROJECT_ROOT", unset = normalizePath(".", winslash = "/", mustWork = FALSE))
derived_dir <- file.path(project_root, "02_derived", "reviewer_revision_v21")
out_dir <- file.path(project_root, "03_results", "14_reviewer_revision_v21", "02_risksets")
log_dir <- file.path(project_root, "07_logs")
for (d in c(derived_dir, out_dir, log_dir)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
stamp <- format(Sys.time(), "%Y%m%dT%H%M%S", tz = "America/Chicago")
sink(file.path(log_dir, paste0("56_build_v21_strict9_risksets_", stamp, ".log")), split = TRUE)
on.exit(sink(), add = TRUE)

chr_id <- function(z) {
  if (is.character(z)) return(z)
  if (is.numeric(z)) return(format(z, scientific = FALSE, trim = TRUE, digits = 22))
  as.character(z)
}
num <- function(z) suppressWarnings(as.numeric(z))
getv <- function(x, name) {
  if (!length(name) || is.na(name) || !name %in% names(x)) return(rep(NA_real_, nrow(x)))
  num(x[[name]])
}
valid_binary <- function(z) {
  z <- num(z); fifelse(z %in% 0:1, z, NA_real_)
}
valid_item <- valid_binary
valid_srh <- function(z) {
  z <- num(z); fifelse(z %in% 1:5, z, NA_real_)
}
valid_mobility_item <- function(z) {
  z <- num(z); fifelse(z == 0, 0, fifelse(z %in% c(1, 2), 1, NA_real_))
}
valid_proxy <- function(z) {
  z <- num(z); fifelse(z == 0, 0, fifelse(z %in% 1:3, 1, NA_real_))
}
valid_weight <- function(z) {
  z <- num(z); fifelse(is.finite(z) & z > 0, z, NA_real_)
}
valid_partnered <- function(z) {
  z <- num(z); fifelse(z %in% c(1, 2, 3), 1, fifelse(z %in% 4:8, 0, NA_real_))
}
education3 <- function(z, cohort) {
  z <- num(z)
  if (cohort == "HRS") return(fifelse(z == 1, 1, fifelse(z %in% 2:4, 2, fifelse(z == 5, 3, NA_real_))))
  fifelse(z %in% c(0, 1), 1, fifelse(z == 2, 2, fifelse(z == 3, 3, NA_real_)))
}
row_sum_complete <- function(...) as.numeric(rowSums(cbind(...), na.rm = FALSE))

configs <- list(
  CHARLS = list(
    cohort = "CHARLS", country = "China",
    path = Sys.getenv("CHARLS_DATA", unset = file.path(project_root, "data", "restricted", "H_CHARLS_D_Data.dta")),
    id = "ID", waves = 2:4, years = c(`2` = 2013, `3` = 2015, `4` = 2018),
    age = function(w) paste0("r", w, "agey"), adl = function(w) paste0("r", w, "adlfive"), iadl = function(w) paste0("r", w, "iadlza"),
    educ = "raeducl", depression = function(w) paste0("r", w, "cesd10"), depression_max = 30,
    srh = function(w) paste0("r", w, "shlt"), proxy = function(w) NA_character_
  ),
  HRS = list(
    cohort = "HRS", country = "United States",
    path = Sys.getenv("HRS_DATA", unset = file.path(project_root, "data", "restricted", "randhrs1992_2022v1.dta")),
    id = "hhidpn", waves = 2:16, years = setNames(seq(1994, 2022, by = 2), 2:16),
    age = function(w) paste0("r", w, "agey_b"), adl = function(w) paste0("r", w, "adl5a"), iadl = function(w) paste0("r", w, "iadl5a"),
    educ = "raeduc", depression = function(w) paste0("r", w, "cesd"), depression_max = 8,
    srh = function(w) paste0("r", w, "shlt"), proxy = function(w) paste0("r", w, "proxy")
  ),
  ELSA = list(
    cohort = "ELSA", country = "England",
    path = Sys.getenv("ELSA_DATA", unset = file.path(project_root, "data", "restricted", "gh_elsa_h.dta")),
    id = "idauniq", waves = 1:10,
    years = c(`1` = 2002, `2` = 2004, `3` = 2006, `4` = 2008, `5` = 2010, `6` = 2012, `7` = 2014, `8` = 2016, `9` = 2018, `10` = 2021),
    age = function(w) paste0("r", w, "agey"), adl = function(w) paste0("r", w, "adlfivea"), iadl = function(w) paste0("r", w, "iadlzaa"),
    educ = "raeducl", depression = function(w) paste0("r", w, "cesd"), depression_max = 8,
    srh = function(w) if (w == 3) "r3shlta" else paste0("r", w, "shlt"), proxy = function(w) paste0("r", w, "proxy")
  ),
  MHAS = list(
    cohort = "MHAS", country = "Mexico", path = Sys.getenv("MHAS_DATA", unset = file.path(project_root, "data", "restricted", "H_MHAS_d.dta")),
    id = "rahhidnp", waves = 1:6, years = c(`1` = 2001, `2` = 2003, `3` = 2012, `4` = 2015, `5` = 2018, `6` = 2021),
    age = function(w) paste0("r", w, "agey"), adl = function(w) paste0("r", w, "adlfivea"), iadl = function(w) paste0("r", w, "iadlfoura"),
    educ = "raeducl", depression = function(w) paste0("r", w, "cesd_m"), depression_max = 9,
    srh = function(w) paste0("r", w, "shlt"), proxy = function(w) paste0("r", w, "proxy")
  )
)

item_suffixes <- c("batha", "dressa", "eata", "beda", "toilta", "mealsa", "medsa", "moneya", "shopa")
phone_suffix <- "phonea"
time_suffixes <- c("mstat", "smoken", "chaira", "lifta", "stoopa", "hibpe", "diabe", "cancre", "stroke", "arthre", "wtresp")

strict_parts <- list(); one_parts <- list(); flow_parts <- list(); death_methods <- list()

for (cfg in configs) {
  cat("Building v2.1 risk sets for ", cfg$cohort, "\n", sep = "")
  meta <- read_dta(cfg$path, n_max = 0)
  vars <- c(cfg$id, "ragender", cfg$educ, "radyear", paste0("inw", cfg$waves), paste0("r", cfg$waves, "iwstat"))
  for (w in cfg$waves) {
    vars <- c(
      vars, cfg$age(w), cfg$adl(w), cfg$iadl(w), cfg$depression(w), cfg$srh(w), cfg$proxy(w),
      paste0("r", w, time_suffixes), paste0("r", w, item_suffixes), paste0("r", w, phone_suffix)
    )
  }
  available <- intersect(unique(na.omit(vars)), names(meta))
  x <- as.data.table(read_dta(cfg$path, col_select = all_of(available)))
  x[, person_id := chr_id(get(cfg$id))]
  female <- fifelse(getv(x, "ragender") == 2, 1, fifelse(getv(x, "ragender") == 1, 0, NA_real_))
  educ3 <- education3(getv(x, cfg$educ), cfg$cohort)
  death_year_all <- getv(x, "radyear")

  item_cache <- list()
  for (w in cfg$waves) {
    item_mat <- do.call(cbind, lapply(paste0("r", w, item_suffixes), function(v) valid_item(getv(x, v))))
    colnames(item_mat) <- item_suffixes
    complete <- rowSums(is.na(item_mat)) == 0
    count <- rowSums(item_mat, na.rm = FALSE)
    phone_var <- paste0("r", w, phone_suffix)
    phone <- if (phone_var %in% names(x)) valid_item(getv(x, phone_var)) else rep(NA_real_, nrow(x))
    item_cache[[as.character(w)]] <- list(complete = complete, count = count, phone = phone)
  }

  make_part <- function(t, riskset_type) {
    nextw <- t + 1L
    prev <- t - 1L
    curr <- item_cache[[as.character(t)]]
    fut <- item_cache[[as.character(nextw)]]
    prior <- if (as.character(prev) %in% names(item_cache)) item_cache[[as.character(prev)]] else NULL
    curr_in <- getv(x, paste0("inw", t)) == 1
    next_in <- getv(x, paste0("inw", nextw)) == 1
    prior_in <- if (!is.null(prior)) getv(x, paste0("inw", prev)) == 1 else rep(FALSE, nrow(x))
    age <- getv(x, cfg$age(t))

    current_base <- curr_in & !is.na(age) & age >= 60 & curr$complete & curr$count == 0
    if (riskset_type == "two_wave") {
      eligible <- current_base & prior_in & prior$complete & prior$count == 0
    } else {
      eligible <- current_base
    }
    idx <- which(eligible %in% TRUE)
    if (!length(idx)) return(NULL)

    prediction_horizon <- unname(cfg$years[as.character(nextw)] - cfg$years[as.character(t)])
    history_horizon <- if (riskset_type == "two_wave") unname(cfg$years[as.character(t)] - cfg$years[as.character(prev)]) else NA_real_
    primary_horizon <- prediction_horizon >= 1.5 & prediction_horizon <= 3.5
    if (riskset_type == "two_wave") primary_horizon <- primary_horizon & history_horizon >= 1.5 & history_horizon <= 3.5

    outcome_observed <- next_in[idx] & fut$complete[idx]
    event_strict9 <- fifelse(outcome_observed, as.integer(fut$count[idx] > 0), NA_integer_)
    telephone_only_event <- fifelse(
      outcome_observed & is.finite(fut$phone[idx]),
      as.integer(fut$count[idx] == 0 & fut$phone[idx] == 1), NA_integer_
    )
    future_iwstat <- getv(x, paste0("r", nextw, "iwstat"))[idx]
    status_death <- future_iwstat == 5
    year_death <- is.finite(death_year_all[idx]) & death_year_all[idx] > unname(cfg$years[as.character(t)]) & death_year_all[idx] <= unname(cfg$years[as.character(nextw)])
    death_before_assessment <- !outcome_observed & (status_death | year_death)
    followup_status <- fifelse(outcome_observed, "observed_function",
      fifelse(death_before_assessment, "confirmed_death_before_assessment",
        fifelse(future_iwstat == 4, "confirmed_alive_nonresponse",
          fifelse(future_iwstat == 7, "dropped_from_sample",
            fifelse(future_iwstat == 9, "unknown_alive_or_dead", "other_or_missing_status")))))

    pv <- function(suffix) if (!is.null(prior)) getv(x, paste0("r", prev, suffix))[idx] else rep(NA_real_, length(idx))
    tv <- function(suffix) getv(x, paste0("r", t, suffix))[idx]
    partnered_prev <- valid_partnered(pv("mstat")); partnered_t <- valid_partnered(tv("mstat"))
    srh_prev <- if (!is.null(prior)) valid_srh(getv(x, cfg$srh(prev))[idx]) else rep(NA_real_, length(idx))
    srh_t <- valid_srh(getv(x, cfg$srh(t))[idx])
    smoking_prev <- valid_binary(pv("smoken")); smoking_t <- valid_binary(tv("smoken"))
    mobility_prev <- row_sum_complete(valid_mobility_item(pv("chaira")), valid_mobility_item(pv("lifta")), valid_mobility_item(pv("stoopa")))
    mobility_t <- row_sum_complete(valid_mobility_item(tv("chaira")), valid_mobility_item(tv("lifta")), valid_mobility_item(tv("stoopa")))
    chronic_prev <- row_sum_complete(valid_binary(pv("hibpe")), valid_binary(pv("diabe")), valid_binary(pv("cancre")), valid_binary(pv("stroke")), valid_binary(pv("arthre")))
    chronic_t <- row_sum_complete(valid_binary(tv("hibpe")), valid_binary(tv("diabe")), valid_binary(tv("cancre")), valid_binary(tv("stroke")), valid_binary(tv("arthre")))
    dep_prev_raw <- if (!is.null(prior)) getv(x, cfg$depression(prev))[idx] else rep(NA_real_, length(idx))
    dep_t_raw <- getv(x, cfg$depression(t))[idx]
    dep_prev <- fifelse(dep_prev_raw >= 0 & dep_prev_raw <= cfg$depression_max, dep_prev_raw / cfg$depression_max, NA_real_)
    dep_t <- fifelse(dep_t_raw >= 0 & dep_t_raw <= cfg$depression_max, dep_t_raw / cfg$depression_max, NA_real_)
    proxy_t <- if (is.na(cfg$proxy(t))) rep(NA_real_, length(idx)) else valid_proxy(getv(x, cfg$proxy(t))[idx])
    prior_strict9_free <- if (!is.null(prior)) as.integer(prior_in[idx] & prior$complete[idx] & prior$count[idx] == 0) else NA_integer_
    legacy_next_adl <- getv(x, cfg$adl(nextw))[idx]
    legacy_next_iadl <- getv(x, cfg$iadl(nextw))[idx]
    legacy_outcome_observed <- next_in[idx] & is.finite(legacy_next_adl) & is.finite(legacy_next_iadl)
    legacy_event <- fifelse(legacy_outcome_observed, as.integer(legacy_next_adl > 0 | legacy_next_iadl > 0), NA_integer_)

    out <- data.table(
      cohort = cfg$cohort, country = cfg$country, person_id = x$person_id[idx], riskset_type = riskset_type,
      prior_wave = if (riskset_type == "two_wave") prev else NA_integer_, landmark_wave = t, outcome_wave = nextw,
      prior_year = if (riskset_type == "two_wave") unname(cfg$years[as.character(prev)]) else NA_real_,
      landmark_year = unname(cfg$years[as.character(t)]), outcome_year = unname(cfg$years[as.character(nextw)]),
      history_horizon_years = history_horizon, prediction_horizon_years = prediction_horizon,
      primary_horizon = primary_horizon, analysis_set = ifelse(primary_horizon, "primary_2to3y", "extension_interval"),
      prior_strict9_free = prior_strict9_free,
      outcome_observed = as.integer(outcome_observed), strict9_event = event_strict9,
      telephone_only_event = telephone_only_event, legacy_outcome_observed = as.integer(legacy_outcome_observed), legacy_event = legacy_event,
      next_strict9_count = fifelse(outcome_observed, fut$count[idx], NA_real_),
      future_inw = as.integer(next_in[idx]), future_iwstat = future_iwstat, death_year = death_year_all[idx],
      confirmed_death_before_assessment = as.integer(death_before_assessment), death_status_evidence = as.integer(status_death), death_year_evidence = as.integer(year_death),
      followup_status = followup_status,
      composite_known = as.integer(outcome_observed | death_before_assessment),
      composite_event = fifelse(death_before_assessment, 1L, fifelse(outcome_observed, event_strict9, NA_integer_)),
      age = age[idx], female = female[idx], education3 = educ3[idx],
      partnered_prev = partnered_prev, partnered_t = partnered_t, srh_prev = srh_prev, srh_t = srh_t,
      mobility3_prev = mobility_prev, mobility3_t = mobility_t, chronic5_prev = chronic_prev, chronic5_t = chronic_t,
      smoking_prev = smoking_prev, smoking_t = smoking_t, depression_prop_prev = dep_prev, depression_prop_t = dep_t,
      proxy_t = proxy_t, respondent_weight_t = valid_weight(tv("wtresp"))
    )
    out[, `:=`(
      delta_partnered = partnered_t - partnered_prev, delta_srh = srh_t - srh_prev,
      delta_mobility3 = mobility3_t - mobility3_prev, new_chronic5 = pmax(chronic5_t - chronic5_prev, 0),
      delta_smoking = smoking_t - smoking_prev, delta_depression_prop = depression_prop_t - depression_prop_prev
    )]
    out
  }

  two_t <- cfg$waves[cfg$waves > min(cfg$waves) & cfg$waves < max(cfg$waves)]
  one_t <- cfg$waves[cfg$waves < max(cfg$waves)]
  for (t in two_t) {
    part <- make_part(t, "two_wave")
    if (!is.null(part)) strict_parts[[length(strict_parts) + 1L]] <- part
  }
  for (t in one_t) {
    part <- make_part(t, "one_wave")
    if (!is.null(part)) one_parts[[length(one_parts) + 1L]] <- part
  }

  death_methods[[length(death_methods) + 1L]] <- data.table(
    cohort = cfg$cohort,
    death_year_variable = ifelse("radyear" %in% names(x), "radyear", "not available"),
    interview_status_variables = paste0("r", min(cfg$waves), "iwstat-r", max(cfg$waves), "iwstat"),
    classification = "confirmed iwstat=5 or death year within landmark-to-outcome interval",
    known_boundary = ifelse(cfg$cohort == "ELSA", "No respondent death-year field; later-wave iwstat death confirmation incomplete", "Death-year/status coverage differs by cohort")
  )
  rm(x, meta, item_cache); gc()
}

two_all <- rbindlist(strict_parts, use.names = TRUE, fill = TRUE)
one_all <- rbindlist(one_parts, use.names = TRUE, fill = TRUE)
setorder(two_all, cohort, person_id, landmark_wave)
setorder(one_all, cohort, person_id, landmark_wave)
two_primary <- two_all[primary_horizon == TRUE]
one_primary <- one_all[primary_horizon == TRUE]

for (zname in c("two_primary", "one_primary")) {
  z <- get(zname)
  z[, riskset_sequences_person := .N, by = .(cohort, person_id)]
  z[, observed_sequences_person := sum(outcome_observed), by = .(cohort, person_id)]
  z[, person_equal_weight := 1 / .N, by = .(cohort, person_id)]
  z[, first_eligible_sequence := as.integer(landmark_wave == min(landmark_wave)), by = .(cohort, person_id)]
  assign(zname, z)
}

saveRDS(two_all, file.path(derived_dir, "strict9_two_wave_riskset_all_intervals.rds"), compress = "xz")
saveRDS(two_primary, file.path(derived_dir, "strict9_two_wave_riskset_primary_2to3y.rds"), compress = "xz")
saveRDS(one_all, file.path(derived_dir, "strict9_one_wave_riskset_all_intervals.rds"), compress = "xz")
saveRDS(one_primary, file.path(derived_dir, "strict9_one_wave_riskset_primary_2to3y.rds"), compress = "xz")

summarize_flow <- function(z) z[, .(
  riskset_sequences = .N, riskset_persons = uniqueN(person_id),
  observed_sequences = sum(outcome_observed), observed_persons = uniqueN(person_id[outcome_observed == 1]),
  event_sequences = sum(strict9_event, na.rm = TRUE), event_persons = uniqueN(person_id[!is.na(strict9_event) & strict9_event == 1]),
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

flow_landmark <- rbindlist(list(two_primary, one_primary))[, .(
  riskset_sequences = .N, riskset_persons = uniqueN(person_id), observed_sequences = sum(outcome_observed),
  event_sequences = sum(strict9_event, na.rm = TRUE), confirmed_deaths = sum(confirmed_death_before_assessment),
  unknown_alive_or_dead = sum(followup_status == "unknown_alive_or_dead"),
  telephone_only_events = sum(telephone_only_event, na.rm = TRUE)
), by = .(riskset_type, cohort, landmark_wave, landmark_year, outcome_year, prediction_horizon_years)]
setorder(flow_landmark, riskset_type, cohort, landmark_wave)
fwrite(flow_landmark, file.path(out_dir, "strict9_flow_by_landmark.csv"), na = "")

telephone_audit <- rbindlist(list(two_primary, one_primary))[cohort != "MHAS" & outcome_observed == 1, .(
  observed_sequences = .N, strict9_events = sum(strict9_event), legacy_events_among_legacy_observed = sum(legacy_event, na.rm = TRUE),
  telephone_only_events = sum(telephone_only_event, na.rm = TRUE),
  telephone_only_percent_of_legacy_events = 100 * sum(telephone_only_event, na.rm = TRUE) / sum(legacy_event, na.rm = TRUE)
), by = .(riskset_type, cohort)]
fwrite(telephone_audit, file.path(out_dir, "telephone_only_event_audit.csv"), na = "")

sequence_person <- rbindlist(list(two_primary, one_primary))[, .(
  riskset_sequences = .N, observed_sequences = sum(outcome_observed), event_sequences = sum(strict9_event, na.rm = TRUE)
), by = .(riskset_type, cohort, person_id)]
sequence_summary <- sequence_person[, .(
  riskset_persons = .N, persons_with_observed_sequence = sum(observed_sequences > 0), persons_with_zero_observed_sequence = sum(observed_sequences == 0),
  riskset_sequences_total = sum(riskset_sequences), observed_sequences_total = sum(observed_sequences), event_sequences_total = sum(event_sequences),
  riskset_sequences_mean = mean(riskset_sequences), riskset_sequences_median = as.numeric(median(riskset_sequences)),
  observed_sequences_mean_all_riskset_persons = mean(observed_sequences), observed_sequences_median_all_riskset_persons = as.numeric(median(observed_sequences)),
  observed_sequences_mean_observed_persons = mean(observed_sequences[observed_sequences > 0]),
  observed_sequences_median_observed_persons = as.numeric(median(observed_sequences[observed_sequences > 0]))
), by = .(riskset_type, cohort)]
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

death_method_dt <- rbindlist(death_methods, fill = TRUE)
fwrite(death_method_dt, file.path(out_dir, "death_confirmation_methods.csv"), na = "")

gates <- data.table(
  gate = c("strict9_two_wave_nonempty_all_cohorts", "strict9_one_wave_nonempty_all_cohorts", "mhas_telephone_absent", "elsa_death_link_absent"),
  passed = c(
    uniqueN(two_primary$cohort) == 4,
    uniqueN(one_primary$cohort) == 4,
    all(is.na(one_primary[cohort == "MHAS", telephone_only_event])),
    death_method_dt[cohort == "ELSA", death_year_variable] == "not available"
  )
)
fwrite(gates, file.path(out_dir, "strict9_riskset_build_gates.csv"), na = "")
writeLines(capture.output(sessionInfo()), file.path(out_dir, "sessionInfo.txt"))
print(gates)
print(flow_summary)
print(sequence_summary)
