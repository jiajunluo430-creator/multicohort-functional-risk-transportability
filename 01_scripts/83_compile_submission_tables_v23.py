#!/usr/bin/env python3
"""Compile v2.3 submission tables and figure-source datasets from frozen aggregate results."""

from __future__ import annotations

import os

import json
import shutil
from pathlib import Path

import numpy as np
import pandas as pd


ROOT = Path(os.environ.get("D2_PROJECT_ROOT", Path(__file__).resolve().parents[1]))
V21 = ROOT / "03_results" / "14_reviewer_revision_v21"
V21_TABLES = V21 / "09_submission_tables" / "supplement"
V22 = ROOT / "03_results" / "15_submission_upgrade_v22"
ROBUST = V22 / "01_robustness"
V23 = ROOT / "03_results" / "16_submission_upgrade_v23"
HRS_DCA = V23 / "01_hrs_person_equal_dca"
OUT = V23 / "02_submission_tables"
MAIN = OUT / "main"
SUPP = OUT / "supplement"
FIGSRC = OUT / "figure_sources"
for directory in (MAIN, SUPP, FIGSRC):
    directory.mkdir(parents=True, exist_ok=True)

COHORTS = ["CHARLS", "ELSA", "HRS", "MHAS"]


def save(frame: pd.DataFrame, directory: Path, filename: str) -> None:
    frame.to_csv(directory / filename, index=False)


def copy_table(source_name: str, destination_name: str) -> None:
    source = V21_TABLES / source_name
    if not source.exists():
        raise FileNotFoundError(source)
    shutil.copyfile(source, SUPP / destination_name)


# Main Table 1 is generated directly from the strict risk set by script 82.
table1_display = pd.read_csv(MAIN / "Table1_participant_predictor_profile_display.csv")
table1_numeric = pd.read_csv(MAIN / "Table1_participant_predictor_profile_numeric_long.csv")

# Main-source country-out performance and increments.
point = pd.read_csv(V21 / "03_strict9_loco" / "v21_strict9_loco_performance_point.csv")
ci = pd.read_csv(V21 / "04_cluster_bootstrap" / "v21_strict9_person_cluster_bootstrap_300_ci.csv")
point_unweighted = point[point["evaluation_weighting"] == "unweighted"].copy()
point_unweighted["observed_minus_predicted_pp"] = 100 * (point_unweighted["event_rate"] - point_unweighted["mean_prediction"])
performance = point_unweighted.merge(ci, on=["riskset_type", "heldout", "model"], how="left", suffixes=("", "_bootstrap"))
performance = performance[[
    "riskset_type", "heldout", "model", "records", "events", "event_rate", "mean_prediction", "observed_minus_predicted_pp",
    "auc", "auc_lower_95", "auc_upper_95", "brier", "brier_lower_95", "brier_upper_95",
    "calibration_intercept", "calibration_intercept_lower_95", "calibration_intercept_upper_95",
    "calibration_slope", "calibration_slope_lower_95", "calibration_slope_upper_95",
]]
save(performance[performance["riskset_type"] == "two_wave"], MAIN, "Table2_country_out_performance.csv")

increments = ci[ci["model"] == "M1_MINUS_M0"].copy()
increments = increments.rename(columns={
    "auc_median": "delta_auc_median", "auc_lower_95": "delta_auc_lower_95", "auc_upper_95": "delta_auc_upper_95",
    "brier_median": "delta_brier_median", "brier_lower_95": "delta_brier_lower_95", "brier_upper_95": "delta_brier_upper_95",
    "calibration_intercept_median": "delta_citl_median",
    "calibration_intercept_lower_95": "delta_citl_lower_95", "calibration_intercept_upper_95": "delta_citl_upper_95",
})
increments = increments[[
    "riskset_type", "heldout", "repetitions", "delta_auc_median", "delta_auc_lower_95", "delta_auc_upper_95",
    "delta_brier_median", "delta_brier_lower_95", "delta_brier_upper_95", "delta_citl_median",
    "delta_citl_lower_95", "delta_citl_upper_95",
]]
save(increments, MAIN, "Table3_M1_increment_over_age_sex.csv")

