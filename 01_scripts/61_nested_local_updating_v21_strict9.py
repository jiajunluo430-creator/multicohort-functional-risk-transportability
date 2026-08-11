#!/usr/bin/env python3
"""Nested person-level local-updating analysis for the strict nine-item M1 model.

The update indication is reported separately from the amount-of-local-data analysis.
Thirty outer splits reserve 40% of target-cohort persons for evaluation. Within each
remaining 60% calibration pool, 100 person-level resamples are drawn at each local
data fraction. Decision-curve evaluation uses the same disjoint outer split but fits
each calibrator only in the calibration pool.
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
PRED = ROOT / "03_results" / "14_reviewer_revision_v21" / "03_strict9_loco" / "v21_strict9_loco_predictions_all_risksets.csv.gz"
POINT = ROOT / "03_results" / "14_reviewer_revision_v21" / "03_strict9_loco" / "v21_strict9_loco_performance_point.csv"
BOOT = ROOT / "03_results" / "14_reviewer_revision_v21" / "04_cluster_bootstrap" / "v21_strict9_person_cluster_bootstrap_300_ci.csv"
OUT = ROOT / "03_results" / "14_reviewer_revision_v21" / "07_nested_local_updating"
OUT.mkdir(parents=True, exist_ok=True)

COHORTS = ("CHARLS", "HRS", "ELSA", "MHAS")
FRACTIONS = np.array([0.05, 0.10, 0.20, 0.30, 0.40, 0.50, 0.60], dtype=float)
OUTER_REPS = 30
INNER_REPS = 100
EVAL_FRACTION = 0.40
BRIER_TOLERANCE = 0.001
THRESHOLDS = np.round(np.arange(0.05, 0.3001, 0.025), 3)
BASE_SEED = 20260809


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


def auc_rank(y: np.ndarray, p: np.ndarray) -> float:
    y = np.asarray(y, dtype=np.int8)
    p = np.asarray(p, dtype=np.float64)
    order = np.lexsort((y, p))
    y = y[order]
    p = p[order]
    starts = np.r_[0, np.flatnonzero(np.diff(p) != 0) + 1]
    pos = np.add.reduceat((y == 1).astype(float), starts)
    neg = np.add.reduceat((y == 0).astype(float), starts)
    denom = pos.sum() * neg.sum()
    return float(np.sum(pos * (np.cumsum(neg) - neg + 0.5 * neg)) / denom) if denom > 0 else np.nan


def fit_intercept_matrix(y: np.ndarray, lp: np.ndarray, weights: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    y2 = np.asarray(y, dtype=float)[:, None]
    lp2 = np.asarray(lp, dtype=float)[:, None]
    weights = np.asarray(weights, dtype=float)
    a = np.zeros(weights.shape[1], dtype=float)
    converged = np.zeros(weights.shape[1], dtype=bool)
    for _ in range(80):
        mu = expit(np.clip(lp2 + a[None, :], -30, 30))
        score = np.sum(weights * (y2 - mu), axis=0)
        den = np.sum(weights * mu * (1 - mu), axis=0)
        step = np.divide(score, den, out=np.full_like(score, np.nan), where=den > 1e-12)
        active = ~converged
        step = np.where(active, np.clip(step, -5, 5), 0.0)
        a += np.nan_to_num(step, nan=0.0)
        converged |= active & np.isfinite(step) & (np.abs(step) < 1e-8)
        if converged.all():
            break
    events = np.sum(weights * y2, axis=0)
    totals = np.sum(weights, axis=0)
    success = converged & np.isfinite(a) & (events > 0) & (events < totals)
    return a, success


def fit_full_matrix(y: np.ndarray, lp: np.ndarray, weights: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    y2 = np.asarray(y, dtype=float)[:, None]
    x = np.asarray(lp, dtype=float)[:, None]
    weights = np.asarray(weights, dtype=float)
    b0 = np.zeros(weights.shape[1], dtype=float)
    b1 = np.ones(weights.shape[1], dtype=float)
    converged = np.zeros(weights.shape[1], dtype=bool)
    for _ in range(100):
        eta = np.clip(b0[None, :] + b1[None, :] * x, -30, 30)
        mu = expit(eta)
        v = weights * mu * (1 - mu)
        s0 = np.sum(weights * (y2 - mu), axis=0)
        s1 = np.sum(weights * (y2 - mu) * x, axis=0)
        h00 = np.sum(v, axis=0)
        h01 = np.sum(v * x, axis=0)
        h11 = np.sum(v * x * x, axis=0)
        det = h00 * h11 - h01 * h01
        valid = np.abs(det) > 1e-12
        d0 = np.divide(s0 * h11 - s1 * h01, det, out=np.full_like(det, np.nan), where=valid)
        d1 = np.divide(s1 * h00 - s0 * h01, det, out=np.full_like(det, np.nan), where=valid)
        active = ~converged
        d0 = np.where(active, np.clip(d0, -5, 5), 0.0)
        d1 = np.where(active, np.clip(d1, -5, 5), 0.0)
        b0 += np.nan_to_num(d0, nan=0.0)
        b1 += np.nan_to_num(d1, nan=0.0)
        converged |= active & np.isfinite(d0) & np.isfinite(d1) & (np.maximum(np.abs(d0), np.abs(d1)) < 1e-8)
        if converged.all():
            break
    events = np.sum(weights * y2, axis=0)
    totals = np.sum(weights, axis=0)
    success = converged & np.isfinite(b0) & np.isfinite(b1) & (events > 0) & (events < totals)
    return b0, b1, success


def raw_metrics(y: np.ndarray, p: np.ndarray) -> dict[str, float]:
    p = clip(p)
    lp = np.log(p / (1 - p))
    w = np.ones((len(y), 1), dtype=float)
    citl, ok_i = fit_intercept_matrix(y, lp, w)
    alpha, slope, ok_s = fit_full_matrix(y, lp, w)
    return {
        "records": int(len(y)),
        "events": int(np.sum(y)),
        "event_rate": float(np.mean(y)),
        "mean_prediction": float(np.mean(p)),
        "auc": auc_rank(y, p),
        "brier": float(np.mean((y - p) ** 2)),
        "calibration_intercept": float(citl[0]) if ok_i[0] else np.nan,
        "calibration_slope": float(slope[0]) if ok_s[0] else np.nan,
        "full_alpha": float(alpha[0]) if ok_s[0] else np.nan,
    }


def evaluate_updates(
    y: np.ndarray,
    p: np.ndarray,
    intercepts: np.ndarray,
    slopes: np.ndarray,
    success: np.ndarray,
    raw: dict[str, float],
) -> pd.DataFrame:
    p = clip(p)
    lp = np.log(p / (1 - p))
    nrep = len(intercepts)
    mean_prediction = np.full(nrep, np.nan)
    brier = np.full(nrep, np.nan)
    citl = np.full(nrep, np.nan)
    chunk = 20
    for lo in range(0, nrep, chunk):
        hi = min(nrep, lo + chunk)
        valid = success[lo:hi]
        lp_up = intercepts[None, lo:hi] + lp[:, None] * slopes[None, lo:hi]
        pp = expit(np.clip(lp_up, -30, 30))
        mean_prediction[lo:hi] = np.where(valid, np.mean(pp, axis=0), np.nan)
        brier[lo:hi] = np.where(valid, np.mean((y[:, None] - pp) ** 2, axis=0), np.nan)
        a = np.zeros(hi - lo, dtype=float)
        conv = np.zeros(hi - lo, dtype=bool)
        for _ in range(80):
            mu = expit(np.clip(lp_up + a[None, :], -30, 30))
            score = np.sum(y[:, None] - mu, axis=0)
            den = np.sum(mu * (1 - mu), axis=0)
            step = np.divide(score, den, out=np.full_like(score, np.nan), where=den > 1e-12)
            active = ~conv
            step = np.where(active, np.clip(step, -5, 5), 0.0)
            a += np.nan_to_num(step, nan=0.0)
            conv |= active & np.isfinite(step) & (np.abs(step) < 1e-8)
            if conv.all():
                break
        citl[lo:hi] = np.where(valid & conv, a, np.nan)
    slope_after = np.divide(
        raw["calibration_slope"], slopes,
        out=np.full(nrep, np.nan), where=np.abs(slopes) > 1e-12,
    )
    auc = np.where(slopes > 0, raw["auc"], np.where(slopes < 0, 1 - raw["auc"], 0.5))
    return pd.DataFrame({
        "records": raw["records"], "events": raw["events"], "event_rate": raw["event_rate"],
        "mean_prediction": mean_prediction, "auc": np.where(success, auc, np.nan), "brier": brier,
        "calibration_intercept": np.where(success, citl, np.nan),
        "calibration_slope": np.where(success, slope_after, np.nan),
    })


def selection_matrix(n_pool: int, n_cal: int, seed: int) -> np.ndarray:
    if n_cal == n_pool:
        return np.ones((n_pool, INNER_REPS), dtype=bool)
    rng = np.random.default_rng(seed)
    selected = np.zeros((n_pool, INNER_REPS), dtype=bool)
    for r in range(INNER_REPS):
        selected[rng.choice(n_pool, n_cal, replace=False), r] = True
    return selected


def build_update_indication() -> pd.DataFrame:
    point = pd.read_csv(POINT)
    point = point[(point["riskset_type"] == "two_wave") & (point["model"] == "M1") & (point["evaluation_weighting"] == "unweighted")].copy()
    boot = pd.read_csv(BOOT)
    boot = boot[(boot["riskset_type"] == "two_wave") & (boot["model"] == "M1")].copy()
    z = point.merge(boot, on=["riskset_type", "heldout", "model"], how="left", suffixes=("_point", "_bootstrap"))
    z["no_update_candidate"] = (z["calibration_intercept"].abs() <= 0.10) & z["calibration_slope"].between(0.90, 1.10)
    z["retrospective_update_indication"] = np.where(
        z["no_update_candidate"], "no_update",
        np.where(z["calibration_slope"].between(0.80, 1.20), "intercept_only", "intercept_and_slope"),
    )
    z["indication_rule"] = "no update if |CITL|<=0.10 and slope 0.90-1.10; otherwise intercept-only if slope 0.80-1.20; otherwise intercept+slope"
    keep = [
        "heldout", "records", "events", "event_rate", "mean_prediction", "auc", "brier",
        "calibration_intercept", "calibration_slope",
        "calibration_intercept_lower_95", "calibration_intercept_upper_95",
        "calibration_slope_lower_95", "calibration_slope_upper_95",
        "no_update_candidate", "retrospective_update_indication", "indication_rule",
    ]
    return z[keep].rename(columns={"heldout": "cohort"})


def decision_net_benefit(y: np.ndarray, p: np.ndarray, threshold: float) -> float:
    positive = p >= threshold
    return float(np.mean(positive * y - positive * (1 - y) * threshold / (1 - threshold)))


def nested_analysis(data: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    detail_rows: list[pd.DataFrame] = []
    dca_rows: list[dict[str, float | int | str | bool]] = []
    split_rows: list[dict[str, float | int | str]] = []
    for ci, cohort in enumerate(COHORTS, start=1):
        z = data[data["cohort"] == cohort].copy()
        ids = np.array(sorted(z["person_id"].unique()))
        n_total = len(ids)
        for outer in range(1, OUTER_REPS + 1):
            rng = np.random.default_rng(BASE_SEED + ci * 100000 + outer * 1000)
            eval_ids_arr = rng.choice(ids, int(np.floor(EVAL_FRACTION * n_total)), replace=False)
            eval_ids = set(eval_ids_arr)
            pool_ids = np.array([x for x in ids if x not in eval_ids])
            pool_set = set(pool_ids)
            overlap = len(eval_ids.intersection(pool_set))
            ev = z[z["person_id"].isin(eval_ids)].copy()
            cal = z[z["person_id"].isin(pool_set)].copy()
            y_eval = ev["strict9_event"].to_numpy(dtype=np.int8)
            p_eval = clip(ev["prediction"].to_numpy(dtype=float))
            raw = raw_metrics(y_eval, p_eval)
            raw_row = pd.DataFrame({
                "cohort": [cohort], "outer_split": [outer], "inner_resample": [0], "method": ["none"],
                "calibration_fraction_total_persons": [0.0], "total_persons": [n_total],
                "calibration_pool_persons": [len(pool_ids)], "evaluation_persons": [len(eval_ids)],
                "calibration_evaluation_person_overlap": [overlap], "calibration_persons": [0],
                "calibration_records": [0], "calibration_events": [0], "calibration_event_persons": [0],
                "evaluation_records": [len(ev)], "evaluation_events": [int(y_eval.sum())],
                "evaluation_event_persons": [int(ev.loc[ev["strict9_event"] == 1, "person_id"].nunique())],
                "fit_success": [True], "fitted_intercept": [0.0], "fitted_slope": [1.0],
                **{k: [raw[k]] for k in ["records", "events", "event_rate", "mean_prediction", "auc", "brier", "calibration_intercept", "calibration_slope"]},
                "raw_brier": [raw["brier"]], "delta_brier_vs_raw": [0.0],
            })
            detail_rows.append(raw_row)
            split_rows.append({
                "cohort": cohort, "outer_split": outer, "total_persons": n_total,
                "evaluation_persons": len(eval_ids), "calibration_pool_persons": len(pool_ids),
                "evaluation_records": len(ev), "calibration_pool_records": len(cal),
                "evaluation_events": int(y_eval.sum()), "calibration_pool_events": int(cal["strict9_event"].sum()),
                "calibration_evaluation_person_overlap": overlap,
            })

            pool_map = {person: i for i, person in enumerate(pool_ids)}
            row_person = np.array([pool_map[x] for x in cal["person_id"]], dtype=np.int32)
            y_cal = cal["strict9_event"].to_numpy(dtype=np.int8)
            p_cal = clip(cal["prediction"].to_numpy(dtype=float))
            lp_cal = np.log(p_cal / (1 - p_cal))
            event_by_person = cal.groupby("person_id", sort=False)["strict9_event"].max().reindex(pool_ids, fill_value=0).to_numpy(dtype=np.int8)

            for fi, fraction in enumerate(FRACTIONS, start=1):
                n_cal = min(len(pool_ids), max(2, int(np.floor(fraction * n_total))))
                selected = selection_matrix(len(pool_ids), n_cal, BASE_SEED + ci * 10000000 + outer * 100000 + fi * 1000)
                weights = selected[row_person, :]
                cal_records = weights.sum(axis=0).astype(int)
                cal_events = (weights * y_cal[:, None]).sum(axis=0).astype(int)
                cal_event_persons = (selected * event_by_person[:, None]).sum(axis=0).astype(int)
                a_i, ok_i = fit_intercept_matrix(y_cal, lp_cal, weights)
                a_f, b_f, ok_f = fit_full_matrix(y_cal, lp_cal, weights)
                methods = {
                    "intercept_only": (a_i, np.ones(INNER_REPS), ok_i),
                    "intercept_and_slope": (a_f, b_f, ok_f),
                }
                for method, (aa, bb, ok) in methods.items():
                    met = evaluate_updates(y_eval, p_eval, aa, bb, ok, raw)
                    burden = pd.DataFrame({
                        "cohort": cohort, "outer_split": outer, "inner_resample": np.arange(1, INNER_REPS + 1),
                        "method": method, "calibration_fraction_total_persons": fraction,
                        "total_persons": n_total, "calibration_pool_persons": len(pool_ids),
                        "evaluation_persons": len(eval_ids), "calibration_evaluation_person_overlap": overlap,
                        "calibration_persons": n_cal, "calibration_records": cal_records,
                        "calibration_events": cal_events, "calibration_event_persons": cal_event_persons,
                        "evaluation_records": len(ev), "evaluation_events": int(y_eval.sum()),
                        "evaluation_event_persons": int(ev.loc[ev["strict9_event"] == 1, "person_id"].nunique()),
                        "fit_success": ok, "fitted_intercept": aa, "fitted_slope": bb,
                    })
                    met["raw_brier"] = raw["brier"]
                    met["delta_brier_vs_raw"] = met["brier"] - raw["brier"]
                    detail_rows.append(pd.concat([burden.reset_index(drop=True), met.reset_index(drop=True)], axis=1))

            # DCA uses all calibration-pool persons and the disjoint evaluation persons.
            w_all = np.ones((len(cal), 1), dtype=float)
            ai, oki = fit_intercept_matrix(y_cal, lp_cal, w_all)
            af, bf, okf = fit_full_matrix(y_cal, lp_cal, w_all)
            dca_methods = {
                "raw_untouched": (0.0, 1.0, True),
                "intercept_only_full_pool": (float(ai[0]), 1.0, bool(oki[0])),
                "intercept_and_slope_full_pool": (float(af[0]), float(bf[0]), bool(okf[0])),
            }
            for threshold in THRESHOLDS:
                event_rate = float(np.mean(y_eval))
                dca_rows.append({
                    "cohort": cohort, "outer_split": outer, "method": "treat_none", "threshold": threshold,
                    "net_benefit": 0.0, "fit_success": True, "fitted_intercept": 0.0, "fitted_slope": 1.0,
                    "calibration_persons": len(pool_ids), "evaluation_persons": len(eval_ids),
                    "calibration_evaluation_person_overlap": overlap,
                })
                dca_rows.append({
                    "cohort": cohort, "outer_split": outer, "method": "treat_all", "threshold": threshold,
                    "net_benefit": event_rate - (1 - event_rate) * threshold / (1 - threshold),
                    "fit_success": True, "fitted_intercept": 0.0, "fitted_slope": 1.0,
                    "calibration_persons": len(pool_ids), "evaluation_persons": len(eval_ids),
                    "calibration_evaluation_person_overlap": overlap,
                })
                for method, (a, b, ok) in dca_methods.items():
                    pp = clip(expit(a + b * np.log(p_eval / (1 - p_eval)))) if ok else np.full(len(p_eval), np.nan)
                    dca_rows.append({
                        "cohort": cohort, "outer_split": outer, "method": method, "threshold": threshold,
                        "net_benefit": decision_net_benefit(y_eval, pp, threshold) if ok else np.nan,
                        "fit_success": ok, "fitted_intercept": a, "fitted_slope": b,
                        "calibration_persons": len(pool_ids), "evaluation_persons": len(eval_ids),
                        "calibration_evaluation_person_overlap": overlap,
                    })
            print(f"completed {cohort} outer {outer}/{OUTER_REPS}", flush=True)
    return pd.concat(detail_rows, ignore_index=True), pd.DataFrame(dca_rows), pd.DataFrame(split_rows)


def summarize_nested(detail: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    outer_rows: list[dict[str, float | int | str | bool]] = []
    group_cols = ["cohort", "outer_split", "method", "calibration_fraction_total_persons"]
    for keys, g in detail.groupby(group_cols, sort=True, observed=True):
        ok = g["fit_success"] & np.isfinite(g["calibration_intercept"]) & np.isfinite(g["brier"])
        x = g.loc[ok]
        row = dict(zip(group_cols, keys))
        row.update({
            "inner_attempts": int(len(g)), "inner_successes": int(ok.sum()), "fit_success_rate": float(ok.mean()),
            "total_persons": int(g["total_persons"].iloc[0]), "evaluation_persons": int(g["evaluation_persons"].iloc[0]),
            "evaluation_records": int(g["evaluation_records"].iloc[0]), "evaluation_events": int(g["evaluation_events"].iloc[0]),
            "median_calibration_persons": float(g["calibration_persons"].median()),
            "median_calibration_records": float(g["calibration_records"].median()),
            "median_calibration_events": float(g["calibration_events"].median()),
            "median_calibration_event_persons": float(g["calibration_event_persons"].median()),
            "median_auc": float(x["auc"].median()), "median_brier": float(x["brier"].median()),
            "median_delta_brier_vs_raw": float(x["delta_brier_vs_raw"].median()),
            "median_citl": float(x["calibration_intercept"].median()),
            "median_abs_citl": float(x["calibration_intercept"].abs().median()),
            "median_slope": float(x["calibration_slope"].median()),
            "median_abs_slope_error": float((x["calibration_slope"] - 1).abs().median()),
            "proportion_abs_citl_le_0_20": float((x["calibration_intercept"].abs() <= 0.20).mean()),
            "proportion_brier_within_plus_0_001": float((x["delta_brier_vs_raw"] <= BRIER_TOLERANCE).mean()),
            "proportion_brier_improved": float((x["delta_brier_vs_raw"] <= 0).mean()),
        })
        if row["method"] == "none":
            row["descriptive_tolerance_met"] = bool(row["median_abs_citl"] <= 0.10 and row["median_abs_slope_error"] <= 0.10)
        elif row["method"] == "intercept_only":
            row["descriptive_tolerance_met"] = bool(
                row["fit_success_rate"] >= 0.95 and row["median_abs_citl"] <= 0.10
                and row["proportion_brier_within_plus_0_001"] >= 0.90
            )
        else:
            row["descriptive_tolerance_met"] = bool(
                row["fit_success_rate"] >= 0.95 and row["median_abs_citl"] <= 0.10
                and row["median_abs_slope_error"] <= 0.10
                and row["proportion_brier_within_plus_0_001"] >= 0.90
            )
        outer_rows.append(row)
    outer = pd.DataFrame(outer_rows)

    curve_rows: list[dict[str, float | int | str]] = []
    group_cols2 = ["cohort", "method", "calibration_fraction_total_persons"]
    metrics = [
        "fit_success_rate", "median_calibration_persons", "median_calibration_records", "median_calibration_events",
        "median_calibration_event_persons", "median_auc", "median_brier", "median_delta_brier_vs_raw",
        "median_citl", "median_abs_citl", "median_slope", "median_abs_slope_error",
        "proportion_abs_citl_le_0_20", "proportion_brier_within_plus_0_001", "proportion_brier_improved",
    ]
    for keys, g in outer.groupby(group_cols2, sort=True, observed=True):
        row = dict(zip(group_cols2, keys))
        row.update({"outer_splits": int(len(g)), "outer_tolerance_rate": float(g["descriptive_tolerance_met"].mean())})
        for metric in metrics:
            values = g[metric].to_numpy(dtype=float)
            row[f"{metric}_median_across_outer"] = float(np.nanmedian(values))
            row[f"{metric}_lower_95_outer"] = float(np.nanquantile(values, 0.025))
            row[f"{metric}_upper_95_outer"] = float(np.nanquantile(values, 0.975))
        curve_rows.append(row)
    curves = pd.DataFrame(curve_rows)

    operating_rows: list[dict[str, float | str | bool]] = []
    for (cohort, method), g in curves[curves["method"].isin(["intercept_only", "intercept_and_slope"])].groupby(["cohort", "method"], observed=True):
        passed = g[g["outer_tolerance_rate"] >= 0.80].sort_values("calibration_fraction_total_persons")
        row: dict[str, float | str | bool] = {"cohort": cohort, "method": method, "criterion": "first tested fraction with >=80% outer splits meeting descriptive tolerance; not a minimum-data requirement"}
        if len(passed):
            first = passed.iloc[0]
            row.update({
                "descriptive_operating_point_identified": True,
                "first_fraction_with_ge80pct_outer_tolerance": float(first["calibration_fraction_total_persons"]),
                "persons_at_operating_point_median": float(first["median_calibration_persons_median_across_outer"]),
                "events_at_operating_point_median": float(first["median_calibration_events_median_across_outer"]),
                "outer_tolerance_rate": float(first["outer_tolerance_rate"]),
            })
        else:
            row.update({
                "descriptive_operating_point_identified": False,
                "first_fraction_with_ge80pct_outer_tolerance": np.nan,
                "persons_at_operating_point_median": np.nan,
                "events_at_operating_point_median": np.nan,
                "outer_tolerance_rate": np.nan,
            })
        operating_rows.append(row)
    return outer, curves, pd.DataFrame(operating_rows)


def summarize_dca(dca: pd.DataFrame) -> pd.DataFrame:
    raw = dca[dca["method"] == "raw_untouched"][["cohort", "outer_split", "threshold", "net_benefit"]].rename(columns={"net_benefit": "raw_net_benefit"})
    z = dca.merge(raw, on=["cohort", "outer_split", "threshold"], how="left")
    z["delta_net_benefit_vs_raw"] = z["net_benefit"] - z["raw_net_benefit"]
    rows = []
    for keys, g in z.groupby(["cohort", "method", "threshold"], sort=True, observed=True):
        rows.append({
            "cohort": keys[0], "method": keys[1], "threshold": keys[2], "outer_splits": len(g),
            "net_benefit_median": float(g["net_benefit"].median()),
            "net_benefit_lower_95_outer": float(g["net_benefit"].quantile(0.025)),
            "net_benefit_upper_95_outer": float(g["net_benefit"].quantile(0.975)),
            "delta_net_benefit_vs_raw_median": float(g["delta_net_benefit_vs_raw"].median()),
            "proportion_delta_net_benefit_ge_0": float((g["delta_net_benefit_vs_raw"] >= 0).mean()),
        })
    return pd.DataFrame(rows)


def main() -> None:
    usecols = ["riskset_type", "cohort", "person_id", "outcome_observed", "strict9_event", "model", "prediction"]
    data = pd.read_csv(PRED, usecols=usecols, dtype={"person_id": "string", "strict9_event": "float64", "prediction": "float64"})
    data = data[(data["riskset_type"] == "two_wave") & (data["model"] == "M1") & (data["outcome_observed"] == 1) & data["strict9_event"].notna()].copy()
    data["strict9_event"] = data["strict9_event"].astype(np.int8)
    indication = build_update_indication()
    detail, dca, split_audit = nested_analysis(data)
    outer, curves, operating = summarize_nested(detail)
    dca_summary = summarize_dca(dca)

    detail.to_csv(OUT / "v21_strict9_nested_updating_detail_30x100.csv.gz", index=False, compression="gzip")
    outer.to_csv(OUT / "v21_strict9_nested_updating_outer_summaries.csv", index=False)
    curves.to_csv(OUT / "v21_strict9_nested_updating_continuous_curves.csv", index=False)
    operating.to_csv(OUT / "v21_strict9_nested_updating_descriptive_operating_points.csv", index=False)
    indication.to_csv(OUT / "v21_strict9_update_indication_separate_from_data_amount.csv", index=False)
    split_audit.to_csv(OUT / "v21_strict9_nested_updating_split_audit.csv", index=False)
    dca.to_csv(OUT / "v21_strict9_disjoint_sample_dca_by_outer_split.csv.gz", index=False, compression="gzip")
    dca_summary.to_csv(OUT / "v21_strict9_disjoint_sample_dca_summary.csv", index=False)

    update_detail = detail[detail["method"] != "none"]
    expected_groups = len(COHORTS) * OUTER_REPS * len(FRACTIONS) * 2
    actual_groups = update_detail.groupby(["cohort", "outer_split", "calibration_fraction_total_persons", "method"]).ngroups
    inner_counts = update_detail.groupby(["cohort", "outer_split", "calibration_fraction_total_persons", "method"])["inner_resample"].nunique()
    gates = pd.DataFrame({
        "gate": [
            "30_outer_splits_per_cohort", "100_inner_resamples_per_fraction_method", "zero_person_overlap_all_outer_splits",
            "no_update_zero_person_candidate_present", "brier_tolerance_plus_0_001_encoded", "dca_calibration_evaluation_disjoint",
        ],
        "passed": [
            bool((split_audit.groupby("cohort")["outer_split"].nunique() == OUTER_REPS).all()),
            bool(actual_groups == expected_groups and (inner_counts == INNER_REPS).all()),
            bool((split_audit["calibration_evaluation_person_overlap"] == 0).all()),
            bool((detail[(detail["method"] == "none") & (detail["calibration_persons"] == 0)].groupby("cohort")["outer_split"].nunique() == OUTER_REPS).all()),
            bool(BRIER_TOLERANCE == 0.001 and "proportion_brier_within_plus_0_001" in outer.columns),
            bool((dca["calibration_evaluation_person_overlap"] == 0).all()),
        ],
    })
    gates.to_csv(OUT / "v21_strict9_nested_updating_gates.csv", index=False)
    provenance = {
        "python": sys.version, "platform": platform.platform(), "numpy": np.__version__, "pandas": pd.__version__,
        "riskset": "strict nine-item two-wave primary 2-3-year", "model": "M1 country-out predictions",
        "outer_splits": OUTER_REPS, "inner_resamples": INNER_REPS, "outer_evaluation_fraction_persons": EVAL_FRACTION,
        "calibration_pool_fraction_persons": 1 - EVAL_FRACTION, "calibration_fractions_total_target_persons": FRACTIONS.tolist(),
        "brier_noninferiority_tolerance": BRIER_TOLERANCE, "dca_thresholds": THRESHOLDS.tolist(),
        "split_unit": "person", "data_amount_claim": "continuous curves; descriptive operating point is not a minimum-data requirement",
    }
    (OUT / "v21_strict9_nested_updating_provenance.json").write_text(json.dumps(provenance, indent=2), encoding="utf-8")
    print(gates.to_string(index=False), flush=True)
    print(indication.to_string(index=False), flush=True)
    print(operating.to_string(index=False), flush=True)


if __name__ == "__main__":
    main()
