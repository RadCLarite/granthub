# 04_validate.R — compare local-model labels with the human gold standard
# (data/manual/handlabels_60.csv). Per field: accuracy, and per class precision and
# recall with a confusion matrix. Also lists every disagreement with the abstract
# text, so real model errors can be quoted (never manufactured).
# Requires 00_config.R and a labels table from 03_llm_label.R.

suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(stringr); library(purrr); library(tibble) })

HANDLABELS_PATH <- function() file.path(DIR_MANUAL, "handlabels_60.csv")

# Field pairs: human column, model column, type.
VALIDATION_FIELDS <- tribble(
  ~field,               ~human,                 ~model,             ~type,
  "administrable",      "human_administrable",  "llm_administrable", "bool",
  "domain",             "human_domain",         "llm_domain",        "class",
  "DHHS alignment",     "human_align_dhhs",     "llm_align_dhhs",    "class",
  "DMVA alignment",     "human_align_dmva",     "llm_align_dmva",    "class",
  "match required",     "human_match_required", "llm_match_required","bool",
  "subrecipients",      "human_subrecipient",   "llm_subrecipient",  "bool",
  "evaluation",         "human_evaluation",     "llm_evaluation",    "bool",
  "capital project",    "human_capital",        "llm_capital",       "bool",
  "designation",        "human_designation",    "llm_designation",   "bool",
  "renewal",            "human_renewal",        "llm_renewal",       "bool",
  "target population",  "human_population",     "llm_population",    "class"
)

load_handlabels <- function(path = HANDLABELS_PATH()) {
  if (!file.exists(path)) return(NULL)
  # Mac Excel saves "CSV" as Mac Roman; read it as that if the file is not valid UTF-8.
  raw <- readBin(path, "raw", file.size(path))
  enc <- if (validUTF8(rawToChar(raw))) "UTF-8" else "macintosh"
  hl <- readr::read_csv(path, col_types = readr::cols(.default = "c"),
                        locale = readr::locale(encoding = enc), show_col_types = FALSE) |>
    mutate(across(starts_with("human_"), ~ na_if(str_squish(str_to_lower(.x)), "")))
  # An unfilled copy of the template counts as no hand labels yet.
  filled <- hl |> filter(if_any(starts_with("human_"), ~ !is.na(.x)))
  if (nrow(filled) == 0) return(NULL)
  filled
}

norm_bool <- function(x) {
  y <- str_to_lower(as.character(x))
  case_when(y %in% c("true", "t", "yes", "y", "1") ~ "TRUE",
            y %in% c("false", "f", "no", "n", "0") ~ "FALSE", TRUE ~ NA_character_)
}

# Hand labels for domain were written as "d08 public health preparedness ..."; compare on
# the domain ID only. Other class fields are compared as written (lower case, trimmed).
norm_class <- function(x, field) {
  x <- str_squish(str_to_lower(as.character(x)))
  if (field == "domain") {
    id <- str_extract(x, "^d0?[0-9]+")
    x <- ifelse(is.na(id), x, sprintf("d%02d", as.integer(str_remove(id, "^d"))))
  }
  x
}

paired <- function(hl, labels, f) {
  hl |> select(opportunity_number, human = all_of(f$human)) |>
    inner_join(labels |> select(opportunity_number, model = all_of(f$model)), by = "opportunity_number") |>
    mutate(human = if (f$type == "bool") norm_bool(human) else norm_class(human, f$field),
           model = if (f$type == "bool") norm_bool(model) else norm_class(model, f$field)) |>
    filter(!is.na(human))
}

# A field is comparable only if most human answers use the model's closed vocabulary.
comparable <- function(hl, f, labels) {
  if (f$type == "bool") return(TRUE)
  p <- paired(hl, labels, f)
  vocab <- switch(f$field,
                  "target population" = str_to_lower(names(POPULATIONS)),
                  "domain" = c(str_to_lower(names(DOMAINS)), "none"),
                  c("strong", "partial", "none"))
  nrow(p) > 0 && mean(p$human %in% vocab) >= 0.5
}

