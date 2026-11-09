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
console.log(n + ' tests pass');
