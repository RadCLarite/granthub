# 01_profile.R: first look at every raw file, before deciding which fields can carry a
# criterion. Writes one profile CSV per file to data/processed/profile/.
# Rule from the Deloitte training: write the user and criteria on paper BEFORE this step.
# Run: Rscript R/01_profile.R

here::i_am("src/R/01_profile.R")
source(here::here("src", "R", "00_config.R"))
source(here::here("src", "R", "helpers_io.R"))

files <- list.files(DIR_RAW, pattern = "\\.(csv|tsv|xlsx|xls|json|rds)$", recursive = TRUE,
                    full.names = TRUE, ignore.case = TRUE)
if (!length(files)) {
  message("No raw data yet. Put downloads in ", DIR_RAW, " (never edit them), then rerun.")
} else {
  out_dir <- file.path(DIR_PROCESSED, "profile"); dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  for (f in files) {
    x <- tryCatch(read_any(f), error = function(e) { message("Skipped ", basename(f), ": ", conditionMessage(e)); NULL })
    if (is.null(x) || !is.data.frame(x)) next
    p <- profile_data(x)
    readr::write_csv(p, file.path(out_dir, paste0(tools::file_path_sans_ext(basename(f)), "_profile.csv")))
    message(basename(f), ": ", nrow(x), " rows, ", ncol(x), " columns")
    print(utils::head(p, 25), n = 25)
  }
}
