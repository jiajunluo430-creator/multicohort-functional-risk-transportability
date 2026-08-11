# Risk Ranking and Absolute-Risk Transportability for Functional Difficulty in 4 National Cohorts

## Title Page

**Article type:** Original Investigation  
**Study type:** Cohort Study  
**Authors:** Jiajun Luo<sup>1,2</sup>; Qinglong Chen<sup>3</sup>; Jing Liu<sup>3</sup>; Fanghui Lu, PhD<sup>3</sup>; Xiaolong Liang, MD, PhD<sup>1</sup>  
**Affiliations:** <sup>1</sup>Department of Gastrointestinal Surgery, The First Affiliated Hospital of Chongqing Medical University, Chongqing, China; <sup>2</sup>Molecular Oncology Laboratory, Department of Orthopedic Surgery and Rehabilitation Medicine, The University of Chicago Medical Center, Chicago, Illinois; <sup>3</sup>Department of Cancer Center, The Second Affiliated Hospital of Chongqing Medical University, Chongqing, China  
**Author notes:** Jiajun Luo, Qinglong Chen, and Jing Liu contributed equally. Fanghui Lu and Xiaolong Liang are co-corresponding authors.  
**Primary corresponding author:** Xiaolong Liang, MD, PhD, Department of Gastrointestinal Surgery, The First Affiliated Hospital of Chongqing Medical University, Chongqing 400016, China (204951@hospital.cqmu.edu.cn; [TELEPHONE TO BE PROVIDED]).  
**Co-corresponding author:** Fanghui Lu, PhD, Department of Cancer Center, The Second Affiliated Hospital of Chongqing Medical University, Chongqing, China (lufh@cqmu.edu.cn).  
**Main-text word count:** 2410  
**Abstract word count:** 349  
**Tables and figures:** 1 table and 4 figures  

## Key Points

**Question** Does current health improve prediction beyond age and sex in held-out national cohorts, and do rankings imply accurate probabilities?

**Findings** In this cohort study of 37,732 adults, current health improved AUC by 0.046 to 0.112 in all 4 holdouts. Yet China was underpredicted (20.1% observed vs 11.2% predicted) and Mexico overpredicted (15.0% vs 26.2%); pooled splits concealed cohort-specific calibration error in 99 of 100 repetitions.

**Meaning** Transportable discrimination did not guarantee transportable absolute risk; target gap size identified where recalibration added up to 27.7 net true positives per 1000.

## Abstract

### Importance

Transported functional-difficulty models may rank older adults correctly yet misstate absolute risk enough to alter geriatric assessment, referral, or service planning.

### Objective

To determine whether current health improved prediction beyond age and sex across national aging cohorts, whether better ranking yielded accurate absolute risk, and when local recalibration added decision value.

### Design

Retrospective cohort study with complete-cohort holdout and disjoint person-level evaluation of local updating. Observations spanned 1994 to 2022; analyses were conducted in August 2026.

### Setting

Population-based aging cohorts in China, England, the United States, and Mexico.

### Participants

Adults aged 60 years or older who were difficulty-free in 9 common ADL/IADL items at 2 consecutive waves and reassessed 2 to 3 years later.

### Exposures

Current demographic, social, physical, chronic disease, behavioral, and mental health predictors.

### Main Outcomes and Measures

New difficulty in any common item; area under the receiver operating characteristic curve (AUC), Brier score, calibration, and decision-curve net benefit.

### Results

Among 37,732 adults (mean cohort age, 66.1-67.9 years; 43.5%-58.2% female), 126,264 prediction episodes included 13,000 events. Compared with age and sex alone, current health improved AUC in every held-out cohort by 0.0464 to 0.1122; Brier score improved in China, England, and the United States but worsened in Mexico by 0.0113 (95% CI, 0.0070-0.0151). Despite these ranking gains, observed risk was 20.1% when 11.2% was predicted in China and 15.0% when 26.2% was predicted in Mexico. Pooled calibration met the prespecified region in all 100 random splits but concealed at least 1 cohort-specific calibration error in 99. At an illustrative 20% threshold under equal-cohort development weighting, intercept updating yielded median gains of 18.8 and 14.3 net true positives per 1000 in China and Mexico, compared with 1.1 in England and -0.3 in the United States.

