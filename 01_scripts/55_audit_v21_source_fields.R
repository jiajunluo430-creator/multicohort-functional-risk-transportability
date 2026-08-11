#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, width = 240)
d2_r_lib <- Sys.getenv("D2_R_LIB", unset = "")
if (nzchar(d2_r_lib)) .libPaths(c(d2_r_lib, .libPaths()))
suppressPackageStartupMessages({
  library(data.table)
  library(haven)
})

project_root <- Sys.getenv("D2_PROJECT_ROOT", unset = normalizePath(".", winslash = "/", mustWork = FALSE))
out_dir <- file.path(project_root, "03_results", "14_reviewer_revision_v21", "01_source_audit")
log_dir <- file.path(project_root, "07_logs")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
stamp <- format(Sys.time(), "%Y%m%dT%H%M%S", tz = "America/Chicago")
sink(file.path(log_dir, paste0("55_audit_v21_source_fields_", stamp, ".log")), split = TRUE)
on.exit(sink(), add = TRUE)

num <- function(z) suppressWarnings(as.numeric(z))
getv <- function(x, name) {
  if (!name %in% names(x)) return(rep(NA_real_, nrow(x)))
  num(x[[name]])
}
lab <- function(z) {
  x <- attr(z, "label", exact = TRUE)
  if (is.null(x)) "" else as.character(x)
}
value_labels <- function(z) {
  x <- attr(z, "labels", exact = TRUE)
  if (is.null(x)) return(data.table(value = numeric(), value_label = character()))
  data.table(value = as.numeric(x), value_label = names(x))
}

configs <- list(
  CHARLS = list(
    path = Sys.getenv("CHARLS_DATA", unset = file.path(project_root, "data", "restricted", "H_CHARLS_D_Data.dta")),
    waves = 2:4, adl = function(w) paste0("r", w, "adlfive"), iadl = function(w) paste0("r", w, "iadlza")
  ),
  HRS = list(
    path = Sys.getenv("HRS_DATA", unset = file.path(project_root, "data", "restricted", "randhrs1992_2022v1.dta")),
    waves = 2:16, adl = function(w) paste0("r", w, "adl5a"), iadl = function(w) paste0("r", w, "iadl5a")
  ),
  ELSA = list(
    path = Sys.getenv("ELSA_DATA", unset = file.path(project_root, "data", "restricted", "gh_elsa_h.dta")),
    waves = 1:10, adl = function(w) paste0("r", w, "adlfivea"), iadl = function(w) paste0("r", w, "iadlzaa")
  ),
  MHAS = list(
    path = Sys.getenv("MHAS_DATA", unset = file.path(project_root, "data", "restricted", "H_MHAS_d.dta")),
    waves = 1:6, adl = function(w) paste0("r", w, "adlfivea"), iadl = function(w) paste0("r", w, "iadlfoura")
  )
)

item_suffixes <- c(
  bath = "batha", dress = "dressa", eat = "eata", bed = "beda", toilet = "toilta",
  meal = "mealsa", medication = "medsa", money = "moneya", shopping = "shopa", telephone = "phonea"
)

inventory <- list()
counts <- list()
labels_out <- list()
concordance <- list()
death_inventory <- list()

