#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, width = 240)
d2_r_lib <- Sys.getenv("D2_R_LIB", unset = "")
if (nzchar(d2_r_lib)) .libPaths(c(d2_r_lib, .libPaths()))
suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(patchwork)
  library(scales)
})

root <- Sys.getenv("D2_PROJECT_ROOT", unset = normalizePath(".", winslash = "/", mustWork = FALSE))
v21 <- file.path(root, "03_results", "14_reviewer_revision_v21")
v22 <- file.path(root, "03_results", "15_submission_upgrade_v22")
v23 <- file.path(root, "03_results", "16_submission_upgrade_v23")
table_source <- file.path(v23, "02_submission_tables", "figure_sources")
fig_root <- file.path(root, "04_figures", "submission_v25")
vec_dir <- file.path(fig_root, "vector")
png_dir <- file.path(fig_root, "review_previews")
supp_png_dir <- file.path(fig_root, "supplement_previews")
source_dir <- file.path(fig_root, "source_data")
log_dir <- file.path(root, "07_logs")
for (path in c(vec_dir, png_dir, supp_png_dir, source_dir, log_dir)) dir.create(path, recursive = TRUE, showWarnings = FALSE)
stamp <- format(Sys.time(), "%Y%m%dT%H%M%S", tz = "America/Chicago")
sink(file.path(log_dir, paste0("102_make_submission_figures_v25_", stamp, ".log")), split = TRUE)
on.exit(sink(), add = TRUE)

cohort_levels <- c("CHARLS", "ELSA", "HRS", "MHAS")
cohort_cols <- c(CHARLS = "#C44E52", ELSA = "#2A9D8F", HRS = "#4C78A8", MHAS = "#7A5195")
flow_cols <- c(
  "Observed function" = "#2C7FB8", "Confirmed death" = "#636363",
  "Unknown vital status" = "#B7791F", "Other unavailable function" = "#59636E"
)
weight_cols <- c(equal_cohort = "#153B5B", sequence_weighted = "#6B8E23", person_equal = "#D95F02")
cohort_shapes <- c(CHARLS = 16, ELSA = 17, HRS = 15, MHAS = 18)
cohort_linetypes <- c(CHARLS = "solid", ELSA = "dashed", HRS = "dotdash", MHAS = "longdash")

theme_pub <- function(base_size = 9) theme_minimal(base_family = "Arial", base_size = base_size) +
  theme(
    panel.grid.minor = element_blank(), panel.grid.major = element_line(linewidth = 0.25, colour = "#E4E7EB"),
    plot.title = element_text(face = "bold", size = base_size + 1.1, colour = "#15202B", margin = margin(b = 5)),
    plot.subtitle = element_text(size = base_size - 0.25, colour = "#4B5563", margin = margin(b = 5)),
    axis.title = element_text(face = "bold", colour = "#263238"), axis.text = element_text(colour = "#263238"),
    strip.text = element_text(face = "bold", colour = "#15202B"), strip.background = element_rect(fill = "#EDF3F7", colour = NA),
    legend.position = "bottom", legend.title = element_text(face = "bold"), plot.margin = margin(7, 8, 7, 8)
  )

save_plot <- function(name, plot, width, height) {
  ggsave(file.path(vec_dir, paste0(name, ".svg")), plot, width = width, height = height, units = "in", device = svglite::svglite, bg = "white")
  ggsave(file.path(vec_dir, paste0(name, ".pdf")), plot, width = width, height = height, units = "in", device = cairo_pdf, bg = "white")
  ggsave(file.path(png_dir, paste0(name, ".png")), plot, width = width, height = height, units = "in", dpi = 300, bg = "white")
  if (grepl("^eFigure_", name)) {
    ggsave(file.path(supp_png_dir, paste0(name, ".png")), plot, width = width, height = height, units = "in", dpi = 180, bg = "white")
  }
}

flow <- fread(file.path(v21, "02_risksets", "strict9_flow_summary.csv"))
ci <- fread(file.path(v21, "04_cluster_bootstrap", "v21_strict9_person_cluster_bootstrap_300_ci.csv"))
bins <- fread(file.path(v21, "05_flexible_calibration", "v21_strict9_calibration_bins_cluster_ci.csv"))
curves <- fread(file.path(v21, "05_flexible_calibration", "v21_strict9_flexible_calibration_curves_cluster_robust.csv"))
random_detail <- fread(file.path(v21, "06_validation_design_contrast", "v21_strict9_random_split_performance_100.csv.gz"))
temporal <- fread(file.path(v21, "08_temporal_all_windows", "v21_strict9_temporal_updating_all_windows.csv"))
window_scope <- fread(file.path(v21, "08_temporal_all_windows", "v21_strict9_raw_performance_primary_vs_all_windows.csv"))
point <- fread(file.path(v21, "03_strict9_loco", "v21_strict9_loco_performance_point.csv"))
gap_summary <- fread(file.path(table_source, "Figure2C_probability_gap_bootstrap.csv"))
failure_distribution <- fread(file.path(table_source, "Figure2D_random_split_country_failure_distribution.csv"))
indication_consequence <- fread(file.path(table_source, "Figure4A_indication_consequence_at_threshold_020.csv"))
update_intercept <- fread(file.path(table_source, "Figure4BC_intercept_update_by_independent_event_persons.csv"))
dca_delta <- fread(file.path(table_source, "Figure4D_DCA_delta_outer_summary.csv"))
death_bounds <- fread(file.path(v22, "01_robustness", "v22_CHARLS_ELSA_unknown_death_boundary_summary.csv"))
weighting <- fread(file.path(v22, "01_robustness", "v22_development_weighting_M1_point.csv"))