### Conclusions and Relevance

Current multidomain health consistently improved risk ranking, but absolute-risk accuracy varied markedly across national cohorts. Complete-cohort holdout revealed errors hidden by pooled validation, and independently evaluated updating added decision value primarily where target probability error was substantial.

## Introduction

New difficulty with activities of daily living (ADL) or instrumental activities of daily living (IADL) affects older adults, caregivers, and health systems.<sup>1-5</sup> Physical performance, chronic conditions, and multidomain health predict functional decline,<sup>6-9</sup> but reviews identify limited external validation and incomplete calibration reporting.<sup>10,11</sup> A model may rank people correctly while systematically understating or overstating their probabilities, which matters when absolute risk informs geriatric assessment, follow-up intensity, or community-service planning.

Transportability requires more than a random split of pooled data. Complete source holdout better represents use in a target that supplied no development data,<sup>12-15</sup> and calibration must be assessed on the probability scale as well as through formal summary measures.<sup>16-18</sup> Country is nevertheless entangled with survey design, period, language, interview practice, and measurement. Local recalibration may correct a baseline-risk difference, but it can add little or be unstable when the target probability error is small.

We used 4 national aging cohorts to determine whether current multidomain health improved prediction beyond age and sex in a completely held-out cohort, whether better ranking translated into accurate absolute risk, whether pooled validation concealed target-specific error, and when local intercept updating improved decision value. We hypothesized that ranking would transport more consistently than absolute risk and that updating consequences would depend on the target error produced by the development composition.

## Methods

### Study Design and Cohorts

We conducted a retrospective cohort study using the China Health and Retirement Longitudinal Study (CHARLS), English Longitudinal Study of Ageing (ELSA), US Health and Retirement Study (HRS), and Mexican Health and Aging Study (MHAS).<sup>19-23</sup> Public or registered-access data were used under each source study's terms. Reporting followed STROBE for the cohort design and TRIPOD+AI and TRIPOD-Cluster for prediction-model methods and results; PROBAST domains informed safeguards against target leakage and biased performance assessment.<sup>24-27</sup> The parent cohorts obtained approval from their respective institutional review boards or ethics committees, and participants provided informed consent. This secondary analysis used deidentified data available under public or registered-access agreements and involved no direct participant contact. Under applicable institutional policy, [INSERT FORMAL LOCAL REVIEW, WAIVER, OR NOT-HUMAN-PARTICIPANTS DETERMINATION], no additional consent was required for this analysis.

For the primary 3-wave landmark population, participants were aged at least 60 years at wave t, reported no difficulty in the harmonized items at both t-1 and t, and had an observed functional assessment at t+1. Requiring 2 consecutive difficulty-free assessments reduced sensitivity to transient or recurrent reports and defined an incident prediction episode. The prediction horizon was 2 to 3 years. The 2003-to-2012 MHAS interval was excluded from the primary horizon and retained as an extrapolation boundary. A prespecified sensitivity required only current-wave difficulty-free status. People could contribute multiple episodes after again meeting eligibility; the estimand was episode-level risk among people with observed functional follow-up, not lifetime first incidence.

### Outcome and Predictors

The outcome was newly reported difficulty in at least 1 of 9 items common to all cohorts: bathing, dressing, eating, getting in or out of bed, toileting, preparing a hot meal, taking medications, managing money, and shopping. Telephone use was removed from CHARLS, HRS, and ELSA. Difficulty did not imply needing assistance, dependence, or inability.

The minimal model (M0) included age and recorded sex. The current-health model (M1) added education, partnered status, self-rated health, difficulty with 3 mobility tasks, 5 chronic conditions, smoking, depressive-symptom proportion, and prediction horizon, all measured at t. Missing predictors were replaced by development-set medians; indicators were added when a predictor was missing in that development fold. Exploratory history-enriched specifications and their reporting constraints are described in Supplement 1.

### Country-Out Validation and Sensitivity Analyses

Each fold held out 1 complete cohort and fit the modeling strategy in the other 3. Target data were excluded from preprocessing and model fitting. The primary likelihood gave equal total contribution to each development cohort. Two versioned sensitivity analyses gave equal weight to each development sequence or approximately equal total contribution to each development person. Held-out evaluation remained unweighted so that only development composition changed.

