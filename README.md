# Multicohort functional-risk transportability

This repository contains aggregate-only reproducibility materials for the study **Risk Ranking and Absolute-Risk Transportability for Functional Difficulty in 4 National Cohorts**.

The study asks whether current multidomain health improves prediction of new functional difficulty beyond age and sex when an entire national cohort is withheld from development, whether ranking gains imply accurate absolute risk, and when local intercept updating adds decision value.

## Headline results

- Current health improved AUC by 0.0464 to 0.1122 in all 4 complete-cohort holdouts.
- Observed vs predicted risk was 20.1% vs 11.2% in CHARLS and 15.0% vs 26.2% in MHAS.
- Pooled calibration passed the prespecified region in all 100 random splits while concealing at least 1 cohort-specific calibration error in 99.
- At an illustrative 20% threshold, primary equal-cohort intercept updating added 18.8, 1.1, -0.3, and 14.3 net true positives per 1000 in CHARLS, ELSA, HRS, and MHAS, respectively.

## Repository scope

This repository includes versioned protocols, decision logs, portable analysis scripts, aggregate outputs, table sources, vector figures, manuscript sources, and the supplementary-table workbook. It contains **no respondent-level records, identifiers, raw predictions, restricted cohort files, or redistributable copies of source data**.

The code license does not override the source cohorts' data-use terms. Researchers must obtain CHARLS, ELSA, HRS, and MHAS data from their custodians and configure the four restricted input paths described in [`DATA_ACCESS.md`](DATA_ACCESS.md).

## Reproduction

See [`REPRODUCE.md`](REPRODUCE.md). The locked environment used R 4.5.2 and Python 3.13. Aggregate outputs are supplied so every reported number and figure can be audited without redistributing individual-level data.

## Evidence hierarchy

M1 and equal-cohort development weighting define the primary analysis. History-enriched M2H/M2S specifications and the HRS person-equal directional test are explicitly exploratory transparency analyses; complete provenance is retained in Supplement 1 and the versioned charter.

## Citation and archive

Use [`CITATION.cff`](CITATION.cff). The public repository is <https://github.com/jiajunluo430-creator/multicohort-functional-risk-transportability>, and the fixed source release is [v1.0.0](https://github.com/jiajunluo430-creator/multicohort-functional-risk-transportability/releases/tag/v1.0.0) (commit `1c4a23668590ae40daf7b77693ec958fd0dee458`). A DOI may be added through an archival service in a later version.

## License

Code and original repository documentation are released under the MIT License. Source cohort data remain governed by their respective custodians.
