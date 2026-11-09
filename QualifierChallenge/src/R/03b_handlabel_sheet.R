# 03b_handlabel_sheet.R — draw the 60-opportunity gold-standard sample and write a
# blank labeling sheet. The sheet never shows model output, so human labels are blind.
# Run once:  Rscript src/R/03b_handlabel_sheet.R
# Output: data/manual/handlabels_60_template.csv — fill it in and save it as
#         data/manual/handlabels_60.csv (04_validate.R reads that file).

HANDLABEL_N <- 60L

draw_handlabel_sample <- function(g, enrich) {
  set.seed(SEED)
  pool <- label_pool(g) |>
    left_join(select(enrich$nofo, opportunity_number, nofo_chars), by = "opportunity_number") |>
    mutate(has_nofo = coalesce(nofo_chars, 0L) > 0,
           family = case_when(is_va ~ "VA",
                              str_detect(agency_code, "^HHS") ~ "HHS",
                              TRUE ~ "Other federal"),
           stratum = paste(status_group, family, has_nofo, sep = " | "))
  # Every VA opportunity is included (it is the DMVA vignette); the rest are
  # allocated to strata in proportion to their size, at least one per stratum.
  va <- pool |> filter(family == "VA")
  rest <- pool |> filter(family != "VA")
  n_rest <- HANDLABEL_N - nrow(va)
  alloc <- rest |> count(stratum) |>
    mutate(k = pmax(1L, round(n / sum(n) * n_rest)))
  while (sum(alloc$k) > n_rest) { i <- which.max(alloc$k); alloc$k[i] <- alloc$k[i] - 1L }
  while (sum(alloc$k) < n_rest) { i <- which.max(alloc$n - alloc$k); alloc$k[i] <- alloc$k[i] + 1L }
  picked <- rest |> inner_join(select(alloc, stratum, k), by = "stratum") |>
    group_by(stratum) |> group_modify(~ slice_sample(.x, n = min(.x$k[1], nrow(.x)))) |> ungroup()
  bind_rows(va, picked) |> arrange(opportunity_number)
}

write_handlabel_template <- function(sample) {
  sheet <- sample |>
    transmute(
      opportunity_number, opportunity_title, issuing_agency = agency_name, agency_code,
      status = status_group, has_full_announcement = has_nofo, grants_gov_link = url,
      abstract = str_sub(summary_text, 1, 1500),
      # --- Required fields -------------------------------------------------------
      human_administrable = "",   # TRUE / FALSE
      human_domain = "",          # D01-D08 or none
      human_align_dhhs = "",      # strong / partial / none
      human_align_dmva = "",      # strong / partial / none
      human_match_required = "",  # TRUE / FALSE
      human_capabilities = "",    # capability ids separated by ;
      # --- Optional fields ---------------------------------------------------------
      human_subrecipient = "", human_evaluation = "", human_capital = "",
      human_designation = "", human_renewal = "", human_population = "",
      human_division = "", labeler_initials = "", notes = "")
  path <- file.path(DIR_MANUAL, "handlabels_60_template.csv")
  readr::write_csv(sheet, path, na = "")
  path
}

if (sys.nframe() == 0L) {
  here::i_am("src/R/03b_handlabel_sheet.R")
  for (f in c("00_config", "01_load_clean", "01a_grantsgov_enrich", "03_llm_label"))
    source(here::here("src", "R", paste0(f, ".R")))
  enrich <- readRDS(file.path(DIR_PROCESSED, "grantsgov_enrichment.rds"))
  s <- draw_handlabel_sample(grants, enrich)
  message("Sample: ", nrow(s), " opportunities"); print(count(s, stratum))
  message("Wrote ", write_handlabel_template(s))
}