Pre-update performance included observed and mean predicted risk, AUC, Brier score, CITL, calibration slope, and natural-spline calibration curves. Confidence intervals and M1-vs-M0 increments used 300 person-cluster bootstrap repetitions. Respondent-weighted point estimates were a sensitivity because compatible strata and primary sampling units were unavailable across all sources. In 100 cohort-stratified person-level random splits, we compared pooled reporting with country-specific reporting and complete country holdout.

Confirmed deaths were distinguished from unknown vital status. For separate CHARLS and ELSA difficulty-or-death composites, the lower boundary included observed difficulty and confirmed deaths only; the upper boundary assigned every remaining unknown-status sequence to death. Intermediate 25% and 50% assignments were sampled within landmark strata in 200 fixed-seed repetitions. These scenarios were boundaries, not imputations or mortality estimates.

### Local and Temporal Updating

The analysis charter defined a descriptive rule that classified no update when absolute CITL was at most 0.10 and slope was 0.90 to 1.10, intercept-only updating when the slope was 0.80 to 1.20, and intercept-plus-slope updating otherwise. This statistical classification was not treated as a sufficient clinical trigger. We separately examined the observed-minus-predicted risk difference and decision-curve consequences.

For each target, 30 person-level outer splits reserved 40% of people for evaluation and 60% for calibration. Within every outer split, 100 person-level calibration resamples were drawn at fractions from 5% through 60% of target people. A 0-person, no-update strategy was retained. Performance was reported continuously against independent target event-person counts; grid crossings were descriptive, not minimum sample-size requirements.<sup>28-30</sup>

Decision curves used calibrators fitted in the calibration pool and net benefit evaluated only in the disjoint outer evaluation set at thresholds from 5% to 30%.<sup>31,32</sup> Development-weighting sensitivities and the fixed post-result directional test are described in Supplement 1.

Earlier-wave calibrators were also applied to later primary windows; these analyses were descriptive because people could recur and calendar time, aging, and survey changes co-varied. Analyses used R version 4.5.2 and Python version 3.13. OpenAI Codex (GPT-5; OpenAI) was used in August 2026 to assist with analysis-code drafting and debugging, generation of tables and figures from author-verified aggregate outputs, and language editing. It did not make final eligibility decisions or scientific interpretations. Named authors reviewed the scripts, verified numerical checks, and accept responsibility for the work.

## Results

### Analysis Population

The primary risk set comprised 146,605 eligible sequences from 43,740 cohort-specific people; 126,264 sequences from 37,732 people had observed functional follow-up and included 13,000 new-difficulty episodes (Table 1 and Figure 1). At each person's first eligible episode, mean age ranged from 66.1 to 67.9 years across cohorts and 43.5% to 58.2% were female. Observed risks were 20.1% in CHARLS, 9.7% in ELSA, 9.6% in HRS, and 15.0% in MHAS. Removing the t-1 requirement expanded the observed sensitivity population to 174,240 sequences from 53,043 people with 23,276 events. Confirmed-death and unknown-status counts were source dependent and were not interpreted as comparable mortality rates.

### Incremental Prediction and Absolute-Risk Transport

Across all 4 complete-cohort holdouts, M1 improved discrimination beyond age and sex. Pre-update M1 AUCs were 0.662 (95% CI, 0.642-0.684) in CHARLS, 0.749 (0.741-0.759) in ELSA, 0.748 (0.743-0.753) in HRS, and 0.702 (0.684-0.718) in MHAS. M1-minus-M0 AUC increments were 0.0464 (95% CI, 0.0230-0.0675), 0.1057 (0.0968-0.1138), 0.1122 (0.1062-0.1188), and 0.0638 (0.0473-0.0811), respectively. Brier score improved by 0.0096 in CHARLS, 0.0077 in ELSA, and 0.0103 in HRS but worsened by 0.0113 (95% CI, 0.0070-0.0151) in MHAS (Figure 2).

