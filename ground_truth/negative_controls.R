# sarkar_coppock_2026/ground_truth/negative_controls.R
# Output: ground_truth/negative_controls.csv
# Depends on: ground_truth/build_ground_truth.R and its inputs
# Description: Break one input at a time in a scratch copy, run the gates, and halt unless each broken
#   input stops the build and the unbroken copy passes. This tests that the gates fire on these faults,
#   not that they catch every fault.

library(tidyverse)
library(here)
here::i_am("ground_truth/negative_controls.R")

script <- read_lines(here::here("ground_truth", "build_ground_truth.R")) |>
  str_subset("^here::i_am", negate = TRUE) |> str_replace_all("here::here\\(", "scratch_path(")

run_control <- function(break_input) {
  scratch <- tempfile("control")
  dir.create(file.path(scratch, "ground_truth"), recursive = TRUE)
  dir.create(file.path(scratch, "maintained", "output"), recursive = TRUE)
  file.symlink(here::here("maintained", "archive_run"), file.path(scratch, "maintained", "archive_run"))
  c("published_claims.csv", "published_numeric_tokens.csv") |> walk(\(f) file.copy(here::here("ground_truth", f), file.path(scratch, "ground_truth", f)))
  file.copy(here::here("errata_entries.csv"), file.path(scratch, "errata_entries.csv"))
  file.copy(here::here("maintained", "output", "page_values.csv"), file.path(scratch, "maintained", "output", "page_values.csv"))
  break_input(scratch)
  sandbox <- new.env(parent = globalenv())
  sandbox$scratch_path <- \(...) file.path(scratch, ...)
  outcome <- tryCatch({ capture.output(eval(parse(text = script), envir = sandbox)); "passed" }, error = \(e) "halted")
  unlink(scratch, recursive = TRUE)
  outcome
}
edit_csv <- function(scratch, path, edit) {
  full <- file.path(scratch, path)
  read_csv(full, col_types = cols(.default = col_character())) |> edit() |> write_csv(full, na = "")
}
claims <- "ground_truth/published_claims.csv"
controls <- list(
  "no fault" = \(s) NULL,
  "a page value mistyped" = \(s) edit_csv(s, claims, \(d) mutate(d, value_paper = if_else(claim_id == "abstract_studies", "44", value_paper))),
  "a claim with no computed value" = \(s) edit_csv(s, claims, \(d) add_row(d, claim_id = "bogus", value_paper = "1", digits = "0")),
  "a duplicated claim id" = \(s) edit_csv(s, claims, \(d) bind_rows(d, slice(d, 1))),
  "a spine id with no row" = \(s) edit_csv(s, "errata_entries.csv", \(d) mutate(d, claim_ids = if_else(entry == "1", str_c(claim_ids, ";bogus"), claim_ids))),
  "a mismatch the spine does not report" = \(s) edit_csv(s, "errata_entries.csv", \(d) filter(d, entry != "1")),
  "a spine entry on a claim that holds" = \(s) edit_csv(s, "errata_entries.csv", \(d) mutate(d, claim_ids = if_else(entry == "1", str_c(claim_ids, ";rm_k"), claim_ids))),
  "a table number altered on the page" = \(s) edit_csv(s, "ground_truth/published_numeric_tokens.csv", \(d) mutate(d, token = if_else(token == "0.030*", "0.031*", token)))
)
results <- tibble(control = names(controls), outcome = map_chr(controls, run_control), expected = if_else(control == "no fault", "passed", "halted"))
write_csv(results, here::here("ground_truth", "negative_controls.csv"))
print(results)
stopifnot(all(results$outcome == results$expected))
