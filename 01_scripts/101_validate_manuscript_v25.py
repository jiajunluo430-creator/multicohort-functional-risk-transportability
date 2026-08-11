#!/usr/bin/env python3
"""Numerical, narrative-hierarchy, author-field, and journal-format checks for v2.5 sources."""

from __future__ import annotations

import os

import json
import re
from pathlib import Path


ROOT = Path(os.environ.get("D2_PROJECT_ROOT", Path(__file__).resolve().parents[1]))
SOURCE = ROOT / "06_manuscript" / "submission_v25"
OUT = ROOT / "03_results" / "18_submission_upgrade_v25" / "03_manuscript_qc"
OUT.mkdir(parents=True, exist_ok=True)

main_path = SOURCE / "main_manuscript.md"
supp_path = SOURCE / "supplement.md"
cover_path = SOURCE / "cover_letter.md"
crosswalk_path = SOURCE / "reporting_crosswalk.md"
main = main_path.read_text(encoding="utf-8")
supp = supp_path.read_text(encoding="utf-8")
cover = cover_path.read_text(encoding="utf-8")
crosswalk = crosswalk_path.read_text(encoding="utf-8")


def section(text: str, start: str, end: str) -> str:
    if start not in text or end not in text:
        raise ValueError(f"Missing section boundary: {start!r} to {end!r}")
    return text.split(start, 1)[1].split(end, 1)[0]


def word_count(text: str) -> int:
    text = re.sub(r"<[^>]+>", " ", text)
    text = re.sub(r"[`*_#|]", " ", text)
    return len(re.findall(r"[A-Za-z0-9]+(?:[-'][A-Za-z0-9]+)*", text))


title = main.splitlines()[0].removeprefix("# ")
key_points = section(main, "## Key Points", "## Abstract")
abstract = section(main, "## Abstract", "## Introduction")
main_text = section(main, "## Introduction", "## Acknowledgment Section")

# Reference resolution and first-appearance order.
reference_section = section(main, "## References", "# Table 1. Participant Characteristics at the First Eligible Prediction Episode")
reference_numbers = [int(value) for value in re.findall(r"(?m)^([0-9]+)\. ", reference_section)]
citation_text = main.split("## References", 1)[0]
citation_groups = re.findall(r"<sup>([^<]+)</sup>", citation_text)


def expand_citation(group: str) -> list[int]:
    values: list[int] = []
    for part in re.split(r"[,;]", group):
        part = part.strip()
        match = re.fullmatch(r"([0-9]+)-([0-9]+)", part)
        if match:
            values.extend(range(int(match.group(1)), int(match.group(2)) + 1))
        elif re.fullmatch(r"[0-9]+", part):
            values.append(int(part))
        else:
            raise ValueError(f"Unparseable citation group: {group}")
    return values


citations = [number for group in citation_groups for number in expand_citation(group)]
first_appearance: list[int] = []
for number in citations:
    if number not in first_appearance:
        first_appearance.append(number)

table_header = re.search(r"\| Characteristic \| CHARLS \| ELSA \| HRS \| MHAS \|", main)
internal_terms = ["reviewer revision", "authoritative file", "signed charter", "high-risk concern", "v2.1", "v2.2", "v2.3"]
author_facing_text = "\n".join([main, supp, cover, crosswalk]).lower()

required_numeric_phrases = [
    "20.1% vs 11.2%", "15.0% vs 26.2%", "99 of 100", "8 of 30",
    "18.8, 1.1, -0.3, and 14.3", "6.2 to 8.9", "9.0 to 11.1",
    "0.504", "0.806", "-0.051", "0.700", "0.0059 to 0.0201",
    "30 of 30", "0.815, 0.135, -0.351, and -0.757",
    "0.0464 (95% CI, 0.0230-0.0675)", "2 of 7 ELSA windows", "1 of 12 HRS windows",
]

supplement_inventory_count = len(re.findall(r"(?m)^\| eTable [0-9]+[A-C]? \|", supp))

