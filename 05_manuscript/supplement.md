# Supplement 1

## Supplementary Methods, Results, Figures, and Reproducibility Information

### Contents

- eMethods
- eResults
- eFigure Legends
- eTable Inventory
- Reproducibility Map

# eMethods

## Data Sources and Access

The analysis used respondent-level files from CHARLS, ELSA, HRS, and MHAS under each study's access terms. Harmonized variables were obtained from verified public or registered-access releases and reconciled against source-wave documentation. Source data were read only. Individual-level data are not redistributed; scripts, aggregate outputs, and derivation manifests are prepared for public deposition.

## Target Population and Landmark

The primary unit was a prediction episode. At landmark t, a person was aged 60 years or older and reported no difficulty in any common outcome item at both t-1 and t. The outcome was assessed at t+1 after 2 to 3 years. Requiring 2 consecutive difficulty-free assessments reduced sensitivity to a transient report at a single wave and defined a new-difficulty episode. A person could contribute another episode after again meeting the eligibility criteria.

The primary estimand was risk of newly reported difficulty at an observed next assessment among eligible people with functional follow-up. It was not lifetime first incidence. The one-wave sensitivity required only difficulty-free status at t. MHAS sequences containing the 2003-to-2012 gap, either as history or prediction interval, were excluded from the primary horizon and retained as an extrapolation boundary.

## Exact Common Outcome

The primary outcome was difficulty in at least 1 of 9 items present in every cohort and configured wave:

- ADL: dressing, bathing, eating, getting in or out of bed, and toileting.
- IADL: preparing a hot meal, taking medications, managing money, and shopping.

Telephone difficulty was excluded from CHARLS, ELSA, and HRS because it was not available in MHAS. The former 10-item outcome in those 3 cohorts and 9-item MHAS outcome was retained only as a legacy sensitivity. Reported difficulty was not interpreted as needing help, dependence, or inability.

## Predictors and Model Specifications

M0 included age per 10 years and recorded sex. M1 included age, recorded sex, harmonized education category, partnered status, self-rated health (1, excellent, to 5, poor), a 0-to-3 mobility difficulty score, a 0-to-5 chronic-condition count, current smoking, depressive-symptom proportion, and prediction horizon.

M2H was the history-enriched specification: M1 plus prior-wave partnered status, self-rated health, mobility score, chronic-condition count, and depressive-symptom proportion. M2S was the reduced state-plus-history specification: age, sex, prediction horizon, current and prior self-rated health, current and prior mobility, current chronic-condition count, and current and prior depressive-symptom proportion. M2H used development-fold missingness indicators; M2S used development-fold median replacement without indicators. Both were specified after reviewing earlier results in these cohorts and therefore were not independently validated. They were reported as transparency analyses and could not replace M1.

Within every country-out fold, predictor medians and missingness-indicator eligibility were estimated in the 3 development cohorts only. The same transformation was then applied to the held-out target cohort. For fold f,

`P(Y=1|X,f) = expit(β0,f + Σj βj,f X*j,f)`,

where `expit(z) = 1/[1 + exp(-z)]`, `X*` contains age divided by 10, unscaled remaining predictors after development-median replacement, and any fold-specific missingness indicators. Four equations were refitted because each fold had a different development set; the study validates a modeling strategy rather than 1 global equation.

## Development-Contribution Weighting

The primary likelihood gave each of the 3 development cohorts the same total contribution. Two sensitivities changed only development weights:

1. Sequence weighted: every observed eligible development sequence received weight 1.
2. Person equal: each sequence received the inverse of that person's number of observed development sequences, normalized to mean 1, so each development person contributed approximately equal total weight.

Target evaluation was unweighted in all 3 analyses. The sensitivity reported point metrics only; no alternative weighting scheme was selected as a replacement after results.

After person-equal weighting increased HRS overprediction from 1.9 to 9.4 percentage points, a post-result directional decision-curve test was entered in the versioned charter before computation. HRS, M1, the 30 fixed outer person splits, 60% calibration and 40% evaluation allocation, intercept-only updating, and the 20% threshold were fixed. The analysis was repeated only for the person-equal HRS model; no other target-threshold combination was tested. This was a within-study corroboration, not independent validation.

## Country-Out Performance and Uncertainty

Every fold held out an entire data source. Pre-update target performance included observed risk, mean prediction, their percentage-point difference, AUC, Brier score, CITL, calibration slope, and flexible calibration. Person-cluster bootstrap intervals and paired M1-minus-M0 increments used 300 repetitions. Each sampled person carried all of that person's eligible sequences.

Flexible calibration used natural splines of the pre-update logit prediction. Displayed risk groups were equal-frequency groups with person-cluster robust uncertainty. Points were uniformly sized.

## Random-Split Contrast

