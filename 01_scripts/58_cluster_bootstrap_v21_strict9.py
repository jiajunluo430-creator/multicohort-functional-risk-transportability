from __future__ import annotations

import os

import gzip
import json
from pathlib import Path

import numpy as np
import pandas as pd


ROOT = Path(os.environ.get("D2_PROJECT_ROOT", Path(__file__).resolve().parents[1]))
INPUT = ROOT / "03_results" / "14_reviewer_revision_v21" / "03_strict9_loco" / "v21_strict9_loco_predictions_all_risksets.csv.gz"
POINT = ROOT / "03_results" / "14_reviewer_revision_v21" / "03_strict9_loco" / "v21_strict9_loco_performance_point.csv"
OUT = ROOT / "03_results" / "14_reviewer_revision_v21" / "04_cluster_bootstrap"
OUT.mkdir(parents=True, exist_ok=True)

REPS = 300
BASE_SEED = 20260809
EPS = 1e-6


def clip(p: np.ndarray) -> np.ndarray:
    return np.clip(np.asarray(p, dtype=float), EPS, 1 - EPS)


def calibration(y: np.ndarray, p: np.ndarray, w: np.ndarray) -> tuple[float, float]:
    lp = np.log(clip(p) / (1 - clip(p)))
    a = 0.0
    for _ in range(50):
        mu = 1 / (1 + np.exp(-np.clip(lp + a, -30, 30)))
        den = np.sum(w * mu * (1 - mu))
        if not np.isfinite(den) or den < 1e-12:
            return np.nan, np.nan
        step = np.sum(w * (y - mu)) / den
        a += step
        if abs(step) < 1e-8:
            break
    beta = np.array([0.0, 1.0])
    for _ in range(80):
        eta = np.clip(beta[0] + beta[1] * lp, -30, 30)
        mu = 1 / (1 + np.exp(-eta))
        v = w * mu * (1 - mu)
        h = np.array(
            [[np.sum(v), np.sum(v * lp)], [np.sum(v * lp), np.sum(v * lp * lp)]]
        )
        score = np.array([np.sum(w * (y - mu)), np.sum(w * (y - mu) * lp)])
        try:
            step = np.linalg.solve(h, score)
        except np.linalg.LinAlgError:
            return a, np.nan
        beta += step
        if np.max(np.abs(step)) < 1e-8:
            break
    return float(a), float(beta[1])


def precompute_auc(p: np.ndarray) -> tuple[np.ndarray, np.ndarray, int]:
    order = np.argsort(p, kind="mergesort")
    ps = p[order]
    group = np.cumsum(np.r_[True, np.diff(ps) != 0]) - 1
    return order, group, int(group[-1] + 1)


def auc_with_precomputed(
    y: np.ndarray,
    w: np.ndarray,
    order: np.ndarray,
    group: np.ndarray,
    n_groups: int,
) -> float:
    ys = y[order]
    ws = w[order]
    pos = np.bincount(group, weights=ws * (ys == 1), minlength=n_groups)
    neg = np.bincount(group, weights=ws * (ys == 0), minlength=n_groups)
    total_pos = pos.sum()
    total_neg = neg.sum()
    if total_pos <= 0 or total_neg <= 0:
        return np.nan
    return float(np.sum(pos * (np.cumsum(neg) - neg + 0.5 * neg)) / (total_pos * total_neg))


def compute_metrics(
    y: np.ndarray,
    p: np.ndarray,
    w: np.ndarray,
    auc_cache: tuple[np.ndarray, np.ndarray, int],
) -> dict[str, float]:
    sw = w.sum()
    if sw <= 0:
        return {k: np.nan for k in ["event_rate", "mean_prediction", "auc", "brier", "calibration_intercept", "calibration_slope"]}
    er = float(np.sum(w * y) / sw)
    mp = float(np.sum(w * p) / sw)
    brier = float(np.sum(w * (y - p) ** 2) / sw)
    citl, slope = calibration(y, p, w)
    auc = auc_with_precomputed(y, w, *auc_cache)
    return {
        "event_rate": er,
        "mean_prediction": mp,
        "auc": auc,
        "brier": brier,
        "calibration_intercept": citl,
        "calibration_slope": slope,
    }


df = pd.read_csv(INPUT)
df = df[(df["outcome_observed"] == 1) & df["strict9_event"].notna()].copy()
df["strict9_event"] = df["strict9_event"].astype(int)

detail_rows: list[dict[str, float | int | str]] = []
point_rows: list[dict[str, float | int | str]] = []

