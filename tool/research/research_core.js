/* Researcher tab core: tokenizer, synonym expansion, BM25 index and search.
   UMD style: module.exports in Node, window.ResearchCore in the browser. No dependencies. */
(function (root, factory) {
  var api = factory();
  if (typeof module === 'object' && module.exports) { module.exports = api; }
  else { root.ResearchCore = api; }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  var K1 = 1.2, B = 0.75, MAX_TERMS = 40, DEFAULT_LIMIT = 50;
  var PHRASE_BOOST = 0.5; /* per matched adjacent pair, times its mean idf; fixed in advance, not tuned on the test set */
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

  /* Quoted phrases count only in short queries: the same box takes pasted abstracts, where quote marks are punctuation. */
  var PHRASE_QUERY_MAX_CHARS = 200, MAX_PHRASES = 5;
  function parseQuery(raw) {
    var s = typeof raw === 'string' ? raw : '', plain = s.replace(/[“”„‟«»"]/g, ' '), phrases = [];
    /* An odd number of quote marks (5" display "deep learning") means the pairing is a guess: treat all of them as punctuation. */
    if (s.length <= PHRASE_QUERY_MAX_CHARS && (s.match(/[“”„‟«»"]/g) || []).length % 2 === 0) {
      var re = /[“”„‟«»"]([^“”„‟«»"]*)[“”„‟«»"]/g, m, seen = new Set();
      while (phrases.length < MAX_PHRASES && (m = re.exec(s))) {
        var tokens = tokenize(m[1]), key = tokens.join(' ');
        if (!tokens.length || seen.has(key)) continue;
        seen.add(key);
        phrases.push({ text: m[1].trim(), tokens: tokens });
      }
    }
    return { plain: plain, phrases: phrases };
  }

  var PHRASE_TIP = 'Tip: put a phrase in double quotes to require it, for example “artificial intelligence”. Quotes work in searches up to ' + PHRASE_QUERY_MAX_CHARS + ' characters, not in a pasted abstract.';
  /* Text the tab shows for a phrase search: prefix for the match line, and the message for "words match, phrase does not". */
  function phraseNotices(phrases) {
    if (!phrases || !phrases.length) return { prefix: '', empty: '' };
    var list = phrases.map(function (p) { return '“' + p.text + '”'; }).join(', ');
    return { prefix: 'Exact phrase required: ' + list + '. ',
      empty: 'No open opportunity contains ' + (phrases.length > 1 ? 'all of these exact phrases: ' : 'the exact phrase ') + list + '. Remove the quotes to search the words separately.' };
  }

  function hasPair(seq, a, b) {
    for (var i = 0; i + 1 < seq.length; i++) if (seq[i] === a && seq[i + 1] === b) return true;
    return false;
  }

  function hasRun(seq, toks) {
    for (var i = 0; i + toks.length <= seq.length; i++) {
      var j = 0;
      while (j < toks.length && seq[i + j] === toks[j]) j++;
      if (j === toks.length) return true;
    }
    return false;
  }

  /* Doc indexes (as a Set) holding every phrase as a consecutive run inside the title or the summary. */
  function phraseDocs(index, phrases) {
    var allowed = null;
    for (var p = 0; p < phrases.length; p++) {
      var toks = phrases[p].tokens, lists = [], ok = true;
      for (var k = 0; k < toks.length; k++) {
        var post = index.postings.get(toks[k]);
        if (!post) { ok = false; break; }
        lists.push(post);
      }
      var next = new Set();
      if (ok) {
        lists.sort(function (a, b) { return a.length - b.length; });
        for (var c = 0; c < lists[0].length; c++) {
          var d = lists[0][c];
          if ((allowed && !allowed.has(d)) || next.has(d)) continue;
          var seq = index.docs[d].seq;
          if (hasRun(seq[0], toks) || hasRun(seq[1], toks)) next.add(d);
        }
      }
      allowed = next;
    }
    return allowed;
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
      docs.push({ id: String(r.id), tf: tf, len: len, seq: [tt, st] });
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

  /* Distinct consecutive query-token pairs (query order, before synonym expansion) as Map "a b" -> mean idf of the two words.
     Like MAX_TERMS, only the 40 heaviest pairs are kept (ties by first appearance), so a pasted abstract stays cheap. */
  function queryBigrams(index, qt) {
    var N = index.N, found = new Map(), list = [];
    function idfOf(term) { var n = index.df.get(term); return n ? Math.log(1 + (N - n + 0.5) / (n + 0.5)) : null; }
    for (var i = 0; i + 1 < qt.length; i++) {
      var key = qt[i] + ' ' + qt[i + 1];
      if (found.has(key)) continue;
      var a = idfOf(qt[i]), b = idfOf(qt[i + 1]);
      found.set(key, true);
      if (a !== null && b !== null) list.push({ key: key, w: (a + b) / 2, order: list.length });
    }
    list.sort(function (x, y) { return y.w - x.w || x.order - y.order; });
    var out = new Map();
    for (var j = 0; j < list.length && j < MAX_TERMS; j++) out.set(list[j].key, list[j].w);
    return out;
  }

  /* Unusual-case flags (from research.json row.flags). The notice "mentions" a thing; a missing key means unknown, never "no". */
  var FLAG_LABELS = { loi: 'letter of intent', foreign: 'foreign participation allowed', cost_share: 'cost sharing', subaward: 'subaward',
    multi_pi: 'multiple PIs', ind_ide: 'IND or IDE', data_sharing: 'data sharing', animals: 'animal research', human_subjects: 'human subjects' };
  function flagNotes(row, ticked) {
    var flags = row && row.flags && typeof row.flags === 'object' ? row.flags : {}, want = new Set(ticked || []), shown = [], unknownTicked = [];
    Object.keys(FLAG_LABELS).forEach(function (k) {
      if (flags[k] === 'yes' || flags[k] === 'no') shown.push({ key: k, label: FLAG_LABELS[k], state: flags[k] });
      else if (want.has(k)) unknownTicked.push({ key: k, label: FLAG_LABELS[k] });
    });
    shown.sort(function (a, b) { return (want.has(b.key) ? 1 : 0) - (want.has(a.key) ? 1 : 0); });
    return { shown: shown, unknownTicked: unknownTicked };
  }

  /* ---- calendar text and pasted-list cleanup ---- */
  function icsText(s) { return String(s == null ? '' : s).replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\r?\n/g, ' '); }
  function icsDate(ms) { var d = new Date(ms); return d.getUTCFullYear() * 10000 + (d.getUTCMonth() + 1) * 100 + d.getUTCDate() + ''; }
  /* RFC 5545 text: one all-day event per row with a readable close date. stamp (YYYYMMDDTHHMMSSZ) is passed in so the function stays pure. */
  function buildIcs(rows, stamp) {
    var ev = [];
    (rows || []).forEach(function (r) {
      var ms = isoToUtcMs(r && r.close);
      if (ms === null) return;
      ev.push('BEGIN:VEVENT', 'UID:research-' + r.id + '@ffm', 'DTSTAMP:' + stamp, 'DTSTART;VALUE=DATE:' + icsDate(ms), 'DTEND;VALUE=DATE:' + icsDate(ms + DAY_MS),
        'SUMMARY:' + icsText('Closes: ' + r.title), 'DESCRIPTION:' + icsText((r.num || '') + '. ' + (r.url || '')), 'END:VEVENT');
    });
    if (!ev.length) return '';
    return ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//FFM//EN', 'CALSCALE:GREGORIAN'].concat(ev, ['END:VCALENDAR']).join('\r\n') + '\r\n';
  }
  /* Strips reference numbers, "doi:" tokens, DOI strings and links from a pasted publication list so they do not become query terms. */
  function cleanPublicationList(text) {
    if (typeof text !== 'string') return '';
    return text.split(/\r?\n/).map(function (line) {
      return line.replace(/^\s*(\[\d+\]|\d+[.)])\s*/, '').replace(/https?:\/\/\S+/gi, ' ').replace(/\bdoi:?\s*/gi, ' ').replace(/\b10\.\d{4,9}\/\S+/g, ' ').replace(/[ \t]+/g, ' ').trim();
    }).filter(Boolean).join('\n');
  }

  /* ---- ORCID iD and OpenAlex (the only request the tab can make; the iD is the only thing sent) ---- */
  /* Canonical 0000-0002-1825-0097 form, or null. Only an orcid.org prefix is accepted; the last digit is the ISO 7064 mod 11-2 check. */
  function normalizeOrcid(raw) {
    if (typeof raw !== 'string') return null;
    var s = raw.trim().replace(/^https?:\/\/(www\.)?orcid\.org\//i, '').replace(/[\s-]/g, '');
    if (!/^\d{15}[\dXx]$/.test(s)) return null;
    s = s.toUpperCase();
    var total = 0;
    for (var i = 0; i < 15; i++) total = (total + Number(s.charAt(i))) * 2;
    var check = (12 - total % 11) % 11;
    if (s.charAt(15) !== (check === 10 ? 'X' : String(check))) return null;
    return s.slice(0, 4) + '-' + s.slice(4, 8) + '-' + s.slice(8, 12) + '-' + s.slice(12);
  }
  function openAlexWorksUrl(orcid, perPage) {
    var id = normalizeOrcid(orcid), n = perPage > 0 ? Math.min(200, Math.floor(perPage)) : 25;
    if (!id) return '';
    return 'https://api.openalex.org/works?filter=authorships.author.orcid:https://orcid.org/' + id + '&sort=publication_year:desc&per-page=' + n +
      '&select=title,publication_year,abstract_inverted_index,topics';
  }
  /* Titles, abstracts (rebuilt from OpenAlex's word-position index) and up to 2 topic names per work, cut at maxChars on a word boundary. */
  function worksToText(works, maxChars) {
    var max = maxChars > 0 ? maxChars : 3000, parts = [];
    (Array.isArray(works) ? works : []).forEach(function (w) {
      if (!w || typeof w !== 'object') return;
      var words = [], idx = w.abstract_inverted_index;
      if (idx && typeof idx === 'object') Object.keys(idx).forEach(function (word) {
        (Array.isArray(idx[word]) ? idx[word] : []).forEach(function (pos) { if (pos >= 0 && pos < 5000) words[pos] = word; });
      });
      var topics = (Array.isArray(w.topics) ? w.topics : []).slice(0, 2).map(function (t) { return t && t.display_name; }).filter(Boolean);
      var line = [w.title || '', words.filter(Boolean).join(' '), topics.join(' ')].filter(Boolean).join(' ');
      if (line) parts.push(line);
    });
    var out = parts.join('\n');
    if (out.length <= max) return out;
    var cut = out.slice(0, max);
    if (!/\s/.test(out.charAt(max))) cut = cut.replace(/\s*\S*$/, '');
    return cut.trim();
  }

  function search(index, query, opts) {
    var limit = opts && opts.limit > 0 ? Math.floor(opts.limit) : DEFAULT_LIMIT;
    var parsed = parseQuery(query), qt = tokenize(parsed.plain);
    if (!qt.length || !index.N) return [];
    var allowed = parsed.phrases.length && !(opts && opts.phraseFilter === false) ? phraseDocs(index, parsed.phrases) : null;
    if (allowed && !allowed.size) return [];
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
    /* Words inside a required phrase are never cut by the cap: a phrase row would otherwise score 0 and vanish. */
    var forced = new Set();
    if (allowed) parsed.phrases.forEach(function (ph) { ph.tokens.forEach(function (w) { forced.add(w); }); });
    cand = cand.filter(function (x, i) { return i < MAX_TERMS || forced.has(x.term); });
    var scores = new Map(), matched = new Map();
    for (var c = 0; c < cand.length; c++) {
      var term = cand[c].term, post = index.postings.get(term);
      for (var p = 0; p < post.length; p++) {
        if (allowed && !allowed.has(post[p])) continue;
        var doc = index.docs[post[p]], f = doc.tf.get(term);
        var s = cand[c].idf * (f * (K1 + 1)) / (f + K1 * (1 - B + B * doc.len / index.avgdl));
        scores.set(post[p], (scores.get(post[p]) || 0) + s);
        var m = matched.get(post[p]); if (!m) { m = []; matched.set(post[p], m); } m.push(term);
      }
    }
    var boost = opts && typeof opts.phraseBoost === 'number' && isFinite(opts.phraseBoost) && opts.phraseBoost >= 0 ? opts.phraseBoost : PHRASE_BOOST;
    var pairs = boost > 0 ? queryBigrams(index, qt) : null;
    if (pairs && pairs.size) {
      /* Per query pair, visit only the rows that hold both words (walk the shorter posting list, test the other), then look for the pair side by side. */
      var bonus = new Map();
      pairs.forEach(function (w, key) {
        var sp = key.indexOf(' '), a = key.slice(0, sp), b = key.slice(sp + 1), pa = index.postings.get(a), pb = index.postings.get(b);
        if (!pa || !pb) return;
        var small = pa.length <= pb.length ? pa : pb, other = small === pa ? pb : pa, j = 0;
        for (var i2 = 0; i2 < small.length; i2++) {
          var d = small[i2];
          while (j < other.length && other[j] < d) j++;
          if (j >= other.length) break;
          if (other[j] !== d || !scores.has(d)) continue;
          var seqs = index.docs[d].seq;
          if (hasPair(seqs[0], a, b) || hasPair(seqs[1], a, b)) bonus.set(d, (bonus.get(d) || 0) + w);
        }
      });
      bonus.forEach(function (bn, d) { scores.set(d, scores.get(d) + boost * bn); });
    }
    var res = [];
    scores.forEach(function (s, d) { if (s > 0) res.push({ id: index.docs[d].id, score: s, matched: matched.get(d) }); });
    res.sort(function (x, y) { return y.score - x.score || (x.id < y.id ? -1 : x.id > y.id ? 1 : 0); });
    return res.slice(0, limit);
  }

  /* ---- foundations: same BM25 engine over each foundation's name (title) and its own focus sentence (summary) ---- */
  var FOUNDATION_STALE_DAYS = 365;
  function foundationStale(verifiedIso, todayIso, maxDays) {
    var n = daysSince(verifiedIso, todayIso);
    return n === null || n > (maxDays > 0 ? maxDays : FOUNDATION_STALE_DAYS);
  }
  function buildFoundationIndex(rows, groups) {
    return buildIndex((rows || []).map(function (r) { return { id: r.id, title: r.name, sum: r.focus }; }), groups);
  }
  function searchFoundations(index, query, opts) { return search(index, query, opts); }

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

  return { tokenize: tokenize, parseQuery: parseQuery, phraseNotices: phraseNotices, PHRASE_TIP: PHRASE_TIP, PHRASE_QUERY_MAX_CHARS: PHRASE_QUERY_MAX_CHARS, expandTerms: expandTerms, buildIndex: buildIndex, search: search,
    applyFilters: applyFilters, flagNotes: flagNotes, buildIcs: buildIcs, normalizeOrcid: normalizeOrcid, openAlexWorksUrl: openAlexWorksUrl, worksToText: worksToText,cleanPublicationList: cleanPublicationList,foundationStale: foundationStale, buildFoundationIndex: buildFoundationIndex, searchFoundations: searchFoundations, FLAG_LABELS: FLAG_LABELS, daysUntil: daysUntil, daysSince: daysSince, staleNotice: staleNotice, businessDaysBefore: businessDaysBefore, timeWarning: timeWarning };
});
