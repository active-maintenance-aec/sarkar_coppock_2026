# sarkar_coppock_2026/maintained/run_archive.R
# Output: maintained/archive_run/ (gitignored), maintained/output/archive_run_status.csv
# Depends on: original_extracted/ (rebuilt by download_original.R)
# Description: Copy the deposit to a scratch directory, strip every derived file, and run its scripts there in the README's
#   order, each in a fresh R process. The deposit omits Wallsten and Nteta's raw data, so that study's shipped cleaned file
#   stays as an input. Set SARKAR_REUSE_ARCHIVE_RUN=TRUE to reuse a finished run.

library(tidyverse)
library(here)
here::i_am("maintained/run_archive.R")

run_dir <- here::here("maintained", "archive_run")
archive <- file.path(run_dir, "sarkar_coppock_replication_archive")
status_path <- here::here("maintained", "output", "archive_run_status.csv")

if (!(Sys.getenv("SARKAR_REUSE_ARCHIVE_RUN") == "TRUE" && file.exists(file.path(run_dir, "finished")))) {
  dir.create(run_dir, showWarnings = FALSE)
  unlink(archive, recursive = TRUE)
  unlink(file.path(run_dir, "finished"))
  file.copy(here::here("original_extracted", "sarkar_coppock_replication_archive"), run_dir, recursive = TRUE)
  keep <- "wallsten_nteta_2016_all_studies_clean.rds"
  derived <- c(setdiff(list.files(file.path(archive, "cleaned_data"), full.names = TRUE),
                       file.path(archive, "cleaned_data", keep)),
               list.files(file.path(archive, "estimates"), full.names = TRUE),
               list.files(file.path(archive, "output"), recursive = TRUE, full.names = TRUE))
  unlink(derived)

  scripts <- c(list.files(file.path(archive, "code", "cleaning"), pattern = "[.]R$", full.names = TRUE),
               list.files(file.path(archive, "code", "analysis"), pattern = "[.]R$", full.names = TRUE),
               list.files(file.path(archive, "code", "analysis_s"), pattern = "[.]R$", full.names = TRUE),
               setdiff(list.files(file.path(archive, "code"), pattern = "[.]R$", full.names = TRUE),
                       file.path(archive, "code", c("helpers.R", "in_text_claims.R"))),
               file.path(archive, "code", "in_text_claims.R"))
  scripts <- str_remove(scripts, str_c("^", fixed(archive), "/"))

  run_one <- function(script) {
    log_lines <- withr::with_dir(archive, suppressWarnings(
      system2("Rscript", shQuote(script), stdout = TRUE, stderr = TRUE)))
    exit <- attr(log_lines, "status") %||% 0L
    log_file <- file.path(run_dir, "logs", str_c(str_replace_all(script, "/", "__"), ".log"))
    dir.create(dirname(log_file), showWarnings = FALSE)
    write_lines(log_lines, log_file)
    tibble(script = script, exit = exit,
           last_error = if (exit == 0L) NA_character_ else last(str_subset(log_lines, "Error"), default = NA_character_))
  }
  status <- map(scripts, run_one) |> list_rbind()
  write_csv(status, status_path)
  file.create(file.path(run_dir, "finished"))
}

status <- read_csv(status_path, show_col_types = FALSE)
print(str_glue("Deposit rerun: {sum(status$exit == 0)} of {nrow(status)} scripts exit 0."))
