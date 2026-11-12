'use strict';
/* Keyword query vs abstract text for the ORCID lookup, on the 10 test-set awards. NOT run by CI: it calls api.openalex.org.
   The test set has no PI names or ORCIDs, so the papers are the OpenAlex works that list the award (awards.funder_award_id = core project
   number), up to 25 each, which is the same kind of input the ORCID lookup gets. Only public NIH project numbers are sent, 10 requests.
   Queries, each searched against data/processed/research.json (limit 50); a hit is a same-funder (IC) or same-mechanism row in the top 10:
     A  the award's own title and abstract (the baseline run_testset.js uses)
     B  the old ORCID fill: titles and abstracts of the papers (worksToText)
     C  the new ORCID fill: keyword phrases (worksToQuery)
   Awards with no papers on OpenAlex are left out of the counts. Usage: node tests/research/compare_orcid_keywords.js */
const path = require('path');
const root = path.join(__dirname, '..', '..');
const RC = require(path.join(root, 'tool', 'research', 'research_core.js'));
const rows = require(path.join(root, 'data', 'processed', 'research.json')).rows;
const groups = require(path.join(root, 'tool', 'research', 'synonyms.json'));
const awards = require(path.join(root, 'data', 'research_testset', 'reporter_sample.json'));
const index = RC.buildIndex(rows, groups), byId = new Map(rows.map(r => [String(r.id), r]));
const SELECT = 'title,publication_year,abstract_inverted_index,topics,keywords';

const coreNumber = pn => { const m = String(pn).toUpperCase().match(/([A-Z]\d{2}[A-Z]{2}\d{6})/); return m ? m[1] : null; };
function rank(res, field, want) {
  for (let i = 0; i < res.length; i++) {
    const r = byId.get(res[i].id);
    if (r && r[field] != null && String(r[field]).toUpperCase() === want) return i + 1;
  }
  return null;
}
async function worksFor(core) {
  if (!core) return [];
  const u = 'https://api.openalex.org/works?filter=awards.funder_award_id:' + core + '&per-page=25&select=' + SELECT;
  try { const r = await fetch(u); return r.ok ? (await r.json()).results || [] : []; } catch (e) { return []; }
}

(async () => {
  const out = [];
  for (const a of awards) {
    const core = coreNumber(a.project_num), ic = String(a.ic).toUpperCase(), mech = String(a.mechanism || '').toUpperCase();
    const works = await worksFor(core);
    await new Promise(r => setTimeout(r, 400));
    const kq = RC.worksToQuery(works);
    const qs = { A: [a.title, a.abstract].filter(Boolean).join(' '), B: RC.worksToText(works), C: kq.text };
    const row = { project: core, ic, works: works.length, kind: kq.kind, keywords: kq.count, mech: !!mech };
    ['A', 'B', 'C'].forEach(k => {
      const res = qs[k] ? RC.search(index, qs[k], { limit: 50 }) : [];
      row[k + '_ic'] = rank(res, 'ic', ic);
      row[k + '_mech'] = mech ? rank(res, 'mech', mech) : null;
    });
    row.box = kq.text.slice(0, 110);
    out.push(row);
  }
  console.table(out.map(r => ({ project: r.project, ic: r.ic, works: r.works, kind: r.kind, A_ic: r.A_ic, B_ic: r.B_ic, C_ic: r.C_ic, A_mech: r.A_mech, B_mech: r.B_mech, C_mech: r.C_mech })));
  const used = out.filter(r => r.works > 0), hit = (k, f) => used.filter(r => r[k + '_' + f] != null && r[k + '_' + f] <= 10).length;
  console.log('awards with papers on OpenAlex:', used.length, 'of', out.length);
  ['A', 'B', 'C'].forEach(k => console.log(k, 'IC hit@10', hit(k, 'ic'), '/', used.length, '  mechanism hit@10', hit(k, 'mech'), '/', used.filter(r => r.mech).length));
  used.forEach(r => console.log(r.project, '|', r.box));
})();
