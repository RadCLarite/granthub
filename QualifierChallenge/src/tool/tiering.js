/* tiering.js — the only place authority tiers are computed.
 *
 * Pure functions: no DOM, no globals read, no dates from the clock. Runs in the
 * browser (window.Tiering) and in R through V8 (globalThis.Tiering), so the
 * notebook's static tables come from this exact code.
 *
 * Inputs
 *   opp       one element of payload.opportunities
 *   s         current settings: { ref_day, runway_days, match_authority, staff_fte,
 *             min_award_usd, include_forecasts, show_screened, agency,
 *             domain_weights, appropriation_usd, fte_by_burden }
 *   profile   payload.capabilities.profiles[s.agency]: { capability_id: {control, label, to_resolve} }
 *
 * Dates are integer days since 1970-01-01, so no timezone can shift a deadline.
 */
(function (root) {
  "use strict";

  function usd(x) {
    if (x === null || x === undefined) return "unknown";
    if (x >= 1e6) return "$" + (x / 1e6).toFixed(x >= 1e7 ? 0 : 1) + "M";
    if (x >= 1e3) return "$" + Math.round(x / 1e3) + "K";
    return "$" + Math.round(x);
  }

  function asArray(x) {
    if (x === null || x === undefined) return [];
    return Array.isArray(x) ? x : [x];
  }

  // Deadline used for runway: posted close date, or forecasted close for forecasts.
  function closeDay(opp) {
    return opp.close_day !== null && opp.close_day !== undefined ? opp.close_day : null;
  }

  // ---- Step 1: where does the opportunity go? ------------------------------------
  // Every opportunity lands somewhere, so the counts always add up to the whole file.
  // Returns { include: bool, drawer: null | "out_of_scope" | "screened" | "not_this_cycle", why }
  function placement(opp, s) {
    if (opp.state_eligible === false) {
      return { include: false, drawer: "out_of_scope", why: "State governments are not listed as eligible" };
    }
    if (asArray(opp.audience).indexOf(s.agency) < 0) {
      return { include: false, drawer: "out_of_scope", why: "Not relevant to " + s.agency };
    }
    if (opp.status === "forecasted" && !s.include_forecasts) {
      return { include: false, drawer: "out_of_scope", why: "Forecast (forecasts are hidden)" };
    }
    var cd = closeDay(opp);
    if (cd !== null && cd < s.ref_day) {
      return { include: false, drawer: "out_of_scope", why: "Closed before the reference date" };
    }
    var scr = opp.screen || {};
    // Restricted competitions name their applicants; no signature changes that, so they
    // stay in the informational list even when research awards are shown.
    if (scr.is_restricted) {
      return { include: false, drawer: "screened", why: "Restricted competition (named or invited applicants only)" };
    }
    if ((scr.is_nih || scr.is_research_mechanism || scr.not_administrable) && !s.show_screened) {
      var why = scr.is_nih ? "NIH research opportunity"
        : scr.is_research_mechanism ? "Research mechanism (e.g. R01, clinical trial)"
        : "Labeler: a state agency is unlikely to be the lead applicant";
      return { include: false, drawer: "screened", why: why };
    }
    if (cd !== null && cd - s.ref_day < s.runway_days) {
      return { include: false, drawer: "not_this_cycle",
               why: (cd - s.ref_day) + " days to deadline; you need " + s.runway_days };
    }
    if (opp.award_estimate_usd !== null && opp.award_estimate_usd !== undefined &&
        opp.award_estimate_usd < s.min_award_usd) {
      return { include: false, drawer: "not_this_cycle",
               why: "Award about " + usd(opp.award_estimate_usd) + ", below your " + usd(s.min_award_usd) + " minimum" };
    }
    return { include: true, drawer: null, why: "" };
  }

  // ---- Step 2: authority tier from explicit rules -------------------------------
  // Every rule is evaluated; tier_reason lists all that fired, not just the first.
  function assignTier(opp, s, profile) {
    var t3 = [], t2 = [];
    var caps = asArray(opp.required_capabilities);
    var award = opp.award_estimate_usd;

    // Tier 3 rules
    if (opp.cost_share && award !== null && award !== undefined && award >= s.appropriation_usd) {
      t3.push({ rule: "T3_match_appropriation",
                text: "Cost share on a ~" + usd(award) + " award likely needs a state appropriation (line set at " + usd(s.appropriation_usd) + ")" });
    }
    if (opp.cost_share && s.match_authority === "no") {
      t3.push({ rule: "T3_match_no_authority",
                text: "Cost share required and no one below the secretary can commit match" });
    }
    if (opp.is_capital_project) {
      t3.push({ rule: "T3_capital", text: "Capital construction project" });
    }
    if (opp.needs_formal_designation) {
      t3.push({ rule: "T3_designation", text: "Requires a formal state designation (e.g. by the Governor)" });
    }
    caps.forEach(function (c) {
      var p = profile[c];
      if (p && p.control === "none") {
        t3.push({ rule: "T3_capability_none", capability: c,
                  text: "Needs " + p.label.toLowerCase() + ", which " + s.agency + " has no route to" });
      }
    });

    // Tier 2 rules
    caps.forEach(function (c) {
      var p = profile[c];
      if (p && p.control === "partner") {
        t2.push({ rule: "T2_capability_partner", capability: c,
                  text: "Needs " + p.label.toLowerCase() + ", which " + s.agency + " reaches only through a partner" });
      }
    });
    if (opp.cost_share && s.match_authority === "with_approval") {
      t2.push({ rule: "T2_match_approval",
                text: "Cost share required" + (opp.match_pct ? " (" + opp.match_pct + "% stated)" : " (percentage not published)") + ": supervisor must approve match" });
    }
    if (opp.subrecipient_required) {
      t2.push({ rule: "T2_subrecipients", text: "Requires funding and monitoring subrecipients" });
    }
    if (opp.instrument === "cooperative_agreement" && opp.evaluation_required) {
      t2.push({ rule: "T2_coop_evaluation", text: "Cooperative agreement with a required evaluation" });
    }
    var need = s.fte_by_burden[opp.instrument_burden];
    if (need !== undefined && s.staff_fte < need) {
      t2.push({ rule: "T2_staff", text: "Needs about " + need + " FTE to apply; you have " + s.staff_fte });
    }

    // Tier 4: someone else leads. Research awards need a university or research institution
    // as the applicant; the agency's role is partner. Other rules that fired are listed too.
    var scr = opp.screen || {};
    var t4 = null;
    if (scr.is_nih || scr.is_research_mechanism) {
      t4 = { rule: "T4_research_partner",
             text: "Research award: a university or research institution would be the applicant; " + s.agency +
                   " takes part as a partner (data, sites, letter of support)" };
    } else if (scr.not_administrable) {
      t4 = { rule: "T4_partner_lead",
             text: "A state agency is unlikely to lead this; pursue it through a partner organization" };
    }

    var tier, fired;
    if (t4) { tier = 4; fired = [t4].concat(t3, t2); }
    else if (t3.length) { tier = 3; fired = t3.concat(t2); }
    else if (t2.length) { tier = 2; fired = t2; }
    else {
      tier = 1;
      var capText = caps.length
        ? "required capabilities are in-house or contracted"
        : "no special capabilities detected in the abstract (unverified)";
      fired = [{ rule: "T1_clear",
                 text: "No escalation: " + capText + ", no cost share, about " +
                       (need === undefined ? "?" : need) + " FTE fits your staff" }];
    }
    return {
      tier: tier,
      fired: fired,
      tier_reason: fired.map(function (f) { return f.text; }).join("; ")
    };
  }

  // Capability gap detail for the click-through panel.
  function capabilityGaps(opp, profile) {
    return asArray(opp.required_capabilities).map(function (c) {
      var p = profile[c] || { control: "unknown", label: c, to_resolve: "" };
      return { capability: c, label: p.label, control: p.control,
               has_it: p.control === "direct" || p.control === "contracted",
               to_resolve: p.to_resolve || "" };
    });
  }

  // ---- Impact score: orders opportunities *within* a pile; never changes a tier. -------
  // Five parts, each on a 0-1 scale. Reach, depth and award are percentile ranks among the
  // opportunities currently in view (piles plus "doesn't fit this cycle"), so the score is
  // relative to what the writer is looking at. A part that is unknown for an opportunity is
  // left out and the remaining weights are rescaled, rather than treated as zero.
  var IMPACT_PARTS = ["alignment", "reach", "depth", "award", "priority"];
  var ALIGN_VALUE = { strong: 1, partial: 0.5, none: 0 };

  function alignmentValue(opp, agency) {
    var a = opp.alignment && opp.alignment[agency];
    if (!a) return null;
    if (a.llm_level && ALIGN_VALUE[a.llm_level] !== undefined) return ALIGN_VALUE[a.llm_level];
    return a.pct === null || a.pct === undefined ? null : a.pct;
  }

  function rawParts(opp, s) {
    var people = opp.people_est, award = opp.award_estimate_usd;
    return {
      alignment: alignmentValue(opp, s.agency),
      reach: people ? Math.log10(people) : null,
      depth: people && award ? Math.log10(award / people) : null,
      award: award ? Math.log10(award) : null,
      priority: opp.domain ? (s.domain_weights[opp.domain] || 0) / 3 : 0
    };
  }

  function percentileRanks(values) {
    var idx = [];
    values.forEach(function (v, i) { if (v !== null) idx.push(i); });
    var sorted = idx.map(function (i) { return values[i]; }).sort(function (a, b) { return a - b; });
    var out = values.map(function () { return null; });
    idx.forEach(function (i) {
      var v = values[i], lo = 0, hi = 0;
      sorted.forEach(function (x) { if (x < v) lo++; if (x <= v) hi++; });
      out[i] = sorted.length < 2 ? 1 : ((lo + hi - 1) / 2) / (sorted.length - 1);
    });
    return out;
  }

  // Adds item.impact = { score (0-100 or null), parts: {name: 0-1 or null}, top: [names] }.
  function scoreImpact(items, s) {
    var raw = items.map(function (it) { return rawParts(it.opp, s); });
    var ranked = {};
    ["reach", "depth", "award"].forEach(function (k) {
      ranked[k] = percentileRanks(raw.map(function (r) { return r[k]; }));
    });
    var w = s.impact_weights || {};
    items.forEach(function (it, i) {
      var parts = { alignment: raw[i].alignment, reach: ranked.reach[i], depth: ranked.depth[i],
                    award: ranked.award[i], priority: raw[i].priority };
      var num = 0, den = 0;
      IMPACT_PARTS.forEach(function (k) {
        if (parts[k] !== null && (w[k] || 0) > 0) { num += w[k] * parts[k]; den += w[k]; }
      });
      var top = IMPACT_PARTS.filter(function (k) { return parts[k] !== null && (w[k] || 0) > 0; })
        .sort(function (a, b) { return w[b] * parts[b] - w[a] * parts[a]; }).slice(0, 2);
      it.impact = { score: den > 0 ? Math.round(100 * num / den) : null, parts: parts, top: top };
    });
  }

  // Ordering inside a pile: by impact score (the default) or by soonest deadline.
  // Ties fall back to the other key.
  function compare(s) {
    function deadline(x) { var c = closeDay(x.opp); return c === null ? Infinity : c; }
    function imp(x) { return x.impact && x.impact.score !== null ? x.impact.score : -1; }
    return function (a, b) {
      if (s.sort_by === "deadline") return (deadline(a) - deadline(b)) || (imp(b) - imp(a));
      return (imp(b) - imp(a)) || (deadline(a) - deadline(b));
    };
  }

  function run(payload, s) {
    var profile = payload.capabilities.profiles[s.agency] || {};
    var piles = { 1: [], 2: [], 3: [], 4: [] };
    var drawers = { screened: [], not_this_cycle: [], out_of_scope: [] };
    payload.opportunities.forEach(function (opp) {
      var pl = placement(opp, s);
      if (!pl.include) {
        if (pl.drawer) drawers[pl.drawer].push({ opp: opp, why: pl.why });
        return;
      }
      var t = assignTier(opp, s, profile);
      piles[t.tier].push({ opp: opp, tier: t.tier, fired: t.fired, tier_reason: t.tier_reason,
                           days_left: closeDay(opp) === null ? null : closeDay(opp) - s.ref_day });
    });
    var inView = [].concat(piles[1], piles[2], piles[3], piles[4], drawers.not_this_cycle);
    scoreImpact(inView, s);
    var cmp = compare(s);
    [1, 2, 3, 4].forEach(function (k) { piles[k].sort(cmp); });
    drawers.not_this_cycle.sort(cmp);
    return { piles: piles, drawers: drawers,
             counts: { tier1: piles[1].length, tier2: piles[2].length, tier3: piles[3].length, tier4: piles[4].length,
                       screened: drawers.screened.length, not_this_cycle: drawers.not_this_cycle.length,
                       out_of_scope: drawers.out_of_scope.length, total: payload.opportunities.length } };
  }

  // Flat table of every opportunity's outcome, for the notebook (via V8).
  function runFlat(payload, s) {
    var profile = payload.capabilities.profiles[s.agency] || {};
    return payload.opportunities.map(function (opp) {
      var pl = placement(opp, s);
      var out = { opportunity_number: opp.number, placement: pl.include ? "pile" : (pl.drawer || "hidden"),
                  placement_why: pl.why, tier: null, tier_reason: null, rules: null };
      if (pl.include) {
        var t = assignTier(opp, s, profile);
        out.tier = t.tier; out.tier_reason = t.tier_reason;
        out.rules = t.fired.map(function (f) { return f.rule; }).join(",");
      }
      return out;
    });
  }

  root.Tiering = { placement: placement, assignTier: assignTier, capabilityGaps: capabilityGaps,
                   run: run, runFlat: runFlat, usd: usd, IMPACT_PARTS: IMPACT_PARTS, SCHEMA: "1.0.0" };
})(typeof window !== "undefined" ? window : globalThis);
