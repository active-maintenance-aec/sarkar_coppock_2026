# sarkar_coppock_2026/maintained/outcome_ranges.R
# Output: maintained/output/outcome_ranges.csv
# Depends on: maintained/archive_run/ (from run_archive.R)
# Description: Rerun the deposit's analysis scripts in a scratch directory with lm_robust wrapped, and
#   record the range of the outcome and the se_type and weights arguments at every call. The article
#   says standardization by scale length puts every outcome in 0 to 1, and that its standard errors are
#   HC2. Nothing in the deposit's own code checks the first, and this script tests both on the outcome
#   each regression actually used. It does not test which way an outcome points.

library(tidyverse)
library(here)
here::i_am("maintained/outcome_ranges.R")

archive <- here::here("maintained", "archive_run", "sarkar_coppock_replication_archive")
scratch <- tempfile("ranges")
dir.create(file.path(scratch, "estimates"), recursive = TRUE)
c("cleaned_data", "code", "metadata", "original_materials") |>
  walk(\(d) file.symlink(file.path(archive, d), file.path(scratch, d)))

tracer <- new.env()
tracer$rows <- list()
tracer$script <- ""
lm_robust <- function(formula, data = NULL, ...) {
  call <- match.call()
  call[[1]] <- quote(estimatr::lm_robust)
  y <- suppressWarnings(as.numeric(unclass(eval(formula[[2]], data, environment(formula)))))
  tracer$rows[[length(tracer$rows) + 1]] <- tibble(
    script = tracer$script, outcome = deparse1(formula[[2]]), n = sum(!is.na(y)),
    low = min(y, na.rm = TRUE), high = max(y, na.rm = TRUE),
    se_type = deparse1(call$se_type), weights = deparse1(call$weights))
  eval(call, parent.frame())
}

withr::with_dir(scratch, {
  scripts <- list.files("code/analysis", pattern = "[.]R$", full.names = TRUE)
  run_env <- new.env(parent = globalenv())
  run_env$lm_robust <- lm_robust
  walk(scripts, \(script) {
    tracer$script <- basename(script)
    # The scripts open with rm(list = ls()), which would remove the wrapper.
    code <- read_lines(script) |> str_subset("^\\s*rm\\(list", negate = TRUE)
    suppressMessages(suppressWarnings(capture.output(eval(parse(text = code), envir = run_env))))
  })
})

ranges <- bind_rows(tracer$rows) |>
  summarise(calls = n(), low = min(low), high = max(high), n_low = min(n), n_high = max(n),
            se_type = str_flatten(unique(se_type), "|"), weights = str_flatten(unique(weights), "|"),
            .by = c(script, outcome))
write_csv(ranges, here::here("maintained", "output", "outcome_ranges.csv"))
print(as.data.frame(ranges |> mutate(script = str_remove(script, "_analysis.R$"))), right = FALSE)
