# Reproduction guide

## 1. Environment

- R 4.5.2 with `data.table`, `haven`, `ggplot2`, `patchwork`, `scales`, and `svglite`.
- Python 3.13 with packages in `requirements.txt`.

Set `D2_PROJECT_ROOT` to the repository root and configure the four licensed input files listed in `DATA_ACCESS.md`.

## 2. End-to-end analysis order

Run the scripts in their numeric order through `62_temporal_all_windows_v21_strict9.R`, followed by `69_v22_weighting_m2_charls_boundary.R`, `80_v23_prepare_hrs_person_equal_predictions.R`, `81_v23_hrs_person_equal_dca.py`, `82_v23_table1_predictor_profile.R`, `83_compile_submission_tables_v23.py`, and `102_make_submission_figures_v25.R`.

The pipeline creates a restricted `02_derived` layer locally. That layer is intentionally absent from Git and must remain private. Aggregate results are written under `03_results` and figures under `04_figures`.

## 3. Audit without individual-level data

The committed aggregate result tree, figure source CSVs, SVG/PDF figures, manuscript source, and Supplement 2 workbook permit number-by-number review. Run `101_validate_manuscript_v25.py` after setting `D2_PROJECT_ROOT` to check word limits, evidence hierarchy, citations, and locked numerical phrases.

## 4. Locked boundaries

The 2003-to-2012 MHAS interval is excluded from the primary 2- to 3-year horizon. The primary outcome uses 9 common ADL/IADL difficulty items. Every validation fold withholds a complete cohort from preprocessing and fitting. HRS person-equal decision analysis is a post-result within-study corroboration and not independent external validation.
