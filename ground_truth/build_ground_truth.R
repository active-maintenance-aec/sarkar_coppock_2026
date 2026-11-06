# sarkar_coppock_2026/ground_truth/build_ground_truth.R
# Output: ground_truth/sarkar_coppock_2026_ground_truth.csv, ground_truth/float_coverage.csv
# Depends on: ground_truth/published_claims.csv, ground_truth/published_numeric_tokens.csv,
#   errata_entries.csv, maintained/output/page_values.csv, maintained/archive_run/
# Description: Compare the extracted prose values with the rerun at the page's precision, and each
#   appendix table row with the page's numbers, then halt on a mismatch the spine does not report, a
#   spine id with no row, or a table row not found. Table rows are matched as runs of tokens anywhere
#   in the appendix, so this does not show a row sits in the right table. Table 4 is matched by set
#   membership on its page. Table H.51 is excluded because its bootstrap differs on rerun.

library(tidyverse)
library(here)
here::i_am("ground_truth/build_ground_truth.R")

claims <- read_csv(here::here("ground_truth", "published_claims.csv"), col_types = cols(.default = col_character(), digits = col_integer()))
values <- read_csv(here::here("maintained", "output", "page_values.csv"), show_col_types = FALSE)
spine <- read_csv(here::here("errata_entries.csv"), show_col_types = FALSE)
spine_ids <- spine$claim_ids |> na.omit() |> str_split(";") |> unlist() |> discard(\(x) x == "")

ground_truth <- claims |>
  left_join(values, by = "claim_id", relationship = "one-to-one") |>
  mutate(printed = sprintf(str_c("%.", digits, "f"), value_rewrite),
         match_rewrite = as.numeric(printed == value_paper),
         defect_locus = case_when(match_rewrite == 0 ~ "paper_internal", .default = NA_character_),
         paper_id = "sarkar_coppock_2026") |>
  select(paper_id, claim_id, location, claim, value_paper, value_rewrite, match_rewrite, defect_locus)

stopifnot(all(!is.na(ground_truth$value_rewrite)),
          all(spine_ids %in% ground_truth$claim_id),
          all(ground_truth$claim_id[ground_truth$match_rewrite == 0] %in% spine_ids),
          all(ground_truth$match_rewrite[ground_truth$claim_id %in% spine_ids] == 0))
write_csv(ground_truth, here::here("ground_truth", "sarkar_coppock_2026_ground_truth.csv"))

tokens <- read_csv(here::here("ground_truth", "published_numeric_tokens.csv"), col_types = "cic")
output <- here::here("maintained", "archive_run", "sarkar_coppock_replication_archive", "output")
haystack <- str_c(" ", str_c(tokens$token[tokens$document == "appendix"], collapse = " "), " ")
row_numbers <- function(line) {
  str_remove_all(line, "\\\\\\\\|\\$|\\{|\\}") |> str_extract_all("\\(?-?\\d*\\.?\\d+\\)?\\*{0,3}") |> pluck(1)
}
coverage <- function(path) {
  rows <- read_lines(path) |> str_subset("&") |> str_subset("^\\s*%", negate = TRUE) |> map(row_numbers) |> keep(\(n) length(n) > 0)
  found <- map_lgl(rows, \(n) str_detect(haystack, fixed(str_c(" ", str_c(n, collapse = " "), " "))))
  tibble(table = basename(path), rows = length(rows), covered = sum(found))
}
appendix_tables <- map(list.files(file.path(output, "appendix_tables"), full.names = TRUE), coverage) |> list_rbind()
table_4_tokens <- tokens$token[tokens$document == "article" & tokens$page == 17]
table_4_cells <- list.files(file.path(output, "tables"), "^summary_table_", full.names = TRUE) |>
  map(\(path) str_extract_all(str_c(str_subset(read_lines(path), "^\\s*%", negate = TRUE), collapse = " "), "\\(?-?\\d*\\.\\d+\\)?")[[1]]) |> unlist()
float_coverage <- add_row(appendix_tables, table = "Table 4, cells on the page", rows = length(table_4_cells), covered = sum(table_4_cells %in% table_4_tokens))
write_csv(float_coverage, here::here("ground_truth", "float_coverage.csv"))
print(filter(float_coverage, rows != covered), n = 20)
stopifnot(all(float_coverage$rows == float_coverage$covered))
print(count(ground_truth, match_rewrite))
print(filter(ground_truth, match_rewrite == 0) |> select(claim_id, value_paper, printed = value_rewrite), n = 30)
print(summarise(float_coverage, tables = n(), rows = sum(rows), covered = sum(covered)))
