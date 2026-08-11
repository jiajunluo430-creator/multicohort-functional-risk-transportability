# Analysis Charter v2.2: Submission-Story and Robustness Upgrade

Date frozen: 2026-08-10 (America/Chicago)

## Scope and non-drift rules

- The protocol-primary population remains the strict 9-item, two-wave difficulty-free risk set with a 2- to 3-year prediction horizon.
- The primary outcome remains newly reported difficulty in any of 5 common ADL or 4 common IADL items at the next observed assessment.
- Complete leave-one-cohort-out validation remains binding. No target cohort may enter preprocessing, coefficient fitting, or development-weight selection.
- M1 remains the principal model. The one-wave population remains a broader deployment sensitivity and is not promoted to primary after seeing results.
- This amendment does not tune an outcome, predictor, cohort, threshold, split, or model to improve results.

## Rationale for the two-wave primary population

Two consecutive difficulty-free assessments reduce sensitivity to transient or recurrent reports and define a clinically interpretable incident episode. A current-wave-only risk set is retained as a broader target-population sensitivity because it requires less history but has a different event burden.

## New analysis A: development-contribution weighting

Purpose: determine whether the principal country-out M1 result is driven by the current equal-cohort likelihood contribution.

Data and evaluation:

- Strict 9-item, two-wave, primary-horizon, observed-outcome records only.
- Identical M1 predictors and development-only median replacement/missingness indicators used in v2.1.
- Identical four complete cohort holdouts.
- Held-out evaluation is unweighted for this analysis so only development weighting changes.

Frozen development schemes:

1. `equal_cohort`: every development cohort contributes the same total likelihood weight, as in v2.1.
2. `sequence_weighted`: every eligible observed development sequence receives weight 1.
3. `person_equal`: within each development fold, sequence weights are the inverse of that person's number of observed development sequences and are normalized to mean 1; consequently each person contributes approximately the same total likelihood weight.

Report point estimates only: held-out observed risk, mean predicted risk, risk gap in percentage points, AUC, Brier score, calibration-in-the-large, and calibration slope. No new bootstrap, updating, or decision-curve analysis is authorized for this sensitivity.

Interpretation rule: the v2.1 equal-cohort analysis remains primary regardless of direction. Alternatives quantify dependence on development composition and cannot be selected post hoc as a replacement model.

## New analysis B: strict-outcome M2 transparency

Purpose: restore model-complexity transparency without changing the M1-centered story.

- Same strict 9-item, two-wave observed risk set and equal-cohort development weighting.
- `M2H` is the previously frozen history-enriched specification: M1 plus prior partnered status, self-rated health, mobility score, chronic-condition count, and depression proportion.
- `M2S` is the previously frozen reduced state-plus-history specification: age, sex, prediction horizon, current and prior self-rated health, current and prior mobility, current chronic-condition count, and current and prior depression proportion.
- Development-only preprocessing is unchanged; M2H uses missingness indicators and M2S uses median replacement without indicators, matching the previously declared specifications.
- Report point metrics and contrasts with M1. M2H/M2S remain explicitly exploratory and cannot displace M1 in the main claims.

## New analysis C: CHARLS unknown-vital-status boundary

Purpose: parallel the existing ELSA boundary analysis for the second cohort with a material unknown-status fraction.

- Reuse the already completed ELSA boundary results; do not refit or regenerate them.
- Develop an M1 difficulty-or-confirmed-death composite model in the other three cohorts and hold CHARLS out completely.
- The lower boundary uses observed difficulty plus confirmed deaths only. The upper boundary assigns all remaining unknown-alive-or-dead records as deaths.
- At 25% and 50%, select unknown records within landmark-wave strata in 200 fixed-seed repetitions, identical in principle to v2.1 ELSA analysis.
- These are deterministic or stochastic boundaries, not imputations and not mortality estimates.

## Updating interpretation amendment

- Retain absolute CITL, slope, Brier score, and the previously frozen retrospective indication rule for audit continuity.
- Do not treat absolute CITL alone as a clinical updating trigger.
- Present the probability-scale observed-minus-predicted risk gap first and decision-curve consequences from the existing disjoint calibration/evaluation outer splits second.
- No replacement threshold or optimized trigger is introduced. With only 4 targets, any relation between calibration error, target-data amount, and clinical consequence is descriptive; no correlation, dose-response, or universal rule is claimed.
- Selective updating means target-specific assessment of probability error and use consequences, not withholding standard calibration reporting.

## Table and figure population rules

- Main Table 1 predictor distributions use each person's earliest observed primary strict-9 two-wave sequence, one record per person.
- Episode-level risk-set, observed-follow-up, event, confirmed-death, and unknown-status counts remain separate rows and are not mixed with person-level predictor summaries.
- Main figures use cohort order CHARLS, ELSA, HRS, MHAS throughout.
- Figure 4 may use median independent calibration event-person counts already produced by the 30-outer-split nested analysis; no refitting is required.

## Writing claims

- Lead with absolute risks: CHARLS underprediction and MHAS overprediction; describe HRS/ELSA as smaller probability gaps even when CITL crosses a fixed diagnostic threshold.
- Central claim: risk ranking may transport while absolute probabilities do not; pooled internal validation can conceal target-specific failures; updating should be assessed selectively.
- Do not claim functional dependency, first-ever incidence, one universal global equation, prospective clinical utility, deployment readiness, global validity, or a universal target-sample requirement.
- The manuscript study type is `Prognostic Study` within a JAMA Network Open Original Investigation format, subject to current official instructions.