These discrimination gains did not ensure accurate absolute risk. Observed vs mean predicted M1 risk was 20.1% vs 11.2% in CHARLS, 9.7% vs 8.2% in ELSA, 9.6% vs 11.5% in HRS, and 15.0% vs 26.2% in MHAS (Figures 2 and 3). The corresponding observed-minus-predicted differences were 8.9, 1.6, -1.9, and -11.1 percentage points. CITL was 0.746 (95% CI, 0.667-0.829), 0.207 (0.166-0.243), -0.215 (-0.235 to -0.192), and -0.786 (-0.852 to -0.719); slopes were 0.855, 1.102, 1.106, and 0.834.

### Pooled Validation and Robustness of Target Errors

Pooled M1 calibration met the descriptive joint region in all 100 random-split repetitions, while at least 1 cohort was outside the region in 99; the median number outside when the pooled result passed was 2 (Figure 2D). Country-specific random-split errors were attenuated because every fitted model had seen people from every cohort.

The large opposing errors persisted across development-contribution schemes: CHARLS underprediction ranged from 6.2 to 8.9 percentage points, and MHAS overprediction from 9.0 to 11.1 points. HRS and ELSA were composition sensitive: person-equal weighting increased HRS overprediction from 1.9 to 9.4 points and changed ELSA from 1.6-point underprediction to 2.7-point overprediction. In the current-wave eligibility sensitivity, CITL was 0.815, 0.135, -0.351, and -0.757 in CHARLS, ELSA, HRS, and MHAS, preserving each primary error direction; M1 AUC remained higher in every cohort than in the primary 2-wave risk set (eTable 6).

In CHARLS, difficulty-or-death composite CITL ranged from 0.504 when only confirmed deaths were included to 0.806 when all 304 unknown-status sequences were assigned to death, retaining underprediction throughout. In ELSA, composite CITL ranged from -0.051 to 0.700 across the corresponding boundaries, so incomplete death confirmation could change magnitude and direction (eFigure 3 and eTable 16). Exploratory M2H and M2S increased AUC over M1 by 0.0059 to 0.0201 but did not reduce the principal absolute-risk errors; both worsened MHAS Brier score and overprediction (eTables 17 and 18).

### Selective Updating and Decision Value

At the illustrative 20% risk threshold under equal-cohort development weighting, median intercept-update net-benefit increments were 18.8, 1.1, -0.3, and 14.3 net true positives per 1000 in CHARLS, ELSA, HRS, and MHAS. Increments were nonnegative in 30 of 30 outer splits in CHARLS, ELSA, and MHAS but only 8 of 30 in HRS. Across all 11 thresholds, median increments were positive in CHARLS and MHAS, small and nonnegative at 10 thresholds in ELSA, and nonnegative at 7 in HRS; threshold ordering varied, with the largest median gain of 27.7 per 1000 in MHAS (Figure 4).

Absolute CITL exceeded 0.10 in all 4 held-out target cohorts before updating, and slopes remained within 0.80 to 1.20; the descriptive rule therefore classified intercept-only updating in every target despite probability gaps from 1.6 to 11.1 percentage points. Across 30 outer splits, intercept updating reduced absolute CITL and Brier score much more in CHARLS and MHAS than in ELSA and HRS. The first tested fractions meeting the descriptive tolerance in at least 80% of outer splits corresponded to medians of 783 people and 158 event persons in CHARLS and 519 people and 117 event persons in MHAS; these were operating points, not minimum data requirements (Figure 4 and eTable 14B).

Development-weighting sensitivity results are reported in eFigure 8 and eTable 17. Earlier-wave updating nevertheless worsened absolute CITL in 2 of 7 ELSA windows, 1 of 12 HRS windows, and all 3 MHAS windows (eFigure 6).

## Discussion

Across 4 national aging cohorts, current multidomain health consistently improved discrimination beyond age and sex, with AUC gains of 0.046 to 0.112. Yet those gains did not ensure accurate probabilities: risk was underestimated by 8.9 percentage points in CHARLS and overestimated by 11.1 points in MHAS, with worse overall accuracy in MHAS. Pooled random splits concealed at least 1 cohort-specific calibration error in 99 of 100 repetitions. Intercept updating added substantial decision value in the 2 markedly miscalibrated targets but little or inconsistent value where probability gaps were small.

