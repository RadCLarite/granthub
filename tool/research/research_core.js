/* Researcher tab core: tokenizer, synonym expansion, BM25 index and search.
   UMD style: module.exports in Node, window.ResearchCore in the browser. No dependencies. */
(function (root, factory) {
  var api = factory();
  if (typeof module === 'object' && module.exports) { module.exports = api; }
  else { root.ResearchCore = api; }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  var K1 = 1.2, B = 0.75, MAX_TERMS = 40, DEFAULT_LIMIT = 50;
  var STOP = new Set(('a an and are as at be by for from has have in into is it its of on or that the this to was were will with ' +
    'not no we our their these those can may use using used via within across between among about over under per than then also').split(' '));

  function tokenize(text) {
    if (typeof text !== 'string' || !text) return [];
    var parts = text.toLowerCase().split(/[^\p{L}\p{N}]+/u), out = [];
    for (var i = 0; i < parts.length; i++) {
      var w = parts[i];
      if (w.length < 2 || STOP.has(w)) continue;
      if (w.length > 3 && w.charAt(w.length - 1) === 's' && w.slice(-2) !== 'ss') w = w.slice(0, -1);
      if (w.length < 2 || STOP.has(w)) continue;
      out.push(w);
    }
    return out;
  }

  var groupMaps = new WeakMap();
  function groupMap(groups) {
    var m = groupMaps.get(groups);
    if (m) return m;
    m = new Map();
    for (var g = 0; g < groups.length; g++) {
      var toks = [], seen = new Set();
      for (var j = 0; j < groups[g].length; j++) {
        var tt = tokenize(String(groups[g][j]));
        for (var k = 0; k < tt.length; k++) if (!seen.has(tt[k])) { seen.add(tt[k]); toks.push(tt[k]); }
      }
      for (var i = 0; i < toks.length; i++) {
        var list = m.get(toks[i]);
        if (!list) { list = []; m.set(toks[i], list); }
        list.push(toks);
      }
    }
    groupMaps.set(groups, m);
    return m;
  }

  function expandTerms(tokens, groups) {
    var m = groupMap(groups || []), out = [], seen = new Set();
    function add(t) { if (!seen.has(t)) { seen.add(t); out.push(t); } }
    for (var i = 0; i < tokens.length; i++) add(tokens[i]);
    for (var j = 0; j < tokens.length; j++) {
      var lists = m.get(tokens[j]);
      if (!lists) continue;
      for (var a = 0; a < lists.length; a++) for (var b = 0; b < lists[a].length; b++) add(lists[a][b]);
    }
    return out;
  }

  function buildIndex(rows, groups) {
    var docs = [], df = new Map(), total = 0;
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i], tf = new Map(), len = 0;
      var tt = tokenize(r.title || ''), st = tokenize(r.sum || '');
      var all = tt.concat(tt, st);
      for (var k = 0; k < all.length; k++) { tf.set(all[k], (tf.get(all[k]) || 0) + 1); len++; }
      tf.forEach(function (_, term) { df.set(term, (df.get(term) || 0) + 1); });
      docs.push({ id: String(r.id), tf: tf, len: len });
      total += len;
    }
    var postings = new Map();
    for (var d = 0; d < docs.length; d++) {
      docs[d].tf.forEach(function (_, term) {
        var p = postings.get(term); if (!p) { p = []; postings.set(term, p); } p.push(d);
      });
    }
    return { N: docs.length, avgdl: docs.length ? total / docs.length : 0, docs: docs, df: df, postings: postings, groups: groups || [] };
  }

  function search(index, query, opts) {
    var limit = opts && opts.limit > 0 ? Math.floor(opts.limit) : DEFAULT_LIMIT;
    var qt = tokenize(query);
    if (!qt.length || !index.N) return [];
    var qf = new Map();
    for (var i = 0; i < qt.length; i++) qf.set(qt[i], (qf.get(qt[i]) || 0) + 1);
    var terms = expandTerms(Array.from(qf.keys()), index.groups), N = index.N, cand = [];
    for (var t = 0; t < terms.length; t++) {
      var n = index.df.get(terms[t]);
      if (!n) continue;
      var idf = Math.log(1 + (N - n + 0.5) / (n + 0.5));
      cand.push({ term: terms[t], idf: idf, w: idf * (qf.get(terms[t]) || 1), order: t });
    }
    cand.sort(function (x, y) { return y.w - x.w || x.order - y.order; });
    cand = cand.slice(0, MAX_TERMS);
    var scores = new Map(), matched = new Map();
    for (var c = 0; c < cand.length; c++) {
      var term = cand[c].term, post = index.postings.get(term);
      for (var p = 0; p < post.length; p++) {
        var doc = index.docs[post[p]], f = doc.tf.get(term);
        var s = cand[c].idf * (f * (K1 + 1)) / (f + K1 * (1 - B + B * doc.len / index.avgdl));
        scores.set(post[p], (scores.get(post[p]) || 0) + s);
        var m = matched.get(post[p]); if (!m) { m = []; matched.set(post[p], m); } m.push(term);
      }
    }
    var res = [];
    scores.forEach(function (s, d) { if (s > 0) res.push({ id: index.docs[d].id, score: s, matched: matched.get(d) }); });
    res.sort(function (x, y) { return y.score - x.score || (x.id < y.id ? -1 : x.id > y.id ? 1 : 0); });
    return res.slice(0, limit);
  }

  /* ---- filters and time warnings (all date math is UTC, from YYYY-MM-DD only) ---- */
  var DAY_MS = 86400000;
  var INSTITUTION_CODES = { university: ['06', '20'], hospital_nonprofit: ['12', '13', '25'], small_business: ['23'] };
  var CAREER_MECHS = { early: ['R01', 'R21', 'R03', 'R00'] };
  var CAREER_FAMILIES = { trainee: ['K', 'F', 'T'], early: ['K'] };
  var TRAINING_FAMILIES = ['K', 'F', 'T'];
  var DEFAULT_LEAD_WEEKS = { R01: 8, R21: 6, K: 8 };
  var DEFAULT_SIGNOFF_DAYS = 5;

  function isoToUtcMs(iso) {
    var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(iso || ''));
    if (!m) return null;
    var ms = Date.UTC(+m[1], +m[2] - 1, +m[3]), d = new Date(ms);
    return d.getUTCFullYear() === +m[1] && d.getUTCMonth() === +m[2] - 1 && d.getUTCDate() === +m[3] ? ms : null;
  }
  function utcMsToIso(ms) {
    var d = new Date(ms), mo = d.getUTCMonth() + 1, da = d.getUTCDate();
    return d.getUTCFullYear() + '-' + (mo < 10 ? '0' : '') + mo + '-' + (da < 10 ? '0' : '') + da;
  }
  function daysUntil(closeIso, todayIso) {
    var a = isoToUtcMs(closeIso), b = isoToUtcMs(todayIso);
    return a === null || b === null ? null : Math.round((a - b) / DAY_MS);
  }
  function daysSince(fromIso, toIso) { return daysUntil(toIso, fromIso); }
  var STALE_DAYS = 3;
  /* Banner text when the listings are STALE_DAYS or more days older than today; null otherwise (or if a date is unreadable). */
  function staleNotice(sourceIso, todayIso) {
    var n = daysSince(sourceIso, todayIso);
    if (n === null || n < STALE_DAYS) return null;
    return 'These listings are ' + n + ' days old. Newer postings are missing. Check Grants.gov for anything posted since.';
  }
  function businessDaysBefore(isoDate, n) {
    var ms = isoToUtcMs(isoDate);
    if (ms === null) return isoDate;
    var left = n;
    while (left > 0) {
      ms -= DAY_MS;
      var dow = new Date(ms).getUTCDay();
      if (dow !== 0 && dow !== 6) left--;
    }
    return utcMsToIso(ms);
  }
  function leadWeeksFor(mech, table) {
    if (!mech) return null;
    var code = String(mech).toUpperCase();
    if (table[code] != null) return table[code];
    var fam = code.charAt(0);
    if (TRAINING_FAMILIES.indexOf(fam) >= 0 && table[fam] != null) return table[fam];
    return null;
  }
  function timeWarning(row, todayIso, settings) {
    var st = settings || {};
    var table = {}, k;
    for (k in DEFAULT_LEAD_WEEKS) table[k] = DEFAULT_LEAD_WEEKS[k];
    if (st.leadWeeks) for (k in st.leadWeeks) table[k] = st.leadWeeks[k];
    var signoff = st.signoffBusinessDays != null ? st.signoffBusinessDays : DEFAULT_SIGNOFF_DAYS;
    var weeks = leadWeeksFor(row.mech, table);
    var needDays = weeks == null ? null : weeks * 7;
    if (!row.close) return { level: 'unknown', daysToInstitution: null, needDays: needDays, reason: 'Closing date not announced yet.' };
    var daysToInst = daysUntil(businessDaysBefore(row.close, signoff), todayIso);
    if (daysToInst === null) return { level: 'unknown', daysToInstitution: null, needDays: needDays, reason: 'Date could not be read.' };
    if (needDays === null) return { level: 'unknown', daysToInstitution: daysToInst, needDays: null, reason: 'No lead time set for this mechanism.' };
    var level, reason;
    if (daysToInst < 0) { level = 'late'; reason = 'The institutional deadline passed ' + (-daysToInst) + (daysToInst === -1 ? ' day ago.' : ' days ago.'); }
    else if (daysToInst < needDays) { level = 'tight'; reason = daysToInst + ' days to the institutional deadline; ' + needDays + ' are usually needed.'; }
    else { level = 'ok'; reason = daysToInst + ' days to the institutional deadline; ' + needDays + ' are usually needed.'; }
    return { level: level, daysToInstitution: daysToInst, needDays: needDays, reason: reason };
  }

  /* Each check returns "remove", "unknown" or "keep". A row is removed only on a known conflict. */
  function checkInstitution(row, kind) {
    var codes = INSTITUTION_CODES[kind];
    if (!codes) return 'keep';
    var elig = String(row.elig || '');
    if (!elig) return 'unknown';
    var have = elig.split('|');
    if (have.indexOf('99') >= 0) return 'keep';
    for (var i = 0; i < codes.length; i++) if (have.indexOf(codes[i]) >= 0) return 'keep';
    if (kind === 'university' && have.indexOf('25') >= 0) return 'unknown';  // "Others, see text" may include universities
    return 'remove';
  }
  function checkTrial(row, want) {
    if (row.trial == null) return 'unknown';
    if (want === 'yes') return row.trial === 'not_allowed' ? 'remove' : 'keep';
    if (want === 'no') return row.trial === 'required' ? 'remove' : 'keep';
    return 'keep';
  }
  function finiteOrNull(v) {
    if (typeof v === 'string') v = v.replace(/^\s+|\s+$/g, '');
    if (v == null || v === '') return null;
    var x = Number(v);
    return isFinite(x) ? x : null;
  }
  function checkBudget(row, lo, hi) {
    var hasLo = lo !== null, hasHi = hi !== null;
    if (hasLo && row.ceil != null && row.ceil < lo) return 'remove';
    if (hasHi && row.floor != null && row.floor > hi) return 'remove';
    if ((hasLo && row.ceil == null) || (hasHi && row.floor == null)) return 'unknown';
    return 'keep';
  }
  function checkCareer(row, career) {
    if (!row.mech) return 'unknown';
    var code = String(row.mech).toUpperCase(), fam = code.charAt(0);
    var inTraining = TRAINING_FAMILIES.indexOf(fam) >= 0;
    var ok;
    if (career === 'trainee') ok = inTraining;
    else if (career === 'early') ok = CAREER_MECHS.early.indexOf(code) >= 0 || CAREER_FAMILIES.early.indexOf(fam) >= 0;
    else if (career === 'established') ok = !inTraining;
    else return 'keep';
    return ok ? 'keep' : 'remove';
  }
  function checkMechs(row, list) {
    if (!row.mech) return 'unknown';
    var code = String(row.mech).toUpperCase();
    for (var i = 0; i < list.length; i++) if (String(list[i]).toUpperCase() === code) return 'keep';
    return 'remove';
  }
  function applyFilters(rows, profile) {
    var p = profile || {}, checks = [];
    if (p.institution) checks.push(['institution', function (r) { return checkInstitution(r, p.institution); }]);
    if (p.trial) checks.push(['trial', function (r) { return checkTrial(r, p.trial); }]);
    var bMin = finiteOrNull(p.budgetMin), bMax = finiteOrNull(p.budgetMax);
    if (bMin !== null || bMax !== null) checks.push(['budget', function (r) { return checkBudget(r, bMin, bMax); }]);
    if (p.career) checks.push(['career', function (r) { return checkCareer(r, p.career); }]);
    if (p.mechs && p.mechs.length) checks.push(['mechs', function (r) { return checkMechs(r, p.mechs); }]);
    var kept = [], unknown = {}, removedBy = {};
    for (var i = 0; i < rows.length; i++) {
      var row = rows[i], unk = [], gone = null;
      for (var c = 0; c < checks.length; c++) {
        var res = checks[c][1](row);
        if (res === 'remove') { gone = checks[c][0]; break; }
        if (res === 'unknown') unk.push(checks[c][0]);
      }
      if (gone) { removedBy[gone] = (removedBy[gone] || 0) + 1; continue; }
      kept.push(row);
      if (unk.length) unknown[row.id] = unk;
    }
    return { kept: kept, unknown: unknown, removedBy: removedBy };
  }

  return { tokenize: tokenize, expandTerms: expandTerms, buildIndex: buildIndex, search: search,
    applyFilters: applyFilters, daysUntil: daysUntil, daysSince: daysSince, staleNotice: staleNotice, businessDaysBefore: businessDaysBefore, timeWarning: timeWarning };
});
