# 03_merge_opportunities.R: one table of opportunities from every source pulled so far.
# Inputs (all produced by earlier scripts, nothing is fetched here):
#   data/processed/grantsgov_extract.csv     02a, canonical: every field, derived status
#   data/processed/grantsgov_api_status.csv  02b, official posted/forecasted status (overrides 02a)
#   data/processed/nc_awards_by_cfda.csv     02c, NC state agencies' past awards by CFDA
#   data/processed/simpler_opportunities.csv 02e, second source: fills blanks, adds ids Grants.gov lacks
#   data/processed/federal_register_notices.csv 02d, announcements: matched by opportunity number in the
#     title or abstract; unmatched notices stay as their own rows with status "notice"
# Grants.gov (extract + API) is canonical. Other sources only fill blank fields or add rows; each row
# lists every source that carries it in sources_seen.
# Output: data/processed/opportunities.csv and opportunities.json. Nothing is scored or dropped.
# Run from Finalists/src: Rscript R/03_merge_opportunities.R   (offline; identical on every rerun)

here::i_am("src/R/03_merge_opportunities.R")
source(here::here("src", "R", "00_config.R"))
suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr); library(stringr); library(jsonlite) })

rd <- function(f, ...) read_csv(file.path(DIR_PROCESSED, f), show_col_types = FALSE, guess_max = 1e5, ...)
ex  <- rd("grantsgov_extract.csv")
api <- rd("grantsgov_api_status.csv", col_types = cols(.default = "c"))
won <- rd("nc_awards_by_cfda.csv", col_types = cols(cfda = "c"))
sim <- rd("simpler_opportunities.csv", col_types = cols(.default = "c")) |>
  mutate(across(c(post_date, close_date, archive_date), as.Date), across(c(award_floor, award_ceiling, est_total_funding, n_awards), as.numeric))
fr  <- rd("federal_register_notices.csv")

# The extract text carries XML entities, sometimes doubled (&amp;apos;).
decode <- function(x) {
  for (i in 1:2) x <- x |> str_replace_all("&amp;", "&") |> str_replace_all("&apos;", "'") |>
    str_replace_all("&quot;", "\"") |> str_replace_all("&lt;", "<") |> str_replace_all("&gt;", ">")
  str_squish(x)
}

# Status: the API is the official word for posted and forecasted; the extract fills the rest.
ex <- ex |> mutate(opp_id = as.character(opp_id)) |>
  left_join(api |> select(opp_id, api_status), by = "opp_id") |>
  mutate(status_extract = status,
         status = coalesce(api_status, if_else(status %in% c("posted", "forecasted"), "closed", status)),
         is_forecast = status == "forecasted",
         is_recent_closed = status == "closed" & !is.na(close_date) & close_date >= CLOSED_SINCE) |>
  select(-api_status)

# Opportunities the API lists but the extract (a day old) lacks: keep them as thin rows.
missing_api <- api |> filter(!opp_id %in% ex$opp_id) |>
  transmute(opp_id, opp_number, title, agency_code, status = api_status, is_forecast = api_status == "forecasted",
            close_date = as.Date(close_date_api, "%m/%d/%Y"), cfda_list = cfda_list_api, source = "grantsgov_api",
            url = paste0("https://www.grants.gov/search-results-detail/", opp_id))
opps <- bind_rows(ex |> mutate(source = "grantsgov_extract"), missing_api)

# Simpler.Grants.gov: fill blanks on rows Grants.gov already has (matched on the legacy Grants.gov id),
# keep its named applicant types, and add rows only Simpler lists.
sim <- sim |> mutate(opp_id = coalesce(opp_id, simpler_id))
fill <- sim |> select(opp_id, award_floor_s = award_floor, award_ceiling_s = award_ceiling, est_total_funding_s = est_total_funding,
                      n_awards_s = n_awards, close_date_s = close_date, elig_s = eligibility_text, cfda_s = cfda_list, summary_s = summary,
                      applicant_types_named = applicant_types)
opps <- opps |> left_join(fill, by = "opp_id") |>
  mutate(award_floor = coalesce(award_floor, award_floor_s), award_ceiling = coalesce(award_ceiling, award_ceiling_s),
         est_total_funding = coalesce(est_total_funding, est_total_funding_s), n_awards = coalesce(n_awards, n_awards_s),
         close_date = coalesce(close_date, close_date_s), eligibility_text = coalesce(eligibility_text, elig_s),
         cfda_list = coalesce(cfda_list, cfda_s), summary = coalesce(summary, summary_s)) |>
  select(-ends_with("_s"))