The principal contribution is empirical. By combining complete national-cohort holdout, an explicit pooled-validation concealment test, and disjoint post-update decision evaluation, this study moves beyond documenting calibration drift to show when that drift changed the value of local updating. Ranking and probability transport can separate because predictors may preserve relative gradients while baseline risk, measurement, survey practice, and case mix shift.<sup>12-18</sup> The consistent AUC gains therefore support a portable current-health risk-ranking strategy, whereas the opposing probability errors argue against assuming one universally calibrated equation.

Pooled random splits concealed cohort-specific calibration errors because each model saw every cohort and opposing errors averaged. The updating results exposed the converse problem: every target crossed the fixed CITL rule, yet equal-cohort development produced 20%-threshold gains of 18.8 and 14.3 per 1000 in CHARLS and MHAS but only 1.1 and -0.3 in ELSA and HRS. CITL remains essential, but the magnitude of target probability error and independent decision evaluation better distinguished where updating mattered.

These differences are clinically legible at an illustrative 20% threshold. In CHARLS, mean predicted risk was 11.2% when observed risk was 20.1%, creating potential for systematic under-referral; updating added 18.8 net true-positive equivalents per 1000 evaluated. In MHAS, mean predicted risk was 26.2% when 15.0% was observed, creating potential for over-referral; updating added 14.3 per 1000 at 20% and up to 27.7 per 1000 across thresholds. Descriptive operating points occurred at 783 people with 158 event persons in CHARLS and 519 with 117 in MHAS, but were not minimum sample-size requirements. The small ELSA and HRS gains show why an identical statistical trigger need not justify the same local action.

Strengths include an exact common outcome, 4 complete source holdouts, development-only preprocessing, person-level resampling, and disjoint calibration and decision-curve evaluation. Four limitations define the claim. First, observed-follow-up episodes are not lifetime first events and exclude unobserved future function. Second, cohort cannot be separated from survey design, language, period, horizon, and measurement practice. Third, death confirmation was uncertain in CHARLS and especially ELSA; boundary analyses expose but do not resolve that uncertainty. Fourth, thresholds were illustrative, and no prospective impact study tested workflow or benefit. Together, these findings define a practical evaluation pathway for probability-based transport: complete target holdout, probability-scale assessment, selective updating, and independent post-update evaluation.

## Conclusions

Across 4 national aging cohorts, current multidomain health consistently improved prediction beyond age and sex, but absolute-risk accuracy varied. Measuring target-specific probability error after complete-cohort holdout identified where independently evaluated recalibration delivered substantial decision value and where it delivered little or none.

## Acknowledgment Section

**Author Contributions:** Concept and design: Luo, Lu, Liang. Acquisition, analysis, or interpretation of data: Luo, Chen, Liu. Drafting of the manuscript: Luo, Chen, Liu. Critical revision of the manuscript for important intellectual content: All authors. Statistical analysis: Luo, Chen. Administrative, technical, or material support: Liu, Lu. Supervision: Lu, Liang.  
**Data Access and Responsibility:** Jiajun Luo and Xiaolong Liang had full access to all data available under the source-study agreements and take responsibility for the integrity of the data and accuracy of the analysis.  
**Conflict of Interest Disclosures:** None reported.  
**Funding/Support:** This study received no external funding.  
**Role of the Funder/Sponsor:** Not applicable.  
**Additional Contributions:** The authors thank the participants, investigators, and staff of CHARLS, ELSA, HRS, and MHAS.  

## Data Sharing Statement

Individual-level CHARLS, HRS, ELSA, and MHAS data are available from their custodians under study-specific access terms and cannot be redistributed by the authors. The protocol, decision log, analysis code, aggregate results, and figure-generation code are publicly available in the aggregate-only GitHub repository (release v1.0.2): https://github.com/jiajunluo430-creator/multicohort-functional-risk-transportability.

## References

