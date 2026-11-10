/* Researcher tab UI. Adds only window.ResearchTab. All inserted text goes through textContent (never innerHTML).
   Needs window.ResearchCore. Fetches research.json and synonyms.json from the same folder. Sends only an ORCID iD to api.openalex.org, and only on click. */
(function () {
  'use strict';
  var MAX_SHOW = 50, FILTER_NAMES = { institution: 'institution type', trial: 'clinical trial', budget: 'budget', career: 'career stage', mechs: 'preferred mechanisms' };
  var EXAMPLES = ['stroke CT perfusion imaging AI', 'multimodal AI for radiology reports', 'physics-based MRI'];
  var LEVEL_TEXT = { ok: 'Time looks OK', tight: 'Tight for sign-off', late: 'Institutional deadline passed', unknown: 'Time check unavailable' };
  var state = { rows: [], index: null, asOf: '', sourceDate: '', today: '', ui: {}, started: false };

  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }
  function localToday() {
    var d = new Date(), m = d.getMonth() + 1, day = d.getDate();
    return d.getFullYear() + '-' + (m < 10 ? '0' : '') + m + '-' + (day < 10 ? '0' : '') + day;
  }
  function money(n) { return '$' + Number(n).toLocaleString('en-US'); }
  function field(label, input, id) {
    var w = el('div'), l = el('label', null, label);
    input.id = id; l.htmlFor = id; w.appendChild(l); w.appendChild(input); return w;
  }
  function numInput(val, min) { var i = el('input'); i.type = 'number'; i.min = min; i.value = val; i.inputMode = 'numeric'; return i; }
  function selectOf(pairs) {
    var s = el('select');
    pairs.forEach(function (p) { var o = el('option', null, p[1]); o.value = p[0]; s.appendChild(o); });
    return s;
  }

  /* Highlighted text is built from text nodes plus <mark> elements, so nothing is ever parsed as HTML. */
  function highlight(parent, text, matched) {
    var re = /[\p{L}\p{N}]+/gu, last = 0, m;
    while ((m = re.exec(text)) !== null) {
      var toks = window.ResearchCore.tokenize(m[0]);
      if (toks.length && matched[toks[0]]) {
        if (m.index > last) parent.appendChild(document.createTextNode(text.slice(last, m.index)));
        parent.appendChild(el('mark', null, m[0]));
        last = m.index + m[0].length;
      }
    }
    if (last < text.length) parent.appendChild(document.createTextNode(text.slice(last)));
  }
  function snippet(sum, matched) {
    if (!sum) return '';
    var re = /[\p{L}\p{N}]+/gu, m, at = -1;
    while ((m = re.exec(sum)) !== null) {
      var t = window.ResearchCore.tokenize(m[0]);
      if (t.length && matched[t[0]]) { at = m.index; break; }
    }
    var start = Math.max(0, (at < 0 ? 0 : at) - 60), end = start + 240, s;
    if (start > 0) { var sp = sum.indexOf(' ', start); start = sp < 0 || sp > at ? start : sp + 1; }
    s = sum.slice(start, end);
    if (end < sum.length) { var cut = s.lastIndexOf(' '); if (cut > 40) s = s.slice(0, cut); }
    return (start > 0 ? '... ' : '') + s.replace(/\s+$/, '') + (end < sum.length ? ' ...' : '');
  }

  function isLive(r) { return !(r.close && r.close < state.today); }
  function searchedLine() {
    var live = state.rows.filter(isLive), fc = live.filter(function (r) { return r.status === 'forecasted'; }).length;
    return live.length + ' opportunities searched (' + fc + ' forecasted, not yet open). Listings fetched ' + state.sourceDate + '; page built ' + state.asOf + '.';
  }
  function updateMeta(prefix) {
    state.ui.meta.textContent = (prefix ? prefix + ' ' : '') + searchedLine();
    var note = window.ResearchCore.staleNotice(state.sourceDate, state.today), b = state.ui.stale;
    b.textContent = note || ''; b.hidden = !note;
  }
  function sortDate(row) { return row.status === 'forecasted' || !row.close ? '9999-99-99' : row.close; }
  function readProfile() {
    var u = state.ui, mechs = [];
    u.mechBoxes.forEach(function (b) { if (b.checked) mechs.push(b.value); });
    return { institution: u.inst.value, trial: u.trial.value === 'unsure' ? '' : u.trial.value, budgetMin: u.bmin.value, budgetMax: u.bmax.value, career: u.career.value, mechs: mechs };
  }
  function readSettings() {
    var u = state.ui;
    function n(i, d) { var v = Number(i.value); return i.value !== '' && isFinite(v) && v >= 0 ? v : d; }
    function whole(i, d) { var v = n(i, d); return Math.max(0, Math.round(v)); }
    return { leadWeeks: { R01: n(u.wR01, 8), R21: n(u.wR21, 6), K: n(u.wK, 8) }, signoffBusinessDays: whole(u.sign, 5) };
  }

  function buildCard(row, hit, unk, settings) {
    var RC = window.ResearchCore, matched = {}, card = el('article', 'rt-card');
    hit.matched.forEach(function (t) { matched[t] = 1; });
    var h = el('h3'), a = el('a');
    if (typeof row.url === 'string' && /^https?:\/\//i.test(row.url)) {
      a.href = row.url; a.target = '_blank'; a.rel = 'noopener noreferrer';
      highlight(a, row.title || '(untitled)', matched);
      h.appendChild(a);
    } else highlight(h, row.title || '(untitled)', matched);
    card.appendChild(h);
    var who = [row.agency, row.ic].filter(Boolean).join(' / ');
    if (who) card.appendChild(el('p', 'rt-sub', who));
    var b = el('div', 'rt-badges');
    b.appendChild(el('span', 'rt-badge', row.mech ? 'Mechanism: ' + row.mech : 'Mechanism: unknown'));
    b.appendChild(el('span', 'rt-badge', row.trial === 'required' ? 'Clinical trial required' : row.trial === 'not_allowed' ? 'Clinical trial not allowed' : row.trial === 'optional' ? 'Clinical trial optional' : 'Clinical trial: unknown'));
    (unk || []).forEach(function (k) { b.appendChild(el('span', 'rt-badge rt-unknown', 'unknown: ' + (FILTER_NAMES[k] || k))); });
    card.appendChild(b);
    var ticked = (state.ui.flagBoxes || []).filter(function (c) { return c.checked; }).map(function (c) { return c.value; }), fn = RC.flagNotes(row, ticked);
    if (fn.shown.length) {
      var fb = el('div', 'rt-badges');
      fn.shown.forEach(function (x) { fb.appendChild(el('span', 'rt-badge rt-flag' + (ticked.indexOf(x.key) >= 0 ? ' rt-flag-mine' : ''), (x.state === 'no' ? 'No ' : 'Mentioned: ') + x.label)); });
      card.appendChild(fb);
    }
    if (fn.unknownTicked.length) card.appendChild(el('p', 'rt-line rt-muted', 'You ticked ' + fn.unknownTicked.map(function (x) { return x.label; }).join(', ') + '. This listing does not say. Read the notice.'));
    card.appendChild(el('p', 'rt-line', row.ceil != null ? 'Award ceiling ' + money(row.ceil) + ' as listed' : 'Budget: unknown'));
    var line = el('p', 'rt-line'), level, label, days = RC.daysUntil(row.close, state.today);
    if (row.status === 'forecasted' || !row.close) { line.textContent = 'Date not announced'; level = 'unknown'; label = 'No deadline to check'; }
    else if (days === 0) { line.textContent = 'Closes today. Confirm the time on Grants.gov.'; level = 'unknown'; label = 'Closes today'; }
    else {
      var w = RC.timeWarning(row, state.today, settings);
      level = w.level; label = LEVEL_TEXT[level];
      line.textContent = 'Closes ' + row.close + (days != null ? ' (' + days + (days === 1 ? ' day' : ' days') + '). ' : '. ') + w.reason;
    }
    card.appendChild(line);
    var wrap = el('div', 'rt-badges'); wrap.appendChild(el('span', 'rt-badge rt-' + level, label)); card.appendChild(wrap);
    var sn = snippet(row.sum, matched);
    if (sn) { var p = el('p', 'rt-snip'); highlight(p, sn, matched); card.appendChild(p); }
    return card;
  }

  function render(msg, cards, tail) {
    var out = state.ui.out;
    while (out.firstChild) out.removeChild(out.firstChild);
    if (msg) out.appendChild(el('p', 'rt-empty', msg));
    (cards || []).forEach(function (c) { out.appendChild(c); });
    if (tail) out.appendChild(el('p', 'rt-meta', tail));
  }

  function run() { state.searched = true; runFederal(); }

  function runFederal() {
    var RC = window.ResearchCore, q = state.ui.box.value;
    state.today = localToday();
    updateMeta('');
    if (!state.index) { render('Still loading the opportunity list. Try again in a moment.'); return; }
    if (!RC.tokenize(q).length) { render('Type or paste a few topic words, for example the aims of your project. Common words alone cannot be searched.'); return; }
    var phrases = RC.parseQuery(q).phrases, notice = RC.phraseNotices(phrases);
    var hits = RC.search(state.index, q, { limit: state.rows.length || 1 }), byId0 = {};
    state.rows.forEach(function (r) { byId0[r.id] = r; });
    function live(hs) { return hs.filter(function (h) { return isLive(byId0[h.id]); }); }  /* a tab left open past midnight must not show a closed grant */
    hits = live(hits);
    if (!hits.length) {
      if (phrases.length && live(RC.search(state.index, q, { limit: state.rows.length || 1, phraseFilter: false })).length) {
        render(notice.empty);
        return;
      }
      render('No open opportunity shares words with this text. Try fewer or more general words.'); return;
    }
    var byId = {}, hitById = {};
    state.rows.forEach(function (r) { byId[r.id] = r; });
    hits.forEach(function (h) { hitById[h.id] = h; });
    var f = RC.applyFilters(hits.map(function (h) { return byId[h.id]; }), readProfile());
    if (!f.kept.length) {
      var top = null, best = 0;
      Object.keys(f.removedBy).forEach(function (k) { if (f.removedBy[k] > best) { best = f.removedBy[k]; top = k; } });
      render('No match left after filtering. The "' + (FILTER_NAMES[top] || top) + '" filter removed the most (' + best + '). Open Filters and loosen it.');
      return;
    }
    var kept = f.kept.map(function (r) { return { row: r, hit: hitById[r.id] }; });
    kept.sort(function (x, y) {
      var d = y.hit.score - x.hit.score;
      if (Math.abs(d) > 1e-9) return d;
      var a = sortDate(x.row), b = sortDate(y.row);
      return a < b ? -1 : a > b ? 1 : 0;
    });
    var settings = readSettings(), shown = kept.slice(0, MAX_SHOW);
    var cards = shown.map(function (k) { return buildCard(k.row, k.hit, f.unknown[k.row.id], settings); });
    var tail = kept.length > MAX_SHOW ? (kept.length - MAX_SHOW) + ' more not shown. Narrow your text or use Filters.' : '';
    render(null, cards, tail);
    addCalendarButton(shown.map(function (k) { return k.row; }));
    updateMeta(notice.prefix + 'Showing ' + shown.length + ' of ' + kept.length + ' matches.');
  }

  function addCalendarButton(rows) {
    var stamp = new Date().toISOString().slice(0, 19).split('-').join('').split(':').join('') + 'Z', ics = window.ResearchCore.buildIcs(rows, stamp);
    if (!ics) return;
    var b = el('button', 'rt-btn', 'Add these deadlines to my calendar (.ics)'); b.type = 'button';
    b.addEventListener('click', function () {
      var url = URL.createObjectURL(new Blob([ics], { type: 'text/calendar' })), a = el('a');
      a.href = url; a.download = 'grant-deadlines.ics'; document.body.appendChild(a); a.click(); document.body.removeChild(a);
      setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
    });
    var row = el('div', 'rt-row'); row.appendChild(b); state.ui.out.appendChild(row);
  }

  var ORCID_NOTICE = 'Clicking Look up sends only your ORCID iD to OpenAlex (api.openalex.org) and reads your public papers. Nothing is stored. Your pasted text never leaves this page.';
  function buildOrcidBlock(u) {
    var RC = window.ResearchCore, det = el('details', 'rt-orcid'), row = el('div', 'rt-row');
    det.appendChild(el('summary', null, 'Use my ORCID'));
    det.appendChild(el('p', 'rt-meta', ORCID_NOTICE));
    var inp = el('input'); inp.type = 'text'; inp.id = 'rt-orcid'; inp.placeholder = '0000-0002-1825-0097'; inp.autocomplete = 'off'; inp.setAttribute('aria-label', 'ORCID iD');
    var btn = el('button', 'rt-btn', 'Look up my papers'); btn.type = 'button';
    var msg = el('p', 'rt-meta'); msg.setAttribute('role', 'status');
    btn.addEventListener('click', function () {
      var id = RC.normalizeOrcid(inp.value);
      if (!id) { msg.textContent = 'That iD does not look right. It has 16 characters, like 0000-0002-1825-0097.'; return; }
      btn.disabled = true; msg.textContent = 'Looking up your papers...';
      var ctl = new AbortController(), timer = setTimeout(function () { ctl.abort(); }, 10000);
      fetch(RC.openAlexWorksUrl(id), { signal: ctl.signal, credentials: 'omit', headers: { Accept: 'application/json' } }).then(function (r) {
        if (r.status === 429 || r.status === 402 || r.status === 403) throw new Error('limit');
        if (!r.ok) { var he = new Error('http'); he.status = r.status; throw he; }
        return r.json();
      }).then(function (d) {
        var works = (d && d.results) || [], text = RC.worksToText(works), st = RC.worksStats(works);
        if (!text) { msg.textContent = 'OpenAlex has no papers with text for that iD. Paste your abstract instead.'; return; }
        if (u.box.value.trim() && !window.confirm('Replace the text in the box with text from your papers?')) { msg.textContent = 'Left your text as it was.'; return; }
        u.box.value = text;
        msg.textContent = 'Filled from ' + st.used + (st.used === 1 ? ' paper. ' : ' papers. ') + (st.withAbstract === 0
          ? 'None has an abstract on OpenAlex, so this is titles only and matches will be rough. Add an abstract if you can, then press Search.'
          : 'Edit the text, then press Search.');
      }).catch(function (err) {
        msg.textContent = RC.openAlexFailureText(err);
      }).then(function () { clearTimeout(timer); btn.disabled = false; });
    });
    row.appendChild(inp); row.appendChild(btn); det.appendChild(row); det.appendChild(msg);
    return det;
  }

  function buildUi(root) {
    var u = state.ui;
    root.appendChild(el('h2', null, 'Find funding for a research project'));
    root.appendChild(el('p', 'rt-privacy', 'Your text stays in this browser. Nothing is sent unless you press Look up in the ORCID box below.'));
    var panel = el('div', 'rt-panel');
    panel.appendChild(buildOrcidBlock(u));
    u.box = el('textarea'); u.box.id = 'rt-text'; u.box.rows = 5;
    var l = el('label', null, 'Paste an abstract, aims, or keywords'); l.htmlFor = 'rt-text';
    panel.appendChild(l); panel.appendChild(u.box);
    panel.appendChild(el('p', 'rt-meta', window.ResearchCore.PHRASE_TIP));
    var cl = el('button', 'rt-btn rt-ex', 'Clean pasted publication list'); cl.type = 'button';
    cl.addEventListener('click', function () { u.box.value = window.ResearchCore.cleanPublicationList(u.box.value); });
    panel.appendChild(cl);
    var r1 = el('div', 'rt-row'), go = el('button', 'rt-btn', 'Search'); go.type = 'button'; go.addEventListener('click', run);
    r1.appendChild(go); panel.appendChild(r1);
    var r2 = el('div', 'rt-row'); r2.appendChild(el('span', 'rt-exlabel', 'Try:'));
    EXAMPLES.forEach(function (t) {
      var b = el('button', 'rt-btn rt-ex', t); b.type = 'button';
      b.addEventListener('click', function () { u.box.value = t; run(); });
      r2.appendChild(b);
    });
    panel.appendChild(r2); root.appendChild(panel);

    var det = el('details', 'rt-filters'), sum = el('summary', null, 'Filters');
    det.appendChild(sum);
    var g = el('div', 'rt-grid');
    u.inst = selectOf([['', 'Any'], ['university', 'University'], ['hospital_nonprofit', 'Hospital or nonprofit'], ['small_business', 'Small business']]);
    u.trial = selectOf([['unsure', 'Unsure'], ['yes', 'Yes'], ['no', 'No']]);
    u.career = selectOf([['', 'Any'], ['trainee', 'Trainee'], ['early', 'Early career'], ['established', 'Established']]);
    u.bmin = numInput('', 0); u.bmax = numInput('', 0);
    g.appendChild(field('Institution type', u.inst, 'rt-inst'));
    g.appendChild(field('Plans a clinical trial', u.trial, 'rt-trial'));
    g.appendChild(field('Career stage', u.career, 'rt-career'));
    g.appendChild(field('Budget minimum (US dollars)', u.bmin, 'rt-bmin'));
    g.appendChild(field('Budget maximum (US dollars)', u.bmax, 'rt-bmax'));
    det.appendChild(g);
    var fs = el('fieldset'); fs.appendChild(el('legend', null, 'Preferred mechanisms'));
    var count = {};
    state.rows.forEach(function (r) { if (r.mech) count[r.mech] = (count[r.mech] || 0) + 1; });
    var mechs = Object.keys(count).sort(function (a, b) { return count[b] - count[a] || (a < b ? -1 : 1); }).slice(0, 12).sort();
    u.mechBoxes = mechs.map(function (m) {
      var lab = el('label'), cb = el('input'); cb.type = 'checkbox'; cb.value = m;
      lab.appendChild(cb); lab.appendChild(document.createTextNode(m)); fs.appendChild(lab); return cb;
    });
    det.appendChild(fs);
    var fs3 = el('fieldset'); fs3.appendChild(el('legend', null, 'My project has... (highlights only, hides nothing)'));
    u.flagBoxes = Object.keys(window.ResearchCore.FLAG_LABELS).map(function (k) {
      var lab = el('label'), cb = el('input'); cb.type = 'checkbox'; cb.value = k;
      cb.addEventListener('change', function () { if (state.searched) run(); });  /* ticks only highlight, so redraw the current results at once */
      lab.appendChild(cb); lab.appendChild(document.createTextNode(window.ResearchCore.FLAG_LABELS[k])); fs3.appendChild(lab); return cb;
    });
    det.appendChild(fs3);
    var fs2 = el('fieldset'); fs2.appendChild(el('legend', null, 'Lead time and sign-off (estimates)'));
    var g2 = el('div', 'rt-grid');
    u.wR01 = numInput(8, 0); u.wR21 = numInput(6, 0); u.wK = numInput(8, 0); u.sign = numInput(5, 0);
    g2.appendChild(field('Weeks needed for an R01 (estimate)', u.wR01, 'rt-w1'));
    g2.appendChild(field('Weeks needed for an R21 (estimate)', u.wR21, 'rt-w2'));
    g2.appendChild(field('Weeks needed for a K award (estimate)', u.wK, 'rt-w3'));
    g2.appendChild(field('Sign-off at your institution, business days (estimate)', u.sign, 'rt-sg'));
    fs2.appendChild(g2);
    fs2.appendChild(el('p', 'rt-note', 'These are estimates you can change. Weekends are skipped; holidays are ignored. Check your own office for its real deadline.'));
    det.appendChild(fs2);
    det.appendChild(el('p', 'rt-note', 'Filters hide an opportunity only when its listing clearly conflicts. If a listing does not say, it stays and shows an "unknown" badge.'));
    var rb = el('div', 'rt-row'), again = el('button', 'rt-btn', 'Apply filters'); again.type = 'button';
    again.addEventListener('click', run); rb.appendChild(again); det.appendChild(rb);
    root.appendChild(det);

    u.stale = el('p', 'rt-stale'); u.stale.setAttribute('role', 'status'); u.stale.hidden = true;
    root.appendChild(u.stale);
    u.meta = el('p', 'rt-meta');
    root.appendChild(u.meta);
    updateMeta('');
    u.out = el('div'); u.out.id = 'rt-results'; u.out.setAttribute('aria-live', 'polite');
    root.appendChild(u.out);
    root.appendChild(el('p', 'rt-aid', 'Screening aid. Confirm every date and rule on Grants.gov before you act.'));
    render('Results appear here.');
  }

  function fetchJson(name) {
    return fetch('research/' + name, { cache: 'no-cache', credentials: 'same-origin' }).then(function (r) {
      if (!r.ok) throw new Error(name + ' ' + r.status);
      return r.json();
    });
  }

  function init(container) {
    if (state.started || !container) return;
    state.started = true;
    state.today = localToday();
    container.appendChild(el('p', 'rt-meta', 'Loading the opportunity list...'));
    Promise.all([fetchJson('research.json'), fetchJson('synonyms.json')]).then(function (res) {
      var data = res[0], rows = (data && data.rows) || [];
      state.rows = rows.filter(function (r) { return !(r.close && r.close < state.today); });
      state.asOf = data.as_of || 'unknown';
      state.sourceDate = data.source_date || data.as_of || 'unknown';
      state.index = window.ResearchCore.buildIndex(state.rows, res[1]);
      while (container.firstChild) container.removeChild(container.firstChild);
      buildUi(container);
    }).catch(function () {
      state.started = false;
      while (container.firstChild) container.removeChild(container.firstChild);
      container.appendChild(el('p', 'rt-empty', 'The opportunity list could not be loaded. Reload the page to try again.'));
    });
  }

  window.ResearchTab = { init: init };
})();