# Preserve the 15 already audited eTable families unchanged.
for source_name, destination_name in [
    ("eTable1_strict9_flow_and_population.csv", "eTable1_strict9_flow_and_population.csv"),
    ("eTable2_exact_common_9item_concordance.csv", "eTable2_exact_common_9item_concordance.csv"),
    ("eTable3_flow_by_landmark.csv", "eTable3_flow_by_landmark.csv"),
    ("eTable4_strict9_M0_M1_country_out_performance_with_CI.csv", "eTable4_strict9_M0_M1_country_out_performance_with_CI.csv"),
    ("eTable5_M1_increment_cluster_bootstrap.csv", "eTable5_M1_increment_cluster_bootstrap.csv"),
    ("eTable6_one_wave_riskset_country_out_sensitivity.csv", "eTable6_one_wave_riskset_country_out_sensitivity.csv"),
    ("eTable7_respondent_weighted_point_estimates.csv", "eTable7_respondent_weighted_point_estimates.csv"),
    ("eTable8_legacy_vs_exact9_outcome_sensitivity.csv", "eTable8_legacy_vs_exact9_outcome_sensitivity.csv"),
    ("eTable9A_telephone_specific_event_crossclassification.csv", "eTable9A_telephone_specific_event_crossclassification.csv"),
    ("eTable9B_telephone_specific_trigger_counts.csv", "eTable9B_telephone_specific_trigger_counts.csv"),
    ("eTable10A_random_split_pooled_and_country_summary.csv", "eTable10A_random_split_pooled_and_country_summary.csv"),
    ("eTable10B_random_split_concealment_frequency.csv", "eTable10B_random_split_concealment_frequency.csv"),
    ("eTable10C_random_split_vs_country_out.csv", "eTable10C_random_split_vs_country_out.csv"),
    ("eTable11_flexible_calibration_bins.csv", "eTable11_flexible_calibration_bins.csv"),
    ("eTable12_flexible_calibration_curves.csv", "eTable12_flexible_calibration_curves.csv"),
    ("eTable13_update_indication_separate_from_data_amount.csv", "eTable13_update_indication_separate_from_data_amount.csv"),
    ("eTable14A_nested_updating_continuous_curves.csv", "eTable14A_nested_updating_continuous_curves.csv"),
    ("eTable14B_descriptive_operating_points_not_minima.csv", "eTable14B_descriptive_operating_points_not_minima.csv"),
    ("eTable14C_nested_updating_outer_split_summaries.csv", "eTable14C_nested_updating_outer_split_summaries.csv"),
    ("eTable15_disjoint_sample_decision_curve_summary.csv", "eTable15_disjoint_sample_decision_curve_summary.csv"),
]:
    copy_table(source_name, destination_name)

# New and renumbered robustness tables.
combined_death = pd.read_csv(ROBUST / "v22_CHARLS_ELSA_unknown_death_boundary_summary.csv")
charls_death_reps = pd.read_csv(ROBUST / "CHARLS_unknown_death_boundary_replicates.csv.gz")
weighting = pd.read_csv(ROBUST / "v22_development_weighting_M1_contrasts.csv")
complexity = pd.read_csv(ROBUST / "v22_strict9_model_complexity_contrasts.csv")
hrs_weighting_dca = pd.read_csv(HRS_DCA / "v23_HRS_weighting_DCA_summary.csv")
hrs_weighting_paired = pd.read_csv(HRS_DCA / "v23_HRS_weighting_DCA_paired_summary.csv").iloc[0]
for column in [
    "DCA_threshold", "DCA_delta_net_true_positives_per_1000_median",
    "DCA_delta_net_true_positives_per_1000_empirical_p2_5",
    "DCA_delta_net_true_positives_per_1000_empirical_p97_5",
    "DCA_nonnegative_outer_splits", "DCA_outer_splits",
    "paired_increment_vs_equal_cohort_per_1000_median",
]:
    weighting[column] = np.nan
for row in hrs_weighting_dca.itertuples():
    mask = (weighting["heldout"] == "HRS") & (weighting["development_weighting"] == row.development_weighting)
    weighting.loc[mask, "DCA_threshold"] = row.threshold
    weighting.loc[mask, "DCA_delta_net_true_positives_per_1000_median"] = row.delta_net_true_positives_per_1000_median
    weighting.loc[mask, "DCA_delta_net_true_positives_per_1000_empirical_p2_5"] = row.delta_net_true_positives_per_1000_empirical_p2_5
    weighting.loc[mask, "DCA_delta_net_true_positives_per_1000_empirical_p97_5"] = row.delta_net_true_positives_per_1000_empirical_p97_5
    weighting.loc[mask, "DCA_nonnegative_outer_splits"] = row.nonnegative_outer_splits
    weighting.loc[mask, "DCA_outer_splits"] = row.outer_splits