1. World Health Organization. *World Report on Ageing and Health*. World Health Organization; 2015.
2. Katz S, Ford AB, Moskowitz RW, Jackson BA, Jaffe MW. Studies of illness in the aged: the Index of ADL. *JAMA*. 1963;185:914-919. doi:10.1001/jama.1963.03060120024016
3. Lawton MP, Brody EM. Assessment of older people: self-maintaining and instrumental activities of daily living. *Gerontologist*. 1969;9(3):179-186. doi:10.1093/geront/9.3_Part_1.179
4. Verbrugge LM, Jette AM. The disablement process. *Soc Sci Med*. 1994;38(1):1-14. doi:10.1016/0277-9536(94)90294-1
5. Stuck AE, Walthert JM, Nikolaus T, Büla CJ, Hohmann C, Beck JC. Risk factors for functional status decline in community-living elderly people: a systematic literature review. *Soc Sci Med*. 1999;48(4):445-469. doi:10.1016/S0277-9536(98)00370-0
6. Guralnik JM, Ferrucci L, Pieper CF, et al. Lower extremity function and subsequent disability: consistency across studies, predictive models, and value of gait speed alone compared with the Short Physical Performance Battery. *J Gerontol A Biol Sci Med Sci*. 2000;55(4):M221-M231. doi:10.1093/gerona/55.4.M221
7. Covinsky KE, Hilton J, Lindquist K, Dudley RA. Development and validation of an index to predict activity of daily living dependence in community-dwelling elders. *Med Care*. 2006;44(2):149-157. doi:10.1097/01.mlr.0000196955.99704.64
8. Kurichi JE, Kwong PL, Xie D, Bogner HR. Predictive indices for functional improvement and deterioration, institutionalization, and death among elderly Medicare beneficiaries. *PM R*. 2017;9(11):1065-1076. doi:10.1016/j.pmrj.2017.04.005
9. Jonkman NH, Colpo M, Klenk J, et al. Development of a clinical prediction model for the onset of functional decline in people aged 65-75 years: pooled analysis of four European cohort studies. *BMC Geriatr*. 2019;19(1):179. doi:10.1186/s12877-019-1192-1
10. Van Grootven B, van Achterberg T. Prediction models for functional status in community dwelling older adults: a systematic review. *BMC Geriatr*. 2022;22(1):465. doi:10.1186/s12877-022-03156-7
11. Zhou J, Xu Y, Yang D, Zhou Q, Ding S, Pan H. Risk prediction models for disability in older adults: a systematic review and critical appraisal. *BMC Geriatr*. 2024;24(1):806. doi:10.1186/s12877-024-05409-z
12. Altman DG, Royston P. What do we mean by validating a prognostic model? *Stat Med*. 2000;19(4):453-473. doi:10.1002/(SICI)1097-0258(20000229)19:4<453::AID-SIM350>3.0.CO;2-5
13. Steyerberg EW, Harrell FE Jr. Prediction models need appropriate internal, internal-external, and external validation. *J Clin Epidemiol*. 2016;69:245-247. doi:10.1016/j.jclinepi.2015.04.005
14. Debray TPA, Vergouwe Y, Koffijberg H, Nieboer D, Steyerberg EW, Moons KGM. A new framework to enhance the interpretation of external validation studies of clinical prediction models. *J Clin Epidemiol*. 2015;68(3):279-289. doi:10.1016/j.jclinepi.2014.06.018
15. Collins GS, de Groot JA, Dutton S, et al. External validation of multivariable prediction models: a systematic review of methodological conduct and reporting. *BMC Med Res Methodol*. 2014;14:40. doi:10.1186/1471-2288-14-40
16. Van Calster B, Nieboer D, Vergouwe Y, De Cock B, Pencina MJ, Steyerberg EW. A calibration hierarchy for risk models was defined: from utopia to empirical data. *J Clin Epidemiol*. 2016;74:167-176. doi:10.1016/j.jclinepi.2015.12.005
17. Van Calster B, McLernon DJ, van Smeden M, Wynants L, Steyerberg EW. Calibration: the Achilles heel of predictive analytics. *BMC Med*. 2019;17(1):230. doi:10.1186/s12916-019-1466-7
18. Alba AC, Agoritsas T, Walsh M, et al. Discrimination and calibration of clinical prediction models: users' guides to the medical literature. *JAMA*. 2017;318(14):1377-1384. doi:10.1001/jama.2017.12126
19. Zhao Y, Hu Y, Smith JP, Strauss J, Yang G. Cohort profile: the China Health and Retirement Longitudinal Study. *Int J Epidemiol*. 2014;43(1):61-68. doi:10.1093/ije/dys203
20. Steptoe A, Breeze E, Banks J, Nazroo J. Cohort profile: the English Longitudinal Study of Ageing. *Int J Epidemiol*. 2013;42(6):1640-1648. doi:10.1093/ije/dys168
21. Sonnega A, Faul JD, Ofstedal MB, Langa KM, Phillips JWR, Weir DR. Cohort profile: the Health and Retirement Study. *Int J Epidemiol*. 2014;43(2):576-585. doi:10.1093/ije/dyu067
22. Wong R, Michaels-Obregon A, Palloni A. Cohort profile: the Mexican Health and Aging Study. *Int J Epidemiol*. 2017;46(2):e2. doi:10.1093/ije/dyu263
23. Lee J, Phillips D, Wilkens J; Gateway to Global Aging Data Team. Gateway to Global Aging Data: resources for cross-national comparisons of family, social environment, and healthy aging. *J Gerontol B Psychol Sci Soc Sci*. 2021;76(suppl 1):S5-S16. doi:10.1093/geronb/gbab050
24. Collins GS, Moons KGM, Dhiman P, et al. TRIPOD+AI statement: updated guidance for reporting clinical prediction models that use regression or machine learning methods. *BMJ*. 2024;385:e078378. doi:10.1136/bmj-2023-078378
25. Debray TPA, Collins GS, Riley RD, et al. Transparent reporting of multivariable prediction models developed or validated using clustered data: TRIPOD-Cluster checklist. *BMJ*. 2023;380:e071018. doi:10.1136/bmj-2022-071018
26. von Elm E, Altman DG, Egger M, Pocock SJ, Gøtzsche PC, Vandenbroucke JP. The Strengthening the Reporting of Observational Studies in Epidemiology (STROBE) statement. *Lancet*. 2007;370(9596):1453-1457. doi:10.1016/S0140-6736(07)61602-X
27. Wolff RF, Moons KGM, Riley RD, et al. PROBAST: a tool to assess the risk of bias and applicability of prediction model studies. *Ann Intern Med*. 2019;170(1):51-58. doi:10.7326/M18-1376
28. Janssen KJM, Moons KGM, Kalkman CJ, Grobbee DE, Vergouwe Y. Updating methods improved the performance of a clinical prediction model in new patients. *J Clin Epidemiol*. 2008;61(1):76-86. doi:10.1016/j.jclinepi.2007.04.018
29. Toll DB, Janssen KJM, Vergouwe Y, Moons KGM. Validation, updating and impact assessment of prognostic models: time for a change. *J Clin Epidemiol*. 2008;61(11):1085-1094. doi:10.1016/j.jclinepi.2008.04.008
30. Riley RD, Debray TPA, Collins GS, et al. Minimum sample size for external validation of a clinical prediction model with a binary outcome. *Stat Med*. 2021;40(19):4230-4251. doi:10.1002/sim.9025
31. Vickers AJ, Elkin EB. Decision curve analysis: a novel method for evaluating prediction models. *Med Decis Making*. 2006;26(6):565-574. doi:10.1177/0272989X06295361
32. Vickers AJ, Van Calster B, Steyerberg EW. Net benefit approaches to the evaluation of prediction models, molecular markers, and diagnostic tests. *BMJ*. 2016;352:i6. doi:10.1136/bmj.i6