# Figure 1: landmark, complete country holdout, and reconciled flow.
timeline <- data.table(
  x = 1:3, label = c("t−1", "t", "t+1"),
  detail = c("Difficulty-free\nprior assessment", "Difficulty-free\nprediction landmark", "New difficulty in\n5 ADL + 4 IADL items")
)
p1a <- ggplot(timeline, aes(x, 1)) +
  annotate("segment", x = 1, xend = 3, y = 1, yend = 1, arrow = grid::arrow(length = grid::unit(0.11, "in")), linewidth = 0.8, colour = "#153B5B") +
  geom_point(size = 5, shape = 21, fill = "white", colour = "#153B5B", stroke = 1.15) +
  geom_text(aes(label = label), y = 1.24, fontface = "bold", size = 3.5) +
  geom_text(aes(label = detail), y = 0.75, size = 2.85, lineheight = 0.95) +
  annotate("text", x = 2, y = 0.38, label = "Primary history and prediction intervals: 2–3 years", size = 2.65, colour = "#4B5563") +
  coord_cartesian(xlim = c(0.65, 3.35), ylim = c(0.25, 1.36), clip = "off") +
  labs(title = "A  Two-wave prediction episode") + theme_void(base_family = "Arial", base_size = 9) +
  theme(plot.title = element_text(face = "bold", size = 10), plot.margin = margin(7, 8, 7, 8))

rotations <- rbindlist(lapply(cohort_levels, function(target) data.table(
  target = target, development = paste(setdiff(cohort_levels, target), collapse = " + ")
)))
rotations[, y := rev(seq_len(.N))]
p1b <- ggplot(rotations) +
  geom_label(aes(x = 1, y = y, label = development), fill = "#E8F0F5", colour = "#153B5B", linewidth = 0, size = 2.65, fontface = "bold", label.padding = grid::unit(0.14, "lines")) +
  geom_segment(aes(x = 1.42, xend = 1.76, y = y, yend = y), arrow = grid::arrow(length = grid::unit(0.08, "in")), colour = "#59636E", linewidth = .55) +
  geom_label(aes(x = 2.15, y = y, label = target, fill = target), colour = "white", linewidth = 0, size = 2.8, fontface = "bold", label.padding = grid::unit(0.14, "lines")) +
  annotate("text", x = 1, y = 4.62, label = "Development: 3 cohorts", fontface = "bold", size = 2.8) +
  annotate("text", x = 2.15, y = 4.62, label = "Held-out target cohort", fontface = "bold", size = 2.8) +
  annotate("text", x = 1.58, y = 0.35, label = "Target excluded from preprocessing and fitting", size = 2.45, colour = "#4B5563") +
  scale_fill_manual(values = cohort_cols, guide = "none") + coord_cartesian(xlim = c(.45, 2.62), ylim = c(.15, 4.85), clip = "off") +
  labs(title = "B  Four complete-cohort holdouts") + theme_void(base_family = "Arial", base_size = 9) +
  theme(plot.title = element_text(face = "bold", size = 10), plot.margin = margin(7, 8, 7, 8))

flow_primary <- flow[riskset_type == "two_wave"]
flow_primary[, other_unavailable := riskset_sequences - observed_sequences - confirmed_deaths - unknown_alive_or_dead]
if (any(flow_primary$other_unavailable < 0)) stop("Figure 1 flow categories do not reconcile")
flow_display <- flow_primary[, .(
  cohort = factor(cohort, levels = rev(cohort_levels)), riskset_sequences,
  observed_sequences, observed_proportion = observed_sequences / riskset_sequences,
  confirmed_deaths, unknown_alive_or_dead, other_unavailable
)]
p1c <- ggplot(flow_display, aes(y = cohort)) +
  geom_segment(aes(x = 0, xend = observed_proportion, yend = cohort), linewidth = 1.4, colour = "#B9D5E8") +
  geom_point(aes(x = observed_proportion), shape = 21, size = 3.2, stroke = .8, fill = "#2C7FB8", colour = "#153B5B") +
  geom_text(aes(x = observed_proportion, label = percent(observed_proportion, accuracy = .1)), nudge_x = -.018,
            hjust = 1, size = 2.45, fontface = "bold", colour = "#153B5B") +
  geom_vline(xintercept = 1.015, colour = "#9AA6B2", linewidth = .35) +
  geom_text(aes(x = 1.075, label = comma(riskset_sequences)), size = 2.35, colour = "#263238") +
  geom_text(aes(x = 1.205, label = comma(confirmed_deaths)), size = 2.35, colour = flow_cols[["Confirmed death"]]) +
  geom_text(aes(x = 1.335, label = comma(unknown_alive_or_dead)), size = 2.35, colour = flow_cols[["Unknown vital status"]]) +
  geom_text(aes(x = 1.465, label = comma(other_unavailable)), size = 2.35, colour = flow_cols[["Other unavailable function"]]) +
  annotate("text", x = c(1.075, 1.205, 1.335, 1.465), y = 4.62,
           label = c("Risk set", "Confirmed\ndeath", "Unknown\nvital status", "Other\nunavailable"),
           size = 2.15, fontface = "bold", lineheight = .92, colour = "#263238") +
  scale_x_continuous(labels = percent_format(accuracy = 25), breaks = c(0, .25, .5, .75, 1), limits = c(0, 1.53), expand = c(0, 0)) +
  coord_cartesian(ylim = c(.55, 4.75), clip = "off") +
  labs(title = "C  Observed follow-up and unavailable outcomes among 146,605 eligible sequences",
       subtitle = "Dots show observed functional follow-up; aligned columns reconcile unavailable outcomes within each cohort risk set.",
       x = "Observed functional follow-up, % of eligible sequences", y = NULL) + theme_pub(8.5) +
  theme(panel.grid.major.y = element_blank(), legend.position = "none", plot.margin = margin(7, 12, 7, 8))