sim_only <- sim |> filter(!opp_id %in% opps$opp_id) |>
  transmute(opp_id, opp_number, title, agency, agency_code, status, is_forecast = status == "forecasted", post_date, close_date,
            award_floor, award_ceiling, est_total_funding, n_awards, eligibility_text, cfda_list, summary, applicant_types_named = applicant_types,
            category, url, source = "simpler")
message("Simpler-only rows added: ", nrow(sim_only))
opps <- bind_rows(opps, sim_only)

# Past NC wins by CFDA (state agencies only, FY2022-2026): a flag plus the top recipients.
won_top <- won |> arrange(cfda, desc(total_obligated)) |> group_by(cfda) |>
  summarise(nc_won_n_awards = sum(n_awards), nc_won_recipients = paste(head(recipient, 3), collapse = "; "), .groups = "drop")
cfda_long <- opps |> select(opp_id, cfda_list) |> separate_longer_delim(cfda_list, "|") |>
  filter(!is.na(cfda_list)) |> inner_join(won_top, by = c("cfda_list" = "cfda"))
won_by_opp <- cfda_long |> group_by(opp_id) |>
  summarise(nc_won_n_awards = sum(nc_won_n_awards), nc_won_recipients = paste(unique(unlist(strsplit(nc_won_recipients, "; "))) |> head(3), collapse = "; "), .groups = "drop")

out <- opps |> left_join(won_by_opp, by = "opp_id") |>
  mutate(nc_won_before = !is.na(nc_won_n_awards),
         nc_won_n_awards = replace_na(nc_won_n_awards, 0L),
         sources_seen = paste0(case_when(source == "grantsgov_api" ~ "grantsgov_api",
                                         source == "simpler" ~ "simpler",
                                         opp_id %in% api$opp_id ~ "grantsgov_extract|grantsgov_api",
                                         TRUE ~ "grantsgov_extract"),
                               if_else(source != "simpler" & opp_id %in% sim$opp_id, "|simpler", "")),
         across(c(title, agency, summary, eligibility_text, cost_sharing, close_date_note), decode)) |>
  transmute(opp_id, opp_number, source, sources_seen, title, agency, agency_code, status, is_forecast, is_recent_closed,
            post_date, close_date, award_floor, award_ceiling, est_total_funding, n_awards, cost_sharing,
            applicant_types = applicant_type_codes, applicant_types_named, eligibility_text, cfda_list, category, funding_instrument, funding_activity,
            summary, url, nc_won_before, nc_won_n_awards, nc_won_recipients) |>
  arrange(status, close_date)

# Federal Register: match by opportunity number found in title/abstract (numbers of 6+ characters only).
nums <- out |> filter(!is.na(opp_number), nchar(opp_number) >= 6) |> distinct(opp_number, opp_id)
fr_text <- str_to_upper(paste(fr$title, fr$abstract))
fr$matched_opp <- vapply(fr_text, function(t) { h <- nums$opp_id[stringi::stri_detect_fixed(t, str_to_upper(nums$opp_number))]; if (length(h)) h[1] else NA_character_ }, character(1))
hit <- fr |> filter(!is.na(matched_opp)) |> group_by(matched_opp) |> summarise(url = paste(url, collapse = " | "), .groups = "drop")
out <- out |> left_join(hit |> transmute(opp_id = matched_opp, fr_url = url), by = "opp_id") |>
  mutate(sources_seen = if_else(!is.na(fr_url), paste0(sources_seen, "|federal_register"), sources_seen))
fr_only <- fr |> filter(is.na(matched_opp)) |>
  transmute(opp_id = paste0("fr:", document_number), source = "federal_register", sources_seen = "federal_register",
            title, agency, status = "notice", is_forecast = FALSE, is_recent_closed = FALSE, post_date = publication_date,
            summary = abstract, url, fr_url = url, nc_won_before = FALSE, nc_won_n_awards = 0L)
message("Federal Register: ", sum(!is.na(fr$matched_opp)), " notices matched to a Grants.gov row, ", nrow(fr_only), " kept as notice rows")
out <- bind_rows(out, fr_only) |> arrange(status, close_date)

stopifnot(!anyDuplicated(out$opp_id))
write_csv(out, file.path(DIR_PROCESSED, "opportunities.csv"))
write_json(out, file.path(DIR_PROCESSED, "opportunities.json"), na = "null", digits = NA, dataframe = "rows")
message("Wrote opportunities.csv/.json: ", nrow(out), " rows")
print(count(out, source, status))
message("nc_won_before TRUE: ", sum(out$nc_won_before), " of ", nrow(out))