# Table 1. Participant Characteristics at the First Eligible Prediction Episode

| Characteristic | CHARLS | ELSA | HRS | MHAS |
| --- | ---: | ---: | ---: | ---: |
| Participants, No. | 3,915 | 8,609 | 20,016 | 5,192 |
| Age, mean (SD), y | 67.0 (6.0) | 66.4 (7.0) | 66.1 (7.0) | 67.9 (6.3) |
| Female, No. (%) | 1,703 (43.5) | 4,590 (53.3) | 11,653 (58.2) | 2,995 (57.7) |
| Education: low, No. (%) | 3,558 (90.9) | 2,490 (31.5) | 3,988 (19.9) | 4,425 (85.9) |
| Education: middle, No. (%) | 291 (7.4) | 3,869 (48.9) | 11,560 (57.8) | 162 (3.1) |
| Education: high, No. (%) | 66 (1.7) | 1,547 (19.6) | 4,464 (22.3) | 565 (11.0) |
| Partnered, No. (%) | 3,304 (84.4) | 6,345 (73.7) | 13,742 (68.7) | 3,527 (67.9) |
| Current smoking, No. (%) | 1,233 (31.5) | 994 (11.6) | 2,790 (14.0) | 585 (11.3) |
| Any M1 predictor missing, No. (%) | 345 (8.8) | 926 (10.8) | 1,374 (6.9) | 147 (2.8) |
| Proxy interview, No. (%) | NA | 213 (2.5) | 775 (3.9) | 0 (0.0) |
| Self-rated health score, mean (SD) | 3.7 (0.9) | 2.5 (1.0) | 2.6 (1.0) | 3.6 (0.8) |
| Mobility difficulty score, mean (SD) | 0.4 (0.7) | 0.5 (0.8) | 0.7 (0.9) | 0.8 (0.9) |
| Chronic condition count, mean (SD) | 0.9 (0.8) | 0.9 (0.9) | 1.3 (1.0) | 1.2 (0.9) |
| Depression symptom proportion, mean (SD) | 0.21 (0.18) | 0.14 (0.20) | 0.14 (0.21) | 0.31 (0.27) |
| Prediction horizon, median (IQR), y | 3.0 (3.0-3.0) | 2.0 (2.0-2.0) | 2.0 (2.0-2.0) | 3.0 (3.0-3.0) |