One hundred cohort-stratified person-level random splits retained people from every cohort in development and evaluation. Pooled evaluation used equal total cohort contribution. A descriptive joint region required absolute CITL of 0.20 or less and slope from 0.80 to 1.20. For each repetition, the analysis counted how many countries were outside that region and whether a passing pooled result concealed at least 1 country outside it. The region summarized concealment; it was not a clinical acceptance threshold.

## Follow-up and Death Boundaries

Functional follow-up, confirmed death, unknown alive-or-dead status, and other known-alive records without functional assessment were kept separate. Source-specific death counts were not compared as mortality rates.

Separate CHARLS and ELSA composite models predicted difficulty or confirmed death after complete target holdout. The lower boundary included only observed difficulty and confirmed deaths. The upper boundary assigned every remaining unknown-status sequence as death. At 25% and 50%, unknown sequences were sampled as deaths within landmark-wave strata in 200 fixed-seed repetitions. These were boundary assignments, not imputations.

## Nested Local Updating

The pre-update statistical diagnostic and the amount of target information were separated. The versioned analysis charter defined the descriptive classification as:

- no update if absolute CITL was 0.10 or less and slope was 0.90 to 1.10;
- intercept-only update if slope was 0.80 to 1.20 outside the no-update region;
- intercept-plus-slope update otherwise.

This rule did not define clinical need. Observed-minus-predicted risk and decision consequences were evaluated separately.

Thirty outer person-level splits reserved 40% of target people for evaluation and 60% for calibration. Within each calibration pool, 100 person-level resamples were drawn at 5%, 10%, 20%, 30%, 40%, 50%, and 60% of all target people. The 0-person no-update option was retained. Continuous curves use the median number of independent event persons in the calibration sample. The +0.001 Brier tolerance and any first grid crossing were descriptive operating summaries, not minimum target sample sizes.

## Decision-Curve Analysis

For each outer split, the local calibrator was fitted in the 60% calibration pool. Net benefit was evaluated only in the disjoint 40% evaluation people at thresholds 0.05 to 0.30 in 0.025 increments:

`net benefit = TP/N - FP/N × pt/(1-pt)`.

Changes vs pre-update M1 were computed within each outer split before medians, empirical 2.5th and 97.5th outer-split percentiles, and nonnegative proportions were calculated. Net benefit multiplied by 1000 is reported as net true positives per 1000. Thresholds were illustrative; no action pathway or impact study was tested.

## Temporal Updating

Earlier-wave intercept or intercept-plus-slope calibrators were applied to every available later primary-horizon window. People could recur across windows, so this analysis did not provide independent temporal validation. Calendar time, aging, cohort composition, and survey changes co-varied.

## Respondent Weights

Respondent-weighted point estimates used the available landmark respondent weight. Compatible strata and primary sampling units were unavailable across all 4 sources; therefore, no full design-based variance or population-representative claim was made.

## Software

Primary modeling and figures used R 4.5.2. Aggregate table assembly and nested updating used Python 3.13. OpenAI Codex (GPT-5; OpenAI) was used in August 2026 for analysis-code drafting and debugging, generation of tables and figures from author-verified aggregate outputs, and language editing. Named authors reviewed the scripts, verified numerical checks, and accept responsibility for the work. Seeds, software-session information, fit convergence, person-overlap checks, table counts, and vector-structure checks were logged.

# eResults

## Population and Outcome Audit

All 9 items were available in every configured source wave. The primary risk set contained 146,605 eligible sequences from 43,740 people. Functional follow-up was observed for 126,264 sequences from 37,732 people, including 13,000 events. The one-wave risk set contained 207,773 sequences from 61,897 people; 174,240 sequences from 53,043 people had observed follow-up, including 23,276 events (eTables 1-3).

Telephone-specific cross-classification confirmed that removing telephone use produced the same 9-item outcome in all cohorts. The legacy outcome is reported only as a sensitivity (eTables 8-9).

## Primary Country-Out Performance

M1 improved AUC over age and sex in all 4 holdouts. Paired increments were 0.0464 in CHARLS, 0.1057 in ELSA, 0.1122 in HRS, and 0.0638 in MHAS. Brier changes were -0.0096, -0.0077, -0.0103, and +0.0113, respectively; negative values favor M1 (eTables 4-5).

Observed-minus-predicted risks were +8.9 percentage points in CHARLS, +1.6 in ELSA, -1.9 in HRS, and -11.1 in MHAS. Flexible calibration showed the same directions across the risk range (eTables 11-12).

## Development Weighting and History Models

CHARLS underprediction persisted with equal-cohort, sequence, and person weighting at 8.9, 8.2, and 6.2 percentage points. MHAS overprediction persisted at 11.1, 9.0, and 10.7 points. The closer ELSA and HRS results were more sensitive: person-equal weighting produced 2.7-point ELSA overprediction and 9.4-point HRS overprediction (eTable 17 and eFigure 7).

