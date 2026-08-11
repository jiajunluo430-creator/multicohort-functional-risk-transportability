#!/usr/bin/env python3
"""Frozen v2.3 HRS person-equal M1 decision-curve sensitivity.

The script reuses the exact HRS person-level outer-split seeds from the v2.1
nested analysis, fits an intercept-only calibrator in the 60% calibration pool,
and evaluates net benefit at the single prespecified 0.20 threshold in the
disjoint 40% evaluation sample. The equal-cohort reference is read, not rerun.
"""

from __future__ import annotations

import os

import json
import platform
import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(os.environ.get("D2_PROJECT_ROOT", Path(__file__).resolve().parents[1]))
PRED = ROOT / "03_results" / "16_submission_upgrade_v23" / "01_hrs_person_equal_dca" / "v23_HRS_person_equal_M1_predictions.csv.gz"
V22_POINT = ROOT / "03_results" / "15_submission_upgrade_v22" / "01_robustness" / "v22_development_weighting_M1_point.csv"
REFERENCE_DCA = ROOT / "03_results" / "14_reviewer_revision_v21" / "07_nested_local_updating" / "v21_strict9_disjoint_sample_dca_by_outer_split.csv.gz"
OUT = ROOT / "03_results" / "16_submission_upgrade_v23" / "01_hrs_person_equal_dca"
OUT.mkdir(parents=True, exist_ok=True)

OUTER_REPS = 30
EVAL_FRACTION = 0.40
THRESHOLD = 0.20
BASE_SEED = 20260809
HRS_COHORT_INDEX = 2  # exact position in v2.1 COHORTS=(CHARLS,HRS,ELSA,MHAS)


def clip(p: np.ndarray) -> np.ndarray:
    return np.clip(np.asarray(p, dtype=np.float64), 1e-6, 1 - 1e-6)


def expit(x: np.ndarray) -> np.ndarray:
    x = np.asarray(x, dtype=np.float64)
    out = np.empty_like(x)
    pos = x >= 0
    out[pos] = 1.0 / (1.0 + np.exp(-x[pos]))
    ex = np.exp(x[~pos])
    out[~pos] = ex / (1.0 + ex)
    return out


def fit_intercept(y: np.ndarray, p: np.ndarray) -> tuple[float, bool]:
    lp = np.log(clip(p) / (1 - clip(p)))
    a = 0.0
    converged = False
    for _ in range(80):
        mu = expit(np.clip(lp + a, -30, 30))
        denominator = float(np.sum(mu * (1 - mu)))
        if denominator <= 1e-12:
            return np.nan, False
        step = float(np.sum(y - mu) / denominator)
        a += float(np.clip(step, -5, 5))
        if abs(step) < 1e-8:
            converged = True
            break
    return a, bool(converged and 0 < y.sum() < len(y))


def net_benefit(y: np.ndarray, p: np.ndarray, threshold: float) -> float:
    positive = p >= threshold
    return float(np.mean(positive * y - positive * (1 - y) * threshold / (1 - threshold)))


def summarize(group: pd.DataFrame, weighting: str) -> dict[str, float | int | str]:
    delta = group["delta_net_benefit_vs_raw"].to_numpy(dtype=float)
    return {
        "cohort": "HRS",
        "development_weighting": weighting,
        "method": "intercept_only_full_pool",
        "threshold": THRESHOLD,
        "outer_splits": int(len(group)),
        "raw_net_benefit_median": float(group["raw_net_benefit"].median()),
        "updated_net_benefit_median": float(group["updated_net_benefit"].median()),
        "delta_net_benefit_median": float(np.median(delta)),
        "delta_net_benefit_empirical_p2_5": float(np.quantile(delta, 0.025)),
        "delta_net_benefit_empirical_p97_5": float(np.quantile(delta, 0.975)),
        "delta_net_true_positives_per_1000_median": float(1000 * np.median(delta)),
        "delta_net_true_positives_per_1000_empirical_p2_5": float(1000 * np.quantile(delta, 0.025)),
        "delta_net_true_positives_per_1000_empirical_p97_5": float(1000 * np.quantile(delta, 0.975)),
        "nonnegative_outer_splits": int(np.sum(delta >= 0)),
        "proportion_nonnegative_outer_splits": float(np.mean(delta >= 0)),
        "percentile_definition": "empirical 2.5th and 97.5th percentiles across 30 fixed outer splits",
    }


