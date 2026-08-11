# Analysis charter v2.0 — reviewer-driven validity upgrade

Date frozen: 2026-08-09 (America/Chicago), before any v2.0 result was computed.

## Purpose

Resolve two independent full-package reviews without changing the source cohorts or retrospectively selecting favorable findings. The revised paper asks what aspects of short-horizon prediction transport across country-and-design settings, what aspects do not, and what labeled target outcome data are needed to repair absolute probabilities.

## Terminology and claim hierarchy

- The measured outcome is **incident ADL/IADL difficulty**, not dependency, assistance need, disability, or loss of independence.
- The design is **internal-external cross-validation with country-and-design holdout**, not four independent external validations of the adaptively developed model.
- M0, M1, and the original penalized M2 retain their prespecified status.
- M2H and M2S are **post hoc adaptive exploratory models**. Their bootstrap intervals are conditional on the selected specification and do not include analysis-path uncertainty.
- Pooled random-split **reporting**, not random splitting alone, may conceal country-specific calibration error. Country-stratified random-split reporting is expected to detect but may attenuate the error magnitude.
- Calibration is reported continuously (CITL, slope, Brier score, curves, and uncertainty); pass/fail gates remain secondary operational summaries.

## Core population and windows

The four previously vetted sources, age at landmark 60 years or older, two preceding waves free of observed ADL/IADL difficulty, and the 2- to 3-year primary prediction window remain unchanged. The 9-year MHAS interval remains an excluded boundary analysis. No SHARE or KLoSA data will be accessed for v2.0.

## Estimands

1. **Primary observed-follow-up estimand:** risk of incident ADL/IADL difficulty at t+1 among eligible landmark sequences with an observed t+1 functional assessment. This explicitly conditions on survival and response.
2. **Composite sensitivity estimand:** risk of incident ADL/IADL difficulty or death before/by the scheduled t+1 assessment among sequences eligible at t. Death coding must be supported by source interview-status/death-year labels. Alive nonresponders remain outcome-unknown.
3. **Observation-process sensitivity:** primary estimand reweighted by cohort-specific inverse probability of having an observed t+1 functional outcome, modeled from t predictors. Stabilized weights will be truncated at cohort-specific 1st and 99th percentiles; untruncated results will be retained diagnostically.
4. **Episode estimand:** a randomly selected eligible landmark sequence, used in the original likelihood.
5. **Person-equal sensitivity estimand:** each person contributes total weight 1 within a cohort; first-eligible-sequence analysis remains a separate strong sensitivity.

## Frozen reviewer-driven analyses

### A. Flow, death, and nonresponse

- Construct the risk set after age, t-1/t observed independence, and current predictors, before requiring t+1 observation.
- For every cohort and landmark, report observed functional outcome, death, alive/nonresponding or outcome-missing, and unclassified status.
- Compare age, sex, self-rated health, mobility, chronic conditions, and depressive symptoms between observed and nonobserved t+1 groups.
- Fit the composite and observation-weighted sensitivities only if source coding passes a label/value audit.

### B. Repeated landmark sequences

- Report persons contributing 1, 2, 3, 4, or at least 5 eligible sequences; independent persons with at least 1 event; and persons with repeated event sequences.
- Compare episode-weighted, person-equal-weighted, and first-eligible-sequence results.
- Continue person-level partitioning and bootstrap resampling. No row-level uncertainty will be reported.

### C. Development weighting and calibration decomposition

For each country-and-design holdout, refit M1 under:

1. equal total cohort weight (original primary);
2. record-weighted development;
3. equal-event/equal-nonevent contribution by development cohort.

Report AUC, CITL, calibration slope, Brier score, mean prediction, observed risk, and 95% person-cluster bootstrap intervals. A target-prevalence intercept oracle may be used only to decompose baseline-risk error and will never be called untouched transport.

### D. Country-design and measurement sensitivity

- Overlapping calendar window: landmark years 2012–2016 with outcome year no later than 2018, where available in all four cohorts.
- Horizon strata: 2-year and 3-year analyses reported separately; lack of four-country overlap is itself a design limitation.
- Remove self-rated health and, separately, z-standardize self-rated health within each cohort using unlabeled cohort distributions; report calibration changes.
- Evaluate an incident difficulty threshold of at least 2 ADL/IADL items as an outcome-severity sensitivity when source summary counts permit it.

### E. Calibration curves and updating data cost

- Add cohort/model calibration curves with grouped observed risks, group n/events, and a flexible smooth.
- Report calibration-sample persons, independent event persons, eligible sequences, event sequences, and evaluation events for every resampling condition.
- Re-express data cost primarily in persons and independent events, with percentages secondary.
- Add a fixed-evaluation-set experiment so increasing calibration size does not mechanically shrink the evaluation set.
- Downsample HRS to the CHARLS person/event scale under the same rule to diagnose precision-limited failure.
- In HRS, ELSA, and MHAS, evaluate temporal updating using earlier target waves for calibration and later waves for evaluation when at least 100 later events are available. This is temporally external updating, not a fifth independent model-development cohort.
- Intercept-only updating will be judged on CITL/Brier, not on a slope criterion it cannot alter; intercept-plus-slope retains the joint criterion.

### F. Reporting corrections

- Report M1-vs-M0 and exploratory M2H/M2S increments separately.
- State the negative prespecified M2 result before exploratory models.
- Report MHAS M1 Brier deterioration and the negative HRS 15%–25% incremental net-benefit region directly.
- Add subgroup n/events, disclose the actual bootstrap repetition count, and label sparse estimates hypothesis-generating.
- Replace health-equity claims with distributional validity/country-specific calibration heterogeneity.
- Change article type to Original Investigation — Cohort Study; add STROBE alongside TRIPOD+AI and TRIPOD-Cluster.
- Specify one illustrative action context for DCA (triggering a structured multidomain geriatric assessment or enhanced follow-up) while retaining DCA as secondary and threshold-dependent.

## Stop rules

- Do not redefine death, nonresponse, outcome severity, common calendar windows, or stability gates after inspecting results.
- If death status is not validly classifiable in a cohort, report the unavailable component and do not impute death.
- If a temporal or subgroup analysis has fewer than 100 events, report descriptively or omit inferential claims.
- If reviewer-driven sensitivities attenuate the central calibration result, revise the claim; do not rescue it with alternate weighting or model tuning.
- Do not request a fifth cohort merely to preserve the previous paired-history claim. A new cohort is justified only for a future frozen independent validation.

