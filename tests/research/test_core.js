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
console.log(n + ' tests pass');
