# sarkar_coppock_2026/run_all.R
# Runs in order: verify the deposit, rerun it stripped in a scratch copy (about an hour; set
# SARKAR_REUSE_ARCHIVE_RUN=TRUE to reuse a finished run), compare it with the shipped files, trace the
# outcome ranges, compute the page's values, render the errata, build and test the ground truth.

library(here)
here::i_am("run_all.R")

source(here::here("download_original.R"))
source(here::here("maintained", "run_archive.R"))
source(here::here("maintained", "compare_archive_run.R"))
source(here::here("maintained", "outcome_ranges.R"))
source(here::here("maintained", "page_values.R"))
quarto::quarto_render(here::here("errata.qmd"))
source(here::here("ground_truth", "build_ground_truth.R"))
source(here::here("ground_truth", "negative_controls.R"))
source(here::here("download_original.R"))
