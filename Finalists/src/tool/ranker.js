// ranker.js: the browser copy of the ranking math. R computes the same numbers in
// src/R/score.R; src/tests/run_tests.R runs this file through V8 and fails if the two disagree.
var Ranker = (function () {
  function lt(a, b) { return a < b; }
  function fmt2(x) { return x.toFixed(2); }

  // Same wording as explain_row() in score.R.
  function explain(pts, w, labels, ids) {
    var use = ids.filter(function (id) { return w[id] > 0; });
    if (!use.length) return "No score criteria are on.";
    var byContrib = use.slice().sort(function (a, b) {
      var d = w[b] * pts[b] - w[a] * pts[a];
      return d !== 0 ? d : (lt(labels[a], labels[b]) ? -1 : 1);
    });
    var nPos = use.filter(function (id) { return pts[id] > 0; }).length;
    var strong = byContrib.filter(function (id) { return pts[id] > 0; }).slice(0, Math.min(2, nPos));
    var byWeak = use.slice().sort(function (a, b) {
      if (pts[a] !== pts[b]) return pts[a] - pts[b];
      if (w[a] !== w[b]) return w[b] - w[a];
      return lt(labels[a], labels[b]) ? -1 : 1;
    });
    var nLow = use.filter(function (id) { return pts[id] < 1; }).length;
    var weak = byWeak.filter(function (id) { return pts[id] < 1; }).slice(0, Math.min(1, nLow));
    var s = strong.length
      ? "Strong: " + strong.map(function (id) { return labels[id] + " (" + fmt2(pts[id]) + ")"; }).join(", ")
      : "No strong points";
    var k = weak.length ? ". Weak: " + labels[weak[0]] + " (" + fmt2(pts[weak[0]]) + ")" : "";
    return s + k;
  }

  // state: { weights: {id: number}, filters_on: {id: bool} }; both optional (defaults come from the payload).
  function run(payload, state) {
    state = state || {};
    var filters = payload.criteria.filter(function (c) { return c.type === "filter"; });
    var scores = payload.criteria.filter(function (c) { return c.type === "score"; });
    var w = {}, labels = {}, ids = scores.map(function (c) { return c.id; });
    scores.forEach(function (c) {
      var v = state.weights && state.weights[c.id] != null ? state.weights[c.id] : c.weight;
      w[c.id] = Number(v); labels[c.id] = c.label;
    });
    var on = {};
    filters.forEach(function (c) {
      on[c.id] = state.filters_on && state.filters_on[c.id] != null ? !!state.filters_on[c.id] : true;
    });
    var sumW = ids.reduce(function (a, id) { return a + w[id]; }, 0);
    var droppedBy = {}; filters.forEach(function (c) { droppedBy[c.id] = []; });
    var ranked = [], dropped = [];
    payload.items.forEach(function (it) {
      var failed = it.fails.filter(function (f) { return on[f]; });
      if (failed.length) {
        failed.forEach(function (f) { droppedBy[f].push(it); });
        dropped.push({ item: it, failed: failed });
        return;
      }
      var total = 0;
      if (sumW > 0) ids.forEach(function (id) { total += w[id] * it.pts[id]; });
      total = sumW > 0 ? Math.round(1e4 * 100 * total / sumW) / 1e4 : 0;
      ranked.push({ id: it.id, name: it.name, total: total, item: it, why: explain(it.pts, w, labels, ids) });
    });
    ranked.sort(function (a, b) { return b.total !== a.total ? b.total - a.total : (lt(a.id, b.id) ? -1 : 1); });
    ranked.forEach(function (r, i) { r.rank = i + 1; });
    return { ranked: ranked, dropped: dropped, droppedBy: droppedBy, weights: w, filters_on: on };
  }

  return { run: run, explain: explain };
})();
