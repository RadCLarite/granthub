/* ui.js — controls, scenario parser, piles, detail panel, map, reach chart.
 * All tier logic lives in tiering.js; this file only calls Tiering.run().
 * No network, no storage required: works from file:// and inside an iframe srcdoc. */
(function () {
  "use strict";

  // ---- Load payload --------------------------------------------------------------
  var P;
  try {
    P = JSON.parse(document.getElementById("payload").textContent);
  } catch (e) {
    fail("The tool's data could not be read: " + e.message);
    return;
  }
  if (!window.Tiering || P.schema_version !== window.Tiering.SCHEMA) {
    fail("Data version " + P.schema_version + " does not match tier rules version " +
         (window.Tiering ? window.Tiering.SCHEMA : "(missing)") + ". Rebuild the tool.");
    return;
  }

  function fail(msg) {
    var d = document.createElement("div");
    d.className = "error-banner"; d.textContent = msg;
    document.body.insertBefore(d, document.body.firstChild);
  }

  var CFG = P.config;
  var DOMAIN = {}; P.domains.forEach(function (d) { DOMAIN[d.id] = d.label; });
  var TIERS = {
    1: { name: "Writer can act", meaning: "Start today on your own authority", color: "var(--tier1)" },
    2: { name: "Needs supervisor or division", meaning: "Match approval, new staff, or a partner agency", color: "var(--tier2)" },
    3: { name: "Needs secretary or legislature", meaning: "Appropriation, capital project, or statutory designation", color: "var(--tier3)" },
    4: { name: "Partner-led research", meaning: "A university or research institution applies; the agency takes part as a partner", color: "var(--tier4)" }
  };
  var MATCH_LABEL = { no: "No", with_approval: "With approval", yes: "Yes" };
  var MATCH_HINT = {
    no: "Any cost share escalates to the secretary or legislature.",
    with_approval: "Cost share needs your supervisor's sign-off (Tier 2).",
    yes: "You can commit match yourself; only large awards escalate."
  };

  function clone(o) { return JSON.parse(JSON.stringify(o)); }
  var S = clone(CFG.opening);           // live settings
  var textSet = [];                     // what the scenario text changed, for display

  // ---- Helpers ----------------------------------------------------------------------
  function el(tag, attrs, kids) {
    var e = document.createElement(tag);
    if (attrs) Object.keys(attrs).forEach(function (k) {
      if (k === "class") e.className = attrs[k];
      else if (k === "text") e.textContent = attrs[k];
      else if (k === "html") e.innerHTML = attrs[k];
      else if (k.slice(0, 2) === "on") e.addEventListener(k.slice(2), attrs[k]);
      else e.setAttribute(k, attrs[k]);
    });
    (kids || []).forEach(function (c) { if (c != null) e.appendChild(typeof c === "string" ? document.createTextNode(c) : c); });
    return e;
  }
  function $(id) { return document.getElementById(id); }
  var usd = Tiering.usd;
  function dayToISO(d) { return new Date(d * 86400000).toISOString().slice(0, 10); }
  function isoToDay(s) { var p = s.split("-"); return Math.round(Date.UTC(+p[0], +p[1] - 1, +p[2]) / 86400000); }
  function fmtDate(d) {
    if (d === null || d === undefined) return "no deadline stated";
    return new Date(d * 86400000).toLocaleDateString("en-US", { timeZone: "UTC", month: "short", day: "numeric", year: "numeric" });
  }
  function ordinal(n) { var s = ["th", "st", "nd", "rd"], v = n % 100; return n + (s[(v - 20) % 10] || s[v] || s[0]); }
  function fmtNum(n) { return n === null || n === undefined ? "n/a" : Math.round(n).toLocaleString("en-US"); }
  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  function profile() { return P.capabilities.profiles[S.agency] || {}; }

  // ---- Header note ----------------------------------------------------------------------
  $("data-note").textContent = "Grants.gov export pulled " + P.meta.pull_date + " (" + P.meta.source_rows.toLocaleString() +
    " rows). Current status re-checked " + (P.opportunities.find(function (o) { return o.status_checked; }) || {}).status_checked +
    ". Labels by local model " + P.meta.llm_model + " (" + P.meta.llm_labeled + " opportunities).";

  // ---- Controls -----------------------------------------------------------------------------
  CFG.agencies.forEach(function (a) { $("agency").appendChild(el("option", { value: a, text: a === "DHHS" ? "NC DHHS" : "NC DMVA" })); });

  var R = CFG.ranges;
  // Opportunities that closed before the default reference date keep rule-based labels
  // only, so the reference date cannot be moved earlier than the data pull date.
  $("ref-date").min = CFG.pull_date;
  $("runway").min = R.runway_days[0]; $("runway").max = R.runway_days[1]; $("runway").step = 1;
  $("fte").min = R.staff_fte[0]; $("fte").max = R.staff_fte[1]; $("fte").step = R.staff_fte[2];
  $("minaward").min = R.min_award_usd[0]; $("minaward").max = R.min_award_usd[1]; $("minaward").step = R.min_award_usd[2];

  CFG.match_levels.forEach(function (m) {
    $("match").appendChild(el("button", { type: "button", "data-v": m, text: MATCH_LABEL[m], onclick: function () { S.match_authority = m; update(); } }));
  });

  P.domains.forEach(function (d) {
    var inp = el("input", { type: "range", min: 0, max: 3, step: 1, "data-d": d.id, "aria-label": "Priority weight for " + d.label });
    inp.addEventListener("input", function () { S.domain_weights[d.id] = +inp.value; update(); });
    $("weights").appendChild(el("div", { class: "weight-row" }, [el("span", { text: d.label }), inp, el("span", { class: "val", "data-dv": d.id })]));
  });

  CFG.presets.forEach(function (p) {
    $("presets").appendChild(el("button", { class: "btn", type: "button", "data-p": p.id, title: p.blurb, text: p.label,
      onclick: function () { applyPreset(p.id); } }));
  });

  function bindRange(id, key, cast) {
    $(id).addEventListener("input", function () { S[key] = cast($(id).value); update(); });
  }
  bindRange("runway", "runway_days", function (v) { return parseInt(v, 10); });
  bindRange("fte", "staff_fte", parseFloat);
  bindRange("minaward", "min_award_usd", parseFloat);

  // ---- Impact ranking controls ---------------------------------------------------------
  var IMPACT_LABEL = { alignment: "Fit with the strategic plan", reach: "People reached",
                       depth: "Help per person", award: "Award size", priority: "My program priorities" };
  var IMPACT_SHORT = { alignment: "plan fit", reach: "reach", depth: "per-person", award: "award", priority: "priority" };
  Tiering.IMPACT_PARTS.forEach(function (k) {
    var inp = el("input", { type: "range", min: 0, max: 3, step: 0.5, "data-iw": k, "aria-label": "Impact weight: " + IMPACT_LABEL[k] });
    inp.addEventListener("input", function () { S.impact_weights[k] = +inp.value; update(); });
    $("impact-weights").appendChild(el("div", { class: "weight-row" }, [el("span", { text: IMPACT_LABEL[k] }), inp, el("span", { class: "val", "data-iwv": k })]));
  });
  $("sort-by").addEventListener("change", function () { S.sort_by = $("sort-by").value; update(); });
  $("most-important").addEventListener("change", function () {
    var pick = $("most-important").value;
    Tiering.IMPACT_PARTS.forEach(function (k) { S.impact_weights[k] = !pick || pick === k ? (pick ? 3 : 1) : 1; });
    if (pick) S.sort_by = "impact";
    update();
  });
  // Which "most important" option (if any) matches the current weights.
  function mostImportantFromWeights() {
    var w = S.impact_weights, parts = Tiering.IMPACT_PARTS;
    if (parts.every(function (k) { return w[k] === 1; })) return "";
    var hi = parts.filter(function (k) { return w[k] === 3; });
    if (hi.length === 1 && parts.every(function (k) { return k === hi[0] || w[k] === 1; })) return hi[0];
    return "custom";
  }
  $("ref-date").addEventListener("change", function () { if ($("ref-date").value) { S.ref_day = isoToDay($("ref-date").value); update(); } });
  $("agency").addEventListener("change", function () { S.agency = $("agency").value; update(); });
  $("forecasts").addEventListener("change", function () { S.include_forecasts = $("forecasts").checked; update(); });
  $("show-screened").addEventListener("change", function () { S.show_screened = $("show-screened").checked; update(); });
  $("approp").addEventListener("change", function () { S.appropriation_usd = +$("approp").value || 0; update(); });
  ["low", "medium", "high"].forEach(function (b) {
    $("fte-" + b).addEventListener("change", function () { S.fte_by_burden[b] = +$("fte-" + b).value; update(); });
  });
  $("reset-all").addEventListener("click", function () { S = clone(CFG.opening); textSet = []; $("scenario-text").value = ""; activePreset = CFG.opening_preset; update(); });

  var activePreset = CFG.opening_preset;
  function applyPreset(id) {
    var p = CFG.presets.find(function (x) { return x.id === id; });
    Object.keys(p.settings).forEach(function (k) { S[k] = p.settings[k]; });
    activePreset = id; textSet = [{ key: "preset", label: "Preset: " + p.label + " (" + p.blurb + ")" }];
    update();
  }

  function syncControls() {
    $("agency").value = S.agency;
    $("ref-date").value = dayToISO(S.ref_day);
    $("runway").value = S.runway_days; $("runway-val").textContent = S.runway_days + " days";
    $("fte").value = S.staff_fte; $("fte-val").textContent = S.staff_fte + " FTE";
    $("minaward").value = S.min_award_usd; $("minaward-val").textContent = usd(S.min_award_usd);
    Array.prototype.forEach.call($("match").children, function (b) {
      var on = b.getAttribute("data-v") === S.match_authority;
      b.classList.toggle("on", on); b.setAttribute("aria-pressed", on ? "true" : "false");
    });
    $("match-hint").textContent = MATCH_HINT[S.match_authority];
    $("forecasts").checked = !!S.include_forecasts;
    $("show-screened").checked = !!S.show_screened;
    Array.prototype.forEach.call(document.querySelectorAll("[data-d]"), function (inp) { inp.value = S.domain_weights[inp.getAttribute("data-d")]; });
    Array.prototype.forEach.call(document.querySelectorAll("[data-dv]"), function (s) { s.textContent = "x" + S.domain_weights[s.getAttribute("data-dv")]; });
    $("approp").value = S.appropriation_usd; $("approp-val").textContent = usd(S.appropriation_usd);
    $("sort-by").value = S.sort_by;
    var mi = mostImportantFromWeights(), sel = $("most-important"), custom = sel.querySelector("option[value=custom]");
    if (mi === "custom" && !custom) sel.appendChild(el("option", { value: "custom", text: "Custom weights" }));
    if (mi !== "custom" && custom) custom.remove();
    sel.value = mi;
    Array.prototype.forEach.call(document.querySelectorAll("[data-iw]"), function (inp) { inp.value = S.impact_weights[inp.getAttribute("data-iw")]; });
    Array.prototype.forEach.call(document.querySelectorAll("[data-iwv]"), function (sp) { sp.textContent = "x" + S.impact_weights[sp.getAttribute("data-iwv")]; });
    ["low", "medium", "high"].forEach(function (b) { $("fte-" + b).value = S.fte_by_burden[b]; });
    Array.prototype.forEach.call(document.querySelectorAll("[data-p]"), function (b) { b.classList.toggle("active", b.getAttribute("data-p") === activePreset); });
  }

  // ---- Scenario text parser ------------------------------------------------------------------
  // A small, visible keyword parser. Every rule that fires becomes a chip the user can undo.
  var WORDS = { a: 1, an: 1, one: 1, two: 2, three: 3, four: 4, five: 5, six: 6, seven: 7, eight: 8, nine: 9, ten: 10, twelve: 12, half: 0.5 };
  function num(w) {
    w = String(w).toLowerCase();
    if (/^half/.test(w)) return 0.5;
    return WORDS[w] !== undefined ? WORDS[w] : parseFloat(w);
  }
  // "half an" is listed first so "half an FTE" is read as 0.5, not as "an FTE".
  var NUM = "(half an?|\\d+(?:\\.\\d+)?|a|an|one|two|three|four|five|six|seven|eight|nine|ten|twelve|half)";
  var DOMAIN_WORDS = [
    ["D01", /\b(behavioral|mental health|crisis|suicide|988)\b/i],
    ["D02", /\b(opioid|substance|overdose|addiction|harm reduction)\b/i],
    ["D03", /\b(maternal|prenatal|pregnan|birth|infant|reproductive|title x)\w*/i],
    ["D04", /\b(child welfare|foster|kinship|adoption|early childhood|families|family)\b/i],
    ["D05", /\b(food|nutrition|snap|wic|hunger)\b/i],
    ["D06", /\b(aging|older adults?|seniors?|disabilit\w*|long[- ]term care|nursing home|veterans? home)\b/i],
    ["D07", /\b(rural|telehealth|workforce|primary care|access)\b/i],
    ["D08", /\b(disaster|hurricane|flood|emergency|preparedness|outbreak|infectious)\b/i]
  ];

  var MONEY_UNIT = "(k|m|mil|million|thousand)";
  var AWARD_RE = new RegExp(
    "\\$\\s?(\\d+(?:\\.\\d+)?)\\s?" + MONEY_UNIT + "?\\b" +
    "|\\b(?:at least|minimum(?: of)?|min|over|above|more than|no less than|awards? (?:of|over|above|at least))\\s+(\\d+(?:\\.\\d+)?)\\s?" + MONEY_UNIT + "\\b" +
    "|\\b(\\d+(?:\\.\\d+)?)\\s?" + MONEY_UNIT + "\\b(?!\\s*(?:people|residents|persons|veterans|children|adults|kids|families|fte|staff))");
  var IMPACT_WORDS = [
    ["reach", /\b(reach(es|ing)? (the )?most|most people|many people|people reached|broad(est)? reach|widest reach|reach more|statewide reach|reach)\b/],
    ["depth", /\b(per[- ]person|per capita|deep(er|est)? impact|intensity|depth|help per person|intensive)\b/],
    ["award", /\b((big|bigg|larg)\w* (awards?|grants?|money|dollars|funding)|award size|most money|most funding|big money)\b/],
    ["alignment", /\b(strategic plan|plan fit|fits? (the |our )?plan|align\w*)\b/],
    ["priority", /\b(my (program )?priorit\w*|program priorit\w*|our priorit\w*)\b/]
  ];

  function parseScenario(text) {
    var t = " " + text.toLowerCase() + " ", out = [], m;
    function set(key, value, label, from) { out.push({ key: key, value: value, label: label, from: from }); }

    if ((m = t.match(new RegExp(NUM + "\\s*(day|week|month)s?\\b")))) {
      var n = num(m[1]), unit = m[2];
      var days = Math.round(unit === "day" ? n : unit === "week" ? n * 7 : n * 30);
      set("runway_days", Math.max(R.runway_days[0], Math.min(R.runway_days[1], days)), "Runway: " + days + " days", m[0].trim());
    }
    if ((m = t.match(/\b(no|without|can'?t|cannot|zero)\b[^.]{0,25}\b(match|matching|cost[- ]share)/))) {
      set("match_authority", "no", "Match: no", m[0].trim());
    } else if ((m = t.match(/\b(approv\w*|supervisor|boss|sign[- ]off)\b[^.]{0,30}\b(match|matching|cost[- ]share)|\b(match|matching|cost[- ]share)\b[^.]{0,30}\b(approv\w*|supervisor|boss|sign[- ]off)/))) {
      set("match_authority", "with_approval", "Match: with approval", m[0].trim());
    } else if ((m = t.match(/\b(can|able to|have|has)\b[^.]{0,20}\b(commit |provide )?(match|matching|cost[- ]share)/))) {
      set("match_authority", "yes", "Match: yes", m[0].trim());
    }
    if ((m = t.match(new RegExp(NUM + "\\s*(fte|staff|people|writers?|person|employees?)\\b")))) {
      var f = num(m[1]);
      if (m[1] === "a" || m[1] === "an") f = 1;
      set("staff_fte", Math.max(R.staff_fte[0], Math.min(R.staff_fte[1], f)), "Staff: " + f + " FTE", m[0].trim());
    } else if ((m = t.match(/\b(no staff|nobody|by myself|just me|only me|alone)\b/))) {
      set("staff_fte", m[0].indexOf("no staff") >= 0 || m[0] === "nobody" ? 0 : 1, "Staff: " + (m[0].indexOf("no staff") >= 0 || m[0] === "nobody" ? 0 : 1) + " FTE", m[0].trim());
    }
    // Minimum award: "$500k", "at least 250 thousand", "awards over 1 million", "2m".
    // An amount followed by people words ("10 million residents") is reach, not money.
    if ((m = t.match(AWARD_RE))) {
      var amt = m[1] || m[3] || m[5], unit = (m[2] || m[4] || m[6] || "").trim();
      var v = parseFloat(amt) * (/^(m|mil|million)$/.test(unit) ? 1e6 : /^(k|thousand)$/.test(unit) ? 1e3 : 1);
      set("min_award_usd", Math.max(R.min_award_usd[0], Math.min(R.min_award_usd[1], v)), "Minimum award: " + usd(v), m[0].trim());
    }
    // What matters most for the impact score. Each phrase raises one part's weight to 3.
    IMPACT_WORDS.forEach(function (iw) {
      var mm = t.match(iw[1]);
      if (mm) set("iw:" + iw[0], 3, "Impact weight up: " + IMPACT_LABEL[iw[0]], mm[0].trim());
    });
    if ((m = t.match(/\b(soonest|closing soon|closes soon|by deadline|deadline first|sort by deadline|most urgent)\b/))) {
      set("sort_by", "deadline", "Order piles by: deadline", m[0].trim());
    } else if ((m = t.match(/\b(most|highest|biggest|greatest|max(imum)?) impact\b|\bimpact (first|matters)\b/)) ||
               out.some(function (o) { return o.key.indexOf("iw:") === 0; })) {
      var from = m ? m[0].trim() : out.filter(function (o) { return o.key.indexOf("iw:") === 0; })[0].from;
      set("sort_by", "impact", "Order piles by: impact score", from);
    }
    if ((m = t.match(/\b(forecast\w*|upcoming|next year|plan(ning)? ahead|not yet open)\b/))) {
      set("include_forecasts", true, "Include forecasts", m[0].trim());
    }
    if ((m = t.match(/\b(dmva|veterans? affairs|military and veterans)\b/))) set("agency", "DMVA", "Agency: DMVA", m[0].trim());
    else if ((m = t.match(/\b(dhhs|health and human services)\b/))) set("agency", "DHHS", "Agency: DHHS", m[0].trim());
    DOMAIN_WORDS.forEach(function (dw) {
      var mm = t.match(dw[1]);
      if (mm) set("domain:" + dw[0], CFG.parser_domain_boost, "Priority up: " + DOMAIN[dw[0]], mm[0].trim());
    });
    return out;
  }

  function applyText() {
    var text = $("scenario-text").value;
    var found = parseScenario(text);
    textSet = [];
    found.forEach(function (f) {
      var prev;
      if (f.key.indexOf("domain:") === 0) { var d = f.key.slice(7); prev = S.domain_weights[d]; S.domain_weights[d] = f.value; }
      else if (f.key.indexOf("iw:") === 0) { var k = f.key.slice(3); prev = S.impact_weights[k]; S.impact_weights[k] = f.value; }
      else { prev = S[f.key]; S[f.key] = f.value; }
      f.prev = prev; textSet.push(f);
    });
    if (!found.length) textSet = [{ key: "none", label: "Nothing recognized. Try phrases like \"one month\", \"no match\", \"two staff\", \"rural\", \"at least $500k\", \"reach the most people\"." }];
    activePreset = null;
    update();
  }
  $("apply-text").addEventListener("click", applyText);
  // Example scenarios: one click fills the box and applies it (useful for a live demo).
  [["No match, half an FTE", "Two weeks, no matching funds, half an FTE, rural behavioral health"],
   ["Big-picture planning", "Planning ahead three months, forecasts, supervisor approves match, two staff, reach the most people"],
   ["Worth the effort", "One month, match with approval, one staff, awards of at least $1 million, biggest grants first"]]
    .forEach(function (ex) {
      $("examples").appendChild(el("button", { class: "btn ghost", type: "button", title: ex[1], text: ex[0], onclick: function () {
        // Start each example from the opening scenario so examples don't stack on each other.
        S = clone(CFG.opening); activePreset = null;
        $("scenario-text").value = ex[1]; applyText();
      } }));
    });
  // Larger text for projecting the tool in a meeting.
  $("present-toggle").addEventListener("click", function () {
    var on = document.documentElement.classList.toggle("present");
    $("present-toggle").setAttribute("aria-pressed", on ? "true" : "false");
    $("present-toggle").textContent = on ? "Normal text" : "Larger text";
  });
  $("scenario-text").addEventListener("keydown", function (e) { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); applyText(); } });

  function renderChips() {
    var c = $("chips"); c.innerHTML = "";
    textSet.forEach(function (f, i) {
      if (f.key === "none" || f.key === "preset") { c.appendChild(el("span", { class: "chip none", text: f.label })); return; }
      c.appendChild(el("span", { class: "chip", title: 'From your text: "' + f.from + '"' }, [
        f.label + '  ← "' + f.from + '"',
        el("button", { type: "button", "aria-label": "Undo " + f.label, text: "×", onclick: function () {
          if (f.key.indexOf("domain:") === 0) S.domain_weights[f.key.slice(7)] = f.prev;
          else if (f.key.indexOf("iw:") === 0) S.impact_weights[f.key.slice(3)] = f.prev;
          else S[f.key] = f.prev;
          textSet.splice(i, 1); update();
        } })
      ]));
    });
  }

  // ---- Piles ---------------------------------------------------------------------------------
  var lastRun = null;
  function statusBadge(o) {
    if (o.status_now === "closed" || o.status_now === "archived") {
      return el("span", { class: "badge crit", title: "Grants.gov listed this as " + o.status_now + " on " + o.status_checked },
        [el("span", { class: "ico", text: "!" }), "Now " + o.status_now]);
    }
    return null;
  }

  function card(item) {
    var o = item.opp, t = TIERS[item.tier];
    var days = item.days_left;
    var c = el("button", { class: "card", type: "button", style: "--tier-color:" + t.color, onclick: function () { openDetail(o); } }, [
      el("div", { class: "t", text: o.title }),
      el("div", { class: "meta" }, [
        el("span", { text: o.agency_code }),
        el("span", { text: days === null ? "No deadline stated" : fmtDate(o.close_day) + " (" + days + " days)" }),
        el("span", { text: o.award_estimate_usd == null ? "Award not stated" : o.award_basis === "total_over_awards" ? "About " + usd(o.award_estimate_usd) + " (est.)" : "Up to " + usd(o.award_estimate_usd) }),
        o.domain ? el("span", { text: DOMAIN[o.domain] }) : null,
        o.status === "forecasted" ? el("span", { class: "badge", text: "Forecast" }) : null,
        statusBadge(o)
      ]),
      item.impact && item.impact.score !== null ? el("div", { class: "meta", title: "Impact score: used only to order this pile" }, [
        el("span", { class: "impact-pill" }, [el("span", { class: "impact-bar" }, [el("span", { style: "width:" + Math.max(4, Math.min(100, item.impact.score)) + "%" })]), "Impact " + item.impact.score]),
        el("span", { text: item.impact.top.length ? "led by " + item.impact.top.map(function (k) { return IMPACT_SHORT[k]; }).join(" and ") : "" })
      ]) : null,
      el("div", { class: "reason", text: item.tier_reason })
    ]);
    return c;
  }

  function renderPiles(res) {
    var root = $("piles"); root.innerHTML = "";
    [1, 2, 3, 4].forEach(function (k) {
      if (k === 4 && !S.show_screened) return;
      var t = TIERS[k], items = res.piles[k];
      var body = el("div", { class: "pile-body" });
      if (!items.length) body.appendChild(el("div", { class: "pile-empty", text: "Nothing lands here with the current settings." }));
      items.forEach(function (it) { body.appendChild(card(it)); });
      root.appendChild(el("div", { class: "pile" + (k === 4 ? " pile-wide" : ""), style: "--tier-color:" + t.color }, [
        el("div", { class: "pile-head" }, [
          el("div", { class: "title" }, [el("h2", {}, [el("span", { class: "tier-mark t" + k }), "Tier " + k + ": " + t.name]), el("span", { class: "count", text: String(items.length) })]),
          el("div", { class: "meaning", text: t.meaning })
        ]),
        body
      ]));
    });

    // Summary: one tile per pile, then a single line accounting for everything else.
    $("summary").innerHTML = "";
    var tiles = el("div", { class: "stat-tiles" });
    [[1, "Writer can act", res.counts.tier1], [2, "Needs supervisor", res.counts.tier2],
     [3, "Needs secretary or legislature", res.counts.tier3]].concat(S.show_screened ? [[4, "Partner-led research", res.counts.tier4]] : [])
      .forEach(function (x) {
        tiles.appendChild(el("div", { class: "stat", style: "--tier-color:" + TIERS[x[0]].color }, [
          el("div", { class: "stat-label" }, [el("span", { class: "tier-mark t" + x[0] }), "Tier " + x[0]]),
          el("div", { class: "stat-num", text: String(x[2]) }),
          el("div", { class: "stat-sub", text: x[1] })
        ]));
      });
    $("summary").appendChild(tiles);
    var rest = [["Doesn't fit this cycle", res.counts.not_this_cycle],
      [S.show_screened ? "Restricted (information only)" : "Screened as research or restricted", res.counts.screened],
      ["Outside your scope", res.counts.out_of_scope]];
    $("summary").appendChild(el("div", { class: "stat-rest" }, rest.map(function (x) {
      return el("span", {}, [x[0] + " ", el("strong", { text: x[1].toLocaleString() })]);
    }).concat([el("span", { class: "muted" }, ["= all ", el("strong", { text: res.counts.total.toLocaleString() }), " opportunities in the file are accounted for"])])));

    drawer("drawer-cycle", "Doesn't fit this cycle", res.drawers.not_this_cycle,
      "Relevant to " + S.agency + " but the deadline or award size fails your settings.");
    drawer("drawer-screened", "Screened out as research or restricted", res.drawers.screened, screenedNote());
    drawer("drawer-scope", "Outside your scope", res.drawers.out_of_scope, scopeNote(res.drawers.out_of_scope));
  }
  function scopeNote(items) {
    var by = {};
    items.forEach(function (x) { by[x.why] = (by[x.why] || 0) + 1; });
    return "Everything the tool is not showing in a pile, with the reason. " +
      Object.keys(by).sort(function (a, b) { return by[b] - by[a]; }).map(function (k) { return k + ": " + by[k].toLocaleString(); }).join(" · ");
  }

  function drawer(id, label, items, note) {
    var d = $(id);
    d.querySelector("summary").textContent = label + " (" + items.length + ")";
    var searchId = { "drawer-screened": "screened-search", "drawer-scope": "scope-search" }[id];
    var list = searchId ? $(searchId.replace("search", "rows")) : d.querySelector(".list");
    list.innerHTML = "";
    if (searchId) {
      var q = ($(searchId).value || "").toLowerCase();
      if (q) items = items.filter(function (x) { return (x.opp.title + " " + x.opp.agency_code + " " + x.why).toLowerCase().indexOf(q) >= 0; });
      if (id === "drawer-scope") {
        var shown = items.slice(0, 200);
        if (items.length > shown.length) list.appendChild(el("div", { class: "small muted", text: "Showing the first 200 of " + items.length.toLocaleString() + "; search to narrow." }));
        items = shown;
      }
    }
    list.appendChild(el("div", { class: "small muted", text: note, style: "margin-bottom:6px" }));
    var rescue = CFG.rescue_pct;
    items.slice().sort(function (a, b) { return al(b.opp) - al(a.opp); }).forEach(function (x) {
      var hi = id === "drawer-screened" && al(x.opp) >= rescue;
      list.appendChild(el("div", { class: "drow", onclick: function () { openDetail(x.opp); } }, [
        el("div", {}, [el("span", { class: "dt", text: x.opp.title }), hi ? el("span", { class: "flag", title: "Plan alignment in the top " + Math.round((1 - rescue) * 100) + "%", text: "check this" }) : null,
          el("div", { class: "why", text: x.why + (id === "drawer-screened" ? planMatch(x.opp) : "") })]),
        el("div", { class: "small muted", text: x.opp.agency_code })
      ]));
    });
  }
  function planMatch(o) {
    var a = o.alignment && o.alignment[S.agency];
    if (!a) return "";
    var row = a.llm_level && a.llm_level !== "none" ? a.llm_row : a.embed_best_id;
    if (!row || row === "none") return "";
    return " \u00b7 closest plan row " + row + (a.pct != null ? " (" + ordinal(Math.round(a.pct * 100)) + " percentile)" : "");
  }
  $("scope-search").addEventListener("input", function () { if (lastRun) drawer("drawer-scope", "Outside your scope", lastRun.drawers.out_of_scope, scopeNote(lastRun.drawers.out_of_scope)); });
  $("screened-search").addEventListener("input", function () { if (lastRun) drawer("drawer-screened", "Screened out as research or restricted", lastRun.drawers.screened, screenedNote()); });
  function screenedNote() {
    return S.show_screened
      ? "Restricted competitions only (named or invited applicants). Research awards are in Tier 4, partner-led research."
      : "NIH and research-mechanism awards need a university or research institution as the applicant. Turn on \"Include research awards\" to see them as Tier 4. Items marked \"check this\" align closely with the agency's plan.";
  }
  function al(o) { var a = o.alignment && o.alignment[S.agency]; return a && a.pct != null ? a.pct : 0; }

  // ---- Where the people served live ---------------------------------------------------------------
  var C = P.community || null;
  var RURAL_LABEL = { rural: "Rural counties", suburban: "Regional city or suburban", urban: "Urban counties" };
  function countyName(f) { return (P.county_names[f] || f) + " County"; }
  function whereTheyLive(popId) {
    var pop = P.populations[popId];
    if (!C || !pop || !pop.county) return null;
    var rows = Object.keys(pop.county).map(function (f) {
      var n = pop.county[f], tot = C.county_pop[f];
      return { fips: f, n: n, rate: tot ? n / tot : null, rurality: C.county_rurality[f] };
    });
    var total = rows.reduce(function (a, r) { return a + r.n; }, 0);
    var byR = { rural: 0, suburban: 0, urban: 0 }, cntR = { rural: 0, suburban: 0, urban: 0 };
    rows.forEach(function (r) { if (byR[r.rurality] != null) { byR[r.rurality] += r.n; cntR[r.rurality]++; } });
    var districts = pop.district ? Object.keys(pop.district).map(function (g) {
      return { id: g, name: (C.district_names || {})[g] || g, n: pop.district[g] };
    }).sort(function (a, b) { return (+a.id) - (+b.id); }) : null;
    return {
      pop: pop, total: total, rows: rows, byRurality: byR, countiesByRurality: cntR,
      topCount: rows.slice().sort(function (a, b) { return b.n - a.n; }).slice(0, 5),
      topRate: rows.filter(function (r) { return r.rate != null && popId !== "all_residents"; })
                   .sort(function (a, b) { return b.rate - a.rate; }).slice(0, 5),
      districts: districts
    };
  }
  function fmtPct(x) { return (x * 100).toFixed(x < 0.1 ? 1 : 0) + "%"; }

  function reachSection(o) {
    if (!o.target_population || o.target_population === "system_level") return null;
    var w = whereTheyLive(o.target_population);
    if (!w || !w.total) return el("section", {}, [el("h4", { text: "Who this reaches in NC" }),
      el("div", { class: "small muted", text: "No county-level count is available for this population (" + (P.populations[o.target_population] || {}).label + ")." })]);
    var seg = ["rural", "suburban", "urban"].map(function (k) {
      var share = w.byRurality[k] / w.total;
      return el("span", { class: "rur-seg rur-" + k, style: "width:" + (share * 100).toFixed(1) + "%",
        title: RURAL_LABEL[k] + ": " + fmtNum(w.byRurality[k]) + " (" + fmtPct(share) + ")" });
    });
    var legend = el("div", { class: "rur-legend" }, ["rural", "suburban", "urban"].map(function (k) {
      return el("span", {}, [el("i", { class: "rur-" + k }), RURAL_LABEL[k] + " (" + w.countiesByRurality[k] + "): ",
        el("strong", { text: fmtPct(w.byRurality[k] / w.total) }), " · " + fmtNum(w.byRurality[k])]);
    }));
    function list(title, rows, val) {
      return el("div", { class: "reach-list" }, [el("div", { class: "reach-list-h", text: title }),
        el("ol", {}, rows.map(function (r) { return el("li", {}, [countyName(r.fips) + " ", el("span", { class: "muted", text: val(r) })]); }))]);
    }
    var maxD = w.districts ? Math.max.apply(null, w.districts.map(function (d) { return d.n; })) : 0;
    return el("section", { class: "reach-section" }, [
      el("h4", { text: "Who this reaches in NC" }),
      el("div", { class: "small", text: w.pop.label + ": " + fmtNum(w.total) + " people statewide." }),
      el("div", { class: "rur-bar", role: "img", "aria-label": "Share living in rural, suburban and urban counties" }, seg),
      legend,
      el("div", { class: "reach-lists" }, [
        list("Most people", w.topCount, function (r) { return fmtNum(r.n); }),
        w.topRate.length ? list("Highest share of residents", w.topRate, function (r) { return fmtPct(r.rate); }) : null
      ]),
      w.districts ? el("details", { class: "reach-districts" }, [el("summary", { text: "By congressional district" }),
        el("table", { class: "gaps" }, w.districts.map(function (d) {
          return el("tr", {}, [el("td", { text: d.name.replace("Congressional District", "District") }),
            el("td", { class: "num", text: fmtNum(d.n) }),
            el("td", { style: "width:45%" }, [el("span", { class: "dist-bar", style: "width:" + (d.n / maxD * 100).toFixed(0) + "%" })])]);
        })),
        el("div", { class: "small muted", text: C.district_note })]) :
        el("div", { class: "small muted", text: "District counts are not published for this population." }),
      el("div", { class: "reach-actions" }, [
        el("button", { class: "btn", type: "button", text: "Show on the map", onclick: function () {
          $("map-domain").value = "pop:" + o.target_population;
          document.querySelector('[data-tab="map"]').click();
          var d = $("detail-root"); d.innerHTML = "";
          drawMap();
        } })]),
      el("div", { class: "small muted", text: C.caveat + " " + C.rurality_rule })
    ]);
  }

  // ---- Detail panel -------------------------------------------------------------------------------
  function openDetail(o) {
    var root = $("detail-root"); root.innerHTML = "";
    var pl = Tiering.placement(o, S);
    var t = Tiering.assignTier(o, S, profile());
    var gaps = Tiering.capabilityGaps(o, profile());
    var item = null;
    if (lastRun) [].concat(lastRun.piles[1], lastRun.piles[2], lastRun.piles[3], lastRun.piles[4], lastRun.drawers.not_this_cycle)
      .forEach(function (x) { if (x.opp.number === o.number) item = x; });
    var a = (o.alignment || {})[S.agency] || {};
    var rows = (P.priorities[S.agency] || {});
    var days = o.close_day == null ? null : o.close_day - S.ref_day;
    function close() { root.innerHTML = ""; document.removeEventListener("keydown", onKey); }
    function onKey(e) { if (e.key === "Escape") close(); }
    document.addEventListener("keydown", onKey);

    var CTRL = { direct: ["✓", "Agency runs it"], contracted: ["✓", "Through a contract it controls"],
                 partner: ["→", "Only through a partner"], none: ["✕", "No route"], unknown: ["?", "Not in profile"] };

    var gapTable = gaps.length ? el("table", { class: "gaps" }, [
      el("tr", {}, [el("th", { text: "Required capability" }), el("th", { text: S.agency + " control" }), el("th", { text: "What resolving it takes" })])
    ].concat(gaps.map(function (g) {
      var c = CTRL[g.control] || CTRL.unknown;
      return el("tr", {}, [el("td", { text: g.label }),
        el("td", {}, [el("span", { class: "ctrl-pill" }, [el("span", { class: "ico", text: c[0] + " " }), c[1]])]),
        el("td", { text: g.has_it ? "Nothing: in-house" : (g.to_resolve || "") })]);
    }))) : el("div", { class: "small muted", text: "No specific capabilities detected. Read the announcement before relying on this." });

    var panel = el("div", { class: "detail", role: "dialog", "aria-modal": "true", "aria-label": o.title }, [
      el("button", { class: "btn close", type: "button", text: "Close", onclick: close }),
      el("div", { class: "small secondary", text: o.number + " · " + (o.agency_name || o.agency_code) }),
      el("h2", { text: o.title }),
      pl.include
        ? el("div", {}, [el("span", { class: "tier-mark t" + t.tier, style: "--tier-color:" + TIERS[t.tier].color }), el("strong", { text: "Tier " + t.tier + ": " + TIERS[t.tier].name })])
        : el("div", {}, [el("strong", { text: "Not in the piles: " }), pl.why]),
      statusBadge(o),
      el("section", {}, [el("h4", { text: "Why this tier" }),
        el("ul", { class: "rules" }, t.fired.map(function (f) { return el("li", { text: f.text }); }))]),
      el("section", {}, [el("h4", { text: "Capability gaps" }), gapTable]),
      item && item.impact ? el("section", {}, [el("h4", { text: "Impact score: " + (item.impact.score === null ? "n/a" : item.impact.score + " of 100") }),
        el("div", { class: "small muted", text: "Orders this pile only. Each part turns an actual number into points; the points add up to the score. People reached, help per person and award size earn points by how they rank against the opportunities in view. A part with no number is left out and the others share its points." }),
        (function () {
          var parts = item.impact.parts, w = S.impact_weights, den = 0;
          Tiering.IMPACT_PARTS.forEach(function (k) { if (parts[k] !== null && (w[k] || 0) > 0) den += w[k]; });
          function actual(k) {
            var people = o.people_est, award = o.award_estimate_usd, pop = P.populations[o.target_population];
            if (k === "alignment") return a.llm_level ? "Rated " + a.llm_level + " by the labeler" : (a.pct != null ? "Text similarity, " + ordinal(Math.round(a.pct * 100)) + " percentile" : "Not rated");
            if (k === "reach") return people ? fmtNum(people) + " people" + (pop ? " (" + pop.label + ")" : "") : "No population estimate";
            if (k === "depth") return people && award ? "$" + (award / people < 10 ? (award / people).toFixed(2) : fmtNum(award / people)) + " per person" : "Needs both an award and a population";
            if (k === "award") return award ? (o.award_basis === "total_over_awards" ? "About " + usd(award) + " (estimated: total ÷ expected awards)" : "Up to " + usd(award) + " (Grants.gov ceiling)") : "No award amount, and no total or award count to estimate from";
            return (o.domain ? DOMAIN[o.domain] : "No program area") + ": weight " + (o.domain ? S.domain_weights[o.domain] : 0) + " of 3";
          }
          return el("table", { class: "gaps" }, [el("tr", {}, [el("th", { text: "Part" }), el("th", { text: "Actual number" }), el("th", { class: "num", text: "Points" })])]
            .concat(Tiering.IMPACT_PARTS.map(function (k) {
              var v = parts[k], pts = v === null || !(w[k] > 0) || !den ? null : 100 * w[k] * v / den;
              return el("tr", {}, [el("td", { text: IMPACT_LABEL[k] + (w[k] !== 1 ? " (x" + w[k] + ")" : "") }), el("td", { text: actual(k) }),
                el("td", { class: "num", text: pts === null ? "not counted" : pts.toFixed(1) })]);
            }))
            .concat([el("tr", {}, [el("td", {}, [el("strong", { text: "Impact score" })]), el("td", { text: "" }),
              el("td", { class: "num" }, [el("strong", { text: String(item.impact.score) })])])]));
        })()]) : null,
      el("section", {}, [el("h4", { text: "Key facts" }), el("dl", { class: "kv" }, [
        el("dt", { text: o.deadline_source === "grantsgov" ? (o.status === "forecasted" ? "Deadline (Grants.gov estimate)" : "Deadline (Grants.gov)") : "Deadline" }), el("dd", { text: fmtDate(o.close_day) + (days === null ? "" : " (" + days + " days from reference date)") }),
        el("dt", { text: "Award (Grants.gov)" }), el("dd", { text: o.award_estimate_usd == null ? "Not stated on Grants.gov, and no total or award count to estimate from" : o.award_basis === "total_over_awards" ? "About " + usd(o.award_estimate_usd) + " per award, estimated: Grants.gov states no ceiling, so this is total program funding ÷ expected number of awards" : "Up to " + usd(o.award_estimate_usd) + (o.award_floor_usd ? " (floor " + usd(o.award_floor_usd) + ")" : "") + (o.award_basis === "grantsgov_ceiling" ? ", award ceiling on Grants.gov" : ", award ceiling in the export") }),
        el("dt", { text: "Instrument" }), el("dd", { text: (o.instrument || "").replace(/_/g, " ") + " · burden " + o.instrument_burden }),
        el("dt", { text: "Cost share" }), el("dd", { text: o.cost_share ? "Required" + (o.match_pct ? " (" + o.match_pct + "% stated)" : " (percentage not published)") : "Not indicated" }),
        el("dt", { text: "Domain" }), el("dd", { text: o.domain ? DOMAIN[o.domain] : "Unassigned" }),
        el("dt", { text: "Likely owner" }), el("dd", { text: o.division || "Not labeled" }),
        el("dt", { text: "Serves" }), el("dd", { text: o.target_population ? P.populations[o.target_population].label + (o.people_est ? " (~" + fmtNum(o.people_est) + " in NC)" : "") : "Not labeled" }),
        el("dt", { text: "Full announcement" }), el("dd", { text: o.has_full_announcement ? "Read by the labeler" : "Not available; abstract only" })
      ])]),
      reachSection(o),
      o.match_evidence && o.match_evidence !== "none" ? el("section", {}, [el("h4", { text: "Match evidence (quoted)" }), el("blockquote", { text: o.match_evidence })]) : null,
      el("section", {}, [el("h4", { text: "Alignment with the " + S.agency + " strategic plan" }),
        a.llm_level ? el("div", {}, [el("strong", { text: "Labeler: " + a.llm_level }),
          a.llm_row && a.llm_row !== "none" ? el("div", { class: "small", text: a.llm_row + ": " + (rows[a.llm_row] || "") }) : null,
          a.llm_why ? el("blockquote", { text: a.llm_why }) : null]) : null,
        a.embed_best_id ? el("div", { class: "small secondary", text: "Closest plan row by text similarity: " + a.embed_best_id + " (" + ordinal(Math.round(a.pct * 100)) + " percentile). " + (rows[a.embed_best_id] || "") }) : null
      ]),
      el("section", {}, [el("h4", { text: "Abstract" }), el("p", { class: "small", text: o.summary_snippet + (o.summary_snippet && o.summary_snippet.length >= 700 ? "…" : "") }),
        o.url ? el("a", { href: o.url, target: "_blank", rel: "noopener", text: "Open on Grants.gov" }) : null]),
      el("section", {}, [el("h4", { text: "Where these facts came from" }),
        el("div", { class: "small muted", text: "Cost share: " + o.provenance.cost_share + " · Requirements: " + o.provenance.requirements }) ])
    ]);
    root.appendChild(el("div", { class: "detail-backdrop", onclick: close }));
    root.appendChild(panel);
    panel.querySelector(".close").focus();
  }

  // ---- Map --------------------------------------------------------------------------------------------
  var map = null, choro = null, overlay = null;
  var SEQ = ["--seq-100", "--seq-200", "--seq-300", "--seq-400", "--seq-500", "--seq-600", "--seq-700"];
  function cssVar(n) { return getComputedStyle(document.documentElement).getPropertyValue(n).trim(); }

  var needGroup = el("optgroup", { label: "Need by program area" });
  P.domains.forEach(function (d) { needGroup.appendChild(el("option", { value: d.id, text: d.label })); });
  $("map-domain").appendChild(needGroup);
  if (C) {
    var popGroup = el("optgroup", { label: "Where the people served live" });
    Object.keys(P.populations).forEach(function (k) {
      if (P.populations[k].county) popGroup.appendChild(el("option", { value: "pop:" + k, text: P.populations[k].label }));
    });
    $("map-domain").appendChild(popGroup);
  }
  var BOUNDARY_LABEL = { county: "Counties", congressional_district: "Congressional districts", tract: "Census tracts", place: "Census places (cities and towns)" };
  Object.keys(P.geo).forEach(function (g) { $("map-boundary").appendChild(el("option", { value: g, text: BOUNDARY_LABEL[g] || g })); });
  $("map-domain").addEventListener("change", drawMap);
  $("map-boundary").addEventListener("change", drawMap);

  function drawMap() {
    if (typeof L === "undefined") { $("map").textContent = "Map library unavailable."; return; }
    if (!map) {
      map = L.map("map", { minZoom: 6, maxZoom: 12, zoomSnap: 0.25 });
      // Base tiles are optional: if offline they fail silently and the data layers still draw.
      L.tileLayer("https://{s}.basemap.cartocdn.com/light_all/{z}/{x}/{y}{r}.png", {
        attribution: "&copy; OpenStreetMap &copy; CARTO", subdomains: "abcd", maxZoom: 12
      }).addTo(map);
    }
    var dom = $("map-domain").value;
    if (choro) map.removeLayer(choro);
    if (overlay) map.removeLayer(overlay);
    var cols = SEQ.map(cssVar);
    var isPop = dom.indexOf("pop:") === 0;
    $("map-callout").innerHTML = isPop
      ? "<strong>Where the people served live:</strong> each county is shaded by the share of its residents in this population (darker = higher share among NC counties). Open an opportunity and choose \u201cShow on the map\u201d to see the population it serves. This shows where people live, not where any grant would be spent."
      : "<strong>What this map shows:</strong> relative need for a <em>program domain</em> across NC counties, not where any grant would be spent. Nearly every opportunity here is statewide, so an opportunity inherits its domain's map. Color is the county's average percentile rank across the indicators listed below.";
    if (isPop) { drawPopulationMap(dom.slice(4), cols); return; }
    var need = P.domain_need[dom];
    function color(v) { if (v == null) return cssVar("--surface-0"); return cols[Math.min(cols.length - 1, Math.floor(v * cols.length))]; }
    choro = L.geoJSON(P.geo.county, {
      style: function (f) { var v = need.index[f.properties.fips]; return { fillColor: color(v), fillOpacity: 0.85, color: cssVar("--surface-1"), weight: 1 }; },
      onEachFeature: function (f, layer) {
        var fips = f.properties.fips, v = need.index[fips];
        var lines = need.indicators.map(function (ind) {
          var val = need.values[ind.id][fips];
          return esc(ind.label) + ": " + (val == null ? "n/a" : (Math.abs(val) < 1 && ind.id.indexOf("_rate") > 0 || ind.id.indexOf("_share") > 0 ? (val * 100).toFixed(1) + "%" : (+val).toLocaleString()));
        });
        layer.bindTooltip("<strong>" + esc(P.county_names[fips] || f.properties.name) + " County</strong><br>Need index: " +
          (v == null ? "n/a" : ordinal(Math.round(v * 100)) + " percentile") + "<br><span style='font-size:11px'>" + lines.join("<br>") + "</span>", { sticky: true });
      }
    }).addTo(map);
    var b = $("map-boundary").value;
    if (b !== "county" && P.geo[b]) {
      overlay = L.geoJSON(P.geo[b], { style: { fill: false, color: cssVar("--text-primary"), weight: b === "tract" ? 0.4 : 1.2, opacity: 0.7 }, interactive: false }).addTo(map);
    }
    map.fitBounds(choro.getBounds(), { padding: [10, 10] });
    var lg = $("map-legend"); lg.innerHTML = "";
    lg.appendChild(el("span", { class: "lab", text: "Lower need" }));
    cols.forEach(function (c) { lg.appendChild(el("span", { class: "sw", style: "background:" + c })); });
    lg.appendChild(el("span", { class: "lab", text: "Higher need (percentile rank among NC counties)" }));
    $("map-indicators").innerHTML = "<strong>Indicators averaged:</strong> " + need.indicators.map(function (i) { return esc(i.label); }).join("; ") +
      (need.missing_indicators && need.missing_indicators.length ? ". <em>Not available:</em> " + need.missing_indicators.join(", ") : "") +
      ". Boundary overlays other than counties are outlines only; the underlying data are county-level.";
  }

  // Population layer: county color = share of residents in the population (percentile rank
  // among counties), tooltip = count, share and rurality; district outlines carry district counts.
  function drawPopulationMap(popId, cols) {
    var w = whereTheyLive(popId);
    var rates = w.rows.filter(function (r) { return r.rate != null; }).map(function (r) { return r.rate; }).sort(function (a, b) { return a - b; });
    function pct(v) { if (v == null) return null; var i = 0; while (i < rates.length && rates[i] < v) i++; return rates.length > 1 ? i / (rates.length - 1) : 0.5; }
    var byF = {}; w.rows.forEach(function (r) { byF[r.fips] = r; });
    function color(v) { if (v == null) return cssVar("--surface-0"); return cols[Math.min(cols.length - 1, Math.floor(v * cols.length))]; }
    var share = popId === "all_residents";
    choro = L.geoJSON(P.geo.county, {
      style: function (f) { var r = byF[f.properties.fips]; var v = r ? (share ? pct(r.n) : pct(r.rate)) : null;
        return { fillColor: color(v), fillOpacity: 0.85, color: cssVar("--surface-1"), weight: 1 }; },
      onEachFeature: function (f, layer) {
        var r = byF[f.properties.fips];
        layer.bindTooltip("<strong>" + esc(countyName(f.properties.fips)) + "</strong><br>" + esc(w.pop.label) + ": " +
          (r ? fmtNum(r.n) + (r.rate != null && !share ? " (" + fmtPct(r.rate) + " of residents)" : "") : "n/a") +
          "<br>" + esc(RURAL_LABEL[C.county_rurality[f.properties.fips]] || ""), { sticky: true });
      }
    }).addTo(map);
    var b = $("map-boundary").value;
    if (b !== "county" && P.geo[b]) {
      var dist = b === "congressional_district" && w.pop.district;
      overlay = L.geoJSON(P.geo[b], {
        style: { fill: !!dist, fillOpacity: 0, color: cssVar("--text-primary"), weight: b === "tract" ? 0.4 : 1.6, opacity: 0.8 },
        interactive: !!dist,
        onEachFeature: dist ? function (f, layer) {
          var g = Object.keys(w.pop.district).filter(function (k) { return f.properties.name && f.properties.name.replace(/\D/g, "") === String(+k.slice(2)); })[0];
          layer.bindTooltip("<strong>" + esc(f.properties.name) + "</strong><br>" + esc(w.pop.label) + ": " + (g ? fmtNum(w.pop.district[g]) : "n/a"), { sticky: true });
        } : null
      }).addTo(map);
    }
    map.fitBounds(choro.getBounds(), { padding: [10, 10] });
    var lg = $("map-legend"); lg.innerHTML = "";
    lg.appendChild(el("span", { class: "lab", text: share ? "Fewer people" : "Lower share" }));
    cols.forEach(function (c) { lg.appendChild(el("span", { class: "sw", style: "background:" + c })); });
    lg.appendChild(el("span", { class: "lab", text: share ? "More people (rank among NC counties)" : "Higher share of residents (rank among NC counties)" }));
    var ru = ["rural", "suburban", "urban"].map(function (k) { return RURAL_LABEL[k].toLowerCase() + " " + fmtPct(w.byRurality[k] / w.total); }).join(", ");
    $("map-indicators").innerHTML = "<strong>" + esc(w.pop.label) + ":</strong> " + fmtNum(w.total) + " people in NC (" + ru + "). Source: " +
      esc(w.pop.source || "") + ". " + esc(C.caveat) + (b === "congressional_district" ? " " + esc(w.pop.district ? C.district_note + " Hover a district outline for its count." : "District counts are not published for this population.") : " Choose the congressional-district overlay to see counts by district.");
  }

  // ---- Reach vs intensity scatter ---------------------------------------------------------------------
  function drawReach(res) {
    // Piled opportunities are drawn by tier; relevant ones that fail the current runway or
    // award settings are drawn as hollow grey markers so the whole field stays visible.
    var items = [].concat(res.piles[1], res.piles[2], res.piles[3], res.piles[4],
      res.drawers.not_this_cycle.map(function (d) { return { opp: d.opp, tier: 0, why: d.why }; }));
    var plotted = [], systemLevel = [], unlabeled = [], noCount = [], noAward = [];
    items.forEach(function (it) {
      var o = it.opp;
      if (!o.target_population) unlabeled.push(it);
      else if (o.target_population === "system_level") systemLevel.push(it);
      else if (!o.people_est) noCount.push(it);
      else if (!o.award_estimate_usd) noAward.push(it);
      else plotted.push({ it: it, x: o.people_est, y: o.award_estimate_usd / o.people_est });
    });
    var svg = $("reach-svg"), W = 860, H = 440, m = { l: 70, r: 20, t: 16, b: 50 };
    svg.setAttribute("viewBox", "0 0 " + W + " " + H);
    svg.innerHTML = "";
    var ns = "http://www.w3.org/2000/svg";
    function s(tag, attrs, parent) { var e = document.createElementNS(ns, tag); Object.keys(attrs).forEach(function (k) { e.setAttribute(k, attrs[k]); }); (parent || svg).appendChild(e); return e; }
    function logTicks(lo, hi) { var t = []; for (var p = Math.floor(Math.log10(lo)); p <= Math.ceil(Math.log10(hi)); p++) t.push(Math.pow(10, p)); return t; }
    var xs = plotted.map(function (d) { return d.x; }), ys = plotted.map(function (d) { return d.y; });
    var xlo = xs.length ? Math.min.apply(null, xs) : 1e3, xhi = xs.length ? Math.max.apply(null, xs) : 1e7;
    var ylo = ys.length ? Math.min.apply(null, ys) : 0.01, yhi = ys.length ? Math.max.apply(null, ys) : 100;
    xlo = Math.pow(10, Math.floor(Math.log10(xlo))); xhi = Math.pow(10, Math.ceil(Math.log10(xhi)));
    ylo = Math.pow(10, Math.floor(Math.log10(ylo))); yhi = Math.pow(10, Math.ceil(Math.log10(yhi)));
    if (xlo === xhi) xhi *= 10; if (ylo === yhi) yhi *= 10;
    function X(v) { return m.l + (Math.log10(v) - Math.log10(xlo)) / (Math.log10(xhi) - Math.log10(xlo)) * (W - m.l - m.r); }
    function Y(v) { return H - m.b - (Math.log10(v) - Math.log10(ylo)) / (Math.log10(yhi) - Math.log10(ylo)) * (H - m.t - m.b); }
    var grid = s("g", { class: "grid" }), ax = s("g", { class: "axis" });
    logTicks(xlo, xhi).forEach(function (v) {
      s("line", { x1: X(v), x2: X(v), y1: m.t, y2: H - m.b }, grid);
      var tx = s("text", { x: X(v), y: H - m.b + 20, "text-anchor": "middle" }, ax); tx.textContent = v >= 1e6 ? v / 1e6 + "M" : v >= 1e3 ? v / 1e3 + "K" : v;
    });
    logTicks(ylo, yhi).forEach(function (v) {
      s("line", { x1: m.l, x2: W - m.r, y1: Y(v), y2: Y(v) }, grid);
      var ty = s("text", { x: m.l - 8, y: Y(v), "text-anchor": "end", "dominant-baseline": "middle" }, ax);
      ty.textContent = "$" + (v >= 1e3 ? v / 1e3 + "K" : v >= 1 ? v : v >= 0.01 ? v.toFixed(2) : String(+v.toPrecision(1)));
    });
    s("line", { x1: m.l, x2: W - m.r, y1: H - m.b, y2: H - m.b }, ax);
    s("line", { x1: m.l, x2: m.l, y1: m.t, y2: H - m.b }, ax);
    var xt = s("text", { x: (m.l + W - m.r) / 2, y: H - 10, "text-anchor": "middle", class: "axis-title" }); xt.textContent = "People in the population served, NC (log scale, estimate)";
    var yt = s("text", { x: -(m.t + H - m.b) / 2, y: 16, transform: "rotate(-90)", "text-anchor": "middle", class: "axis-title" }); yt.textContent = "Estimated dollars per person (log scale)";
    var tip = $("reach-tip");
    plotted.forEach(function (d) {
      var k = d.it.tier, cx = X(d.x), cy = Y(d.y), col = k ? TIERS[k].color : cssVar("--text-muted"), g;
      if (k === 0) g = s("circle", { cx: cx, cy: cy, r: 5, fill: "none", "stroke-dasharray": "2 2" });
      else if (k === 1) g = s("circle", { cx: cx, cy: cy, r: 6, fill: col });
      else if (k === 2) g = s("rect", { x: cx - 5.5, y: cy - 5.5, width: 11, height: 11, rx: 2, fill: col });
      else if (k === 3) g = s("path", { d: "M" + cx + "," + (cy - 7) + " L" + (cx + 7) + "," + (cy + 5) + " L" + (cx - 7) + "," + (cy + 5) + " Z", fill: col });
      else g = s("path", { d: "M" + cx + "," + (cy - 6) + " L" + (cx + 6) + "," + cy + " L" + cx + "," + (cy + 6) + " L" + (cx - 6) + "," + cy + " Z", fill: col });
      g.setAttribute("stroke", k ? cssVar("--surface-1") : col); g.setAttribute("stroke-width", k ? 2 : 1.5); g.style.cursor = "pointer";
      var hit = s("circle", { cx: cx, cy: cy, r: 12, fill: "transparent" }); hit.style.cursor = "pointer";
      function show(e) {
        var o = d.it.opp, r = $("reach-wrap").getBoundingClientRect();
        tip.innerHTML = "<strong>" + esc(o.title) + "</strong><br>" + (k ? "Tier " + k : "Doesn't fit your settings: " + esc(d.it.why)) + " · " + esc(P.populations[o.target_population].label) +
          "<br>~" + fmtNum(d.x) + " people · ~" + usd(o.award_estimate_usd) + " award<br>≈ $" + (d.y < 1 ? d.y.toFixed(2) : fmtNum(d.y)) + " per person";
        tip.classList.remove("hidden");
        tip.style.left = Math.min(e.clientX - r.left + 12, r.width - 310) + "px"; tip.style.top = (e.clientY - r.top + 12) + "px";
      }
      [g, hit].forEach(function (n) {
        n.addEventListener("mousemove", show); n.addEventListener("mouseleave", function () { tip.classList.add("hidden"); });
        n.addEventListener("click", function () { openDetail(d.it.opp); });
      });
    });
    var lg = $("reach-legend"); lg.innerHTML = "";
    [1, 2, 3, 4].forEach(function (k) { if (k === 4 && !S.show_screened) return; lg.appendChild(el("span", {}, [el("span", { class: "tier-mark t" + k, style: "--tier-color:" + TIERS[k].color }), "Tier " + k + ": " + TIERS[k].name])); });
    lg.appendChild(el("span", {}, [el("span", { class: "tier-mark t1", style: "--tier-color:transparent;border:1.5px dashed var(--text-muted);box-sizing:border-box" }), "Relevant, but doesn't fit your runway or award settings"]));
    var notes = ["Plotted: " + plotted.length + " (" + plotted.filter(function (d) { return d.it.tier; }).length + " in the piles)."];
    if (systemLevel.length) notes.push("System or infrastructure grants, where a per-person figure is not meaningful: " + systemLevel.map(function (i) { return esc(i.opp.title); }).join("; ") + ".");
    if (noCount.length) notes.push("Serving a population with no NC count available (" + noCount.map(function (i) { return esc(P.populations[i.opp.target_population].label.toLowerCase()); }).filter(function (v, i, a) { return a.indexOf(v) === i; }).join(", ") + "): " + noCount.length + ".");
    if (noAward.length) notes.push("No award estimate: " + noAward.length + ".");
    if (unlabeled.length) notes.push("Not yet labeled by the model, so no population chosen: " + unlabeled.length + ".");
    $("reach-notes").innerHTML = notes.join(" ") + " Population counts: ACS 2023 5-year, CDC PLACES, HRSA, OpenFEMA; the labeler chose each opportunity's population.";
    var rows = plotted.slice().sort(function (a, b) { return b.x - a.x; }).map(function (d) {
      return "<tr><td>" + esc(d.it.opp.title) + "</td><td>" + (d.it.tier || "doesn't fit settings") + "</td><td>" + esc(P.populations[d.it.opp.target_population].label) +
        "</td><td class='num'>" + fmtNum(d.x) + "</td><td class='num'>" + usd(d.it.opp.award_estimate_usd) + "</td><td class='num'>$" + (d.y < 1 ? d.y.toFixed(2) : fmtNum(d.y)) + "</td></tr>";
    }).join("");
    $("reach-table").innerHTML = "<table class='plain'><tr><th>Opportunity</th><th>Tier</th><th>Population</th><th class='num'>People</th><th class='num'>Award</th><th class='num'>$/person</th></tr>" + rows + "</table>";
  }

  // ---- Method tab ------------------------------------------------------------------------------------
  function renderMethod() {
    var caps = P.capabilities.profiles[S.agency];
    var capRows = Object.keys(caps).map(function (id) {
      var c = caps[id];
      return "<tr><td>" + esc(c.label) + "</td><td>" + esc(c.control) + "</td><td>" + esc(c.notes) + " <a href='" + esc(c.source_url) + "' target='_blank' rel='noopener'>source</a></td></tr>";
    }).join("");
    $("method").innerHTML =
      "<h3>The three piles</h3><p>Every opportunity is compared against the agency's capability profile and your constraints. " +
      "Rules are checked in order and every rule that fires is listed on the card.</p>" +
      "<table><tr><th>Tier 3 if any of</th><td>Cost share on an award at or above " + usd(S.appropriation_usd) + "; cost share when you have no match authority; " +
      "a capital construction project; a required formal state designation; a required capability the agency has no route to.</td></tr>" +
      "<tr><th>Tier 2 if any of</th><td>A required capability reached only through a partner; cost share needing supervisor approval; " +
      "funding and monitoring subrecipients; a cooperative agreement with a required evaluation; more staff time than you have.</td></tr>" +
      "<tr><th>Tier 4</th><td>Research awards (and programs a state agency is unlikely to lead), when included: a university, research institution or other partner would be the applicant, so the agency takes part as a partner. Other rules that fire are still listed.</td></tr>" +
      "<tr><th>Tier 1</th><td>None of the above.</td></tr></table>" +
      "<p>Before tiering, opportunities are set aside if they are not relevant to the agency, are forecasts (unless included), have closed, are NIH or research " +
      "mechanisms (unless included), are restricted to named applicants, have less runway than you need, or have an estimated award below your minimum.</p>" +
      "<h3>Ranking within a pile</h3><p>The piles answer whose signature you need. Within each pile, the impact score orders opportunities by what you say matters: fit with the strategic plan (the labeler's strong / partial / none), people reached, help per person, award size, and your program priorities. " +
      "Reach, per-person help and award are ranked against the opportunities currently in view. The score never moves an opportunity between piles, and every card shows which parts led its score.</p>" +
      "<h3>Describe your situation</h3><p>The text box understands runway (\u201cone month\u201d), match authority (\u201cno matching funds\u201d, \u201csupervisor approves match\u201d), staff (\u201chalf an FTE\u201d), minimum award (\u201cat least $500k\u201d), program areas (\u201crural behavioral health\u201d), what matters most (\u201creach the most people\u201d, \u201chelp per person\u201d, \u201cbiggest grants\u201d) and order (\u201cclosing soon\u201d). " +
      "Every setting it changes appears as a chip you can undo; nothing is changed silently. The example buttons under the box apply ready-made scenarios, and \u201cLarger text\u201d enlarges the page for a projector.</p>" +
      "<h3>Who an opportunity reaches</h3><p>Open any opportunity to see where the people it serves live: the counties with the most of them and with the highest share of residents, the split between rural, suburban and urban counties, and counts by congressional district. \u201cShow on the map\u201d draws the same population on the Need map. " +
      (P.community ? esc(P.community.rurality_rule) + " " + esc(P.community.district_note) + " " : "") +
      "This shows where people live, not where a statewide award would be spent, and it is only as good as the population the labeler chose.</p>" +
      "<h3>" + esc(S.agency) + " capability profile</h3><table><tr><th>Capability</th><th>Control</th><th>Basis</th></tr>" + capRows + "</table>" +
      "<h3>Where the numbers come from</h3><ul>" +
      "<li>Opportunities: Grants.gov export pulled " + esc(P.meta.pull_date) + "; status re-checked against the Grants.gov API.</li>" +
      "<li>Award = the award ceiling the opportunity states on Grants.gov (its current synopsis or forecast). Where Grants.gov states no ceiling, the award is estimated as total program funding \u00f7 expected number of awards and marked \u201cest.\u201d. The national total is never shown as money NC could receive. Deadlines are Grants.gov\u2019s current application deadlines (estimated, for forecasts).</li>" +
      "<li>Requirements, domain, population, and plan alignment: labeled by a local model (" + esc(P.meta.llm_model) + ", prompt " + esc(P.meta.llm_prompt_version) +
      ") from the abstract and, where available, the full announcement. Validated against 60 hand labels in the project notebook.</li>" +
      "<li>Match percentage is published in structured form almost nowhere; where the tool shows one, it was found in the text.</li>" +
      "<li>County and district counts: ACS 2019-2023 5-year estimates (Census API); CDC PLACES for adults in frequent mental distress; HRSA primary care shortage designations (multi-county designations split evenly); OpenFEMA declarations for hazard exposure. County need maps also use NCHS drug poisoning death rates.</li></ul>" +
      "<div class=\"about-project\"><strong>NC Grants Explorer</strong>, Solve-A-Thon 2026, by Kent Lee, Everett Foo, Marco Gullotto, Matthew Martin and Noah Goldblatt. " +
      "<a href=\"https://kapollol.github.io/SolveAThon_2026/\" target=\"_blank\" rel=\"noopener\">Project website</a> · " +
      "<a href=\"https://kapollol.github.io/SolveAThon_2026/notebook.html\" target=\"_blank\" rel=\"noopener\">Full notebook: data, method and checks</a> · " +
      "<a href=\"https://github.com/KApolloL/SolveAThon_2026\" target=\"_blank\" rel=\"noopener\">Source code</a></div>";
  }

  // ---- Export the current view -------------------------------------------------------------
  function csvCell(v) {
    if (v === null || v === undefined) return "";
    v = String(v);
    return /[",\n]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v;
  }
  $("export-csv").addEventListener("click", function () {
    if (!lastRun) return;
    var head = ["agency", "tier", "tier_name", "rank_in_tier", "impact_score", "opportunity_number", "title",
                "issuing_agency", "status", "deadline", "days_to_deadline", "estimated_award_usd", "domain",
                "cost_share", "tier_reason", "grants_gov_link"];
    var lines = [head.join(",")];
    [1, 2, 3, 4].forEach(function (k) {
      if (k === 4 && !S.show_screened) return;
      lastRun.piles[k].forEach(function (it, i) {
        var o = it.opp;
        lines.push([S.agency, k, TIERS[k].name, i + 1, it.impact ? it.impact.score : "", o.number, o.title, o.agency_code,
                    o.status, o.close_day == null ? "" : dayToISO(o.close_day), it.days_left, o.award_estimate_usd == null ? "" : Math.round(o.award_estimate_usd),
                    o.domain ? DOMAIN[o.domain] : "", o.cost_share ? "required" : "no", it.tier_reason, o.url].map(csvCell).join(","));
      });
    });
    var settingsLine = "# Settings: agency " + S.agency + "; reference date " + dayToISO(S.ref_day) + "; runway " + S.runway_days +
      " days; match " + S.match_authority + "; staff " + S.staff_fte + " FTE; minimum award " + S.min_award_usd +
      "; forecasts " + (S.include_forecasts ? "included" : "hidden") + "; research " + (S.show_screened ? "included" : "hidden");
    var blob = new Blob(["\ufeff" + settingsLine + "\n" + lines.join("\n")], { type: "text/csv;charset=utf-8" });
    var a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "grant-triage-" + S.agency.toLowerCase() + "-" + dayToISO(S.ref_day) + ".csv";
    document.body.appendChild(a); a.click(); a.remove();
    setTimeout(function () { URL.revokeObjectURL(a.href); }, 1000);
  });

  // ---- Tabs & update loop ---------------------------------------------------------------------------------
  var tab = "piles";
  Array.prototype.forEach.call(document.querySelectorAll(".tabs button"), function (b) {
    b.addEventListener("click", function () {
      tab = b.getAttribute("data-tab");
      Array.prototype.forEach.call(document.querySelectorAll(".tabs button"), function (x) {
        x.classList.toggle("on", x === b); x.setAttribute("aria-selected", x === b ? "true" : "false");
      });
      ["piles", "map", "reach", "method"].forEach(function (t) { $("tab-" + t).classList.toggle("hidden", t !== tab); });
      if (tab === "map") { drawMap(); if (map) setTimeout(function () { map.invalidateSize(); }, 50); }
      if (tab === "reach") drawReach(lastRun);
      if (tab === "method") renderMethod();
    });
  });

  function update() {
    syncControls();
    renderChips();
    lastRun = Tiering.run(P, S);
    renderPiles(lastRun);
    if (tab === "reach") drawReach(lastRun);
    if (tab === "method") renderMethod();
  }

  update();
  // Exposed for automated checks and for the notebook embed; nothing depends on it.
  window.__triage = { settings: function () { return clone(S); }, counts: function () { return lastRun.counts; } };
})();