*Participant characteristics use each person's earliest observed primary prediction episode; percentages use nonmissing denominators. Education is the harmonized low/middle/high collapse. Self-rated health ranges from 1 (excellent) to 5 (poor), mobility difficulty from 0 to 3, chronic conditions from 0 to 5, and depression symptom proportion from 0 to 1. Proxy status was unavailable in CHARLS.*  

---

# Figure Legends

## Figure 1. Landmark Design, Complete-Cohort Holdout, and Analysis Flow

Panel A shows the primary landmark: difficulty-free status at t-1 and t followed by a 2- to 3-year prediction to t+1. Telephone use was excluded from the common-item outcome. Panel B shows all 4 rotations of 3-cohort development and held-out target-cohort evaluation; target data were excluded from preprocessing and fitting. Panel C displays observed functional follow-up percentages and aligns risk-set and unavailable-outcome counts. ADL indicates activities of daily living; IADL, instrumental activities of daily living.

## Figure 2. Current Health Improved Discrimination but Absolute Risk Did Not Transport Uniformly

Panels A and B show paired person-cluster bootstrap changes in AUC and Brier score for M1 vs M0; negative changes in Brier score favor M1. Panel C shows observed-minus-predicted risk with within-replicate 95% bootstrap intervals; positive values indicate underprediction. Panel D shows the number of cohort-specific evaluations outside the descriptive joint region in 100 person-level random splits. Pooled calibration met the region in every split but concealed at least 1 cohort-specific calibration error in 99. AUC indicates area under the receiver operating characteristic curve; CITL, calibration-in-the-large.

## Figure 3. Calibration Before Target-Population Updating

Natural-spline calibration curves and person-cluster robust 95% confidence bands are shown for pre-update two-wave M1 predictions. Open points are equal-frequency risk groups and are uniformly sized. Observed and predicted mean risks are labeled in all 4 panels; CHARLS and MHAS are marked as underprediction and overprediction, respectively. Probability axes differ across cohorts; the diagonal denotes perfect calibration.

## Figure 4. Updating Added Decision Value Mainly in Markedly Miscalibrated Targets

All panels use the primary equal-cohort development weighting. Panel A shows each target's pre-update absolute observed-minus-predicted risk gap, its 95% person-cluster bootstrap interval, and its direction. Panel B pairs pre-update absolute calibration-in-the-large (CITL) with intercept-updated values after the largest tested calibration fraction; Panel C shows the corresponding change in Brier score, where negative values favor updating. Both summarize 30 outer splits with disjoint evaluation people. Panel D shows decision-curve increments with empirical 2.5th and 97.5th outer-split percentiles after calibrators were fitted in the 60% calibration pool and evaluated in the disjoint 40%; threshold ordering can vary. At 20%, increments were nonnegative in 100%, 100%, 27%, and 100% of CHARLS, ELSA, HRS, and MHAS outer splits, respectively. Event-information curves and development-weighting sensitivity results appear in eFigure 8.