checks = [
    ("title_at_most_100_characters", len(title) <= 100, len(title)),
    ("title_names_ranking_probability_separation", title == "Risk Ranking and Absolute-Risk Transportability for Functional Difficulty in 4 National Cohorts", title),
    ("key_points_at_most_100_words", word_count(key_points) <= 100, word_count(key_points)),
    ("abstract_at_most_350_words", word_count(abstract) <= 350, word_count(abstract)),
    ("main_text_at_most_3000_words", word_count(main_text) <= 3000, word_count(main_text)),
    ("one_table_four_figures", "**Tables and figures:** 1 table and 4 figures" in main, None),
    ("cohort_study_label", "**Study type:** Cohort Study" in main and "Retrospective cohort study" in main, None),
    ("separate_submission_abstract_headings", all(f"### {heading}" in abstract for heading in ["Design", "Setting", "Participants"]), None),
    ("abstract_results_demographics_first", "Among 37,732 adults (mean cohort age" in abstract, None),
    ("positive_increment_leads_abstract_results", abstract.index("Compared with age and sex alone") < abstract.index("Despite these ranking gains"), None),
    ("headline_excludes_HRS_person_equal", all("person-equal" not in text.lower() and "18.6" not in text for text in [key_points, abstract, cover]), None),
    ("results_section_order", main.index("### Incremental Prediction and Absolute-Risk Transport") < main.index("### Pooled Validation and Robustness of Target Errors") < main.index("### Selective Updating and Decision Value"), None),
    ("results_positive_before_probability_error", main.index("Across all 4 complete-cohort holdouts") < main.index("These discrimination gains did not ensure accurate absolute risk"), None),
    ("table1_exact_five_column_order", table_header is not None, None),
    ("table1_participant_only", "Prediction episodes" not in section(main, "# Table 1.", "# Figure Legends"), None),
    ("table1_mean_sd_predictors", all(term in main for term in ["Self-rated health score, mean (SD)", "Mobility difficulty score, mean (SD)", "Chronic condition count, mean (SD)", "Depression symptom proportion, mean (SD)"]), None),
    ("reference_numbers_sequential", reference_numbers == list(range(1, len(reference_numbers) + 1)), reference_numbers),
    ("all_references_cited", set(reference_numbers) == set(citations), sorted(set(reference_numbers) - set(citations))),
    ("citations_resolve", all(number in reference_numbers for number in citations), sorted(set(citations) - set(reference_numbers))),
    ("references_first_appearance_order", first_appearance == reference_numbers, first_appearance),
    ("DCA_references_cited", 31 in citations and 32 in citations, None),
    ("PROBAST_reference_cited", 27 in citations, None),
    ("no_internal_revision_language", not any(term in author_facing_text for term in internal_terms), [term for term in internal_terms if term in author_facing_text]),
    ("all_required_numeric_phrases_present", all(phrase in main for phrase in required_numeric_phrases), [phrase for phrase in required_numeric_phrases if phrase not in main]),
    ("four_primary_limitations_declared", "Four limitations define the claim" in main, None),
    ("two_wave_rationale_present", "reduced sensitivity to transient or recurrent reports" in main, None),
    ("CITL_not_sufficient_trigger", "not treated as a sufficient clinical trigger" in main and "CITL remains essential" in main, None),
    ("history_models_disclosed_in_supplement", "Exploratory history-enriched specifications and their reporting constraints are described in Supplement 1" in main and "specified after reviewing earlier results in these cohorts and therefore were not independently validated" in supp, None),
    ("post_result_HRS_test_scope_disclosed_in_supplement", "no other target-threshold combination was tested" in supp.lower() and "within-study corroboration, not independent validation" in supp, None),
    ("HRS_sensitivity_demoted_to_supplement", "Development-weighting sensitivity results are reported in eFigure 8 and eTable 17" in main and "18.6 per 1000" not in main and "person-equal" not in section(main, "## Key Points", "## Abstract"), None),
    ("main_figure4_primary_equal_cohort_only", "All panels use the primary equal-cohort development weighting" in main and "development-weighting sensitivity results appear in eFigure 8" in main, None),
    ("supplement_contains_eight_efigures", len(re.findall(r"(?m)^## eFigure [1-8]\. ", supp)) == 8 and "eFigure 8. Updating Performance" in supp, len(re.findall(r"(?m)^## eFigure [1-9]\. ", supp))),
    ("clinical_implications_paragraph_present", all(phrase in main for phrase in ["potential for systematic under-referral", "potential for over-referral", "not minimum sample-size requirements"]), None),
    ("explicit_contribution_statement_present", "The principal contribution is empirical" in main, None),
    ("positive_final_pathway", "Together, these findings define a practical evaluation pathway" in main, None),
    ("AI_disclosure_in_methods", "OpenAI Codex (GPT-5; OpenAI)" in main_text and "accept responsibility for the work" in main_text, None),
    ("no_defensive_audit_phrasing", "for audit continuity" not in author_facing_text and "frozen before the present computation" not in author_facing_text, None),
    ("pre_update_terminology_replaces_untouched", "untouched" not in author_facing_text, None),
    ("key_points_meaning_has_decision_number", "up to 27.7 net true positives per 1000" in key_points, None),
    ("figure1_legend_matches_display", "aligns risk-set and unavailable-outcome counts" in main, None),
    ("figure2_random_split_axis_is_cohort_specific_evaluation", "number of cohort-specific evaluations outside the descriptive joint region" in main, None),
    ("author_names_and_known_degrees_present", all(value in main for value in ["Jiajun Luo", "Qinglong Chen", "Jing Liu", "Fanghui Lu, PhD", "Xiaolong Liang, MD, PhD"]), None),
    ("author_affiliations_present", all(value in main for value in ["The First Affiliated Hospital of Chongqing Medical University", "The University of Chicago Medical Center", "The Second Affiliated Hospital of Chongqing Medical University"]), None),
    ("funding_and_conflict_statements_present", "This study received no external funding" in main and "None reported" in main, None),
    ("parent_cohort_ethics_and_consent_present", "parent cohorts obtained approval" in main.lower() and "participants provided informed consent" in main, None),
    ("clean_cover_letter", "revision" not in cover.lower() and "reviewer" not in cover.lower(), None),
    ("cover_has_no_checklist_upload_claim", "reporting checklists" not in cover.lower(), None),
    ("supplement_has_exactly_31_data_sheets", supplement_inventory_count == 31, supplement_inventory_count),
]

result = {
    "title": title,
    "title_characters": len(title),
    "key_points_words": word_count(key_points),
    "abstract_words": word_count(abstract),
    "main_text_words": word_count(main_text),
    "references": len(reference_numbers),
    "citations": sorted(set(citations)),
    "checks": [{"gate": name, "passed": bool(passed), "detail": detail} for name, passed, detail in checks],
}
(OUT / "manuscript_source_qc.json").write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")

failed = [row for row in result["checks"] if not row["passed"]]
print(json.dumps(result, indent=2, ensure_ascii=False))
if failed:
    raise SystemExit(f"Manuscript source QC failed {len(failed)} gate(s)")