M2H improved AUC over M1 by 0.0076 to 0.0136, and M2S by 0.0059 to 0.0201. Brier changes vs M1 were no larger than 0.0010 in the favorable direction and worsened by 0.0007 to 0.0013 in MHAS. Neither specification reduced the main CHARLS or MHAS probability gaps (eTable 18).

## Current-Wave Population and Other Sensitivities

Removing the t-1 requirement increased event risk in every cohort. One-wave M1 AUC was 0.688 in CHARLS, 0.761 in ELSA, 0.752 in HRS, and 0.720 in MHAS, compared with 0.662, 0.749, 0.748, and 0.702 in the primary 2-wave risk set. CITL remained positive in CHARLS (0.815) and ELSA (0.135) and negative in HRS (-0.351) and MHAS (-0.757). MHAS Brier score again worsened relative to M0 (eTables 6 and 8 and eFigure 1).

Respondent weighting changed magnitudes without removing heterogeneity. M1 CITL remained 0.727 in CHARLS and -0.682 in MHAS (eTable 7 and eFigure 5).

## Pooled Validation Contrast

Pooled M1 calibration met the descriptive joint region in all 100 person-level random splits. At least 1 country was outside the region in 99 repetitions; 0, 1, 2, and 3 countries were outside in 1%, 10%, 74%, and 15% of repetitions. The median number outside when the pooled result passed was 2 (eTables 10A-10C and eFigure 2).

## Death Boundaries

CHARLS contained 304 unknown alive-or-dead sequences. Composite CITL was 0.504 with confirmed outcomes only, 0.587 when 25% of unknowns were assigned as death, 0.665 at 50%, and 0.806 when all unknowns were assigned. Underprediction remained throughout.

ELSA contained 3600 unknown-status sequences. Composite CITL was -0.051 with confirmed outcomes only, 0.192 at 25%, 0.390 at 50%, and 0.700 when all unknowns were assigned as death. Thus ELSA composite calibration depended materially on unresolved death status (eTables 16A-16B and eFigure 3).

## Local Updating

All 4 held-out target cohorts had pre-update absolute CITL greater than 0.10 and slopes from 0.80 to 1.20, so the scripted statistical rule classified intercept-only updating in every target (eTable 13). This common classification contrasted with probability gaps from 1.6 to 11.1 percentage points.

Across 30 outer splits, increasing independent event-person information generally reduced absolute CITL. Median Brier gains at the largest tested fraction were approximately 0.0086 in CHARLS, 0.0005 in ELSA, 0.0003 in HRS, and 0.0155 in MHAS. Outer-split variation and the continuous curves are reported rather than a universal target-data requirement (eTables 14A-14C).

At the illustrative 20% threshold under equal-cohort weighting, median intercept-update increments were 18.8, 1.1, -0.3, and 14.3 net true positives per 1000 in CHARLS, ELSA, HRS, and MHAS. The proportion of outer splits with nonnegative increments was 100%, 100%, 27%, and 100%. Across thresholds, CHARLS and MHAS had positive median increments at all 11, ELSA at 10, and HRS at 7; the largest median increment was 27.7 per 1000 in MHAS (eTable 15).

For the post-result HRS directional test under person-equal weighting, the median increment at 20% was 18.6 net true positives per 1000 (empirical 2.5th-97.5th percentiles, 16.2-20.4), nonnegative in all 30 outer splits. The paired increase over the equal-cohort result was 18.6 per 1000 (17.0-20.4) and favored person-equal weighting in all 30 splits (eTable 17 and eFigure 8).

## Temporal and Horizon Boundaries

Earlier-wave intercept updating worsened absolute CITL in 2 of 7 ELSA windows, 1 of 12 HRS windows, and all 3 MHAS windows. For MHAS, median updated absolute CITL was 2.047 vs 0.650 before updating, with median Brier worsening of 0.0094. Intercept-plus-slope updating improved median Brier overall but still worsened absolute CITL in some windows (eTables 19B-19C and eFigure 6).

Nonprimary MHAS long intervals had a mean prediction of approximately 53.0% against observed risk of 21.1%, Brier score 0.344, and CITL -2.989. These intervals were not mixed into the primary 2- to 3-year analysis (eTable 19A and eFigure 4).

# eFigure Legends

## eFigure 1. Current-Wave-Only Target-Population Calibration

Flexible calibration for the broader population requiring difficulty-free status only at t. Curves and uncertainty bands use the same procedures as the primary two-wave analysis.

## eFigure 2. Pooled Random-Split Reporting Attenuates Target Calibration Error

