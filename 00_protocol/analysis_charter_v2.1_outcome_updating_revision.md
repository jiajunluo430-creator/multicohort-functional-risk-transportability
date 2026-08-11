# Analysis charter v2.1 — outcome harmonization and updating-design revision

Date frozen: 2026-08-09 (America/Chicago), before any v2.1 result was computed.

## Purpose

Resolve the two new full-package reviews of v2 without repeating analyses that already passed. The binding questions are whether the principal CHARLS/MHAS calibration pattern survives an exactly identical 9-item outcome, whether incomplete ELSA death confirmation changes the attrition analysis, and whether local-updating conclusions persist when updating indication is separated from estimation precision and the outer evaluation split is varied.

## Immutable core and permitted correction

- Sources remain CHARLS, HRS, ELSA, and MHAS; no SHARE/KLoSA access.
- Age at landmark remains at least 60 years.
- The protocol-defined two-wave, difficulty-free population remains the primary landmark population. It will not be replaced after seeing v2.1 results.
- Complete country-and-design holdout remains the primary validation design.
- M0 and M1 remain prespecified anchors; the original penalized M2 remains the prespecified history model; M2H/M2S remain post hoc exploratory.
- The measured outcome remains newly reported ADL/IADL difficulty, not dependency or need for assistance.
- Correcting the purported minimum-common outcome from 10 items in 3 cohorts/9 in MHAS to the genuinely common **5 ADL + 4 IADL items** is a measurement-harmonization correction, not an outcome search. The strict 9-item outcome becomes primary for M0/M1 transport analyses. The prior 10/9-item definition is retained as a legacy sensitivity.

## Binding v2.1 analyses

### A. Strict common 9-item outcome

1. Define difficulty from the 5 common ADL items and 4 common IADL items: preparing a hot meal, taking medications, managing money, and shopping. Telephone use is excluded from all cohorts.
2. Rebuild the two-wave primary risk sets and t+1 outcome under the strict 9-item definition.
3. Refit M0 and M1 in genuine leave-one-cohort-out folds with development-only preprocessing and the existing equal-cohort likelihood.
4. Report n, events, observed risk, mean prediction, AUC, Brier score, calibration-in-the-large (CITL), calibration slope, and person-cluster bootstrap intervals.
5. Recompute flexible calibration curves and the pooled-versus-country-stratified random-split contrast under the strict 9-item outcome.
6. In CHARLS, HRS, and ELSA, report the number and proportion of legacy events triggered only by telephone difficulty.
7. If the CHARLS/MHAS pattern changes materially, revise the main interpretation; do not preserve the previous transportability claim by selecting the legacy outcome.

### B. One-wave M0/M1 target-population sensitivity

1. Define an expanded sensitivity risk set using current-wave (t) 9-item difficulty-free status and observed t+1 status, without requiring t-1 observation or t-1 difficulty-free status.
2. Apply the same 2- to 3-year horizon restrictions and genuine country-and-design holdout.
3. Report participants, sequences, events, age/sex/current-health summaries, M1-versus-M0 discrimination, CITL, slope, Brier score, and the direction of CHARLS/MHAS calibration.
4. This analysis is a target-population sensitivity, not a replacement of the protocol-defined primary population.

### C. ELSA death confirmation and boundary analysis

1. Audit all available ELSA harmonized/raw death-year, vital-status, interview-status, and end-of-life fields, with labels and wave coverage.
2. Use a death-linked variable only if its semantics and timing support death before/by the scheduled t+1 assessment.
3. If linked death is incomplete, retain confirmed deaths and conduct an ELSA-only boundary analysis among outcome-unknown sequences: assign 0% and 100% of unknowns to death as deterministic bounds; for 25% and 50%, perform 200 landmark-stratified random assignments with a fixed seed and summarize composite M1 CITL/Brier/AUC distributions.
4. Table 1 will distinguish confirmed death from unknown vital status. Cross-cohort death percentages will not be described as directly comparable unless confirmation methods are demonstrably aligned.

### D. Local updating as a two-stage decision

1. Stage 1 asks whether update is indicated on untouched target data:
   - no update indicated when absolute CITL is at most 0.10 and slope is 0.80-1.20;
   - intercept update indicated when absolute CITL exceeds 0.10 while slope remains 0.80-1.20;
   - intercept-and-slope update indicated when slope falls outside 0.80-1.20;
   - broader revision indicated when flexible calibration remains materially nonlinear or updated Brier performance is not improved within tolerance.