fig1 <- (p1a / p1b / p1c) + plot_layout(heights = c(.75, 1.05, 1.35), guides = "collect") +
  plot_annotation(title = "Figure 1. Landmark design, complete-cohort holdout, and analysis flow",
                  theme = theme(plot.title = element_text(family = "Arial", face = "bold", size = 12))) &
  theme(legend.position = "bottom")
save_plot("Figure_1", fig1, 7.6, 8.6)

fwrite(rotations, file.path(source_dir, "Figure_1B_country_holdout_rotations.csv"))
fwrite(flow_display, file.path(source_dir, "Figure_1C_flow_status.csv"))

# Figure 2: incremental value, probability transport, and pooled concealment.
increment <- ci[riskset_type == "two_wave" & model == "M1_MINUS_M0"]
increment[, heldout := factor(heldout, levels = rev(cohort_levels))]
p2a <- ggplot(increment, aes(auc_median, heldout, colour = heldout)) +
  geom_vline(xintercept = 0, linetype = 2, colour = "#555555") +
  geom_errorbarh(aes(xmin = auc_lower_95, xmax = auc_upper_95), height = .16, linewidth = .6) + geom_point(size = 2.5) +
  scale_colour_manual(values = cohort_cols, guide = "none") +
  labs(title = "A  Incremental discrimination", x = "ΔAUC for M1 vs age + sex (95% CI)", y = NULL) + theme_pub()

p2b <- ggplot(increment, aes(brier_median, heldout, colour = heldout)) +
  geom_vline(xintercept = 0, linetype = 2, colour = "#555555") +
  geom_errorbarh(aes(xmin = brier_lower_95, xmax = brier_upper_95), height = .16, linewidth = .6) + geom_point(size = 2.5) +
  scale_colour_manual(values = cohort_cols, guide = "none") +
  labs(title = "B  Change in Brier score", subtitle = "Negative values favor M1.", x = "ΔBrier score for M1 vs age + sex (95% CI)", y = NULL) + theme_pub()

gap_summary[, heldout := factor(heldout, levels = rev(cohort_levels))]
p2c <- ggplot(gap_summary, aes(gap_median, heldout, colour = heldout)) +
  geom_vline(xintercept = 0, linetype = 2, colour = "#555555") +
  geom_errorbarh(aes(xmin = gap_lower_95, xmax = gap_upper_95), height = .16, linewidth = .6) + geom_point(size = 2.6) +
  scale_colour_manual(values = cohort_cols, guide = "none") +
  labs(title = "C  Absolute-risk transport", subtitle = "Positive = underprediction; negative = overprediction.",
       x = "Observed minus predicted risk, percentage points (95% CI)", y = NULL) + theme_pub()

p2d <- ggplot(failure_distribution, aes(factor(countries_lenient_failure, levels = 0:4), percent_repetitions)) +
  geom_col(width = .66, fill = "#153B5B") + geom_text(aes(label = paste0(round(percent_repetitions), "%")), vjust = -0.4, size = 3) +
  scale_y_continuous(labels = label_percent(scale = 1), limits = c(0, max(failure_distribution$percent_repetitions) * 1.42), expand = c(0, 0)) +
  annotate("label", x = 1.05, y = max(failure_distribution$percent_repetitions) * 1.30,
           label = "Pooled rule passed: 100/100\n≥1 cohort-specific calibration error concealed: 99/100", hjust = 0, size = 2.45,
           fill = "#F4F7F9", colour = "#263238", linewidth = .2) +
  labs(title = "D  Calibration errors hidden by pooled random splits", subtitle = "Descriptive region: |CITL| ≤0.20 and slope 0.80–1.20.",
       x = "Cohort-specific evaluations outside the region per split", y = "Random splits, %") + theme_pub()

fig2 <- (p2a | p2b) / (p2c | p2d) +
  plot_annotation(title = "Figure 2. Current health improved discrimination but absolute risk did not transport uniformly",
                  theme = theme(plot.title = element_text(family = "Arial", face = "bold", size = 12)))
save_plot("Figure_2", fig2, 7.8, 6.6)

fwrite(increment, file.path(source_dir, "Figure_2AB_incremental_value.csv"))
fwrite(gap_summary, file.path(source_dir, "Figure_2C_probability_gap.csv"))
fwrite(failure_distribution, file.path(source_dir, "Figure_2D_failure_distribution.csv"))