def main() -> None:
    data = pd.read_csv(PRED, dtype={"person_id": "string"})
    data = data[(data["cohort"] == "HRS") & (data["outcome_observed"] == 1) & data["strict9_event"].notna()].copy()
    data["strict9_event"] = data["strict9_event"].astype(np.int8)
    ids = np.array(sorted(data["person_id"].unique()))
    n_total = len(ids)

    rows: list[dict[str, float | int | str | bool]] = []
    for outer in range(1, OUTER_REPS + 1):
        rng = np.random.default_rng(BASE_SEED + HRS_COHORT_INDEX * 100000 + outer * 1000)
        eval_ids_arr = rng.choice(ids, int(np.floor(EVAL_FRACTION * n_total)), replace=False)
        eval_ids = set(eval_ids_arr)
        pool_ids = set(x for x in ids if x not in eval_ids)
        evaluation = data[data["person_id"].isin(eval_ids)].copy()
        calibration = data[data["person_id"].isin(pool_ids)].copy()
        y_cal = calibration["strict9_event"].to_numpy(dtype=np.int8)
        p_cal = clip(calibration["prediction"].to_numpy(dtype=float))
        y_eval = evaluation["strict9_event"].to_numpy(dtype=np.int8)
        p_eval = clip(evaluation["prediction"].to_numpy(dtype=float))
        intercept, success = fit_intercept(y_cal, p_cal)
        p_updated = clip(expit(intercept + np.log(p_eval / (1 - p_eval)))) if success else np.full(len(p_eval), np.nan)
        raw_nb = net_benefit(y_eval, p_eval, THRESHOLD)
        updated_nb = net_benefit(y_eval, p_updated, THRESHOLD) if success else np.nan
        rows.append({
            "cohort": "HRS", "development_weighting": "person_equal", "outer_split": outer,
            "threshold": THRESHOLD, "calibration_persons": len(pool_ids), "evaluation_persons": len(eval_ids),
            "calibration_records": len(calibration), "evaluation_records": len(evaluation),
            "calibration_events": int(y_cal.sum()), "evaluation_events": int(y_eval.sum()),
            "calibration_evaluation_person_overlap": len(eval_ids.intersection(pool_ids)),
            "fitted_intercept": intercept, "fit_success": success,
            "raw_net_benefit": raw_nb, "updated_net_benefit": updated_nb,
            "delta_net_benefit_vs_raw": updated_nb - raw_nb,
            "delta_net_true_positives_per_1000": 1000 * (updated_nb - raw_nb),
        })
    person = pd.DataFrame(rows)

    reference = pd.read_csv(
        REFERENCE_DCA,
        usecols=["cohort", "outer_split", "method", "threshold", "net_benefit", "calibration_evaluation_person_overlap"],
    )
    reference = reference[(reference["cohort"] == "HRS") & np.isclose(reference["threshold"], THRESHOLD)]
    raw = reference[reference["method"] == "raw_untouched"][["outer_split", "net_benefit"]].rename(columns={"net_benefit": "raw_net_benefit"})
    updated = reference[reference["method"] == "intercept_only_full_pool"][["outer_split", "net_benefit", "calibration_evaluation_person_overlap"]].rename(columns={"net_benefit": "updated_net_benefit"})
    equal = updated.merge(raw, on="outer_split", how="inner")
    equal["delta_net_benefit_vs_raw"] = equal["updated_net_benefit"] - equal["raw_net_benefit"]
    equal["delta_net_true_positives_per_1000"] = 1000 * equal["delta_net_benefit_vs_raw"]
    equal["cohort"] = "HRS"
    equal["development_weighting"] = "equal_cohort"
    equal["threshold"] = THRESHOLD

    summary = pd.DataFrame([summarize(equal, "equal_cohort"), summarize(person, "person_equal")])
    paired = person[["outer_split", "delta_net_benefit_vs_raw"]].merge(
        equal[["outer_split", "delta_net_benefit_vs_raw"]], on="outer_split", suffixes=("_person_equal", "_equal_cohort")
    )
    paired["paired_delta_net_benefit_person_minus_equal"] = paired["delta_net_benefit_vs_raw_person_equal"] - paired["delta_net_benefit_vs_raw_equal_cohort"]
    paired_summary = pd.DataFrame([{
        "cohort": "HRS", "threshold": THRESHOLD, "outer_splits": len(paired),
        "paired_increment_ntp_per_1000_median": 1000 * float(paired["paired_delta_net_benefit_person_minus_equal"].median()),
        "paired_increment_ntp_per_1000_empirical_p2_5": 1000 * float(paired["paired_delta_net_benefit_person_minus_equal"].quantile(0.025)),
        "paired_increment_ntp_per_1000_empirical_p97_5": 1000 * float(paired["paired_delta_net_benefit_person_minus_equal"].quantile(0.975)),
        "person_equal_exceeds_equal_cohort_splits": int((paired["paired_delta_net_benefit_person_minus_equal"] > 0).sum()),
        "proportion_person_equal_exceeds_equal_cohort": float((paired["paired_delta_net_benefit_person_minus_equal"] > 0).mean()),
    }])

    v22 = pd.read_csv(V22_POINT)
    v22 = v22[(v22["heldout"] == "HRS") & (v22["model"] == "M1") & (v22["development_weighting"] == "person_equal")].iloc[0]
    gates = pd.DataFrame({
        "gate": [
            "single_threshold_0_20", "30_fixed_outer_splits", "zero_person_overlap", "all_intercept_fits_successful",
            "equal_cohort_reference_has_30_splits", "equal_cohort_reference_matches_v22_median",
            "equal_cohort_reference_matches_8_of_30", "person_equal_prediction_matches_v22_gap",
        ],
        "passed": [
            bool(np.isclose(person["threshold"].unique(), THRESHOLD).all()),
            bool(person["outer_split"].nunique() == OUTER_REPS),
            bool((person["calibration_evaluation_person_overlap"] == 0).all()),
            bool(person["fit_success"].all()),
            bool(equal["outer_split"].nunique() == OUTER_REPS),
            bool(abs(summary.loc[summary["development_weighting"] == "equal_cohort", "delta_net_benefit_median"].iloc[0] - (-0.0002940015794492814)) < 1e-15),
            bool(summary.loc[summary["development_weighting"] == "equal_cohort", "nonnegative_outer_splits"].iloc[0] == 8),
            bool(abs(float(data["strict9_event"].mean() - data["prediction"].mean()) * 100 - float(v22["observed_minus_predicted_pp"])) < 1e-10),
        ],
    })
    if not gates["passed"].all():
        raise RuntimeError("Frozen v2.3 DCA gates failed: " + ", ".join(gates.loc[~gates["passed"], "gate"]))

    person.to_csv(OUT / "v23_HRS_person_equal_DCA_by_outer_split.csv", index=False)
    equal.to_csv(OUT / "v23_HRS_equal_cohort_DCA_reference_by_outer_split.csv", index=False)
    summary.to_csv(OUT / "v23_HRS_weighting_DCA_summary.csv", index=False)
    paired.to_csv(OUT / "v23_HRS_weighting_DCA_paired_outer_contrast.csv", index=False)
    paired_summary.to_csv(OUT / "v23_HRS_weighting_DCA_paired_summary.csv", index=False)
    gates.to_csv(OUT / "v23_HRS_person_equal_DCA_gates.csv", index=False)
    provenance = {
        "charter": str(ROOT / "00_contract" / "analysis_charter_v2.3_final_minor_revision.md"),
        "prediction_source": str(PRED), "equal_cohort_reference": str(REFERENCE_DCA),
        "python": sys.version, "platform": platform.platform(), "numpy": np.__version__, "pandas": pd.__version__,
        "target": "HRS", "model": "M1", "development_weighting": "person_equal",
        "threshold": THRESHOLD, "outer_splits": OUTER_REPS, "outer_evaluation_fraction_persons": EVAL_FRACTION,
        "split_seed_formula": "20260809 + 2*100000 + outer_split*1000",
        "update": "intercept_only_full_60_percent_calibration_pool",
        "evaluation": "disjoint_40_percent_target_persons",
        "percentiles": "empirical_2.5_and_97.5_across_outer_splits",
        "no_inner_resampling_reason": "DCA branch uses the full outer calibration pool; 100 inner resamples belong only to the reused data-amount curves",
    }
    (OUT / "v23_HRS_person_equal_DCA_provenance.json").write_text(json.dumps(provenance, indent=2), encoding="utf-8")
    print(summary.to_string(index=False), flush=True)
    print(paired_summary.to_string(index=False), flush=True)
    print(gates.to_string(index=False), flush=True)


if __name__ == "__main__":
    main()

