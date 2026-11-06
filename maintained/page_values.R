# sarkar_coppock_2026/maintained/page_values.R
# Output: maintained/output/page_values.csv, maintained/output/significant_estimates.csv
# Depends on: maintained/archive_run/, ground_truth/published_table_f47.csv
# Description: Compute every number the article's prose states and the errata needs, from the rerun's
#   estimates and the deposit's metadata, with the deposit's own estimators. Table F.47's counts come from
#   the transcription of the printed table, which is the authority for a qualitative judgment.

library(tidyverse)
library(readxl)
library(metafor)
library(here)
here::i_am("maintained/page_values.R")

archive <- here::here("maintained", "archive_run", "sarkar_coppock_replication_archive")
metadata <- \(file) file.path(archive, "metadata", file)
estimates <- \(name) read_rds(file.path(archive, "estimates", str_c(name, ".rds")))

# The papers: three rows of the manifest carry a key whose year is not the study's. ----
manifest <- read_excel(metadata("study_manifest.xlsx")) |> filter(study_id != "meta")
autofill <- manifest |> filter(as.numeric(str_extract(bibtexkey, "\\d{4}")) != year)
stopifnot(setequal(autofill$bibtexkey, str_c("wallsten_nteta_", 2017:2019)),
          all(str_starts(autofill$study_id, "wallsten_nteta_2016")))
paper_key <- \(key) if_else(key %in% autofill$bibtexkey, "wallsten_nteta_2016", key)

included <- read_excel(metadata("estimand_table.xlsx")) |>
  left_join(select(manifest, study_id, bibtexkey), by = join_by(study_id))
meta_rows <- manifest |> filter(included_meta == 1)
considered <- read_rds(metadata("religious_estimands_clean.rds")) |>
  mutate(bibtexkey = if_else(is.na(bibtexkey), str_remove(study_id, "_study_[12]"), bibtexkey))

# Meta-analyses ----
pool <- function(name) {
  d <- estimates(name)
  fit <- rma(estimate ~ 1, sei = std.error, data = d)
  clustered <- robust(fit, cluster = d$study_id, clubSandwich = TRUE)
  fdr <- p.adjust(d$p.value, "fdr")
  tibble(k = nrow(d), mu = 100 * clustered$beta[1], se = 100 * clustered$se, tau = 100 * sqrt(fit$tau2),
         q_p = fit$QEp, positive = sum(d$estimate > 0 & d$p.value <= 0.05),
         negative = sum(d$estimate < 0 & d$p.value <= 0.05), fdr_kept = sum(fdr <= 0.05))
}
rm_pool <- pool("all_ate_rm")
rg_pool <- pool("all_ate_rg")
re_pool <- pool("all_ate_re")
ates <- map(c(rm = "all_ate_rm", rg = "all_ate_rg", re = "all_ate_re"), estimates) |> list_rbind(names_to = "estimand")
dic <- \(group) map(c("rm", "rg", "re"), \(x) estimates(str_c("dic_", group, "_", x)) |> mutate(comparison = x)) |> list_rbind()
dic_affiliation <- dic("ra")
dic_religiosity <- dic("rp")
pooled_dic <- bind_rows(mutate(dic_affiliation, heterogeneity = "affiliation"), mutate(dic_religiosity, heterogeneity = "religiosity"))
dic_fdr_kept <- \(d) sum(p.adjust(d$p.value, "fdr") <= 0.05)

significant <- bind_rows(
  ates |> filter(p.value <= 0.05) |> transmute(kind = "ate", comparison = estimand, study_id, estimate, p.value),
  pooled_dic |> mutate(fdr = p.adjust(p.value, "fdr")) |> filter(p.value <= 0.05) |>
    transmute(kind = str_c("difference_", heterogeneity), comparison, study_id, estimate, p.value, fdr))
write_csv(significant, here::here("maintained", "output", "significant_estimates.csv"))

# Appendix E: studies by place. ----
place <- meta_rows |> count(country)
place_n <- \(names) sum(place$n[place$country %in% names])
african <- c("Burkina Faso", "Kenya", "Nigeria", "Tanzania")
figure_rows <- read_csv(metadata("countries.csv"), show_col_types = FALSE)
stopifnot(!"Burkina Faso" %in% figure_rows$country, "Burkina" %in% figure_rows$country)