# Figure 3: pre-update flexible calibration.
calibration_curves <- curves[riskset_type == "two_wave" & model == "M1"]
calibration_bins <- bins[riskset_type == "two_wave" & model == "M1"]
calibration_curves[, heldout := factor(heldout, cohort_levels)]
calibration_bins[, heldout := factor(heldout, cohort_levels)]
annotation <- point[riskset_type == "two_wave" & model == "M1" & evaluation_weighting == "unweighted", .(
  heldout, label = sprintf("Observed %.1f%%\nPredicted %.1f%%", 100 * event_rate, 100 * mean_prediction)
)]
annotation[, interpretation := fcase(
  heldout == "CHARLS", "Underprediction",
  heldout == "MHAS", "Overprediction",
  default = NA_character_
)]
annotation[!is.na(interpretation), label := paste0(interpretation, "\n", label)]
annotation[, `:=`(heldout = factor(heldout, cohort_levels), x = Inf, y = -Inf)]
fig3 <- ggplot(calibration_curves, aes(nominal_prediction, flexible_observed_risk, colour = heldout, fill = heldout)) +
  geom_abline(slope = 1, intercept = 0, linetype = 2, colour = "#555555", linewidth = .5) +
  geom_ribbon(aes(ymin = lower_95_cluster, ymax = upper_95_cluster), alpha = .14, colour = NA) + geom_line(linewidth = .9) +
  geom_errorbar(data = calibration_bins, aes(x = mean_prediction, ymin = observed_lower_95_cluster, ymax = observed_upper_95_cluster),
                inherit.aes = FALSE, width = 0, colour = "#15202B", linewidth = .42) +
  geom_point(data = calibration_bins, aes(mean_prediction, observed_risk), inherit.aes = FALSE, colour = "#15202B", fill = "white", shape = 21, size = 2.05, stroke = .65) +
  geom_label(data = annotation, aes(x = x, y = y, label = label), inherit.aes = FALSE, hjust = 1.05, vjust = -.28,
             size = 2.65, lineheight = .95, fill = "white", colour = "#263238", label.size = .18) +
  facet_wrap(~heldout, ncol = 2, scales = "free") + scale_colour_manual(values = cohort_cols, guide = "none") + scale_fill_manual(values = cohort_cols, guide = "none") +
  scale_x_continuous(labels = percent_format(accuracy = 1)) + scale_y_continuous(labels = percent_format(accuracy = 1)) +
  coord_cartesian(clip = "off") +
  labs(title = "Figure 3. Calibration before target-population updating",
       subtitle = "Natural-spline curves with person-cluster robust 95% bands; open points are equal-frequency risk groups.\nAxes differ across cohorts.",
       x = "Predicted risk", y = "Observed risk") + theme_pub(9.3) +
  theme(plot.margin = margin(8, 15, 12, 8))
save_plot("Figure_3", fig3, 7.5, 6.8)

fwrite(calibration_curves, file.path(source_dir, "Figure_3_flexible_calibration_curves.csv"))
fwrite(calibration_bins, file.path(source_dir, "Figure_3_calibration_bins.csv"))

# Figure 4: primary equal-cohort probability and decision consequences.
indication_consequence[, cohort := factor(cohort, cohort_levels)]
indication_primary <- indication_consequence[development_weighting == "equal_cohort"]
indication_person <- indication_consequence[development_weighting == "person_equal"]
indication_primary[, `:=`(
  direction = fifelse(observed_minus_predicted_pp >= 0, "under", "over"),
  gap_label = sprintf("%.1f pp %s", absolute_probability_gap_pp,
                      fifelse(observed_minus_predicted_pp >= 0, "under", "over"))
)]

p4_gap <- copy(gap_summary)
p4_gap[, `:=`(
  cohort = factor(as.character(heldout), levels = rev(cohort_levels)),
  absolute_gap = abs(gap_median),
  absolute_lower = pmin(abs(gap_lower_95), abs(gap_upper_95)),
  absolute_upper = pmax(abs(gap_lower_95), abs(gap_upper_95)),
  direction_label = sprintf("%.1f pp %s", abs(gap_median), fifelse(gap_median >= 0, "underprediction", "overprediction"))
)]

p4a <- ggplot(p4_gap, aes(absolute_gap, cohort, colour = cohort)) +
  geom_errorbarh(aes(xmin = absolute_lower, xmax = absolute_upper), height = .16, linewidth = .6) +
  geom_point(size = 2.7) +
  geom_text(aes(x = absolute_upper + .22, label = direction_label), hjust = 0, size = 2.45, fontface = "bold", show.legend = FALSE) +
  scale_colour_manual(values = cohort_cols, guide = "none") +
  scale_x_continuous(expand = expansion(mult = c(.02, .27))) +
  coord_cartesian(clip = "off") +
  labs(title = "A  Pre-update absolute probability error",
       subtitle = "Dots and 95% CIs; labels show error direction.",
       x = "Absolute observed-predicted risk gap, percentage points", y = NULL) + theme_pub(8.7) +
  theme(panel.grid.major.y = element_blank(), plot.margin = margin(7, 18, 7, 8))

up <- update_intercept[method %in% c("none", "intercept_only")]
up[, cohort := factor(cohort, cohort_levels)]
up[, event_persons := median_calibration_event_persons_median_across_outer]
raw_update <- up[method == "none", .(
  cohort, stage = "Before updating",
  abs_citl = median_abs_citl_median_across_outer,
  abs_citl_lower = median_abs_citl_lower_95_outer,
  abs_citl_upper = median_abs_citl_upper_95_outer
)]
largest_update <- up[method == "intercept_only" & abs(calibration_fraction_total_persons - .60) < 1e-8, .(
  cohort, stage = "After intercept update",
  abs_citl = median_abs_citl_median_across_outer,
  abs_citl_lower = median_abs_citl_lower_95_outer,
  abs_citl_upper = median_abs_citl_upper_95_outer,
  delta_brier = median_delta_brier_vs_raw_median_across_outer,
  delta_brier_lower = median_delta_brier_vs_raw_lower_95_outer,
  delta_brier_upper = median_delta_brier_vs_raw_upper_95_outer,
  calibration_persons = median_calibration_persons_median_across_outer,
  calibration_event_persons = median_calibration_event_persons_median_across_outer
)]
citl_pair <- rbindlist(list(
  raw_update,
  largest_update[, .(cohort, stage, abs_citl, abs_citl_lower, abs_citl_upper)]
), use.names = TRUE)
citl_pair[, stage := factor(stage, c("Before updating", "After intercept update"))]

