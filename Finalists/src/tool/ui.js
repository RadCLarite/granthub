// ui.js: draws the controls and the ranked list from the payload and Ranker.run().
(function () {
  var P = window.PAYLOAD;
  var state = { weights: {}, filters_on: {} };
  P.criteria.forEach(function (c) {
    if (c.type === "score") state.weights[c.id] = Number(c.weight);
    else state.filters_on[c.id] = true;
  });
  var defaults = JSON.parse(JSON.stringify(state));

  function el(tag, attrs, kids) {
    var e = document.createElement(tag);
    Object.keys(attrs || {}).forEach(function (k) {
      if (k === "text") e.textContent = attrs[k]; else e.setAttribute(k, attrs[k]);
    });
    (kids || []).forEach(function (c) { e.appendChild(c); });
    return e;
  }

  document.getElementById("title").textContent = P.title;
  document.getElementById("sub").textContent = P.subtitle + " · rules as of " + P.ref_date;

  var controls = document.getElementById("controls");
  var range = P.config.weight_range, step = P.config.weight_step;

  function buildControls() {
    controls.innerHTML = "";
    var filters = P.criteria.filter(function (c) { return c.type === "filter"; });
    var scores = P.criteria.filter(function (c) { return c.type === "score"; });
    if (filters.length) controls.appendChild(el("h2", { text: "Must pass (filters)" }));
    filters.forEach(function (c) {
      var cb = el("input", { type: "checkbox", id: "f-" + c.id });
      cb.checked = state.filters_on[c.id];
      cb.addEventListener("change", function () { state.filters_on[c.id] = cb.checked; render(); });
      var lab = el("label", { for: "f-" + c.id, class: "check" }, [cb, el("span", { text: " " + c.label })]);
      controls.appendChild(el("div", { class: "ctl" }, [lab, el("div", { class: "why", text: c.why })]));
    });
    if (scores.length) controls.appendChild(el("h2", { text: "How much it matters (weights)" }));
    scores.forEach(function (c) {
      var out = el("span", { id: "wv-" + c.id, text: String(state.weights[c.id]) });
      var inp = el("input", { type: "range", id: "w-" + c.id, min: range[0], max: range[1], step: step, value: state.weights[c.id], "aria-label": c.label + " weight" });
      inp.addEventListener("input", function () { state.weights[c.id] = Number(inp.value); out.textContent = inp.value; render(); });
      controls.appendChild(el("div", { class: "ctl" }, [
        el("label", { for: "w-" + c.id }, [el("span", { text: c.label }), out]), inp,
        el("div", { class: "why", text: c.why })]));
    });
  }

  function render() {
    var res = Ranker.run(P, state);
    var n = P.items.length;
    document.getElementById("counts").textContent =
      n + " items: " + res.ranked.length + " ranked, " + res.dropped.length + " dropped by filters";
    var list = document.getElementById("results"); list.innerHTML = "";
    res.ranked.slice(0, P.config.top_n).forEach(function (r) {
      var fields = P.show_fields.map(function (f) { return r.item.fields[f] ? f.replace(/_/g, " ") + ": " + r.item.fields[f] : null; })
        .filter(Boolean).join(" · ");
      var rows = P.criteria.filter(function (c) { return c.type === "score"; }).map(function (c) {
        var p = r.item.pts[c.id];
        return el("div", { class: "crit-row" }, [
          el("span", { text: c.label + " (weight " + res.weights[c.id] + ")" }),
          el("div", { class: "bar" }, [el("i", { style: "width:" + Math.round(p * 100) + "%" })]),
          el("span", { text: p.toFixed(2) })]);
      });
      list.appendChild(el("li", { class: "result" }, [
        el("div", { class: "top" }, [el("span", { class: "rank", text: String(r.rank) }),
          el("span", { class: "name", text: r.name }), el("span", { class: "score", text: r.total.toFixed(0) + " / 100" })]),
        el("div", { class: "bar" }, [el("i", { style: "width:" + Math.max(0, Math.min(100, r.total)) + "%" })]),
        el("div", { class: "why-line", text: r.why }),
        el("div", { class: "fields", text: fields }),
        el("details", {}, [el("summary", { text: "Points by criterion" })].concat(rows))]));
    });
    var dl = document.getElementById("dropped"); dl.innerHTML = "";
    res.dropped.forEach(function (d) {
      var labs = d.failed.map(function (f) { return P.criteria.filter(function (c) { return c.id === f; })[0].label; });
      dl.appendChild(el("li", { text: d.item.name + ": fails " + labs.join(", ") }));
    });
    document.getElementById("dropped-wrap").style.display = res.dropped.length ? "" : "none";
  }

  document.getElementById("reset").addEventListener("click", function () {
    state = JSON.parse(JSON.stringify(defaults)); buildControls(); render();
  });
  document.getElementById("large").addEventListener("click", function (e) {
    var on = document.body.classList.toggle("large"); e.target.setAttribute("aria-pressed", on);
  });
  buildControls(); render();
})();
