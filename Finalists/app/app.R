# grantHub (Federal Funds Matchmaker): Azure proof. Display only: no scoring, ranking or LLM.
library(shiny)
library(data.table)
library(DT)

mode <- Sys.getenv("MODE", "app")
opp <- fread("data/opportunities.csv")
n_total <- nrow(opp)
by_status <- opp[, .N, by = status]
by_status <- by_status[order(-N)]
fmt <- function(x) format(x, big.mark = ",")

# long text columns are left out of the table
show_cols <- setdiff(names(opp), c("summary", "eligibility_text"))
tbl <- as.data.frame(opp[, ..show_cols])

# /payload.json: fetched server-side from Blob so no secret reaches the browser.
# Auth, in order: BLOB_SAS (read-only SAS, set as a Container App secret) else managed identity.
blob_base <- "https://ffmdatateam15.blob.core.windows.net/ffm-data/payload.json"
payload_cache <- new.env(); payload_cache$t <- 0; payload_cache$body <- NULL
get_payload <- function() {
  if (!is.null(payload_cache$body) && as.numeric(Sys.time()) - payload_cache$t < 60) return(payload_cache$body)
  sas <- Sys.getenv("BLOB_SAS", "")
  body <- tryCatch({
    if (nzchar(sas)) {
      paste(readLines(url(paste0(blob_base, "?", sub("^\\?", "", sas))), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    } else {
      ep <- Sys.getenv("IDENTITY_ENDPOINT", ""); hd <- Sys.getenv("IDENTITY_HEADER", "")
      stopifnot(nzchar(ep))
      tk <- system2("curl", c("-s", "-H", shQuote(paste0("X-IDENTITY-HEADER: ", hd)),
                    shQuote(paste0(ep, "?api-version=2019-08-01&resource=https://storage.azure.com/"))), stdout = TRUE)
      tok <- sub('.*"access_token":"([^"]+)".*', "\\1", paste(tk, collapse = ""))
      paste(system2("curl", c("-s", "-H", shQuote(paste0("Authorization: Bearer ", tok)),
                    "-H", shQuote("x-ms-version: 2021-08-06"), shQuote(blob_base)), stdout = TRUE), collapse = "\n")
    }
  }, error = function(e) NULL)
  # Fallback while Blob has no newer file: a copy baked into the image (data/payload.json). The newer data_as_of wins.
  baked <- tryCatch(paste(readLines("/srv/app/data/payload.json", warn = FALSE, encoding = "UTF-8"), collapse = "\n"), error = function(e) NULL)
  stamp <- function(x) if (is.null(x)) "" else { m <- regmatches(x, regexpr('"data_as_of"\\s*:\\s*"[^"]*"', x)); if (length(m)) sub('.*:\\s*"([^"]*)"', "\\1", m) else "" }
  ok <- function(x) !is.null(x) && grepl('"agencies"', x, fixed = TRUE)
  if (ok(body) && ok(baked) && stamp(baked) >= stamp(body)) body <- baked
  if (!ok(body) && ok(baked)) body <- baked
  if (ok(body)) { payload_cache$body <- body; payload_cache$t <- as.numeric(Sys.time()) }
  payload_cache$body
}

# /feedback?d=<json>: the tool's "Give feedback" form. Each answer is written to the container log as one line
# starting "FEEDBACK " (Container Apps sends logs to the team's Log Analytics workspace, so only people with the
# team's Azure access can read them). No key, no storage write, nothing echoed back. Read with app/read_feedback.sh.
feedback_handler <- function(req) {
  q <- sub("^\\?", "", req$QUERY_STRING %||% "")
  d <- sub("^.*(^|&)d=([^&]*).*$", "\\2", q)
  if (!nzchar(q) || identical(d, q)) return(httpResponse(400, "text/plain", "missing d"))
  txt <- tryCatch(utils::URLdecode(gsub("+", " ", d, fixed = TRUE)), error = function(e) "")
  txt <- substr(gsub("[\r\n]+", " ", txt), 1, 4000)
  if (!nzchar(txt) || !startsWith(trimws(txt), "{")) return(httpResponse(400, "text/plain", "bad feedback"))
  cat("FEEDBACK ", format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), " ", txt, "\n", sep = "", file = stderr())
  httpResponse(200, "application/json", '{"ok":true}', headers = list("Cache-Control" = "no-store"))
}
`%||%` <- function(a, b) if (is.null(a)) b else a

ui <- function(req) {
  if (identical(req$PATH_INFO, "/feedback")) return(feedback_handler(req))
  if (identical(req$PATH_INFO, "/payload.json")) {
    b <- get_payload()
    if (is.null(b)) return(httpResponse(502, "text/plain", "payload unavailable"))
    return(httpResponse(200, "application/json; charset=utf-8", b, headers = list("Cache-Control" = "no-store")))
  }
  proof_ui
}

proof_ui <- fluidPage(
  titlePanel("grantHub: Azure proof"),
  p(paste0("MODE = ", mode)),
  p("Display only: no scoring or ranking. Snapshot of opportunities.csv."),
  p(a(href = "/", "Open the matchmaker"), " | ", a(href = "/tool.html", "Open the qualifier tool (grant triage)")),
  h4(paste0("Total rows: ", fmt(n_total))),
  tags$ul(lapply(seq_len(nrow(by_status)), function(i)
    tags$li(paste0(by_status$status[i], ": ", fmt(by_status$N[i]))))),
  DTOutput("tbl")
)

server <- function(input, output, session) {
  output$tbl <- renderDT(
    datatable(tbl, filter = "top", rownames = FALSE, options = list(pageLength = 10, scrollX = TRUE)),
    server = TRUE
  )
}

shinyApp(ui, server, uiPattern = "^/(shiny|payload\\.json|feedback)$")
