# sarkar_coppock_2026/ground_truth/build_ground_truth.R
# Output: ground_truth/sarkar_coppock_2026_ground_truth.csv, ground_truth/float_coverage.csv
# Depends on: ground_truth/published_claims.csv, ground_truth/published_numeric_tokens.csv,
#   errata_entries.csv, maintained/output/page_values.csv, maintained/archive_run/
# Description: Compare the extracted prose values with the rerun at the page's precision, and each
#   appendix table row with the page's numbers, then halt on a mismatch the spine does not report, a
#   spine id with no row, or a table row not found. Table rows are matched as runs of tokens anywhere
#   in the appendix, so this does not show a row sits in the right table. Table 4 is matched by set
#   membership on its page. Table H.51 is excluded because its bootstrap differs on rerun. The
#   repository has no independent rewrite: value_rewrite is computed from the deposit's own rerun, and
#   value_script and match are NA because no value is read separately out of the deposit's output.

library(tidyverse)
library(here)
here::i_am("ground_truth/build_ground_truth.R")

claims <- read_csv(here::here("ground_truth", "published_claims.csv"), col_types = cols(.default = col_character(), digits = col_integer()))
values <- read_csv(here::here("maintained", "output", "page_values.csv"), show_col_types = FALSE)
spine <- read_csv(here::here("errata_entries.csv"), col_types = cols(.default = col_character()))
spine_ids <- spine$claim_ids |> na.omit() |> str_split(";") |> unlist() |> discard(\(x) x == "")
stopifnot(!anyDuplicated(claims$claim_id),
          all(claims$digits == excheckr::claim_digits(claims$value_paper)))

# Prose values ----
ground_truth <- claims |>
  left_join(values, by = "claim_id", relationship = "one-to-one") |>
  mutate(printed = sprintf(str_c("%.", digits, "f"), value_rewrite),
         match_rewrite = printed == value_paper,
         defect_locus = if_else(match_rewrite, NA_character_, "paper_internal"),
         disposition = if_else(claim_id %in% spine_ids, "corrected_here", NA_character_),
         paper_id = "sarkar_coppock_2026", value_script = NA_real_, match = NA, holds = NA,
         disposition_reason = NA_character_) |>
  select(paper_id, claim_id, location, claim_type, claim, value_paper, digits, value_script, match, value_rewrite,
         match_rewrite, holds, defect_locus, disposition, disposition_reason, notes)

stopifnot(all(!is.na(ground_truth$value_rewrite)),
          all(spine_ids %in% ground_truth$claim_id),
          all(ground_truth$claim_id[!ground_truth$match_rewrite] %in% spine_ids),
          all(!ground_truth$match_rewrite[ground_truth$claim_id %in% spine_ids]))
undisposed <- ground_truth |> filter(defect_locus == "paper_internal", is.na(disposition))
if (nrow(undisposed) > 0) stop(str_glue("{nrow(undisposed)} paper_internal rows carry no disposition."))
print(ground_truth |> filter(!is.na(defect_locus)) |> count(defect_locus, disposition))
write_csv(ground_truth, here::here("ground_truth", "sarkar_coppock_2026_ground_truth.csv"))

# Appendix tables and Table 4 against the page ----
tokens <- read_csv(here::here("ground_truth", "published_numeric_tokens.csv"), col_types = "cic")
output <- here::here("maintained", "archive_run", "sarkar_coppock_replication_archive", "output")
haystack <- str_c(" ", str_c(tokens$token[tokens$document == "appendix"], collapse = " "), " ")
row_numbers <- function(line) {
  str_remove_all(line, "\\\\\\\\|\\$|\\{|\\}") |> str_extract_all("\\(?-?\\d*\\.?\\d+\\)?\\*{0,3}") |> pluck(1)
}
coverage <- function(path) {
  numbers <- read_lines(path) |> str_subset("&") |> str_subset("^\\s*%", negate = TRUE) |> map(row_numbers) |> keep(\(n) length(n) > 0)
  found <- map_lgl(numbers, \(n) str_detect(haystack, fixed(str_c(" ", str_c(n, collapse = " "), " "))))
  tibble(rows = length(numbers), rows_found = sum(found), published_numbers = sum(lengths(numbers)),
         covered = sum(lengths(numbers)[found]))
}
# The deposit writes Tables C.4 to C.46 one file per study, and their alphabetical order is the appendix's order.
appendix_files <- list.files(file.path(output, "appendix_tables"), full.names = TRUE)
stopifnot(length(appendix_files) == 43)
appendix_tables <- map(appendix_files, coverage) |> list_rbind() |>
  mutate(float = str_c("Table C.", 4:46), .before = 1)
