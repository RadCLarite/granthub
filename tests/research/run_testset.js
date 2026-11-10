'use strict';
/* Test-set harness for the researcher tab search.
   scoreTestset(rows, awards, groups) is pure; the CLI wrapper reads files and writes outs/research_testset_report.csv.
   It measures how well an award abstract finds CURRENTLY OPEN opportunities of the same funder (ic) and mechanism: a proxy.
   An award is "not testable" for a metric when no pool row has that ic (or mech); it leaves that metric's denominator.
   "IC and mechanism each in top 10" = the first same-ic result AND the first same-mechanism result are each within the top 10 (not necessarily one row). */
const fs = require('fs');
const path = require('path');
const RC = require(path.join(__dirname, '..', '..', 'tool', 'research', 'research_core.js'));
const LIMIT = 50, TOP = 10;

function firstRank(results, byId, field, want) {
  for (let i = 0; i < results.length; i++) {
    const r = byId.get(results[i].id);
    if (r && r[field] != null && String(r[field]).toUpperCase() === want) return i + 1;
  }
  return null;
}
const pct = (a, b) => b ? (100 * a / b).toFixed(1) + '%' : 'n/a';
const mean = a => a.length ? a.reduce((x, y) => x + y, 0) / a.length : null;

function scoreTestset(rows, awards, groups, opts) {
  const index = RC.buildIndex(rows, groups || []);
  const byId = new Map(rows.map(r => [String(r.id), r]));
  const nPool = rows.length;
  const cnt = (field, v) => rows.filter(r => r[field] != null && String(r[field]).toUpperCase() === v).length;
  const known = f => nPool ? rows.filter(r => r[f] != null && r[f] !== '').length / nPool : 0;
  const perAward = [], baseIc = [], baseMech = [];
  for (const a of awards) {
    const ic = a.ic ? String(a.ic).toUpperCase() : null, mech = a.mechanism ? String(a.mechanism).toUpperCase() : null;
    const nIc = ic ? cnt('ic', ic) : 0, nMech = mech ? cnt('mech', mech) : 0;
    const ic_testable = nIc > 0, mech_testable = nMech > 0;
    const res = RC.search(index, [a.title, a.abstract].filter(Boolean).join(' '), Object.assign({ limit: LIMIT }, opts));
    const ic_rank = ic_testable ? firstRank(res, byId, 'ic', ic) : null;
    const mech_rank = mech_testable ? firstRank(res, byId, 'mech', mech) : null;
    const hit_ic = ic_testable ? ic_rank != null && ic_rank <= TOP : null;
    const hit_mech = mech_testable ? mech_rank != null && mech_rank <= TOP : null;
    const hit_ic_and_mech = ic_testable && mech_testable ? !!(hit_ic && hit_mech) : null;
    if (ic_testable) baseIc.push(1 - Math.pow(1 - nIc / nPool, TOP));
    if (mech_testable) baseMech.push(1 - Math.pow(1 - nMech / nPool, TOP));
    perAward.push({ id: a.id, source: a.source || '', topic: a.topic || '', ic: ic || '', mechanism: mech || '',
      ic_testable, mech_testable, ic_rank, mech_rank, hit_ic, hit_mech, hit_ic_and_mech, results: res.length });
  }
  const tally = (key, tk) => {
    const t = perAward.filter(p => p[tk]);
    return { testable: t.length, hits: t.filter(p => p[key]).length, not_testable: perAward.length - t.length };
  };
  const bothT = perAward.filter(p => p.ic_testable && p.mech_testable);
  const ic = tally('hit_ic', 'ic_testable'), mech = tally('hit_mech', 'mech_testable');
  const both = { testable: bothT.length, hits: bothT.filter(p => p.hit_ic_and_mech).length, not_testable: perAward.length - bothT.length };
  const summary = {
    awards: awards.length, pool: nPool,
    ic_testable: ic.testable, ic_hits: ic.hits, ic_not_testable: ic.not_testable,
    mech_testable: mech.testable, mech_hits: mech.hits, mech_not_testable: mech.not_testable,
    both_testable: both.testable, both_hits: both.hits, both_not_testable: both.not_testable,
    funder_known: known('ic'), mech_known: known('mech'),
    baseline_ic: mean(baseIc), baseline_mech: mean(baseMech),
  };
  const line = (n, o) => n + ': ' + o.hits + ' of ' + o.testable + ' testable in top ' + TOP + ' (' + pct(o.hits, o.testable) + '), ' + o.not_testable + ' not testable';
  const b = x => x == null ? 'n/a' : (100 * x).toFixed(1) + '%';
  summary.text = [
    summary.awards + ' awards run against a pool of ' + nPool + ' opportunities (search limit ' + LIMIT + ')',
    line('IC hit@10', ic), line('Mechanism hit@10', mech), line('IC and mechanism each in top 10 (separate rows)', both),
    'Pool share with known IC (funder_known): ' + b(summary.funder_known) + '; known mechanism (mech_known): ' + b(summary.mech_known),
    'Random baseline (mean 1-(1-p)^10): IC ' + b(summary.baseline_ic) + ', mechanism ' + b(summary.baseline_mech),
  ].join('\n');
  return { perAward, summary };
}

function toCsv(perAward) {
  const cols = ['id', 'source', 'topic', 'ic', 'mechanism', 'ic_testable', 'mech_testable', 'ic_rank', 'mech_rank', 'hit_ic', 'hit_mech', 'hit_ic_and_mech', 'results'];
  const esc = v => { const s = v == null ? '' : String(v); return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s; };
  return [cols.join(',')].concat(perAward.map(p => cols.map(c => esc(p[c])).join(','))).join('\n') + '\n';
}

if (require.main === module) {
  const root = path.join(__dirname, '..', '..');
  const load = (...p) => JSON.parse(fs.readFileSync(path.join(root, ...p), 'utf8'));
  const rows = load('data', 'processed', 'research.json').rows;
  const awards = load('data', 'research_testset', 'reporter_sample.json').concat(load('data', 'research_testset', 'owner_abstracts.json'))
    .filter(a => a.abstract && String(a.abstract).trim());
  const groups = process.argv.includes('--no-synonyms') ? [] : load('tool', 'research', 'synonyms.json');
  const boostArg = process.argv.find(a => a.indexOf('--phrase-boost=') === 0);
  const r = scoreTestset(rows, awards, groups, boostArg ? { phraseBoost: Number(boostArg.slice('--phrase-boost='.length)) } : undefined);
  if (process.argv.length <= 2) {
    fs.mkdirSync(path.join(root, 'outs'), { recursive: true });
    fs.writeFileSync(path.join(root, 'outs', 'research_testset_report.csv'), toCsv(r.perAward));
  }
  console.log(r.summary.text);
  process.exit(0);
}
module.exports = { scoreTestset };
