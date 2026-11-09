# build_tool.R — emits outs/grant-triage-tool.html: one self-contained file with the
# payload, styles, Leaflet, tier rules, and UI inlined. Opens from a double-click.
#
# Before writing, it runs the tier rules through V8 against synthetic test cases and
# against the payload, and refuses to build if anything fails.
# Run: Rscript src/tool/build_tool.R

here::i_am("src/tool/build_tool.R")
source(here::here("src", "R", "00_config.R"))
suppressPackageStartupMessages({ library(jsonlite); library(purrr) })

read_text <- function(path) paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

# Literal (non-regex) single replacement, safe for payloads containing backslashes.
replace_token <- function(s, token, value) {
  pos <- regexpr(token, s, fixed = TRUE)
  if (pos < 0) stop("Template token not found: ", token)
  paste0(substr(s, 1, pos - 1), value, substr(s, pos + attr(pos, "match.length"), nchar(s)))
}

# Anything inlined inside <script> must not contain a closing script tag.
script_safe <- function(x) gsub("</", "<\\/", x, fixed = TRUE)

run_rule_tests <- function(tiering_js) {
  cases <- fromJSON(here::here("src", "tool", "tiering_cases.json"), simplifyVector = FALSE)
  ctx <- V8::v8()
  ctx$eval(tiering_js)
  ctx$eval(paste0("var T = ", toJSON(cases, auto_unbox = TRUE, null = "null", digits = NA), ";"))
  out <- ctx$eval("JSON.stringify(T.cases.map(function (c) {
      var opp = Object.assign({}, T.base, c.opp);
      var s = Object.assign({}, T.settings, c.settings || {});
      var payload = { opportunities: [opp], capabilities: { profiles: { DHHS: T.profile } } };
      var r = Tiering.runFlat(payload, s)[0];
      var e = c.expect, ok = true;
      if (e.placement && r.placement !== e.placement) ok = false;
      if (e.tier && r.tier !== e.tier) ok = false;
      if (e.rules && r.rules !== e.rules) ok = false;
      return { name: c.name, ok: ok, got: r.placement + ' / ' + r.tier + ' / ' + r.rules };
    }))")
  res <- fromJSON(out)
  # Ordering tests: the impact score must follow the weights, and "deadline" must sort by date.
  ord <- fromJSON(ctx$eval("JSON.stringify((function () {
      function opp(n, award, close) { return Object.assign({}, T.base, { number: n, award_estimate_usd: award, close_day: close }); }
      var P = { opportunities: [opp('small-late', 400000, 20900), opp('big-early', 5000000, 20800)],
                capabilities: { profiles: { DHHS: T.profile } } };
      function first(extra) {
        var s = Object.assign({}, T.settings, { impact_weights: { alignment: 0, reach: 0, depth: 0, award: 1, priority: 0 }, sort_by: 'impact' }, extra);
        return Tiering.run(P, s).piles[1][0].opp.number;
      }
      return [
        { name: 'impact weighted on award puts the bigger award first', ok: first({}) === 'big-early' },
        { name: 'deadline sort puts the earlier deadline first', ok: first({ sort_by: 'deadline' }) === 'big-early' },
        { name: 'zero award weight leaves ties to the deadline', ok: first({ impact_weights: { alignment: 0, reach: 0, depth: 0, award: 0, priority: 1 } }) === 'big-early' }
      ];
    })())"))
  res <- rbind(res[, c("name", "ok")], ord)
  if (!all(res$ok)) {
    print(res[!res$ok, ])
    stop(sum(!res$ok), " tier rule test(s) failed; tool not built")
  }
  message("Tier rule tests: ", nrow(res), " of ", nrow(res), " pass")
}

run_payload_checks <- function(tiering_js, payload_txt) {
  ctx <- V8::v8()
  ctx$eval(tiering_js)
  ctx$eval(paste0("var P = ", payload_txt, ";"))
  # 1. The opening scenario must reproduce the counts computed at export time.
  got <- fromJSON(ctx$eval("JSON.stringify(Tiering.run(P, P.config.opening).counts)"))
  exp <- fromJSON(ctx$eval("JSON.stringify(P.golden.opening_counts)"))
  map_names <- c(tier1 = "tier1", tier2 = "tier2", tier3 = "tier3", tier4 = "tier4", screened = "screened",
                 not_this_cycle = "not_this_cycle", out_of_scope = "out_of_scope")
  for (k in names(map_names)) {
    e <- exp[[k]] %||% 0; g <- got[[k]] %||% 0
    if (e != g) stop("Opening-state count mismatch for ", k, ": export said ", e, ", tool computes ", g)
  }
  # Every opportunity in the file must land somewhere.
  placed <- sum(unlist(got[setdiff(names(got), "total")]))
  if (placed != got$total || got$total != 1662) stop("Placement accounts for ", placed, " of ", got$total, " opportunities (expected 1662)")
  # 2. Section 3 anchor: with research shown and no filters, the fact-check universe is
  #    open, state-eligible, closing on/after ref + 45 days → 296 (272 NIH).
  anchor <- fromJSON(ctx$eval(paste0("JSON.stringify((function () {
      var n = 0, nih = 0, ref = ", as.integer(FACT_REF_DATE), ", cut = ref + ", FACT_RUNWAY_DAYS, ";
      P.opportunities.forEach(function (o) {
        if (o.state_eligible !== false && o.status === 'posted' && (o.export_close_day === undefined ? o.close_day : o.export_close_day) !== null && (o.export_close_day === undefined ? o.close_day : o.export_close_day) >= cut) { n++; if (o.screen.is_nih) nih++; }
      });
      return { n: n, nih: nih };
    })())")))
  if (anchor$n != 296 || anchor$nih != 272) stop("Payload fact anchor failed: ", anchor$n, " / ", anchor$nih, " (expected 296 / 272)")
  message("Payload checks: opening counts match export; all 1,662 placed; fact anchor 296 / 272 reproduced in JS")
}

build_tool <- function(out = TOOL_HTML_OUT) {
  tool_dir <- here::here("src", "tool")
  leaflet_dir <- system.file("htmlwidgets/lib/leaflet", package = "leaflet")
  tiering_js <- read_text(file.path(tool_dir, "tiering.js"))
  payload_txt <- read_text(PAYLOAD_JSON)

  run_rule_tests(tiering_js)
  run_payload_checks(tiering_js, payload_txt)

  html <- read_text(file.path(tool_dir, "index.html"))
  html <- replace_token(html, "/*LEAFLET_CSS*/", read_text(file.path(leaflet_dir, "leaflet.css")))
  html <- replace_token(html, "/*STYLES*/", read_text(file.path(tool_dir, "styles.css")))
  html <- replace_token(html, "/*PAYLOAD*/", script_safe(payload_txt))
  html <- replace_token(html, "/*LEAFLET_JS*/", script_safe(read_text(file.path(leaflet_dir, "leaflet.js"))))
  html <- replace_token(html, "/*TIERING_JS*/", script_safe(tiering_js))
  html <- replace_token(html, "/*UI_JS*/", script_safe(read_text(file.path(tool_dir, "ui.js"))))

  dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
  con <- file(out, open = "w", encoding = "UTF-8"); writeLines(html, con, useBytes = TRUE); close(con)
  size <- file.size(out)
  if (size > TOOL_MAX_BYTES) stop("Tool is ", round(size / 1024^2, 1), " MB, over the ", TOOL_MAX_BYTES / 1024^2, " MB limit")
  message("Wrote ", out, " (", round(size / 1024^2, 2), " MB)")
  invisible(out)
}

if (sys.nframe() == 0L) build_tool()
