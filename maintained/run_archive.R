# sarkar_coppock_2026/maintained/run_archive.R
# Output: maintained/archive_run/ (gitignored), ground_truth/archive_run_status.csv, ground_truth/archive_overwrites.csv
# Depends on: original_extracted/ (rebuilt by download_original.R)
# Description: Copy the deposit to a scratch directory, strip every derived file, and run its scripts there in the README's
#   order, each in a fresh R process. The deposit omits Wallsten and Nteta's raw data, so that study's shipped cleaned file
#   stays as an input. Set SARKAR_REUSE_ARCHIVE_RUN=TRUE to reuse a finished run. The deposit is run once, stripped; there
#   is no as-shipped pass. Each stripped file is then recorded as rebuilt or withheld, and each rebuilt file is compared
#   with the shipped copy: an .rds on its contents, a .tex on its text without comment lines, and a .pdf on its bytes
#   without the creation date, modification date, and producer.

library(tidyverse)
library(here)
here::i_am("maintained/run_archive.R")

run_dir <- here::here("maintained", "archive_run")
archive <- file.path(run_dir, "sarkar_coppock_replication_archive")
shipped <- here::here("original_extracted", "sarkar_coppock_replication_archive")
status_path <- here::here("ground_truth", "archive_run_status.csv")
derived_dirs <- c("cleaned_data", "estimates", "output")
keep <- "cleaned_data/wallsten_nteta_2016_all_studies_clean.rds"

derived_files <- function(root) {
  map(derived_dirs, \(d) file.path(d, list.files(file.path(root, d), recursive = TRUE))) |> unlist() |> setdiff(keep)
}

# The stripped run ----
if (!(Sys.getenv("SARKAR_REUSE_ARCHIVE_RUN") == "TRUE" && file.exists(file.path(run_dir, "finished")))) {
  dir.create(run_dir, showWarnings = FALSE)
  unlink(archive, recursive = TRUE)
  unlink(file.path(run_dir, "finished"))
  file.copy(shipped, run_dir, recursive = TRUE)
  unlink(file.path(archive, derived_files(archive)))

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
    exit_status <- attr(log_lines, "status") %||% 0L
    log_file <- file.path(run_dir, "logs", str_c(str_replace_all(script, "/", "__"), ".log"))
    dir.create(dirname(log_file), showWarnings = FALSE)
    write_lines(log_lines, log_file)
    tibble(pass = "stripped", script = script,
           role = if_else(str_starts(script, "code/cleaning/"), "cleaning", "analysis"),
           exit_status = exit_status,
           outcome = if_else(exit_status == 0L, "clean", "error"),
           stopped_at = if (exit_status == 0L) NA_character_ else last(str_subset(log_lines, "Error"), default = NA_character_))
  }
  status <- map(scripts, run_one) |> list_rbind()
  write_csv(status, status_path)
  file.create(file.path(run_dir, "finished"))
}

# What the stripped run rebuilt ----
same_file <- function(file) {
  a <- file.path(shipped, file)
  b <- file.path(archive, file)
  if (str_ends(file, "[.]rds")) {
    isTRUE(all.equal(read_rds(a), read_rds(b), check.attributes = FALSE))
  } else if (str_ends(file, "[.]tex")) {
    strip <- \(path) read_lines(path) |> str_subset("^\\s*%", negate = TRUE) |> str_squish()
    identical(strip(a), strip(b))
  } else {
    strip <- function(path) {
      bytes <- read_file_raw(path)
      rawToChar(replace(bytes, bytes == as.raw(0), as.raw(32))) |> str_remove_all("/(CreationDate|ModDate|Producer) \\([^)]*\\)")
    }
    identical(strip(a), strip(b))
  }
}
stripped <- derived_files(shipped)
rebuilt <- derived_files(archive)
overwrites <- bind_rows(
  tibble(file = stripped, effect = if_else(stripped %in% rebuilt, "rebuilt", "withheld")),
  tibble(file = setdiff(rebuilt, stripped), effect = "added")) |>
  mutate(pass = "stripped",
         matches_deposit = map2_lgl(file, effect, \(file, effect) if (effect == "rebuilt") same_file(file) else NA)) |>
  select(pass, file, effect, matches_deposit)
write_csv(overwrites, here::here("ground_truth", "archive_overwrites.csv"))

status <- read_csv(status_path, show_col_types = FALSE)
print(str_glue("Deposit rerun: {sum(status$outcome == 'clean')} of {nrow(status)} scripts exit 0."))
print(count(overwrites, effect, matches_deposit))