for riskset in ["two_wave", "one_wave"]:
    for cohort in ["CHARLS", "HRS", "ELSA", "MHAS"]:
        z = df[(df["riskset_type"] == riskset) & (df["cohort"] == cohort)]
        wide = z.pivot_table(
            index=["person_id", "landmark_wave"],
            columns="model",
            values=["strict9_event", "prediction"],
            aggfunc="first",
        ).sort_index()
        required_columns = {
            ("strict9_event", "M0"),
            ("strict9_event", "M1"),
            ("prediction", "M0"),
            ("prediction", "M1"),
        }
        if not required_columns.issubset(set(wide.columns)):
            missing = sorted(required_columns.difference(set(wide.columns)))
            raise RuntimeError(f"Missing paired columns for {riskset}/{cohort}: {missing}")
        y_m0 = wide[("strict9_event", "M0")].to_numpy(dtype=int)
        y_m1 = wide[("strict9_event", "M1")].to_numpy(dtype=int)
        if not np.array_equal(y_m0, y_m1):
            raise RuntimeError(f"Outcome mismatch in paired predictions: {riskset}/{cohort}")
        y = y_m0
        preds = {
            "M0": clip(wide[("prediction", "M0")].to_numpy(dtype=float)),
            "M1": clip(wide[("prediction", "M1")].to_numpy(dtype=float)),
        }
        person_codes, persons = pd.factorize(
            wide.index.get_level_values("person_id").astype(str), sort=True
        )
        n_persons = len(persons)
        auc_cache = {m: precompute_auc(p) for m, p in preds.items()}

        point_metrics = {
            m: compute_metrics(y, p, np.ones(len(y)), auc_cache[m]) for m, p in preds.items()
        }
        for model, metrics in point_metrics.items():
            point_rows.append(
                {
                    "riskset_type": riskset,
                    "heldout": cohort,
                    "model": model,
                    "records": len(y),
                    "persons": n_persons,
                    "events": int(y.sum()),
                    **metrics,
                }
            )

        rng = np.random.default_rng(BASE_SEED + 10000 * (1 + ["two_wave", "one_wave"].index(riskset)) + 100 * (1 + ["CHARLS", "HRS", "ELSA", "MHAS"].index(cohort)))
        for rep in range(1, REPS + 1):
            sampled = rng.integers(0, n_persons, size=n_persons)
            multiplicity = np.bincount(sampled, minlength=n_persons).astype(float)
            w = multiplicity[person_codes]
            rep_metrics = {
                m: compute_metrics(y, p, w, auc_cache[m]) for m, p in preds.items()
            }
            for model, metrics in rep_metrics.items():
                detail_rows.append(
                    {
                        "riskset_type": riskset,
                        "heldout": cohort,
                        "replicate": rep,
                        "model": model,
                        "sampled_persons": n_persons,
                        "sampled_records": int(w.sum()),
                        "sampled_events": float(np.sum(w * y)),
                        **metrics,
                    }
                )
            detail_rows.append(
                {
                    "riskset_type": riskset,
                    "heldout": cohort,
                    "replicate": rep,
                    "model": "M1_MINUS_M0",
                    "sampled_persons": n_persons,
                    "sampled_records": int(w.sum()),
                    "sampled_events": float(np.sum(w * y)),
                    "event_rate": rep_metrics["M1"]["event_rate"] - rep_metrics["M0"]["event_rate"],
                    "mean_prediction": rep_metrics["M1"]["mean_prediction"] - rep_metrics["M0"]["mean_prediction"],
                    "auc": rep_metrics["M1"]["auc"] - rep_metrics["M0"]["auc"],
                    "brier": rep_metrics["M1"]["brier"] - rep_metrics["M0"]["brier"],
                    "calibration_intercept": abs(rep_metrics["M1"]["calibration_intercept"]) - abs(rep_metrics["M0"]["calibration_intercept"]),
                    "calibration_slope": abs(rep_metrics["M1"]["calibration_slope"] - 1) - abs(rep_metrics["M0"]["calibration_slope"] - 1),
                }
            )
        print(f"completed {riskset}/{cohort}: {n_persons} persons, {len(y)} records")

detail = pd.DataFrame(detail_rows)
point_calc = pd.DataFrame(point_rows)
metrics_cols = [
    "event_rate",
    "mean_prediction",
    "auc",
    "brier",
    "calibration_intercept",
    "calibration_slope",
]
summary_rows = []
for keys, z in detail.groupby(["riskset_type", "heldout", "model"], sort=False):
    row = {"riskset_type": keys[0], "heldout": keys[1], "model": keys[2], "repetitions": len(z)}
    for metric in metrics_cols:
        vals = z[metric].dropna().to_numpy()
        row[f"{metric}_median"] = float(np.median(vals))
        row[f"{metric}_lower_95"] = float(np.quantile(vals, 0.025))
        row[f"{metric}_upper_95"] = float(np.quantile(vals, 0.975))
    summary_rows.append(row)
summary = pd.DataFrame(summary_rows)

point_r = pd.read_csv(POINT)
point_r = point_r[point_r["evaluation_weighting"] == "unweighted"]
merged = point_calc.merge(
    point_r,
    left_on=["riskset_type", "heldout", "model"],
    right_on=["riskset_type", "heldout", "model"],
    suffixes=("_python", "_r"),
)
validation_rows = []
for metric in ["event_rate", "mean_prediction", "auc", "brier", "calibration_intercept", "calibration_slope"]:
    diffs = np.abs(merged[f"{metric}_python"] - merged[f"{metric}_r"])
    validation_rows.append({"metric": metric, "max_absolute_difference": float(diffs.max())})
validation = pd.DataFrame(validation_rows)
max_diff = float(validation["max_absolute_difference"].max())

with gzip.open(OUT / "v21_strict9_person_cluster_bootstrap_300.csv.gz", "wt", newline="", encoding="utf-8") as fh:
    detail.to_csv(fh, index=False)
summary.to_csv(OUT / "v21_strict9_person_cluster_bootstrap_300_ci.csv", index=False)
point_calc.to_csv(OUT / "v21_strict9_point_metrics_python.csv", index=False)
validation.to_csv(OUT / "v21_strict9_cross_language_point_validation.csv", index=False)

provenance = {
    "repetitions": REPS,
    "resampling_unit": "person within held-out cohort",
    "paired_models": ["M0", "M1"],
    "risksets": ["two_wave", "one_wave"],
    "evaluation_weighting": "unweighted",
    "base_seed": BASE_SEED,
    "max_cross_language_point_difference": max_diff,
    "validation_pass": max_diff <= 1e-7,
}
(OUT / "v21_strict9_bootstrap_provenance.json").write_text(json.dumps(provenance, indent=2) + "\n", encoding="utf-8")
if not provenance["validation_pass"]:
    raise RuntimeError(f"Cross-language point validation failed: {max_diff}")
print(json.dumps(provenance, indent=2))