2. Stage 2 estimates conditional updating performance only where an update is indicated. A 0-person/no-update strategy is retained as a candidate.
3. Replace a single fixed evaluation split with 30 person-level outer splits. Within each outer split, reserve 40% for evaluation and use 100 inner calibration resamples at each prespecified target fraction/size.
4. Report continuous calibration quality against independent calibration-event persons: median and interquartile range of absolute CITL, slope error, Brier difference, and the proportion of outer splits meeting descriptive quality regions.
5. Permit an absolute Brier noninferiority tolerance of +0.001 versus the raw model. Remove the redundant zero-tolerance and median absolute slope-error gate from headline conclusions.
6. Any first-crossing sample size is explicitly an observed conditional planning estimate. Report its median, interquartile range, range, and fraction of outer splits with no crossing; do not call it a required minimum.
7. Figure 4 will lead with continuous curves, use cohort facets/log or event-count axes, and remove the visually dominant single-split red-cross classification.

### E. Temporal updating

- Report all available later windows, not only the latest window.
- For each cohort/model/method, report median raw and updated absolute CITL, median Brier, and the fraction of windows improved.
- State explicitly when updating worsens already acceptable calibration. Temporal updating remains supportive descriptive evidence because persons may recur and periods/designs co-vary.

### F. Internal consistency and reproducibility

1. Recalculate eligible/observed/risk-set sequence distributions from the authoritative analytic files; distinguish means from medians and persons with zero observed sequences.
2. Add full M1 fold-specific coefficients, intercepts, scaling/preprocessing, missing-value rules, and probability formula.
3. Verify that DCA updating and evaluation samples are disjoint; otherwise replace with fixed independent evaluation or cross-fitting and downgrade claims.
4. Audit the survey-weight claim. If valid respondent weights exist, report respondent-weighted AUC, Brier, CITL, and slope with the exact weight field and limitations; do not call this design-based inference without harmonized strata/PSU. If valid comparable weights are absent, delete the performance claim and retain only weighted event-rate sensitivity.
5. Label the HRS 2-year-horizon row as a one-development-cohort boundary (ELSA only) or remove it from cross-cohort robustness claims.
6. Use “new episode of reported difficulty after 2 consecutive difficulty-free waves” where repeated events/re-entry make first-ever language incorrect.
7. Distinguish transportability of a refitted modeling strategy from validation of one frozen global equation.

## Reporting and figure rules

- Abstract and Key Points will not report single-split “no stable minimum” claims or deterministic required-person counts.
- Key Points will be shortened and include the negative MHAS Brier and threshold-limited HRS decision-curve findings if space permits after the primary transport result.
- eFigure 1 will use cohort-specific/free probability scales or an explicit inset so HRS/ELSA calibration is legible.
- TRIPOD+AI and TRIPOD-Cluster remain the primary prediction-model reporting frameworks; STROBE remains supplementary. Article-category wording will follow current official JAMA Network Open instructions, not reviewer preference alone.
- The public repository DOI remains a true author-controlled pre-submission requirement.

## Stop rules

- Do not change the 9-item definition, outer-split count, Brier tolerance, update-indication thresholds, or one-wave population after inspecting results.
- Do not promote the one-wave sensitivity to primary solely because it is more favorable.
- Do not impute ELSA deaths as facts; boundary assignments remain labeled scenarios.
- Do not rescue a weakened MHAS result by returning to the legacy 10/9-item outcome.
- Do not add a fifth cohort or new algorithm family.
- If strict harmonization or one-wave expansion removes the central calibration pattern, revise the manuscript claim and journal ceiling.

## Signed post-computation implementation note

Recorded 2026-08-09 after all v2.1 computations; no threshold or result was changed.

The executed nested-updating script used a nested descriptive indication rule: no-update candidate when `|CITL| <= 0.10` and slope 0.90-1.10; intercept-only indication when the no-update condition was not met but slope remained 0.80-1.20; intercept-plus-slope consideration outside 0.80-1.20. The charter's Stage 1 narrative had described the no-update slope region as 0.80-1.20. This is a documented implementation discrepancy. It has no effect on the v2.1 indication classification because all 4 strict-outcome holdouts had `|CITL| > 0.10`. The script, outputs, and manuscript report the executed rule; the frozen text above is preserved unchanged for auditability.
