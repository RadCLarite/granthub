'use strict';
const assert = require('assert');
const path = require('path');
const RC = require(path.join(__dirname, '..', '..', 'tool', 'research', 'research_core.js'));
const groups = require(path.join(__dirname, '..', '..', 'tool', 'research', 'synonyms.json'));
let n = 0;
function t(name, fn) { fn(); n++; }

const rows = [
  { id: 'a', title: 'stroke ct perfusion imaging', sum: '' },
  { id: 'b', title: 'breast cancer screening mammography', sum: '' },
  { id: 'c', title: 'cerebrovascular disease imaging', sum: '' },
  { id: 'd', title: 'grain subsidies', sum: '' },
];
const idx = RC.buildIndex(rows, groups);

t('tokenize basic', () => {
  const k = RC.tokenize('T2*-weighted β-amyloid <script>x</script>');
  assert(k.includes('t2')); assert(k.includes('weighted')); assert(!k.includes('β'));
  assert(k.includes('amyloid')); assert(k.includes('script'));
});
t('tokenize empty/stopwords', () => {
  assert.deepStrictEqual(RC.tokenize(''), []);
  assert.deepStrictEqual(RC.tokenize('the and of'), []);
  assert.deepStrictEqual(RC.tokenize(null), []);
});
t('tokenize stemming', () => {
  assert.deepStrictEqual(RC.tokenize('tumors class bus'), ['tumor', 'class', 'bus']);
});
t('synonyms file', () => {
  assert(groups.length >= 30);
  for (const g of groups) for (const w of g) assert(/^[a-z0-9]+$/.test(w), w);
});
t('expandTerms', () => {
  const e = RC.expandTerms(['stroke'], [['stroke', 'cva'], ['ct', 'computed']]);
  assert.deepStrictEqual(e.sort(), ['cva', 'stroke']);
});
t('search stroke ct', () => {
  const r = RC.search(idx, 'stroke CT');
  assert.strictEqual(r[0].id, 'a');
  const c = r.find(x => x.id === 'c');
  assert(c && c.matched.includes('cerebrovascular'));
  assert(!r.some(x => x.id === 'd'));
});
t('search empty', () => {
  assert.deepStrictEqual(RC.search(idx, ''), []);
  assert.deepStrictEqual(RC.search(idx, '   '), []);
});
t('deterministic', () => {
  assert.deepStrictEqual(RC.search(idx, 'imaging'), RC.search(idx, 'imaging'));
  const r = RC.search(idx, 'imaging');
  assert.deepStrictEqual(r.map(x => x.id).sort(), ['a', 'c']);
});
t('ties break by id ascending', () => {
  const ti = RC.buildIndex([{ id: 'z2', title: 'lung nodule', sum: '' }, { id: 'z1', title: 'lung nodule', sum: '' }, { id: 'y', title: 'grain', sum: '' }], groups);
  assert.deepStrictEqual(RC.search(ti, 'nodule').map(x => x.id), ['z1', 'z2']);
});
t('big query fast', () => {
  const words = ['alpha','beta','gamma','delta','stroke','imaging','tumor','grain','lung','heart'];
  const big = [];
  for (let i = 0; i < 1000; i++) big.push({ id: 'r' + String(i).padStart(4, '0'), title: 'w' + i + ' ' + words[i % 10], sum: words[(i * 3) % 10] + ' study ' + i });
  const bi = RC.buildIndex(big, groups);
  const q = []; for (let i = 0; i < 6000; i++) q.push(i % 7 === 0 ? 'w' + (i % 1000) : words[i % 10]);
  const t0 = Date.now();
  const r = RC.search(bi, q.join(' '), { limit: 25 });
  assert(Date.now() - t0 < 2000);
  assert(r.length <= 25 && r.length > 0);
  assert.strictEqual(RC.search(bi, 'stroke').length <= 50, true);
});
const TODAY = '2026-11-09';
t('businessDaysBefore', () => {
  assert.strictEqual(RC.businessDaysBefore('2026-11-20', 5), '2026-11-13');
  assert.strictEqual(RC.businessDaysBefore('2026-11-12', 5), '2026-11-05');
  assert.strictEqual(RC.businessDaysBefore('2026-11-20', 0), '2026-11-20');
});
t('daysUntil', () => {
  assert.strictEqual(RC.daysUntil('2026-11-12', TODAY), 3);
  assert.strictEqual(RC.daysUntil(TODAY, TODAY), 0);
  assert.strictEqual(RC.daysUntil(null, TODAY), null);
});
t('timeWarning cases', () => {
  const w = (mech, close, s) => RC.timeWarning({ mech: mech, close: close }, TODAY, s);
  let r = w('R01', '2026-11-20');
  assert.strictEqual(r.level, 'tight'); assert.strictEqual(r.daysToInstitution, 4); assert.strictEqual(r.needDays, 56);
  r = w('R01', '2026-11-12');
  assert.strictEqual(r.level, 'late'); assert.strictEqual(r.daysToInstitution, -4);
  r = w('R01', '2027-03-01');
  assert.strictEqual(r.level, 'ok'); assert.strictEqual(r.daysToInstitution, 105);
  r = w('K99', '2027-03-01');
  assert.strictEqual(r.level, 'ok'); assert.strictEqual(r.needDays, 56);
  assert.strictEqual(w('R03', '2027-03-01').level, 'unknown');
  r = w('R01', null);
  assert.strictEqual(r.level, 'unknown'); assert(r.reason.indexOf('date not announced') >= 0);
  assert.strictEqual(w('R01', TODAY).level, 'late');
  assert.strictEqual(w('R01', '2026-11-20', { signoffBusinessDays: 0 }).daysToInstitution, 11);
  assert.strictEqual(w('R21', '2026-12-20', { leadWeeks: { R21: 2 } }).needDays, 14);
});
t('filters', () => {
  const R = [
    { id: 'u', elig: '06|20', trial: 'required', ceil: 100000, floor: null, mech: 'R01' },
    { id: 's', elig: '23', trial: 'optional', ceil: null, floor: null, mech: 'K99' },
    { id: 'x', elig: '99', trial: null, ceil: 900000, floor: 600000, mech: null },
    { id: 'e', elig: '', trial: 'not_allowed', ceil: 1000000, floor: null, mech: 'F31' },
  ];
  let r = RC.applyFilters(R, { institution: 'small_business' });
  assert.deepStrictEqual(r.kept.map(x => x.id), ['s', 'x', 'e']);
  assert.deepStrictEqual(r.unknown, { e: ['institution'] });
  assert.deepStrictEqual(r.removedBy, { institution: 1 });
  r = RC.applyFilters(R, { trial: 'no' });
  assert.deepStrictEqual(r.kept.map(x => x.id), ['s', 'x', 'e']);
  assert.strictEqual(r.removedBy.trial, 1);
  assert.deepStrictEqual(r.unknown.x, ['trial']);
  r = RC.applyFilters(R, { trial: 'yes' });
  assert.deepStrictEqual(r.kept.map(x => x.id), ['u', 's', 'x']);
  r = RC.applyFilters(R, { budgetMin: 500000 });
  assert.deepStrictEqual(r.kept.map(x => x.id), ['s', 'x', 'e']);
  assert.deepStrictEqual(r.unknown.s, ['budget']);
  r = RC.applyFilters(R, { budgetMax: 500000 });
  assert.deepStrictEqual(r.kept.map(x => x.id), ['u', 's', 'e']);
  r = RC.applyFilters(R, { career: 'trainee' });
  assert.deepStrictEqual(r.kept.map(x => x.id), ['s', 'x', 'e']);
  assert.deepStrictEqual(r.removedBy, { career: 1 });
  assert.deepStrictEqual(r.unknown.x, ['career']);
  r = RC.applyFilters(R, { career: 'established' });
  assert.deepStrictEqual(r.kept.map(x => x.id), ['u', 'x']);
  r = RC.applyFilters(R, { career: 'early' });
  assert.deepStrictEqual(r.kept.map(x => x.id), ['u', 's', 'x']);
  r = RC.applyFilters(R, { mechs: ['R01'] });
  assert.deepStrictEqual(r.kept.map(x => x.id), ['u', 'x']);
  assert.strictEqual(r.removedBy.mechs, 2);
  r = RC.applyFilters(R, {});
  assert.strictEqual(r.kept.length, 4); assert.deepStrictEqual(r.unknown, {}); assert.deepStrictEqual(r.removedBy, {});
});
t('fix round 1', () => {
  const w = (mech, close, st) => RC.timeWarning({ mech: mech, close: close }, TODAY, st);
  const st = { leadWeeks: { R01: 1 } };
  assert.strictEqual(w('R01', '2027-03-01', st).needDays, 7);
  assert.strictEqual(w('R21', '2027-03-01', st).needDays, 42);
  assert.strictEqual(w('K99', '2027-03-01', st).needDays, 56);
  assert.strictEqual(RC.businessDaysBefore('2026-12-02', 5), '2026-11-25');
  assert.strictEqual(RC.businessDaysBefore('2027-01-05', 5), '2026-12-29');
  assert.strictEqual(RC.businessDaysBefore('2026-11-14', 1), '2026-11-13');
  assert.strictEqual(RC.daysUntil('2026-13-45', TODAY), null);
  assert.strictEqual(RC.daysUntil('2026-02-31', TODAY), null);
  const r = w('R01', '2026-02-31');
  assert.strictEqual(r.level, 'unknown'); assert.strictEqual(r.reason, 'Date could not be read.');
  assert(w('R01', null).reason.indexOf('date not announced') >= 0);
  assert(w('R01', '2026-11-08', { signoffBusinessDays: 0 }).reason.indexOf('1 day ago') >= 0);
  assert(w('R01', '2026-11-07', { signoffBusinessDays: 0 }).reason.indexOf('2 days ago') >= 0);
  const R = [{ id: 'a', mech: 'R01', ceil: 100000 }, { id: 'b', mech: null, ceil: null }];
  let o = RC.applyFilters(R, { mechs: [], institution: null, trial: null, career: null, budgetMin: null, budgetMax: undefined });
  assert.strictEqual(o.kept.length, 2); assert.deepStrictEqual(o.unknown, {}); assert.deepStrictEqual(o.removedBy, {});
  o = RC.applyFilters(R, { budgetMin: '500000' });
  assert.deepStrictEqual(o.kept.map(x => x.id), ['b']); assert.strictEqual(o.removedBy.budget, 1);
  o = RC.applyFilters([{ id: 'f', floor: 600000, ceil: 900000 }], { budgetMin: '  ', budgetMax: '  ' });
  assert.strictEqual(o.kept.length, 1); assert.deepStrictEqual(o.removedBy, {});
  o = RC.applyFilters(R, { budgetMin: 'abc', budgetMax: '' });
  assert.strictEqual(o.kept.length, 2);
});
t('ceil null survives a budget minimum (0 ceilings are emitted as null)', () => {
  const o = RC.applyFilters([{ id: 'z', ceil: null, floor: null }, { id: 'y', ceil: 50000, floor: null }], { budgetMin: 100000 });
  assert.deepStrictEqual(o.kept.map(x => x.id), ['z']);
  assert.deepStrictEqual(o.unknown, { z: ['budget'] });
  assert.strictEqual(o.removedBy.budget, 1);
});
t('university filter: code 25 alone is unknown, not removed', () => {
  const R = [{ id: 'u', elig: '25' }, { id: 'v', elig: '25|12' }, { id: 'w', elig: '12' }, { id: 'x', elig: '20|25' }];
  const o = RC.applyFilters(R, { institution: 'university' });
  assert.deepStrictEqual(o.kept.map(x => x.id), ['u', 'v', 'x']);
  assert.deepStrictEqual(o.unknown, { u: ['institution'], v: ['institution'] });
  assert.deepStrictEqual(o.removedBy, { institution: 1 });
});
t('daysSince and staleNotice threshold', () => {
  assert.strictEqual(RC.daysSince('2026-11-06', '2026-11-09'), 3);
  assert.strictEqual(RC.daysSince('2026-11-06', '2026-11-06'), 0);
  assert.strictEqual(RC.daysSince('bad', '2026-11-06'), null);
  assert.strictEqual(RC.staleNotice('2026-11-06', '2026-11-08'), null);
  assert.strictEqual(RC.staleNotice('2026-11-06', '2026-11-09'),
    'These listings are 3 days old. Newer postings are missing. Check Grants.gov for anything posted since.');
  assert.strictEqual(RC.staleNotice(undefined, '2026-11-09'), null);
  assert(RC.staleNotice('2026-11-06', '2026-12-01').indexOf('25 days old') >= 0);
});