per_class <- function(p) {
  classes <- sort(union(p$human, p$model))
  map_dfr(classes, function(k) {
    tp <- sum(p$model == k & p$human == k); fp <- sum(p$model == k & p$human != k)
    fn <- sum(p$model != k & p$human == k)
    tibble(class = k, support = sum(p$human == k),
           precision = if (tp + fp) tp / (tp + fp) else NA_real_,
           recall = if (tp + fn) tp / (tp + fn) else NA_real_)
  })
}

validate_labels <- function(labels, hl = load_handlabels()) {
  if (is.null(hl)) return(NULL)
  fields <- split(VALIDATION_FIELDS, seq_len(nrow(VALIDATION_FIELDS)))
  ok_names <- VALIDATION_FIELDS$field[map_lgl(fields, ~ comparable(hl, .x, labels))]
  not_comparable <- setdiff(VALIDATION_FIELDS$field, ok_names)
  summary <- map_dfr(fields, function(f) {
    p <- paired(hl, labels, f)
    cmp <- f$field %in% ok_names
    tibble(field = f$field, n = nrow(p),
           accuracy = if (nrow(p) && cmp) mean(p$human == p$model) else NA_real_,
           note = if (!cmp) "not comparable: hand labels are free text, not the model's categories" else "")
  })
  out_of_taxonomy <- paired(hl, labels, VALIDATION_FIELDS[VALIDATION_FIELDS$field == "domain", ]) |>
    filter(!human %in% c(str_to_lower(names(DOMAINS)), "none"))
  fields <- keep(fields, ~ .x$field %in% ok_names)
  by_class <- map_dfr(fields, function(f) {
    p <- paired(hl, labels, f); if (!nrow(p)) return(NULL)
    per_class(p) |> mutate(field = f$field, .before = 1)
  })
  confusion <- map(setNames(fields, map_chr(fields, "field")), function(f) {
    p <- paired(hl, labels, f); if (!nrow(p)) return(NULL)
    table(human = p$human, model = p$model)
  })
  # Capabilities are a set per opportunity: micro precision/recall over all ids.
  # A blank human_capabilities cell means "none apply" (per the labeling instructions).
  caps <- hl |> select(opportunity_number, human_capabilities) |>
    inner_join(labels |> select(opportunity_number, llm_capabilities), by = "opportunity_number") |>
    mutate(h = map(human_capabilities, ~ if (is.na(.x)) character() else str_squish(unlist(str_split(.x, ";")))),
           m = map(llm_capabilities, ~ as.character(unlist(.x))),
           tp = map2_int(h, m, ~ length(intersect(.x, .y))),
           fp = map2_int(h, m, ~ length(setdiff(.y, .x))),
           fn = map2_int(h, m, ~ length(setdiff(.x, .y))))
  cap_summary <- tibble(field = "required capabilities (micro)", n = nrow(caps),
                        precision = sum(caps$tp) / max(1, sum(caps$tp + caps$fp)),
                        recall = sum(caps$tp) / max(1, sum(caps$tp + caps$fn)))
  disagreements <- map_dfr(fields, function(f) {
    paired(hl, labels, f) |> filter(human != model) |> mutate(field = f$field, .before = 1)
  })
  list(summary = summary, by_class = by_class, confusion = confusion,
       capabilities = cap_summary, disagreements = disagreements,
       not_comparable = not_comparable, out_of_taxonomy = out_of_taxonomy)
}

if (sys.nframe() == 0L) {
  here::i_am("src/R/04_validate.R")
  source(here::here("src", "R", "00_config.R"))
  labels <- readRDS(file.path(DIR_PROCESSED, "llm_labels.rds"))
  v <- validate_labels(labels)
  if (is.null(v)) stop("No hand labels yet: save data/manual/handlabels_60.csv")
  saveRDS(v, file.path(DIR_PROCESSED, "validation.rds"))
  readr::write_csv(v$summary, file.path(DIR_OUTS_TABLES, "validation_summary.csv"))
  readr::write_csv(v$by_class, file.path(DIR_OUTS_TABLES, "validation_by_class.csv"))
  print(v$summary); print(v$capabilities)
  cat("\nDisagreements:", nrow(v$disagreements), "\n")
}