weighting.loc[
    (weighting["heldout"] == "HRS") & (weighting["development_weighting"] == "person_equal"),
    "paired_increment_vs_equal_cohort_per_1000_median",
] = hrs_weighting_paired["paired_increment_ntp_per_1000_median"]
save(combined_death, SUPP, "eTable16A_CHARLS_ELSA_unknown_death_boundary_summary.csv")
save(charls_death_reps, SUPP, "eTable16B_CHARLS_unknown_death_boundary_replicates.csv")
save(weighting, SUPP, "eTable17_development_contribution_weighting.csv")
save(complexity, SUPP, "eTable18_exploratory_M1_M2H_M2S_transparency.csv")

for source_name, destination_name in [
    ("eTable17A_primary_vs_extended_windows.csv", "eTable19A_primary_vs_extended_windows.csv"),
    ("eTable17B_all_temporal_updating_windows.csv", "eTable19B_all_temporal_updating_windows.csv"),
    ("eTable17C_temporal_updating_summary.csv", "eTable19C_temporal_updating_summary.csv"),
    ("eTable18_sequence_count_reconciliation.csv", "eTable20_sequence_count_reconciliation.csv"),
    ("eTable19A_M1_country_out_coefficients.csv", "eTable21A_M1_country_out_coefficients.csv"),
    ("eTable19B_M1_preprocessing_and_scaling.csv", "eTable21B_M1_preprocessing_and_scaling.csv"),
    ("eTable20_death_ascertainment_by_cohort.csv", "eTable22_death_ascertainment_by_cohort.csv"),
]:
    copy_table(source_name, destination_name)

# Figure 2 probability-gap bootstrap: gap is calculated within each cluster-bootstrap replicate.
bootstrap = pd.read_csv(V21 / "04_cluster_bootstrap" / "v21_strict9_person_cluster_bootstrap_300.csv.gz")
gap_boot = bootstrap[(bootstrap["riskset_type"] == "two_wave") & (bootstrap["model"] == "M1")].copy()
gap_boot["observed_minus_predicted_pp"] = 100 * (gap_boot["event_rate"] - gap_boot["mean_prediction"])
gap_summary = (gap_boot.groupby("heldout", observed=True)["observed_minus_predicted_pp"]
               .agg(gap_median="median", gap_lower_95=lambda x: x.quantile(0.025), gap_upper_95=lambda x: x.quantile(0.975))
               .reset_index())
save(gap_summary, FIGSRC, "Figure2C_probability_gap_bootstrap.csv")

concealment_by_rep = pd.read_csv(V21 / "06_validation_design_contrast" / "v21_strict9_random_split_concealment_by_repetition.csv")
concealment_m1 = concealment_by_rep[concealment_by_rep["model"] == "M1"].copy()
failure_distribution = (concealment_m1.groupby("countries_lenient_failure", observed=True).size()
                        .rename("repetitions").reset_index())
failure_distribution["percent_repetitions"] = 100 * failure_distribution["repetitions"] / failure_distribution["repetitions"].sum()
save(failure_distribution, FIGSRC, "Figure2D_random_split_country_failure_distribution.csv")

# Figure 4 primary consequences reuse the previously produced equal-cohort disjoint outer-split DCA results.
dca_outer = pd.read_csv(V21 / "07_nested_local_updating" / "v21_strict9_disjoint_sample_dca_by_outer_split.csv.gz")
raw = dca_outer[dca_outer["method"] == "raw_untouched"][["cohort", "outer_split", "threshold", "net_benefit"]].rename(columns={"net_benefit": "raw_net_benefit"})
updated = dca_outer[dca_outer["method"] == "intercept_only_full_pool"].merge(raw, on=["cohort", "outer_split", "threshold"], how="left")
updated["delta_net_benefit_vs_raw"] = updated["net_benefit"] - updated["raw_net_benefit"]
dca_delta = (updated.groupby(["cohort", "threshold"], observed=True)["delta_net_benefit_vs_raw"]
             .agg(delta_median="median", delta_lower_95=lambda x: x.quantile(0.025), delta_upper_95=lambda x: x.quantile(0.975),
                  proportion_nonnegative=lambda x: float((x >= 0).mean()), outer_splits="size")
             .reset_index())
save(dca_delta, FIGSRC, "Figure4D_DCA_delta_outer_summary.csv")