Calibration-in-the-large distributions from 100 cohort-stratified person-level random splits. The pooled value uses equal total cohort contribution. Country-specific values remain attenuated relative to complete country holdout because each model saw all cohorts during development.

## eFigure 3. Composite-Outcome Calibration Under Unknown-Death Boundaries

CHARLS and ELSA difficulty-or-death calibration as 0%, 25%, 50%, or 100% of unknown-status sequences are assigned as deaths. Intermediate points summarize 200 landmark-stratified assignments. Scenarios are boundaries, not imputed deaths.

## eFigure 4. MHAS Long-Interval Extrapolation Is a Transport Boundary

Primary 2- to 3-year and nonprimary long-interval M1 performance. Long history or prediction intervals were excluded from the primary analysis.

## eFigure 5. Respondent Weighting Changes but Does Not Remove Calibration Heterogeneity

Open points are unweighted and arrowheads are respondent-weighted estimates. Compatible strata and primary sampling units were unavailable for full design-based inference.

## eFigure 6. Earlier-Wave Updating Can Improve or Worsen Later Calibration

Pre-update vs updated absolute CITL in all available later primary-horizon windows. Points above the diagonal indicate worsening. People may recur across windows.

## eFigure 7. Absolute-Risk Transport Under 3 Development-Contribution Schemes

Observed-minus-predicted risk after equal-cohort, equal-sequence, or equal-person development weighting. Target evaluation is unchanged and unweighted. Positive values indicate underprediction.

## eFigure 8. Updating Performance Across Target Information and Development Weighting

Panel A contrasts the absolute observed-minus-predicted risk gap with the median change in net true positives per 1000 at the illustrative 20% threshold. The 4 primary points use equal-cohort development; the dashed arrow connects the HRS equal-cohort and post-result person-equal sensitivity for the same held-out target. Panels B and C show median absolute CITL and change in Brier score across 30 outer splits as independent target event-person information increases. Panel D reproduces the primary equal-cohort decision-curve increments across thresholds. This figure supports sensitivity and information-size interpretation rather than the primary evidence hierarchy.

# eTable Inventory

| Display | Content |
| --- | --- |
| eTable 1 | Strict 9-item flow and population |
| eTable 2 | Exact common 5-ADL/4-IADL concordance |
| eTable 3 | Flow by landmark |
| eTable 4 | M0/M1 country-out performance with confidence intervals |
| eTable 5 | Paired M1 increment over age and sex |
| eTable 6 | Current-wave-only country-out sensitivity |
| eTable 7 | Respondent-weighted point estimates |
| eTable 8 | Legacy vs exact 9-item outcome sensitivity |
| eTable 9A | Telephone-specific event cross-classification |
| eTable 9B | Telephone-specific trigger audit |
| eTable 10A | Random-split pooled and country summary |
| eTable 10B | Random-split concealment frequency |
| eTable 10C | Random split vs complete country-out validation |
| eTable 11 | Flexible-calibration bins |
| eTable 12 | Flexible-calibration curve coordinates |
| eTable 13 | Statistical update classification separated from target-data amount |
| eTable 14A | Continuous nested-updating curves |
| eTable 14B | Descriptive operating points, not minima |
| eTable 14C | Nested-updating outer-split summaries |
| eTable 15 | Decision curves with disjoint calibration and evaluation people |
| eTable 16A | CHARLS and ELSA unknown-death boundary summary |
| eTable 16B | CHARLS boundary repetitions |
| eTable 17 | Development-contribution weighting sensitivity and fixed HRS 20% decision analysis |
| eTable 18 | Exploratory M1/M2H/M2S transparency analysis |
| eTable 19A | Primary vs extended window scope |
| eTable 19B | All temporal updating windows |
| eTable 19C | Temporal updating summary |
| eTable 20 | Sequence-count reconciliation |
| eTable 21A | M1 country-out coefficients |
| eTable 21B | M1 preprocessing and scaling |
| eTable 22 | Death ascertainment by cohort |

# Reproducibility Map

| Component | Public aggregate artifact |
| --- | --- |
| Population and exact outcome | eTables 1-3 and 8-9; Figure 1 source data |
| M0/M1 country-out validation | eTables 4-5 and 21A-21B; Figure 2 source data |
| Flexible calibration | eTables 11-12; Figure 3 source data |
| Development weighting, fixed HRS decision test, and history models | eTables 17-18; eFigures 7-8 source data |
| Random-split concealment | eTables 10A-10C; Figure 2D source data |
| Death boundaries | eTables 16A-16B; eFigure 3 source data |
| Nested updating and decision curves | eTables 13-15; Figure 4 and eFigure 8 source data |
| Temporal and horizon boundaries | eTables 19A-19C; eFigures 4 and 6 source data |
| Quality control | fit, split-overlap, table-count, reference-resolution, document-render, and vector-structure checks |