const { scoreTestset } = require(path.join(__dirname, 'run_testset.js'));
t('scoreTestset empty sample', () => {
  const r = scoreTestset([{ id: 'a', title: 'x', sum: '', ic: 'NS', mech: 'R01' }], [], []);
  assert.strictEqual(r.summary.awards, 0);
  assert(r.summary.text.indexOf('0 awards') >= 0);
});
t('scoreTestset one hit and one not-testable', () => {
  const pool = [
    { id: 'p1', title: 'stroke perfusion imaging', sum: 'ct perfusion in acute stroke', ic: 'NS', mech: 'R01' },
    { id: 'p2', title: 'grain subsidies', sum: '', ic: null, mech: null },
  ];
  const aw = [
    { id: 'x1', ic: 'NS', mechanism: 'R01', title: 'stroke ct perfusion', abstract: 'imaging of acute stroke' },
    { id: 'x2', ic: 'HL', mechanism: 'R01', title: 'stroke ct perfusion', abstract: 'imaging of acute stroke' },
  ];
  const r = scoreTestset(pool, aw, []);
  assert.strictEqual(r.summary.awards, 2);
  assert.strictEqual(r.perAward[0].ic_rank, 1); assert.strictEqual(r.perAward[0].mech_rank, 1);
  assert.strictEqual(r.perAward[0].hit_ic_and_mech, true);
  assert.strictEqual(r.perAward[1].ic_testable, false); assert.strictEqual(r.perAward[1].ic_rank, null);
  assert.strictEqual(r.perAward[1].mech_testable, true);
  assert.strictEqual(r.summary.ic_testable, 1); assert.strictEqual(r.summary.ic_hits, 1);
  assert.strictEqual(r.summary.mech_testable, 2); assert.strictEqual(r.summary.mech_hits, 2);
  assert.strictEqual(r.summary.ic_not_testable, 1);
  assert.strictEqual(r.summary.funder_known, 0.5);
  assert(r.summary.text.indexOf('1 of 1') >= 0);
});
/* ---- phrase handling (Task 1) ---- */
const prows = [
  { id: 'p1', title: 'CT perfusion imaging in acute stroke', sum: '' },
  { id: 'p2', title: 'Perfusion of the heart; CT of the lung', sum: '' },
  { id: 'p3', title: 'Stroke outcomes', sum: 'Advanced CT perfusion protocols' },
  { id: 'p4', title: 'Stroke of the brain tumors', sum: '' },
  { id: 'p5', title: 'Lung CT', sum: 'perfusion study' },
];
const pidx = RC.buildIndex(prows, groups);
const ids = r => r.map(x => x.id);
t('parseQuery basics', () => {
  const p = RC.parseQuery('"CT perfusion" stroke');
  assert.strictEqual(p.plain, ' CT perfusion  stroke');
  assert.deepStrictEqual(p.phrases, [{ text: 'CT perfusion', tokens: ['ct', 'perfusion'] }]);
  assert.deepStrictEqual(RC.parseQuery('“ct perfusion”').phrases[0].tokens, ['ct', 'perfusion']);
});
t('parseQuery malformed', () => {
  const u = RC.parseQuery('"ct perfusion');
  assert.deepStrictEqual(u.phrases, []);
  assert.deepStrictEqual(RC.tokenize(u.plain), ['ct', 'perfusion']);
  assert.deepStrictEqual(RC.parseQuery('""').phrases, []);
  assert.deepStrictEqual(RC.parseQuery('"the of"').phrases, []);
  assert.strictEqual(RC.parseQuery('"a1 b1" "a1 b1"').phrases.length, 1);
  const six = ['a1 b1', 'c1 d1', 'e1 f1', 'g1 h1', 'i1 j1', 'k1 l1'].map(s => '"' + s + '"').join(' ');
  assert.strictEqual(RC.parseQuery(six).phrases.length, 5);
});
t('parseQuery odd number of quote marks ignores them all', () => {
  const p = RC.parseQuery('5" display "deep learning"');
  assert.deepStrictEqual(p.phrases, []);
  assert.deepStrictEqual(RC.tokenize(p.plain), ['display', 'deep', 'learning']);
  assert.strictEqual(RC.parseQuery('"a1 b1" "c1 d1" "e1').phrases.length, 0);
  assert.strictEqual(RC.parseQuery('"a1 b1" "c1 d1"').phrases.length, 2);
});
t('parseQuery long query ignores quotes', () => {
  const q = 'word '.repeat(60) + '"ct perfusion"';
  assert(q.length > 200);
  assert.deepStrictEqual(RC.parseQuery(q).phrases, []);
});
t('phrase filter', () => {
  assert.deepStrictEqual(ids(RC.search(pidx, '"ct perfusion"')).sort(), ['p1', 'p3']);
  assert(ids(RC.search(pidx, '"ct perfusion"', { phraseFilter: false })).includes('p2'));
});
t('phrase filter keeps ranking order', () => {
  const f = ids(RC.search(pidx, '"ct perfusion" stroke', { phraseBoost: 0 }));
  const u = ids(RC.search(pidx, 'ct perfusion stroke', { phraseBoost: 0 })).filter(i => !['p2', 'p4', 'p5'].includes(i));
  assert.deepStrictEqual(f, u);
});
t('phrase stop words and plurals', () => {
  assert.deepStrictEqual(ids(RC.search(pidx, '"stroke brain tumor"')), ['p4']);
  assert.deepStrictEqual(RC.search(pidx, '"stroke tumors"'), []);
});
t('phrase does not straddle title and summary', () => {
  assert(!ids(RC.search(pidx, '"ct perfusion"')).includes('p5'));
});
t('two phrases are ANDed', () => {
  assert.deepStrictEqual(ids(RC.search(pidx, '"ct perfusion" "acute stroke"')), ['p1']);
});
t('single-word phrase', () => {
  assert.deepStrictEqual(ids(RC.search(pidx, '"perfusion"')).sort(), ['p1', 'p2', 'p3', 'p5']);
});
/* ---- adjacent-word boost (Task 2) ---- */
const brows = [
  { id: 'z1', title: 'perfusion lung ct', sum: '' },
  { id: 'z2', title: 'ct perfusion lung', sum: '' },
  { id: 'y1', title: 'grain subsidies', sum: '' },
  { id: 'y2', title: 'crop yields', sum: '' },
];
const bidx = RC.buildIndex(brows, []);
const score = (r, id) => r.find(x => x.id === id).score;
t('boost reorders adjacent first', () => {
  const on = RC.search(bidx, 'ct perfusion'), off = RC.search(bidx, 'ct perfusion', { phraseBoost: 0 });
  assert.deepStrictEqual(ids(on).slice(0, 2), ['z2', 'z1']);
  assert.deepStrictEqual(ids(off).slice(0, 2), ['z1', 'z2']);
  assert.strictEqual(score(off, 'z1'), score(off, 'z2'));
});
t('boost size', () => {
  const on = RC.search(bidx, 'ct perfusion');
  assert(Math.abs((score(on, 'z2') - score(on, 'z1')) - 0.5 * Math.LN2) < 1e-9);
});
t('boost adds no rows', () => {
  const q = 'ct perfusion stroke';
  assert.deepStrictEqual(ids(RC.search(pidx, q)).sort(), ids(RC.search(pidx, q, { phraseBoost: 0 })).sort());
});
t('boost bridges stop words', () => {
  const kidx = RC.buildIndex([
    { id: 'k1', title: 'ct perfusion', sum: '' }, { id: 'k2', title: 'perfusion of the ct', sum: '' },
    { id: 'f1', title: 'grain subsidies', sum: '' }, { id: 'f2', title: 'crop yields', sum: '' }], []);
  assert.deepStrictEqual(ids(RC.search(kidx, 'perfusion ct')).slice(0, 2), ['k2', 'k1']);
  assert.deepStrictEqual(ids(RC.search(kidx, 'perfusion ct', { phraseBoost: 0 })).slice(0, 2), ['k1', 'k2']);
});
t('boost is order-sensitive', () => {
  const r = RC.search(bidx, 'perfusion ct');
  assert.strictEqual(score(r, 'z1'), score(r, 'z2'));
  assert.strictEqual(ids(r)[0], 'z1');
});
t('boost deterministic and bounded', () => {
  const words = ['alpha','beta','gamma','delta','stroke','imaging','tumor','grain','lung','heart'];
  const big = [];
  for (let i = 0; i < 1225; i++) big.push({ id: 'r' + String(i).padStart(4, '0'), title: 'w' + i + ' ' + words[i % 10], sum: words[(i * 3) % 10] + ' study ' + words[(i * 7) % 10] + ' ' + i });
  const bi = RC.buildIndex(big, groups);
  const q = []; for (let i = 0; i < 500; i++) q.push(i % 7 === 0 ? 'w' + (i % 1000) : words[(i * i) % 10]);
  const text = q.join(' ').slice(0, 3000);
  const t0 = Date.now();
  const a = RC.search(bi, text, { limit: 25 });
  assert(Date.now() - t0 < 2000);
  assert.deepStrictEqual(a, RC.search(bi, text, { limit: 25 }));
});
t('bad phraseBoost values fall back to the default', () => {
  const d = RC.search(bidx, 'ct perfusion');
  for (const bad of [-1, NaN, 'x']) assert.deepStrictEqual(RC.search(bidx, 'ct perfusion', { phraseBoost: bad }), d);
});
t('scoreTestset passes search options', () => {
  const { scoreTestset } = require(path.join(__dirname, 'run_testset.js'));
  const srows = [
    { id: 'z1', title: 'perfusion lung ct', sum: '', ic: 'AA' },
    { id: 'z2', title: 'ct perfusion lung', sum: '', ic: 'BB' },
    { id: 'y1', title: 'grain subsidies', sum: '', ic: 'CC' },
    { id: 'y2', title: 'crop yields', sum: '', ic: 'CC' },
  ];
  const aw = [{ id: 'a1', ic: 'BB', abstract: 'ct perfusion' }];
  assert.strictEqual(scoreTestset(srows, aw, []).perAward[0].ic_rank, 1);
  assert.strictEqual(scoreTestset(srows, aw, [], { phraseBoost: 0 }).perAward[0].ic_rank, 2);
});
t('parseQuery treats guillemets and low-9 quotes as quote marks', () => {
  assert.deepStrictEqual(RC.parseQuery('«deep learning» imaging').phrases.map(p => p.tokens), [['deep', 'learning']]);
  assert.deepStrictEqual(RC.parseQuery('„deep learning“ imaging').phrases.map(p => p.tokens), [['deep', 'learning']]);
  assert(!/[«»„]/.test(RC.parseQuery('«deep learning» imaging').plain));
});
t('phrase words survive the 40-term cap', () => {
  const fill = [], many = [];
  for (let i = 0; i < 45; i++) many.push('q' + (i < 10 ? '0' : '') + i);  /* 3-char tokens keep the query under the 200-char phrase limit */
  for (let i = 0; i < 60; i++) fill.push({ id: 'f' + i, title: 'alpha beta filler ' + (i < 45 ? many[i] : 'plain'), sum: '' });
  fill.push({ id: 'hit', title: 'alpha beta study', sum: '' });
  const capIdx = RC.buildIndex(fill, []);
  const qs = '"alpha beta" ' + many.join(' ');
  assert(qs.length <= RC.PHRASE_QUERY_MAX_CHARS, 'query must stay within the phrase limit');
  const res = RC.search(capIdx, '"alpha beta" ' + many.join(' '), { limit: 100 });
  assert(res.some(r => r.id === 'hit'), 'phrase row must not be dropped by the term cap');
});
t('phraseNotices builds the tab messages', () => {
  const one = RC.phraseNotices(RC.parseQuery('"artificial intelligence" grants').phrases);
  assert.strictEqual(one.prefix, 'Exact phrase required: “artificial intelligence”. ');
  assert(/the exact phrase “artificial intelligence”\. Remove the quotes/.test(one.empty));
  const two = RC.phraseNotices(RC.parseQuery('"deep learning" "mri scans"').phrases);
  assert(/all of these exact phrases: “deep learning”, “mri scans”/.test(two.empty));
  const none = RC.phraseNotices([]);
  assert.strictEqual(none.prefix, ''); assert.strictEqual(none.empty, '');
});
t('phrase tip states the length limit it enforces', () => {
  assert(RC.PHRASE_TIP.indexOf(String(RC.PHRASE_QUERY_MAX_CHARS)) >= 0);
});
t('boost overhead stays small on a 3,000-char search over a larger pool', () => {
  /* Benchmark: synthetic Zipf-like pool of 5,000 rows (the live pool is 1,225); a 3,000-char query is the worst case the tab allows.
     The boost may cost at most as much as the rest of the search plus 3 ms; median of 9 runs keeps it steady on a busy machine. */
  let seed = 1; const rnd = () => (seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296;
  const V = 3000, vocab = []; for (let i = 0; i < V; i++) vocab.push('w' + i.toString(36) + 'x');
  const word = () => vocab[Math.floor(Math.pow(rnd(), 2) * V)];
  const big = [];
  for (let i = 0; i < 5000; i++) {
    const ti = [], su = []; for (let k = 0; k < 8; k++) ti.push(word()); for (let k = 0; k < 120; k++) su.push(word());
    big.push({ id: 'r' + i, title: ti.join(' '), sum: su.join(' ') });
  }
  const bidx = RC.buildIndex(big, []);
  const qw = []; while (qw.join(' ').length < 3000) qw.push(word());
  const query = qw.join(' ').slice(0, 3000);
  const med = a => a.sort((x, y) => x - y)[a.length >> 1];
  const time = o => { const ts = []; for (let i = 0; i < 9; i++) { const t0 = process.hrtime.bigint(); RC.search(bidx, query, o); ts.push(Number(process.hrtime.bigint() - t0) / 1e6); } return med(ts); };
  time({ phraseBoost: 0 });
  const off = time({ phraseBoost: 0 }), on = time({});
  assert(on - off <= off + 3, 'boost overhead ' + (on - off).toFixed(1) + ' ms against ' + off.toFixed(1) + ' ms for the rest of the search');
});
t('flagNotes puts ticked flags first and lists ticked unknowns', () => {
  const a = RC.flagNotes({ flags: { foreign: 'yes', loi: 'yes' } }, ['loi']);
  assert.deepStrictEqual(a.shown.map(x => x.key), ['loi', 'foreign']);
  assert.strictEqual(a.shown[0].state, 'yes');
  assert.deepStrictEqual(a.unknownTicked, []);
  const b = RC.flagNotes({ flags: {} }, ['ind_ide']);
  assert.deepStrictEqual(b.shown, []);
  assert.deepStrictEqual(b.unknownTicked, [{ key: 'ind_ide', label: RC.FLAG_LABELS.ind_ide }]);
});
t('flagNotes tolerates missing, null and array flags', () => {
  assert.deepStrictEqual(RC.flagNotes({}, []).shown, []);
  assert.deepStrictEqual(RC.flagNotes({ flags: null }, ['loi']).unknownTicked.length, 1);
  assert.deepStrictEqual(RC.flagNotes({ flags: [] }, []).shown, []);
  assert.deepStrictEqual(RC.flagNotes({ flags: { loi: 'yes' } }, ['nonsense']).unknownTicked, []);
});
t('FLAG_LABELS has the nine keys and never says required', () => {
  assert.deepStrictEqual(Object.keys(RC.FLAG_LABELS).sort(), ['animals', 'cost_share', 'data_sharing', 'foreign', 'human_subjects', 'ind_ide', 'loi', 'multi_pi', 'subaward']);
  Object.keys(RC.FLAG_LABELS).forEach(k => assert(!/required/i.test(RC.FLAG_LABELS[k]), k));
  assert.strictEqual(RC.flagNotes({ flags: { cost_share: 'no' } }, []).shown[0].state, 'no');
});
t('foundationStale uses 365 days and treats blank as stale', () => {
  assert.strictEqual(RC.foundationStale('2025-01-01', '2026-11-10'), true);
  assert.strictEqual(RC.foundationStale('2026-06-01', '2026-11-10'), false);
  assert.strictEqual(RC.foundationStale('', '2026-11-10'), true);
  assert.strictEqual(RC.foundationStale(null, '2026-11-10'), true);
  assert.strictEqual(RC.foundationStale('2025-11-10', '2026-11-10'), false);
  assert.strictEqual(RC.foundationStale('2025-11-09', '2026-11-10'), true);
});
t('searchFoundations ranks by focus and name, and rejects empty queries', () => {
  const fr = [
    { id: 'f1', name: 'Cardiology Fund', focus: 'Supports heart failure trials and arrhythmia research.' },
    { id: 'f2', name: 'Neuro Fund', focus: 'Supports stroke imaging, perfusion and cerebrovascular research.' },
  ];
  const fi = RC.buildFoundationIndex(fr, groups);
  const res = RC.searchFoundations(fi, 'stroke perfusion imaging', {});
  assert.strictEqual(res[0].id, 'f2');
  assert.deepStrictEqual(RC.searchFoundations(fi, 'the and of', {}), []);
  assert.deepStrictEqual(RC.searchFoundations(RC.buildFoundationIndex([], groups), 'stroke', {}), []);
  assert.strictEqual(RC.searchFoundations(fi, '"heart failure"', {})[0].id, 'f1');
});
t('buildIcs writes one all-day event per dated row, escaped, with CRLF', () => {
  const rows = [
    { id: 'r1', title: 'Cancer, imaging; R01 & <b>', close: '2026-12-01', url: 'https://example.org/1', num: 'PAR-1' },
    { id: 'r2', title: 'No date', close: null, url: 'https://example.org/2', num: 'PAR-2' },
  ];
  const ics = RC.buildIcs(rows, '20261110T120000Z');
  assert(ics.startsWith('BEGIN:VCALENDAR\r\n'));
  assert(ics.endsWith('END:VCALENDAR\r\n'));
  assert.strictEqual(ics.split('BEGIN:VEVENT').length - 1, 1);
  assert(ics.includes('DTSTART;VALUE=DATE:20261201\r\n'));
  assert(ics.includes('DTEND;VALUE=DATE:20261202\r\n'));
  assert(ics.includes('DTSTAMP:20261110T120000Z\r\n'));
  assert(ics.includes('UID:research-r1@ffm\r\n'));
  assert(ics.includes('SUMMARY:Closes: Cancer\\, imaging\\; R01 & <b>\r\n'));
  assert(!ics.includes('No date'));
  assert(!/[^\r]\n/.test(ics), 'every line break is CRLF');
});
t('buildIcs rolls over month and year ends, and gives nothing for undated input', () => {
  assert(RC.buildIcs([{ id: 'a', title: 'x', close: '2026-12-31' }], '20261110T120000Z').includes('DTEND;VALUE=DATE:20270101'));
  assert(RC.buildIcs([{ id: 'a', title: 'x', close: '2028-02-28' }], '20261110T120000Z').includes('DTEND;VALUE=DATE:20280229'));
  assert.strictEqual(RC.buildIcs([{ id: 'a', title: 'x', close: null }], '20261110T120000Z'), '');
  assert.strictEqual(RC.buildIcs([], '20261110T120000Z'), '');
  assert.strictEqual(RC.buildIcs([{ id: 'a', title: 'x', close: 'soon' }], '20261110T120000Z'), '');
});
t('cleanPublicationList drops numbering, doi and urls but keeps title words', () => {
  const out = RC.cleanPublicationList('1. Smith J, et al. Deep learning for stroke. Radiology 2024. doi:10.1148/radiol.1234\n[2] Lee K. Perfusion CT. https://doi.org/10.1000/xyz123');
  assert(!/(^|\n)\s*1\./.test(out) && !out.includes('[2]'));
  assert(!/doi/i.test(out) && !out.includes('10.1148') && !out.includes('http'));
  assert(out.includes('Deep learning for stroke') && out.includes('Perfusion CT') && out.includes('2024'));
  assert.strictEqual(RC.cleanPublicationList(''), '');
  assert.strictEqual(RC.cleanPublicationList(null), '');
});
t('normalizeOrcid accepts prefixes, spaces and lower-case x, and checks the digit', () => {
  ['0000-0002-1825-0097', 'https://orcid.org/0000-0002-1825-0097', ' 0000 0002 1825 0097 ', '0000000218250097', 'http://orcid.org/0000-0002-1825-0097'].forEach(v =>
    assert.strictEqual(RC.normalizeOrcid(v), '0000-0002-1825-0097', v));
  assert.strictEqual(RC.normalizeOrcid('0000-0002-1694-233x'), '0000-0002-1694-233X');
  ['0000-0002-1825-0098', '0000-0002-1825', '', 'abcd-efgh-ijkl-mnop', null, undefined, 12345, '0000-0002-1825-0097-9', 'https://evil.example/0000-0002-1825-0097'].forEach(v =>
    assert.strictEqual(RC.normalizeOrcid(v), null, String(v)));
});
t('openAlexWorksUrl is the exact one-host request', () => {
  const u = RC.openAlexWorksUrl('0000-0002-1825-0097');
  assert.strictEqual(u, 'https://api.openalex.org/works?filter=authorships.author.orcid:https://orcid.org/0000-0002-1825-0097&sort=publication_year:desc&per-page=25&select=title,publication_year,abstract_inverted_index,topics');
  assert(RC.openAlexWorksUrl('0000-0002-1825-0097', 5).includes('per-page=5&'));
  assert.strictEqual((u.match(/https?:\/\/[^/]+/g) || []).filter(h => h !== 'https://orcid.org').join(), 'https://api.openalex.org');
});
t('worksToText rebuilds abstracts by position and tolerates gaps', () => {
  const w = [{ title: 'A', abstract_inverted_index: { Deep: [0], learning: [1], helps: [2, 4], stroke: [3] }, topics: [{ display_name: 'Stroke' }, { display_name: 'Imaging' }, { display_name: 'Third' }] }];
  assert.strictEqual(RC.worksToText(w).replace(/\s+/g, ' ').trim(), 'A Deep learning helps stroke helps Stroke Imaging');
  assert.strictEqual(RC.worksToText([{ title: 'Only title', abstract_inverted_index: null }]).trim(), 'Only title');
  assert.strictEqual(RC.worksToText([{ title: '', abstract_inverted_index: null }, null, {}]), '');
  assert.strictEqual(RC.worksToText([]), '');
  assert.strictEqual(RC.worksToText(null), '');
  const many = []; for (let i = 0; i < 400; i++) many.push({ title: 'Paper number ' + i + ' about perfusion imaging', abstract_inverted_index: { alpha: [0], beta: [1], gamma: [2] } });
  const out = RC.worksToText(many);
  assert(out.length <= 3000);
  assert(/\w$/.test(out) && out.split(/\s+/).every(t => /^(Paper|number|\d+|about|perfusion|imaging|alpha|beta|gamma)$/.test(t)), 'cut on a word boundary');
});
console.log(n + ' tests pass');
