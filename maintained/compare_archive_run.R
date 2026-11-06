# sarkar_coppock_2026/maintained/compare_archive_run.R
# Output: maintained/output/archive_output_comparison.csv
# Depends on: maintained/archive_run/, original_extracted/
# Description: Compare the stripped rerun with the deposit's shipped files: every estimates/ file on
#   estimate and std.error, and every output table on its text with the timestamp comment removed.
#   This shows the rerun matches the deposit. It does not show the deposit's cleaning is right.

library(tidyverse)
library(here)
here::i_am("maintained/compare_archive_run.R")

rerun <- here::here("maintained", "archive_run", "sarkar_coppock_replication_archive")
shipped <- here::here("original_extracted", "sarkar_coppock_replication_archive")

estimate_files <- list.files(file.path(shipped, "estimates"), pattern = "[.]rds$")
estimates <- map(estimate_files, \(file) {
  a <- read_rds(file.path(shipped, "estimates", file))
  b <- read_rds(file.path(rerun, "estimates", file))
  columns <- intersect(c("estimate", "std.error"), names(a))
  tibble(kind = "estimates", file = file, same_rows = nrow(a) == nrow(b),
         largest_difference = max(c(0, abs(unlist(a[columns]) - unlist(b[columns]))), na.rm = TRUE))
}) |> list_rbind()

table_files <- list.files(file.path(shipped, "output"), pattern = "[.]tex$", recursive = TRUE)
strip <- \(path) read_lines(path) |> str_subset("^\\s*%", negate = TRUE) |> str_squish() |> str_c(collapse = "\n")
tables <- tibble(kind = "tables", file = table_files, same_rows = map_lgl(table_files, \(file) {
  strip(file.path(shipped, "output", file)) == strip(file.path(rerun, "output", file))
}), largest_difference = NA_real_)

comparison <- bind_rows(estimates, tables)
write_csv(comparison, here::here("maintained", "output", "archive_output_comparison.csv"))
print(comparison |> summarise(files = n(), same = sum(same_rows), largest = max(largest_difference), .by = kind))
print(filter(comparison, !same_rows))
