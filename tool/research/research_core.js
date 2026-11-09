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

  return { tokenize: tokenize, expandTerms: expandTerms, buildIndex: buildIndex, search: search };
});