p4b <- ggplot(citl_pair, aes(stage, abs_citl, colour = cohort, group = cohort, shape = cohort)) +
  geom_line(linewidth = .75, alpha = .85) +
  geom_errorbar(aes(ymin = abs_citl_lower, ymax = abs_citl_upper), width = .08, linewidth = .45) +
  geom_point(size = 2.5, fill = "white") +
  scale_colour_manual(values = cohort_cols, guide = "none") +
  scale_shape_manual(values = cohort_shapes, guide = "none") +
  labs(title = "B  Calibration error before vs after updating",
       subtitle = "Largest tested calibration fraction; 30 disjoint outer evaluations.",
       x = NULL, y = "Median |CITL|") + theme_pub(8.7) +
  theme(axis.text.x = element_text(angle = 12, hjust = 1))

p4c <- ggplot(largest_update, aes(cohort, delta_brier, colour = cohort, shape = cohort)) +
  geom_hline(yintercept = 0, colour = "#555555", linewidth = .45) +
  geom_errorbar(aes(ymin = delta_brier_lower, ymax = delta_brier_upper), width = .15, linewidth = .5) +
  geom_point(size = 2.7) +
  scale_colour_manual(values = cohort_cols, guide = "none") +
  scale_shape_manual(values = cohort_shapes, guide = "none") +
  labs(title = "C  Overall accuracy after updating",
       subtitle = "Negative values favor intercept updating.",
       x = NULL, y = "Median ΔBrier vs pre-update") + theme_pub(8.7) +
  theme(panel.grid.major.x = element_blank())

dca_delta[, `:=`(
  cohort = factor(cohort, cohort_levels), delta_per_1000 = 1000 * delta_median,
  lower_per_1000 = 1000 * delta_lower_95, upper_per_1000 = 1000 * delta_upper_95
)]
dca_020 <- dca_delta[abs(threshold - .20) < 1e-8]
p4d <- ggplot(dca_delta, aes(threshold, delta_per_1000, colour = cohort, fill = cohort, group = cohort, linetype = cohort, shape = cohort)) +
  geom_hline(yintercept = 0, colour = "#555555", linewidth = .45) +
  geom_ribbon(aes(ymin = lower_per_1000, ymax = upper_per_1000), alpha = .10, colour = NA) + geom_line(linewidth = .82) +
  geom_point(data = dca_020, size = 2.2) +
  scale_colour_manual(values = cohort_cols) + scale_fill_manual(values = cohort_cols, guide = "none") +
  scale_linetype_manual(values = cohort_linetypes) + scale_shape_manual(values = cohort_shapes) +
  scale_x_continuous(labels = percent_format(accuracy = 1), breaks = c(.05, .10, .15, .20, .25, .30), limits = c(.045, .315)) +
  labs(title = "D  Decision value in disjoint evaluation",
       subtitle = "Empirical 2.5th-97.5th percentiles across 30 outer splits;\nordering varies by threshold.",
       x = "Illustrative risk threshold", y = "Δ net true positives per 1000 vs pre-update", colour = "Target", linetype = "Target", shape = "Target") + theme_pub(8.7)

fig4 <- (p4a | p4b) / (p4c | p4d) + plot_layout(guides = "collect") +
  plot_annotation(title = "Figure 4. Updating added decision value mainly in markedly miscalibrated targets",
                  theme = theme(plot.title = element_text(family = "Arial", face = "bold", size = 12))) &
  theme(legend.position = "bottom")
save_plot("Figure_4", fig4, 8.4, 7.4)

fwrite(indication_primary, file.path(source_dir, "Figure_4A_primary_probability_gap.csv"))
fwrite(citl_pair, file.path(source_dir, "Figure_4B_before_after_abs_CITL.csv"))
fwrite(largest_update, file.path(source_dir, "Figure_4C_delta_Brier_largest_fraction.csv"))
fwrite(dca_delta, file.path(source_dir, "Figure_4D_DCA_outer_intervals.csv"))

# eFigure 1: broader one-wave target-population calibration.
one_curves <- curves[riskset_type == "one_wave" & model == "M1"]
one_bins <- bins[riskset_type == "one_wave" & model == "M1"]
one_curves[, heldout := factor(heldout, cohort_levels)]; one_bins[, heldout := factor(heldout, cohort_levels)]
ef1 <- ggplot(one_curves, aes(nominal_prediction, flexible_observed_risk, colour = heldout, fill = heldout)) +
  geom_abline(slope = 1, intercept = 0, linetype = 2, colour = "#555555") +
  geom_ribbon(aes(ymin = lower_95_cluster, ymax = upper_95_cluster), alpha = .14, colour = NA) + geom_line(linewidth = .9) +
  geom_point(data = one_bins, aes(mean_prediction, observed_risk), inherit.aes = FALSE, shape = 21, colour = "#15202B", fill = "white", size = 2) +
  facet_wrap(~heldout, ncol = 2, scales = "free") + scale_colour_manual(values = cohort_cols, guide = "none") + scale_fill_manual(values = cohort_cols, guide = "none") +
  scale_x_continuous(labels = percent_format(accuracy = 1)) + scale_y_continuous(labels = percent_format(accuracy = 1)) +
  labs(title = "eFigure 1. Current-wave-only target-population calibration", x = "Predicted risk", y = "Observed risk") + theme_pub()