# Appendix G: the census of originally reported estimates. ----
reported <- considered |> filter(included_meta == 1, reported == 1)
excluded <- reported |> filter(included == 0) |> group_by(estimand) |> mutate(n = n()) |> ungroup()

# Appendix H: the p-curve's bins. ----
ate_significant <- ates |> filter(p.value <= 0.05)

# Table F.47 ----
f47 <- read_csv(here::here("ground_truth", "published_table_f47.csv"), show_col_types = FALSE)
f47_count <- \(group_name, verdict_name = NULL) {
  hits <- f47 |> filter(reason == group_name)
  if (!is.null(verdict_name)) hits <- hits |> filter(verdict == verdict_name)
  nrow(hits)
}
different_outcomes <- "Different outcomes, same treatments"

values <- tribble(
  ~claim_id, ~value_rewrite,
  "abstract_pairs", n_distinct(included$estimand_id[included$study_id %in% meta_rows$study_id]),
  "abstract_studies", nrow(meta_rows),
  "abstract_papers", n_distinct(paper_key(meta_rows$bibtexkey)),
  "design_studies", n_distinct(considered$study_id),
  "design_papers", n_distinct(paper_key(considered$bibtexkey)),
  "rm_k", rm_pool$k,
  "rm_positive", rm_pool$positive,
  "rm_negative", rm_pool$negative,
  "rm_nonsignificant", rm_pool$k - rm_pool$positive - rm_pool$negative,
  "rm_significant_total", rm_pool$positive + rm_pool$negative,
  "rm_fdr", rm_pool$fdr_kept,
  "rm_mu", rm_pool$mu,
  "rm_se", rm_pool$se,
  "rm_tau", rm_pool$tau,
  "rg_k", rg_pool$k,
  "rg_positive", rg_pool$positive,
  "rg_negative", rg_pool$negative,
  "rg_mu", rg_pool$mu,
  "rg_se", rg_pool$se,
  "rg_q_p", rg_pool$q_p,
  "rg_tau", rg_pool$tau,
  "rg_tau_ratio", rg_pool$tau / rm_pool$tau,
  "re_k", re_pool$k,
  "re_positive", re_pool$positive,
  "re_mu", re_pool$mu,
  "re_se", re_pool$se,
  "re_q_p", re_pool$q_p,
  "re_tau", re_pool$tau,
  "dic_affiliation_k", nrow(dic_affiliation),
  "dic_affiliation_significant", sum(dic_affiliation$p.value <= 0.05),
  "dic_affiliation_fdr", dic_fdr_kept(dic_affiliation),
  "dic_religiosity_k", nrow(dic_religiosity),
  "dic_religiosity_significant", sum(dic_religiosity$p.value <= 0.05),
  "dic_religiosity_fdr", dic_fdr_kept(dic_religiosity),
  "dic_significant_total", sum(pooled_dic$p.value <= 0.05),
  "dic_total", nrow(pooled_dic),
  "app_e_us", place_n("US"),
  "app_e_mena", place_n(c("Egypt", "Jordan")),
  "app_e_africa", place_n(african),
  "app_e_africa_countries", sum(place$country %in% african),
  "app_e_india", place_n("India"),
  "app_g_reported", nrow(reported),
  "app_g_included", sum(reported$included == 1),
  "app_g_excluded", sum(reported$included == 0),
  "app_g_excluded_sentence", sum(reported$included == 0),
  "app_g_sole", sum(excluded$n == 1),
  "app_g_two", sum(excluded$n == 2),
  "app_g_five_or_fewer", 100 * mean(excluded$n <= 5),
  "app_h_first_bin", 100 * mean(ate_significant$p.value <= 0.01),
  "f47_rows", nrow(f47),
  "f47_no_data", f47_count("No access to original datasets"),
  "f47_no_data_consistent", f47_count("No access to original datasets", "Consistent"),
  "f47_treatments", f47_count("Different treatments, same outcomes"),
  "f47_treatments_not_applicable", f47_count("Different treatments, same outcomes", "Not applicable"),
  "f47_outcomes", f47_count(different_outcomes),
  "f47_outcomes_not_applicable", f47_count(different_outcomes, "Not applicable"),
  "f47_outcomes_consistent", f47_count(different_outcomes, "Consistent"),
  "f47_outcomes_inconsistent", f47_count(different_outcomes, "Inconsistent")
)
write_csv(values, here::here("maintained", "output", "page_values.csv"))
print(as.data.frame(values), right = FALSE)
