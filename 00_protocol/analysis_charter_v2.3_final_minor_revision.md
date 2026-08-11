# Analysis Charter v2.3: Final Presubmission Minor Revision

Date frozen: 2026-08-10 (America/Chicago)

## Binding continuity

- The protocol-primary population, exact common 9-item outcome, 2- to 3-year horizon, complete leave-one-cohort-out design, M0/M1 specifications, and principal claims remain unchanged from v2.2.
- Equal-cohort development weighting remains the primary estimand. Person-equal weighting is a prespecified sensitivity and cannot replace the primary model after results are seen.
- No outcome, feature, cohort, calibration rule, threshold, split, or model-complexity search is authorized.
- Previously passed v2.2 analyses and quality-control gates will be reused, not rerun.

## Sole new inferential analysis: HRS person-equal decision consequence

Purpose: test the prespecified within-study prediction that the larger HRS probability gap produced by person-equal development contribution should make intercept-only updating more useful at the same illustrative 20% risk threshold.

Frozen specification:

1. Target: HRS only.
2. Model: strict-9-item M1, developed in CHARLS, ELSA, and MHAS with the already executed person-equal likelihood contribution (each development person has equal total contribution across their observed sequences).
3. Target exclusion: HRS remains excluded from development preprocessing, coefficient fitting, and development-weight construction.
4. Evaluation design: reuse the exact v2.1 HRS outer-split algorithm and fixed seed, with 30 person-level outer splits, 60% of target persons in the calibration pool, 40% in the disjoint evaluation sample, and zero person overlap.
5. Update: intercept-only logistic recalibration fitted in the complete 60% calibration pool. The raw model and treat-all/treat-none strategies remain comparators.
6. Threshold: exactly 0.20. No threshold grid, optimization, or selection is authorized for the new weighting analysis.
7. Estimand: change in net benefit versus the raw person-equal model, expressed as net true-positive equivalents per 1000 evaluation episodes.
8. Summary: median and empirical 2.5th and 97.5th percentiles across the 30 outer splits, plus the number and proportion of splits with a nonnegative increment.
9. Reference: reuse, without recomputation, the existing equal-cohort HRS results from the same 30 outer splits.

The 100 inner resamples per target-data fraction remain part of the previously completed data-amount analysis and are not rerun: the DCA branch has always used the full outer calibration pool and has no inner-resampling estimand.

Interpretation is binding regardless of direction. Confirmation requires a materially larger median net-benefit increment than the equal-cohort reference and improved consistency across outer splits. Failure to confirm will be reported as evidence that probability-gap magnitude alone does not determine decision value.

## Descriptive Table 1 amendment

- Continue to use each participant's earliest observed primary two-wave sequence, one row per person.
- Display current self-rated health, mobility difficulty, chronic-condition count, and depression symptom proportion as mean (SD), because their medians compress between-cohort contrasts.
- Keep age as mean (SD), categorical predictors as No. (%), prediction horizon as median (IQR), and the proxy-interview row.
- Remove all episode-flow rows from Table 1; Figure 1 and eTable 1 remain the authoritative flow displays.

## Manuscript and display amendments

- Article type: `Original Investigation — Cohort Study` and design wording `retrospective cohort study`, because the current JAMA Network Open instructions define Diagnostic/Prognostic Studies as prospective.
- STROBE is the primary reporting guideline; relevant TRIPOD and TRIPOD+AI cluster-validation items remain reported as supplemental methodological crosswalks.
- For a new submission, retain separate structured-abstract headings `Design`, `Setting`, and `Participants`, as required by the current official instructions; do not combine them preacceptance.
- Figure 1 will replace its stacked-bar flow panel with cohort-specific observed-follow-up markers and aligned count columns; terminology will use `held-out target cohort` and `complete-cohort holdout`.
- Figure 3 will label observed and predicted risks in every cohort and state that axes differ across cohorts.
- Figure 4 will label the log1p x-axis transformation, add the zero-increment line, use empirical percentile wording, distinguish cohorts by both color and shape/line type, and condition the decision curves on equal-cohort development weighting. The new HRS person-equal result may be shown only as the frozen paired sensitivity.
- Table and figure typography must meet the journal's current size and accessibility requirements; main figures must remain vector-only with live text.

## Writing amendments

- Restore the disclosure that M2H and M2S were specified after reviewing earlier results in these cohorts and therefore are not independently validated.
- Add the exact one-wave CITL values and one-wave versus primary M1 AUC values to Results.
- Add the 95% confidence intervals for M1-minus-M0 AUC increments and a compact numeric temporal-updating statement.
- Replace internal or defensive phrases (`for audit continuity`, `frozen before the present computation`, `entirely unseen`, and `clinically constructive alternative`) with direct scientific descriptions.
- Observational time span (1994-2022), age range, and female range will be stated in the abstract after verification against authoritative tables.

## Stop rule

After the single HRS weighting-DCA test, descriptive Table 1 recast, manuscript/display corrections, and full technical verification, v2.3 is final. No 100-split expansion, new cohort, model rescue, threshold search, or additional revision cycle is authorized before submission.