save_plot("eFigure_1", ef1, 7.2, 6.6)

# eFigure 2: full pooled-versus-country CITL distribution.
rd <- random_detail[model == "M1"]
rd[, evaluation_group := factor(evaluation_group, c("POOLED_EQUAL_COHORT", cohort_levels), c("Pooled", cohort_levels))]
ef2 <- ggplot(rd, aes(evaluation_group, calibration_intercept, fill = evaluation_group)) +
  geom_hline(yintercept = 0, linetype = 2) + geom_boxplot(width = .68, outlier.size = .7, linewidth = .45) +
  scale_fill_manual(values = c(Pooled = "#607D8B", cohort_cols), guide = "none") +
  labs(title = "eFigure 2. Pooled random-split reporting attenuates target calibration error",
       subtitle = "100 person-level random splits; pooled values use equal-cohort evaluation weights.", x = NULL, y = "Calibration-in-the-large") + theme_pub() +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))
save_plot("eFigure_2", ef2, 7.2, 4.6)

# eFigure 3: CHARLS and ELSA unknown-vital-status boundaries.
death_bounds[, cohort := factor(cohort, c("CHARLS", "ELSA"))]
ef3 <- ggplot(death_bounds, aes(unknown_death_fraction, citl_median, colour = cohort, group = cohort)) +
  geom_hline(yintercept = 0, linetype = 2, colour = "#555555") + geom_line(linewidth = .9) + geom_point(size = 2.4) +
  geom_errorbar(aes(ymin = citl_low, ymax = citl_high), width = .018) + facet_wrap(~cohort, nrow = 1) +
  scale_colour_manual(values = cohort_cols, guide = "none") + scale_x_continuous(labels = percent_format(accuracy = 1), breaks = c(0, .25, .5, 1)) +
  labs(title = "eFigure 3. Composite-outcome calibration under unknown-death boundaries",
       subtitle = "Scenarios are boundary assignments, not imputed deaths.", x = "Unknown status assigned as death", y = "Composite-outcome CITL") + theme_pub()
save_plot("eFigure_3", ef3, 7.2, 4.6)

# eFigure 4: MHAS long-interval boundary.
ws <- window_scope[cohort == "MHAS" & model == "M1" & evaluation_weighting == "unweighted" & interval_scope %in% c("primary_2to3_year", "extended_nonprimary_intervals")]
ws[, interval_scope := factor(interval_scope, c("primary_2to3_year", "extended_nonprimary_intervals"), c("Primary 2–3 y", "Nonprimary long interval"))]
long_scope <- melt(ws, id.vars = "interval_scope", measure.vars = c("auc", "brier", "calibration_intercept"), variable.name = "metric", value.name = "value")
ef4 <- ggplot(long_scope, aes(interval_scope, value, fill = interval_scope)) + geom_col(width = .62) +
  geom_text(aes(label = sprintf("%.3f", value)), vjust = ifelse(long_scope$value >= 0, -0.35, 1.25), size = 3) +
  facet_wrap(~metric, scales = "free_y", labeller = as_labeller(c(auc = "AUC", brier = "Brier", calibration_intercept = "CITL"))) +
  scale_fill_manual(values = c("Primary 2–3 y" = "#7A5195", "Nonprimary long interval" = "#D7B5D8"), guide = "none") +
  labs(title = "eFigure 4. MHAS long-interval extrapolation is a transport boundary", x = NULL, y = NULL) + theme_pub() +
  theme(axis.text.x = element_text(angle = 16, hjust = 1))
save_plot("eFigure_4", ef4, 7.2, 4.6)

# eFigure 5: respondent weighting.
respondent <- point[riskset_type == "two_wave" & model == "M1", .(heldout, evaluation_weighting, calibration_intercept)]
respondent <- dcast(respondent, heldout ~ evaluation_weighting, value.var = "calibration_intercept")
respondent[, heldout := factor(heldout, levels = rev(cohort_levels))]
ef5 <- ggplot(respondent, aes(y = heldout)) + geom_vline(xintercept = 0, linetype = 2, colour = "#555555") +
  geom_segment(aes(x = unweighted, xend = respondent_weighted, yend = heldout, colour = heldout), arrow = grid::arrow(length = grid::unit(.08, "in")), linewidth = .75) +
  geom_point(aes(x = unweighted), shape = 21, fill = "white", size = 2.5) + geom_point(aes(x = respondent_weighted, colour = heldout), size = 2.5) +
  scale_colour_manual(values = cohort_cols, guide = "none") +
  labs(title = "eFigure 5. Respondent weighting changes but does not remove calibration heterogeneity",
       subtitle = "Open point: unweighted; arrowhead: respondent-weighted point estimate.", x = "Calibration-in-the-large", y = NULL) + theme_pub()
save_plot("eFigure_5", ef5, 7.2, 4.4)

