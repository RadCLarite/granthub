# build_tool.R: emits outs/criteria_tool.html, one self-contained file with the payload,
# styles, ranking math and UI inlined. Opens from a double-click, works offline.
# Refuses to build unless R and the browser copy of the ranking math agree
# (the same check as src/tests/run_tests.R, section "R and JS agree").
# Run: Rscript tool/build_tool.R

here::i_am("src/tool/build_tool.R")
source(here::here("src", "R", "00_config.R"))
source(here::here("src", "tests", "agreement.R"))

read_text <- function(path) paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

# Literal (non-regex) single replacement, safe for payloads containing backslashes.
replace_token <- function(s, token, value) {
  pos <- regexpr(token, s, fixed = TRUE)
  if (pos < 0) stop("Template token not found: ", token)
  paste0(substr(s, 1, pos - 1), value, substr(s, pos + attr(pos, "match.length"), nchar(s)))
}

# Anything inlined inside <script> must not contain a closing script tag.
script_safe <- function(x) gsub("</", "<\\/", x, fixed = TRUE)

build_tool <- function(out = TOOL_HTML_OUT) {
  tool_dir <- here::here("src", "tool")
  if (!file.exists(PAYLOAD_JSON)) stop("Run R/10_run_ranking.R first (no payload.json yet)")
  res <- check_r_js_agreement()
  if (!all(res$ok)) { print(res[!res$ok, ]); stop("R and JS disagree; tool not built") }
  message("R/JS agreement: ", nrow(res), " of ", nrow(res), " checks pass")

  html <- read_text(file.path(tool_dir, "index.html"))
  html <- replace_token(html, "/*STYLES*/", read_text(file.path(tool_dir, "styles.css")))
  html <- replace_token(html, "/*PAYLOAD*/", script_safe(read_text(PAYLOAD_JSON)))
  html <- replace_token(html, "/*RANKER_JS*/", script_safe(read_text(file.path(tool_dir, "ranker.js"))))
  html <- replace_token(html, "/*UI_JS*/", script_safe(read_text(file.path(tool_dir, "ui.js"))))
  html <- sub("<title>Criteria tool</title>", paste0("<title>", PROJECT_TITLE, "</title>"), html, fixed = TRUE)

  dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
  con <- file(out, open = "w", encoding = "UTF-8"); writeLines(html, con, useBytes = TRUE); close(con)
  size <- file.size(out)
  if (size > TOOL_MAX_BYTES) stop("Tool is ", round(size / 1024^2, 1), " MB, over the limit")
  message("Wrote ", out, " (", round(size / 1024, 1), " KB)")
  invisible(out)
}

if (sys.nframe() == 0L) build_tool()