two_m1 = point_unweighted[(point_unweighted["riskset_type"] == "two_wave") & (point_unweighted["model"] == "M1")].copy()
two_m1["observed_minus_predicted_pp"] = 100 * (two_m1["event_rate"] - two_m1["mean_prediction"])
consequence_020 = dca_delta[np.isclose(dca_delta["threshold"], 0.20)].copy()
indication_consequence = two_m1[["heldout", "event_rate", "mean_prediction", "observed_minus_predicted_pp", "calibration_intercept", "calibration_slope"]].rename(columns={"heldout": "cohort"})
indication_consequence = indication_consequence.merge(consequence_020, on="cohort", how="left")
indication_consequence["absolute_probability_gap_pp"] = indication_consequence["observed_minus_predicted_pp"].abs()
indication_consequence["delta_net_true_positives_per_1000_at_020"] = 1000 * indication_consequence["delta_median"]
indication_consequence["development_weighting"] = "equal_cohort"

# Sole new v2.3 point: HRS person-equal development with the same fixed 20% DCA design.
hrs_person_perf = weighting[(weighting["heldout"] == "HRS") & (weighting["development_weighting"] == "person_equal")].iloc[0]
hrs_person_dca = hrs_weighting_dca[hrs_weighting_dca["development_weighting"] == "person_equal"].iloc[0]
hrs_person_point = pd.DataFrame([{
    "cohort": "HRS", "event_rate": float(hrs_person_perf["observed_risk"]),
    "mean_prediction": float(hrs_person_perf["mean_prediction"]),
    "observed_minus_predicted_pp": float(hrs_person_perf["observed_minus_predicted_pp"]),
    "calibration_intercept": float(hrs_person_perf["calibration_intercept"]),
    "calibration_slope": float(hrs_person_perf["calibration_slope"]),
    "delta_median": float(hrs_person_dca["delta_net_benefit_median"]),
    "delta_lower_95": float(hrs_person_dca["delta_net_benefit_empirical_p2_5"]),
    "delta_upper_95": float(hrs_person_dca["delta_net_benefit_empirical_p97_5"]),
    "proportion_nonnegative": float(hrs_person_dca["proportion_nonnegative_outer_splits"]),
    "outer_splits": int(hrs_person_dca["outer_splits"]),
    "absolute_probability_gap_pp": abs(float(hrs_person_perf["observed_minus_predicted_pp"])),
    "delta_net_true_positives_per_1000_at_020": float(hrs_person_dca["delta_net_true_positives_per_1000_median"]),
    "development_weighting": "person_equal",
}])
indication_consequence = pd.concat([indication_consequence, hrs_person_point], ignore_index=True)
save(indication_consequence, FIGSRC, "Figure4A_indication_consequence_at_threshold_020.csv")

update_curves = pd.read_csv(V21 / "07_nested_local_updating" / "v21_strict9_nested_updating_continuous_curves.csv")
update_intercept = update_curves[update_curves["method"].isin(["none", "intercept_only"])].copy()
save(update_intercept, FIGSRC, "Figure4BC_intercept_update_by_independent_event_persons.csv")

# Consolidated gate audit includes all passed v2.1 and v2.2 gates.
gate_rows: list[pd.DataFrame] = []
for gate_file in sorted(V21.glob("**/*gates.csv")) + sorted(V22.glob("**/*gates.csv")) + sorted(V23.glob("**/*gates.csv")):
    if OUT in gate_file.parents or "all_analysis_gates" in gate_file.name:
        continue
    frame = pd.read_csv(gate_file)
    frame.insert(0, "source", str(gate_file.relative_to(ROOT)).replace("\\", "/"))
    gate_rows.append(frame)
gates = pd.concat(gate_rows, ignore_index=True)
gates["passed_normalized"] = gates["passed"].astype(str).str.lower().eq("true")
save(gates, OUT, "v23_all_analysis_gates.csv")

order_index = {cohort: index for index, cohort in enumerate(COHORTS)}
weighting["cohort_order"] = weighting["heldout"].map(order_index)
complexity["cohort_order"] = complexity["heldout"].map(order_index)
weighting = weighting.sort_values(["cohort_order", "development_weighting"])
complexity = complexity.sort_values(["cohort_order", "model"])