# eFigure 6: all earlier-wave updating windows, moved out of the main figure.
temporal_update <- temporal[model == "M1" & evaluation_primary_horizon == TRUE & method %in% c("intercept_only", "intercept_and_slope")]
temporal_update[, `:=`(
  method_label = factor(method, c("intercept_only", "intercept_and_slope"), c("Intercept only", "Intercept + slope")),
  cohort = factor(cohort, cohort_levels)
)]
ef6 <- ggplot(temporal_update, aes(raw_abs_citl, abs(calibration_intercept), colour = cohort, shape = method_label)) +
  geom_abline(slope = 1, intercept = 0, linetype = 2, colour = "#555555") + geom_point(size = 2.1, alpha = .82) +
  facet_wrap(~cohort, ncol = 2) + scale_colour_manual(values = cohort_cols, guide = "none") +
  labs(title = "eFigure 6. Earlier-wave updating can improve or worsen later calibration",
       subtitle = "Points above the diagonal worsened |CITL|; people may recur across windows.",
       x = "Pre-update |CITL| in later window", y = "Updated |CITL|", shape = "Updating") + theme_pub()
save_plot("eFigure_6", ef6, 7.2, 6.2)

# eFigure 7: development-contribution weighting sensitivity.
weighting[, `:=`(
  heldout = factor(heldout, cohort_levels),
  development_weighting = factor(development_weighting, c("equal_cohort", "sequence_weighted", "person_equal"), c("Equal cohort", "Equal sequence", "Equal person"))
)]
ef7 <- ggplot(weighting, aes(development_weighting, observed_minus_predicted_pp, colour = heldout, group = heldout)) +
  geom_hline(yintercept = 0, linetype = 2, colour = "#555555") + geom_line(linewidth = .75) + geom_point(size = 2.4) +
  facet_wrap(~heldout, nrow = 1) + scale_colour_manual(values = cohort_cols, guide = "none") +
  labs(title = "eFigure 7. Absolute-risk transport under 3 development-contribution schemes",
       subtitle = "Positive values indicate underprediction; held-out evaluation is unchanged and unweighted.",
       x = "Development likelihood contribution", y = "Observed minus predicted risk, percentage points") + theme_pub(8.5) +
  theme(axis.text.x = element_text(angle = 25, hjust = 1))
save_plot("eFigure_7", ef7, 7.6, 4.6)

# eFigure 8: information-size curves and exploratory HRS development-weighting sensitivity.
hrs_pair <- merge(
  indication_primary[cohort == "HRS", .(cohort, x = absolute_probability_gap_pp, y = delta_net_true_positives_per_1000_at_020)],
  indication_person[cohort == "HRS", .(cohort, xend = absolute_probability_gap_pp, yend = delta_net_true_positives_per_1000_at_020)],
  by = "cohort"
)
indication_primary[, `:=`(
  point_label = as.character(cohort),
  label_x = absolute_probability_gap_pp,
  label_y = delta_net_true_positives_per_1000_at_020
)]
indication_primary[cohort == "CHARLS", `:=`(label_x = 6.9, label_y = 23.2)]
indication_primary[cohort == "ELSA", `:=`(label_x = 1.0, label_y = 3.6)]
indication_primary[cohort == "HRS", `:=`(point_label = "HRS\n(equal cohort)", label_x = 1.05, label_y = -3.5)]
indication_primary[cohort == "MHAS", `:=`(label_x = 9.5, label_y = 11.2)]
indication_person[, `:=`(point_label = "HRS\n(equal person)", label_x = 10.7, label_y = 22.0)]
log1p_scale <- scales::trans_new("log1p", transform = log1p, inverse = expm1)
ef8a <- ggplot() +
  geom_hline(yintercept = 0, colour = "#555555", linewidth = .45) +
  geom_segment(data = hrs_pair, aes(x = x, y = y, xend = xend, yend = yend),
               linetype = "dashed", arrow = grid::arrow(length = grid::unit(.07, "in")),
               colour = cohort_cols[["HRS"]], linewidth = .7) +
  geom_point(data = indication_primary,
             aes(absolute_probability_gap_pp, delta_net_true_positives_per_1000_at_020, colour = cohort, shape = cohort), size = 3) +
  geom_point(data = indication_person,
             aes(absolute_probability_gap_pp, delta_net_true_positives_per_1000_at_020, colour = cohort),
             shape = 23, fill = "white", stroke = 1.0, size = 3.4) +
  geom_text(data = indication_primary, aes(label_x, label_y, label = point_label, colour = cohort),
            size = 2.35, fontface = "bold", lineheight = .9) +
  geom_text(data = indication_person, aes(label_x, label_y, label = point_label, colour = cohort),
            size = 2.35, fontface = "bold", lineheight = .9) +
  scale_colour_manual(values = cohort_cols, guide = "none") +
  scale_shape_manual(values = cohort_shapes, guide = "none") +
  scale_x_continuous(trans = log1p_scale, breaks = c(1, 2, 5, 10), labels = number_format(accuracy = 1)) +
  coord_cartesian(xlim = c(.8, 12.5), ylim = c(-5, 26), clip = "off") +
  labs(title = "A  Same target, different development weighting",
       subtitle = "Dashed arrow: post-result HRS sensitivity; illustrative 20% threshold.",
       x = "Absolute observed-predicted risk gap, percentage points (log1p scale)",
       y = "Median Δ net true positives per 1000") + theme_pub(8.5)

ef8b <- ggplot(up, aes(event_persons, median_abs_citl_median_across_outer, colour = cohort, group = cohort, linetype = cohort, shape = cohort)) +
  geom_line(linewidth = .8) + geom_point(size = 1.9) + scale_colour_manual(values = cohort_cols) +
  scale_linetype_manual(values = cohort_linetypes) + scale_shape_manual(values = cohort_shapes) +
  scale_x_continuous(trans = pseudo_log_trans(base = 10, sigma = 10), labels = comma, breaks = c(0, 100, 1000, 4000)) +
  labs(title = "B  Calibration vs target event information", x = "Median event persons in calibration sample",
       y = "Median |CITL| across outer splits", colour = "Target") + theme_pub(8.5) +
  guides(colour = "none", linetype = "none", shape = "none")

