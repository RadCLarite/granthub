# 04_plan_text_extract.R: one clean text file per strategic plan PDF, all 34, same format.
# Why: Noah's and Matthew's halves used different file names, one file (Justice) saved empty,
# and 5 plans had image-only pages or lost ligatures (U+FFFD). This script redoes all 34.
# Method: pdftools text per page. A page is re-read with OCR (macOS Vision, local, no network)
# when it has almost no text or contains U+FFFD. OCR pages are tagged "[OCR]" in the page marker.
# Output: data/processed/agency_plan_text/all/<plan>.txt and src/docs/plan_text_extract_log.csv.
# data/raw is read only. Run from Finalists/src: Rscript R/04_plan_text_extract.R
# OCR needs the compiled helper: swiftc -O -o data/cache/ocr_vision src/tools/ocr_vision.swift

here::i_am("src/R/04_plan_text_extract.R")
source(here::here("src", "R", "00_config.R"))
suppressPackageStartupMessages({ library(pdftools); library(dplyr); library(readr); library(stringr); library(purrr) })

PLAN_DIR <- here::here("data", "raw", "agency_plans")
OUT_DIR  <- here::here("data", "processed", "agency_plan_text", "all")
OCR_BIN  <- here::here("data", "cache", "ocr_vision")
OCR_DIR  <- here::here("data", "cache", "ocr")          # cached OCR text per plan and page
MIN_CHARS <- 40                                          # fewer characters than this = image-only page
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE); dir.create(OCR_DIR, recursive = TRUE, showWarnings = FALSE)

manifest <- read_csv(file.path(PLAN_DIR, "MANIFEST.csv"), show_col_types = FALSE)
fname_col <- intersect(c("filename", "file", "local_file"), names(manifest))[1]
manifest$file <- manifest[[fname_col]]

# Pass 1: find pages that need OCR across all plans, then OCR them in one call (startup is slow).
pdf_of <- function(f) file.path(PLAN_DIR, f)
stem_of <- function(f) tools::file_path_sans_ext(f)
texts <- setNames(map(manifest$file, ~ pdf_text(pdf_of(.x))), manifest$file)
need <- map_dfr(manifest$file, function(f) {
  pg <- texts[[f]]; bad <- which(nchar(str_squish(pg)) < MIN_CHARS | str_detect(pg, "\ufffd"))
  tibble(file = f, page = bad)
}) |> mutate(cache = file.path(OCR_DIR, sprintf("%s_p%03d.txt", stem_of(file), page))) |> filter(!file.exists(cache))
message("Pages to OCR: ", nrow(need))
if (nrow(need)) {
  if (!file.exists(OCR_BIN)) stop("OCR helper missing: ", OCR_BIN)
  need$png <- tempfile(fileext = ".png") |> rep_len(nrow(need)) |> (\(x) sprintf("%s_%d.png", tools::file_path_sans_ext(x), seq_along(x)))()
  pwalk(need, function(file, page, cache, png) png::writePNG(pdf_render_page(pdf_of(file), page = page, dpi = 200, numeric = FALSE), png))
  out <- system2(OCR_BIN, need$png, stdout = TRUE)
  grp <- cumsum(startsWith(out, "@@@PAGE "))
  for (k in seq_len(nrow(need))) write_file(paste(out[grp == k][-1], collapse = "\n"), need$cache[k])
  unlink(need$png)
}

# Pass 2: write one file per plan; OCR pages are tagged.
log <- map_dfr(seq_len(nrow(manifest)), function(i) {
  f <- manifest$file[i]; stem <- stem_of(f); pages <- texts[[f]]; n <- length(pages)
  bad <- which(nchar(str_squish(pages)) < MIN_CHARS | str_detect(pages, "\ufffd"))
  tagged <- map_chr(seq_len(n), function(p) {
    if (p %in% bad) sprintf("===== PAGE %d [OCR] =====\n\n%s\n", p, read_file(file.path(OCR_DIR, sprintf("%s_p%03d.txt", stem, p))))
    else sprintf("===== PAGE %d =====\n\n%s\n", p, pages[p])
  })
  write_file(paste(tagged, collapse = "\n"), file.path(OUT_DIR, paste0(stem, ".txt")))
  tibble(row = i, file = f, pages = n, ocr_pages = length(bad), ocr_page_list = paste(bad, collapse = " "),
         chars = sum(nchar(pages)), chars_after = sum(nchar(tagged)), fffd_left = sum(str_count(tagged, "\ufffd")))
})
write_csv(log, here::here("src", "docs", "plan_text_extract_log.csv"))
print(log |> select(row, file, pages, ocr_pages, chars_after, fffd_left), n = 40)