for (cohort in names(configs)) {
  cfg <- configs[[cohort]]
  cat("Auditing ", cohort, "\n", sep = "")
  meta <- read_dta(cfg$path, n_max = 0)
  meta_names <- names(meta)
  meta_labels <- vapply(meta, lab, character(1))

  expected <- unlist(lapply(cfg$waves, function(w) {
    c(
      setNames(paste0("r", w, unname(item_suffixes)), paste0(names(item_suffixes), "_w", w)),
      adl_aggregate = cfg$adl(w), iadl_aggregate = cfg$iadl(w),
      respondent_weight = paste0("r", w, "wtresp"), interview_status = paste0("r", w, "iwstat"), in_wave = paste0("inw", w)
    )
  }), use.names = TRUE)
  expected <- unique(unname(expected))

  for (w in cfg$waves) {
    for (item in names(item_suffixes)) {
      v <- paste0("r", w, item_suffixes[[item]])
      inventory[[length(inventory) + 1L]] <- data.table(
        cohort = cohort, wave = w, domain = ifelse(item %in% c("bath", "dress", "eat", "bed", "toilet"), "ADL", "IADL"),
        item = item, variable = v, available = v %in% meta_names,
        variable_label = if (v %in% meta_names) meta_labels[[v]] else ""
      )
    }
  }

  candidate <- unique(c(
    meta_names[grepl("death|died|deceas|mort|vital|exit|radyear|dyear|iwstat", meta_names, ignore.case = TRUE)],
    meta_names[grepl("death|died|deceas|mort|vital|exit", meta_labels, ignore.case = TRUE)]
  ))
  for (v in candidate) {
    death_inventory[[length(death_inventory) + 1L]] <- data.table(
      cohort = cohort, variable = v, variable_label = meta_labels[[v]], class = paste(class(meta[[v]]), collapse = ";")
    )
    vl <- value_labels(meta[[v]])
    if (nrow(vl)) {
      vl[, `:=`(cohort = cohort, variable = v, variable_label = meta_labels[[v]])]
      labels_out[[length(labels_out) + 1L]] <- vl
    }
  }

  available <- intersect(unique(c(expected, candidate)), meta_names)
  x <- as.data.table(read_dta(cfg$path, col_select = all_of(available)))

  item_vars <- intersect(unlist(lapply(cfg$waves, function(w) paste0("r", w, unname(item_suffixes)))), names(x))
  for (v in item_vars) {
    z <- getv(x, v)
    tab <- data.table(value = z)[, .N, by = value]
    tab[, `:=`(cohort = cohort, variable = v)]
    counts[[length(counts) + 1L]] <- tab
  }

  for (w in cfg$waves) {
    adl_vars <- paste0("r", w, unname(item_suffixes[c("bath", "dress", "eat", "bed", "toilet")]))
    iadl4_vars <- paste0("r", w, unname(item_suffixes[c("meal", "medication", "money", "shopping")]))
    phone_var <- paste0("r", w, item_suffixes[["telephone"]])
    all9 <- c(adl_vars, iadl4_vars)
    if (!all(all9 %in% names(x))) {
      concordance[[length(concordance) + 1L]] <- data.table(
        cohort = cohort, wave = w, complete_9item_n = 0L, strict9_difficulty_n = NA_integer_,
        adl_exact_match_percent = NA_real_, iadl4_vs_legacy_exact_match_percent = NA_real_, telephone_available = phone_var %in% names(x),
        telephone_only_legacy_difficulty_n = NA_integer_
      )
      next
    }
    mat9 <- do.call(cbind, lapply(all9, function(v) getv(x, v)))
    complete9 <- rowSums(is.na(mat9)) == 0 & apply(mat9, 1, function(z) all(z %in% 0:1))
    strict_adl <- rowSums(mat9[, seq_len(5), drop = FALSE], na.rm = FALSE)
    strict_iadl4 <- rowSums(mat9[, 6:9, drop = FALSE], na.rm = FALSE)
    strict9 <- strict_adl + strict_iadl4
    legacy_adl <- getv(x, cfg$adl(w))
    legacy_iadl <- getv(x, cfg$iadl(w))
    phone <- if (phone_var %in% names(x)) getv(x, phone_var) else rep(NA_real_, nrow(x))
    valid_adl <- complete9 & is.finite(legacy_adl)
    valid_iadl <- complete9 & is.finite(legacy_iadl)
    telephone_only <- complete9 & strict9 == 0 & is.finite(phone) & phone == 1 & is.finite(legacy_iadl) & legacy_iadl > 0
    concordance[[length(concordance) + 1L]] <- data.table(
      cohort = cohort, wave = w,
      complete_9item_n = sum(complete9), strict9_difficulty_n = sum(strict9[complete9] > 0),
      adl_exact_match_percent = if (sum(valid_adl)) 100 * mean((strict_adl[valid_adl] > 0) == (legacy_adl[valid_adl] > 0)) else NA_real_,
      iadl4_vs_legacy_exact_match_percent = if (sum(valid_iadl)) 100 * mean((strict_iadl4[valid_iadl] > 0) == (legacy_iadl[valid_iadl] > 0)) else NA_real_,
      telephone_available = phone_var %in% names(x),
      telephone_only_legacy_difficulty_n = sum(telephone_only, na.rm = TRUE)
    )
  }
  rm(x, meta); gc()
}

inv <- rbindlist(inventory, fill = TRUE)
cnt <- rbindlist(counts, fill = TRUE)
vlab <- rbindlist(labels_out, fill = TRUE)
conc <- rbindlist(concordance, fill = TRUE)
dinv <- rbindlist(death_inventory, fill = TRUE)
setorder(inv, cohort, wave, domain, item)
setorder(cnt, cohort, variable, value)
setorder(conc, cohort, wave)
setorder(dinv, cohort, variable)

fwrite(inv, file.path(out_dir, "item_variable_inventory.csv"), na = "")
fwrite(cnt, file.path(out_dir, "item_value_counts.csv"), na = "")
fwrite(conc, file.path(out_dir, "strict9_aggregate_concordance.csv"), na = "")
fwrite(dinv, file.path(out_dir, "death_vital_status_candidate_inventory.csv"), na = "")
fwrite(vlab, file.path(out_dir, "death_vital_status_value_labels.csv"), na = "")

risk <- readRDS(file.path(project_root, "02_derived", "reviewer_revision_v2", "reviewer_riskset_primary_2to3y.rds"))
risk_schema <- data.table(variable = names(risk), class = vapply(risk, function(z) paste(class(z), collapse = ";"), character(1)))
fwrite(risk_schema, file.path(out_dir, "v2_riskset_schema.csv"), na = "")

gate <- data.table(
  gate = c("common_9_items_available_all_configured_waves", "telephone_absent_mhas", "respondent_weight_present_all_cohorts"),
  passed = c(
    all(inv[item != "telephone", available]),
    all(!inv[cohort == "MHAS" & item == "telephone", available]),
    all(conc[, unique(cohort)] %in% names(configs))
  )
)
fwrite(gate, file.path(out_dir, "v21_source_feasibility_gates.csv"), na = "")

writeLines(capture.output(sessionInfo()), file.path(out_dir, "sessionInfo.txt"))
print(gate)
print(conc)
