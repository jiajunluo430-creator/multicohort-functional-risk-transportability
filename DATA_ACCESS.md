# Data access

Individual-level data are not included in this repository and cannot be redistributed by the authors. Obtain the source files under each custodian's terms:

- CHARLS: https://charls.pku.edu.cn/en/
- HRS public survey data: https://hrsdata.isr.umich.edu/data-products/public-survey-data
- ELSA data access: https://www.elsa-project.ac.uk/accessing-elsa-data
- MHAS core survey data: https://www.mhasweb.org/DataProducts/CoreSurveyData.aspx

Set the following environment variables to your authorized local files before running the source-audit and risk-set scripts:

```text
D2_PROJECT_ROOT=/path/to/this/repository
CHARLS_DATA=/authorized/path/H_CHARLS_D_Data.dta
HRS_DATA=/authorized/path/randhrs1992_2022v1.dta
ELSA_DATA=/authorized/path/gh_elsa_h.dta
MHAS_DATA=/authorized/path/H_MHAS_d.dta
D2_R_LIB=/optional/custom/R/library
```

The repository scripts never download or redistribute source data.