dca_020 = indication_consequence[indication_consequence["development_weighting"] == "equal_cohort"].set_index("cohort")
key = {
    "title": "Transportability and Selective Updating of Functional Difficulty Risk in 4 National Aging Cohorts",
    "study_type": "Cohort Study",
    "primary_population": {
        "persons": 37732, "sequences": 126264, "events": 13000,
        "definition": "strict common 9-item two-wave 2-to-3-year observed-follow-up episodes",
    },
    "two_wave_M1": {
        row.heldout: {
            "observed_risk": float(row.event_rate), "mean_prediction": float(row.mean_prediction),
            "observed_minus_predicted_pp": float(100 * (row.event_rate - row.mean_prediction)),
            "auc": float(row.auc), "brier": float(row.brier), "citl": float(row.calibration_intercept),
            "slope": float(row.calibration_slope),
        }
        for row in two_m1.itertuples()
    },
    "development_weighting": weighting.drop(columns="cohort_order").to_dict(orient="records"),
    "model_complexity": complexity.drop(columns="cohort_order").to_dict(orient="records"),
    "unknown_death_boundaries": combined_death.to_dict(orient="records"),
    "DCA_at_threshold_0_20": {
        cohort: {
            "delta_net_benefit_median": float(dca_020.loc[cohort, "delta_median"]),
            "delta_net_true_positives_per_1000": float(dca_020.loc[cohort, "delta_net_true_positives_per_1000_at_020"]),
            "proportion_outer_splits_nonnegative": float(dca_020.loc[cohort, "proportion_nonnegative"]),
        }
        for cohort in COHORTS
    },
    "HRS_development_weighting_DCA_at_threshold_0_20": hrs_weighting_dca.to_dict(orient="records"),
    "HRS_person_equal_minus_equal_cohort_paired_DCA": hrs_weighting_paired.to_dict(),
    "random_split": {
        "repetitions": int(len(concealment_m1)),
        "pooled_pass_repetitions": int(concealment_m1["pooled_joint_lenient_pass"].sum()),
        "concealment_repetitions": int(concealment_m1["pooled_pass_conceals_country_failure"].sum()),
    },
    "all_analysis_gates_passed": bool(gates["passed_normalized"].all()),
}
(OUT / "v23_key_results_canon.json").write_text(json.dumps(key, indent=2, ensure_ascii=False), encoding="utf-8")

inventory = []
for file in sorted(SUPP.glob("*.csv")):
    frame = pd.read_csv(file)
    inventory.append({"file": file.name, "rows": len(frame), "columns": len(frame.columns)})
inventory_frame = pd.DataFrame(inventory)
save(inventory_frame, OUT, "v23_submission_table_inventory.csv")

compiler_gates = pd.DataFrame({
    "gate": [
        "table1_five_display_columns", "table1_has_no_episode_flow", "supplement_31_data_sheets",
        "probability_gap_uses_within_replicate_difference", "DCA_delta_uses_disjoint_outer_splits",
        "HRS_person_equal_DCA_added_as_single_paired_sensitivity", "cohort_order_defined", "all_upstream_gates_passed",
    ],
    "passed": [
        list(table1_display.columns) == ["characteristic", *COHORTS],
        not table1_display["characteristic"].str.contains("sequence|episode|death|status", case=False, regex=True).any(),
        len(inventory_frame) == 31,
        len(gap_summary) == 4 and len(gap_boot) == 1200,
        len(dca_delta) == 44 and (updated["calibration_evaluation_person_overlap"] == 0).all(),
        len(indication_consequence) == 5
        and set(indication_consequence["development_weighting"]) == {"equal_cohort", "person_equal"}
        and int(hrs_person_dca["nonnegative_outer_splits"]) == 30,
        list(order_index) == COHORTS,
        key["all_analysis_gates_passed"],
    ],
})
save(compiler_gates, OUT, "v23_table_compiler_gates.csv")
if not compiler_gates["passed"].all():
    raise RuntimeError(f"v2.3 table compiler gates failed:\n{compiler_gates}")

print(json.dumps({
    "main_table1_rows": len(table1_display), "supplement_data_sheets": len(inventory_frame),
    "all_upstream_gates_passed": key["all_analysis_gates_passed"],
    "charls_gap_pp": key["two_wave_M1"]["CHARLS"]["observed_minus_predicted_pp"],
    "mhas_gap_pp": key["two_wave_M1"]["MHAS"]["observed_minus_predicted_pp"],
    "HRS_DCA_nonnegative_at_0_20": key["DCA_at_threshold_0_20"]["HRS"]["proportion_outer_splits_nonnegative"],
    "HRS_person_equal_DCA_ntp_per_1000_at_0_20": float(hrs_person_dca["delta_net_true_positives_per_1000_median"]),
}, indent=2))