ef8c <- ggplot(up, aes(event_persons, median_delta_brier_vs_raw_median_across_outer, colour = cohort, group = cohort, linetype = cohort, shape = cohort)) +
  geom_hline(yintercept = 0, colour = "#555555", linewidth = .45) + geom_line(linewidth = .8) + geom_point(size = 1.9) +
  scale_colour_manual(values = cohort_cols) + scale_linetype_manual(values = cohort_linetypes) + scale_shape_manual(values = cohort_shapes) +
  scale_x_continuous(trans = pseudo_log_trans(base = 10, sigma = 10), labels = comma, breaks = c(0, 100, 1000, 4000)) +
  labs(title = "C  Change in Brier score", subtitle = "Negative values favor updating.",
       x = "Median event persons in calibration sample", y = "Median ΔBrier vs pre-update", colour = "Target") + theme_pub(8.5) +
  guides(colour = "none", linetype = "none", shape = "none")

ef8d <- p4d +
  scale_x_continuous(labels = percent_format(accuracy = 1), breaks = c(.05, .10, .20, .30), limits = c(.045, .315)) +
  labs(title = "D  Equal-cohort decision-curve increments")
ef8 <- (ef8a | ef8b) / (ef8c | ef8d) + plot_layout(guides = "collect") +
  plot_annotation(title = "eFigure 8. Updating performance across target information and development weighting",
                  theme = theme(plot.title = element_text(family = "Arial", face = "bold", size = 12))) &
  theme(legend.position = "bottom")
save_plot("eFigure_8", ef8, 8.5, 7.5)

fwrite(death_bounds, file.path(source_dir, "eFigure_3_death_boundaries.csv"))
fwrite(temporal_update, file.path(source_dir, "eFigure_6_temporal_updating.csv"))
fwrite(weighting, file.path(source_dir, "eFigure_7_development_weighting.csv"))
fwrite(indication_consequence, file.path(source_dir, "eFigure_8A_indication_consequence.csv"))
fwrite(up, file.path(source_dir, "eFigure_8BC_update_curves.csv"))

# Vector and analytic-source gates.
svg_files <- list.files(vec_dir, pattern = "\\.svg$", full.names = TRUE)
audit <- rbindlist(lapply(svg_files, function(file) {
  text <- paste(readLines(file, warn = FALSE), collapse = "\n")
  data.table(
    file = basename(file), bytes = file.info(file)$size,
    raster_image_tags = lengths(regmatches(text, gregexpr("<image\\b", text, perl = TRUE))),
    text_tags = lengths(regmatches(text, gregexpr("<text\\b", text, perl = TRUE))),
    svg_reopen_parse = grepl("<svg", text, fixed = TRUE) && grepl("</svg>", text, fixed = TRUE)
  )
}))
fwrite(audit, file.path(fig_root, "vector_figure_structural_audit.csv"))

figure_gates <- data.table(
  gate = c(
    "four_main_and_eight_supplement_figures", "all_svg_files_vector_only", "all_svg_files_have_live_text",
    "figure1_flow_reconciles_without_stacked_bars", "figure2_gap_has_1200_within_replicate_inputs",
    "figure3_all_four_cohorts_annotated", "figure4_primary_equal_cohort_only", "figure4_equal_cohort_DCA_30_outer_splits",
    "HRS_equal_cohort_nonnegative_fraction_at_020_is_8_of_30",
    "HRS_person_equal_DCA_is_30_of_30_and_18_60_per_1000", "standard_cohort_order"
  ),
  passed = c(
    length(svg_files) == 12,
    all(audit$raster_image_tags == 0) && all(audit$svg_reopen_parse),
    all(audit$text_tags > 0),
    all(flow_primary$riskset_sequences == flow_primary$observed_sequences + flow_primary$confirmed_deaths + flow_primary$unknown_alive_or_dead + flow_primary$other_unavailable) && nrow(flow_display) == 4,
    nrow(fread(file.path(v21, "04_cluster_bootstrap", "v21_strict9_person_cluster_bootstrap_300.csv.gz"))[riskset_type == "two_wave" & model == "M1"]) == 1200,
    nrow(annotation) == 4,
    nrow(indication_primary) == 4 && all(indication_primary$development_weighting == "equal_cohort") && nrow(largest_update) == 4,
    all(dca_delta$outer_splits == 30),
    abs(dca_020[cohort == "HRS", proportion_nonnegative] - 8 / 30) < 1e-10,
    nrow(indication_person) == 1 && indication_person$outer_splits == 30 &&
      abs(indication_person$proportion_nonnegative - 1) < 1e-12 &&
      abs(indication_person$delta_net_true_positives_per_1000_at_020 - 18.601498559386428) < 1e-9,
    identical(cohort_levels, c("CHARLS", "ELSA", "HRS", "MHAS"))
  )
)
fwrite(figure_gates, file.path(fig_root, "v25_figure_gates.csv"))
if (!all(figure_gates$passed)) stop("v2.5 figure gates failed")
writeLines(capture.output(sessionInfo()), file.path(fig_root, "sessionInfo.txt"))
print(figure_gates)
print(audit)
cat("Completed: ", format(Sys.time(), tz = "America/Chicago"), "\n", sep = "")
