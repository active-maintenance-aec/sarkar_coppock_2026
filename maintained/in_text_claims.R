# sarkar_coppock_2026/maintained/in_text_claims.R
# Output: printed CLAIM lines and a CLAIM SUMMARY line; no files
# Depends on: maintained/output/page_values.csv (from page_values.R), ground_truth/published_claims.csv,
#   errata_entries.csv (from errata.qmd), excheckr
# Description: One claim() per extraction row with needs_block = TRUE, each scoring the value page_values.R
#   computes from the deposit's rerun against the number the article prints and, where a quantity erratum
#   names the claim, against the corrected value it publishes. The repository has no independent rewrite,
#   so this checks the page and the errata against the deposit's own pipeline, not the pipeline itself.
#   The run fails on any MISMATCH, STALE, DRIFT, or MISSING.

library(tidyverse)
library(excheckr)
library(here)
here::i_am("maintained/in_text_claims.R")

page <- read_csv(here::here("maintained", "output", "page_values.csv"), show_col_types = FALSE)
published <- read_csv(here::here("ground_truth", "published_claims.csv"), col_types = cols(.default = col_character()))
errata <- read_csv(here::here("errata_entries.csv"), col_types = cols(.default = col_character()))

value <- function(id) {
  x <- page$value_rewrite[page$claim_id == id]
  stopifnot(length(x) == 1)
  x
}

claim_start(published = published, errata = errata, format = "id", label_column = "claim")

# Abstract and research design ----
claim("abstract_pairs", value("abstract_pairs"))
claim("abstract_studies", value("abstract_studies"))
claim("abstract_papers", value("abstract_papers"))
claim("design_studies", value("design_studies"))
claim("design_papers", value("design_papers"))

# Religious message versus pure control, p. 11 ----
claim("rm_k", value("rm_k"))
claim("rm_positive", value("rm_positive"))
claim("rm_negative", value("rm_negative"))
claim("rm_nonsignificant", value("rm_nonsignificant"))
claim("rm_significant_total", value("rm_significant_total"))
claim("rm_fdr", value("rm_fdr"))
claim("rm_mu", value("rm_mu"))
claim("rm_se", value("rm_se"))
claim("rm_tau", value("rm_tau"))

# Religious message versus secular message, p. 12 ----
claim("rg_k", value("rg_k"))
claim("rg_mu", value("rg_mu"))
claim("rg_se", value("rg_se"))
claim("rg_q_p", value("rg_q_p"))
claim("rg_tau", value("rg_tau"))
claim("rg_tau_ratio", value("rg_tau_ratio"))

# Religious endorsement, p. 12 ----
claim("re_k", value("re_k"))
claim("re_mu", value("re_mu"))
claim("re_se", value("re_se"))
claim("re_q_p", value("re_q_p"))
claim("re_tau", value("re_tau"))

# Differences in CATEs, p. 13 ----
claim("dic_affiliation_k", value("dic_affiliation_k"))
claim("dic_affiliation_significant", value("dic_affiliation_significant"))
claim("dic_religiosity_k", value("dic_religiosity_k"))
claim("dic_religiosity_significant", value("dic_religiosity_significant"))
claim("dic_religiosity_fdr", value("dic_religiosity_fdr"))

# Studies outside the meta-analysis, p. 19 and Table F.47 ----
claim("f47_outcomes", value("f47_outcomes"))
claim("f47_outcomes_not_applicable", value("f47_outcomes_not_applicable"))
claim("f47_outcomes_consistent", value("f47_outcomes_consistent"))
claim("f47_outcomes_inconsistent", value("f47_outcomes_inconsistent"))
claim("f47_rows", value("f47_rows"))
claim("f47_no_data", value("f47_no_data"))
claim("f47_treatments", value("f47_treatments"))
claim("f47_treatments_not_applicable", value("f47_treatments_not_applicable"))

# Appendix E, studies by place ----
claim("app_e_us", value("app_e_us"))
claim("app_e_mena", value("app_e_mena"))
claim("app_e_africa", value("app_e_africa"))
claim("app_e_africa_countries", value("app_e_africa_countries"))
claim("app_e_india", value("app_e_india"))

# Appendix G, the census of reported estimates ----
claim("app_g_reported", value("app_g_reported"))
claim("app_g_included", value("app_g_included"))
claim("app_g_excluded", value("app_g_excluded"))
claim("app_g_excluded_sentence", value("app_g_excluded_sentence"))
claim("app_g_sole", value("app_g_sole"))
claim("app_g_two", value("app_g_two"))
claim("app_g_five_or_fewer", value("app_g_five_or_fewer"))

# Appendix H, the p-curve ----
claim("app_h_first_bin", value("app_h_first_bin"))

# Summary ----
assert_claims()
invisible(claim_summary())