table_4_tokens <- tokens$token[tokens$document == "article" & tokens$page == 17]
table_4_cells <- list.files(file.path(output, "tables"), "^summary_table_", full.names = TRUE) |>
  map(\(path) str_extract_all(str_c(str_subset(read_lines(path), "^\\s*%", negate = TRUE), collapse = " "), "\\(?-?\\d*\\.\\d+\\)?")[[1]]) |> unlist()
compared <- appendix_tables |>
  add_row(float = "Table 4", published_numbers = length(table_4_cells), covered = sum(table_4_cells %in% table_4_tokens)) |>
  mutate(note = if_else(float == "Table 4", "Cells matched by membership among the numbers on p. 17",
                        "Each row matched as a run of numbers anywhere in the appendix, not within this table"))
print(filter(compared, published_numbers != covered), n = 20)
stopifnot(all(compared$published_numbers == compared$covered), all(compared$rows == compared$rows_found, na.rm = TRUE))
print(summarise(compared, tables = n(), rows = sum(rows, na.rm = TRUE), numbers = sum(published_numbers), covered = sum(covered)))

# Float coverage ----
# Every float the article and appendix print, in the order printed. Only Table 4 and Tables C.4 to C.46 are
# compared with the page; the others carry NA counts because nobody has counted what they print.
not_compared <- "Not transcribed or compared with the page"
floats <- bind_rows(tribble(
  ~float, ~note,
  "Figure 1", not_compared,
  "Table 1", "Study manifest; not compared with the deposit's metadata",
  "Table 2", "Study manifest; not compared with the deposit's metadata",
  "Table 3", "Study manifest; not compared with the deposit's metadata",
  "Figure 2", not_compared,
  "Figure 3", not_compared,
  "Figure 4", not_compared,
  "Figure 5", not_compared,
  "Figure 6", not_compared,
  "Figure 7", not_compared,
  "Figure 8", not_compared,
  "Figure 9", not_compared,
  "Figure 10", not_compared,
  "Table 4", NA,
  "Table A.1", not_compared,
  "Table A.2", not_compared,
  "Table A.3", not_compared,
  "Figure B.1", not_compared,
  "Figure B.2", not_compared,
  "Figure B.3", not_compared,
  "Figure B.4", not_compared,
  "Figure B.5", not_compared,
  "Figure B.6", not_compared,
  "Figure B.7", not_compared,
  "Figure B.8", not_compared,
  "Figure B.9", not_compared,
  "Figure B.10", not_compared,
  "Figure B.11", not_compared
), tibble(float = str_c("Table C.", 4:46), note = NA_character_), tribble(
  ~float, ~note,
  "Figure E.12", "Not compared with the page; errata entry 6 reports its missing Burkina Faso row",
  "Table F.47", "Transcribed for its rows, reasons, and verdicts, not its numbers",
  "Figure G.13", not_compared,
  "Figure G.14", not_compared,
  "Figure G.15", not_compared,
  "Figure G.16", not_compared,
  "Figure H.17", "Not compared with the page; errata entry 12 corrects its bin labels",
  "Figure H.18", not_compared,
  "Table H.48", not_compared,
  "Table H.49", "Not compared with the page; errata entry 11 corrects its title",
  "Table H.50", "Not compared with the page; errata entry 11 corrects its title",
  "Table H.51", "Not compared with the page; its unseeded bootstrap differs on rerun"
))
float_coverage <- floats |>
  left_join(select(compared, float, published_numbers, covered, compared_note = note), by = "float", relationship = "one-to-one") |>
  mutate(compared = !is.na(covered),
         reproduced_by_rewrite = NA_integer_,
         reproduced_by_archive = if_else(compared, covered, NA_integer_),
         plotted = NA_integer_, plotted_reproduced = NA_integer_,
         note = if_else(compared, str_c(compared_note, "; no independent rewrite, so the rerun of the deposit is the archive count"), note)) |>
  select(float, published_numbers, covered, reproduced_by_rewrite, reproduced_by_archive, plotted, plotted_reproduced, note)
stopifnot(nrow(float_coverage) == 83, !anyDuplicated(float_coverage$float), all(compared$float %in% float_coverage$float),
          !anyNA(float_coverage$note))
write_csv(float_coverage, here::here("ground_truth", "float_coverage.csv"))

print(count(ground_truth, match_rewrite))
print(filter(ground_truth, !match_rewrite) |> select(claim_id, value_paper, printed = value_rewrite), n = 30)
