"""Assemble the GitHub Pages site in docs/ from the built deliverables.

Run from src/ after the tool and notebook are built:  python3 build_site.py
GitHub Pages is deployed from QualifierChallenge/docs by .github/workflows/pages.yml (Settings > Pages > Source: GitHub Actions).

docs/index.html        landing page (from src/site/index.html; numbers filled from payload.json)
docs/tool.html         outs/grant-triage-tool.html
docs/notebook.html     outs/solveathon_project.html
docs/downloads/        top results (.xlsx, .csv)
"""
import csv, datetime, html, json, os, shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTS, DOCS = os.path.join(ROOT, "outs"), os.path.join(ROOT, "docs")
REPO = "https://github.com/KApolloL/SolveAThon_2026"

COPIES = {
    "grant-triage-tool.html": "tool.html",
    "solveathon_project.html": "notebook.html",
    "top_results_with_rationale.xlsx": "downloads/top_results.xlsx",
    "top_results.csv": "downloads/top_results.csv",
}
TIER_VAR = {"1": "--t1", "2": "--t2", "3": "--t3", "4": "--t4"}


def money(x):
    if not x:
        return "not stated"
    v = float(x)
    return f"${v / 1e6:.1f}M".replace(".0M", "M") if v >= 1e6 else f"${v / 1e3:.0f}K"


def sample_rows(path):
    """A readable sample of the top results: DHHS's top 3 in Tier 1, top 2 in Tier 2, all of Tier 3,
    and DMVA's first Tier 3 item. Reasons are the rules that fired, shortened to two."""
    rows = list(csv.DictReader(open(path, encoding="utf-8")))
    keep = [r for r in rows if r["agency"] == "DHHS" and (
        (r["tier"] == "1" and int(r["rank_in_tier"]) <= 3) or (r["tier"] == "2" and int(r["rank_in_tier"]) <= 2) or r["tier"] == "3")]
    keep += [r for r in rows if r["agency"] == "DMVA"][:1]
    out = []
    for r in keep:
        why = "; ".join(x.strip() for x in r["rules_that_fired"].split(";")[:2])
        why = why.replace("No escalation: ", "Nothing blocks it: ")
        dl = datetime.date.fromisoformat(r["deadline"]).strftime("%b %-d, %Y") if r["deadline"] else "not stated"
        tag = '<span class="tag">forecast</span>' if r["status"] == "forecasted" else ""
        agency = "for DMVA" if r["agency"] == "DMVA" else r["issuing_agency"]
        out.append(
            f'              <tr><td class="pile" style="--c:var({TIER_VAR[r["tier"]]})"><i></i>Tier {r["tier"]}</td>'
            f'<td class="opp"><a class="t" href="{html.escape(r["link"])}">{html.escape(r["title"])}</a>{tag}'
            f'<span class="sub">{html.escape(agency)}</span></td>'
            f'<td class="num">{dl}</td><td class="num">{money(r["estimated_award"])}</td>'
            f'<td class="why">{html.escape(why)}.</td></tr>')
    return "\n".join(out)

def label_cells(page):
    """Copy each table's column headers onto its cells as data-label, so rows can stack on phones."""
    import re

    def one_table(m):
        t = m.group(0)
        heads = [re.sub(r"<[^>]+>", "", h).strip() for h in re.findall(r"<th[^>]*>(.*?)</th>", t)]

        def one_row(r):
            cells = iter(heads)
            return re.sub(r"<td(?![^>]*data-label)", lambda _: f'<td data-label="{html.escape(next(cells, ""))}"', r.group(0))
        return re.sub(r"<tr>.*?</tr>", one_row, t, flags=re.S)
    return re.sub(r"<table class=\"data\">.*?</table>", one_table, page, flags=re.S)


# Never publish anything that contains the Census key.
key = ""
renv = os.path.join(ROOT, ".Renviron")
if os.path.exists(renv):
    for line in open(renv):
        if line.startswith("CENSUS_API_KEY="):
            key = line.split("=", 1)[1].strip().strip('"')

if os.path.isdir(DOCS):
    shutil.rmtree(DOCS)
os.makedirs(DOCS)
for src, dst in COPIES.items():
    s, d = os.path.join(OUTS, src), os.path.join(DOCS, dst)
    if not os.path.exists(s):
        raise SystemExit(f"Missing {s}: build the tool, notebook, top results and slide figures first.")
    os.makedirs(os.path.dirname(d), exist_ok=True)
    shutil.copyfile(s, d)
    if key and key.encode() in open(d, "rb").read():
        raise SystemExit(f"Refusing to publish {dst}: it contains the Census API key.")

p = json.load(open(os.path.join(ROOT, "data", "processed", "payload.json")))
c = p["golden"]["opening_counts"]
fill = {
    "TOTAL": f"{p['meta']['source_rows']:,}", "TIER1": str(c.get("tier1", 0)), "TIER2": str(c.get("tier2", 0)),
    "TIER3": str(c.get("tier3", 0)), "TIER4": str(c.get("tier4", 0)),
    "OPEN_STATE": str(p["golden"]["fact_universe_count"]), "NIH": str(p["golden"]["fact_nih_count"]),
    "PULL_DATE": datetime.date.fromisoformat(p["meta"]["pull_date"]).strftime("%B %-d, %Y"),
    "MODEL": p["meta"]["llm_model"], "BUILT": datetime.date.today().strftime("%B %-d, %Y"), "REPO": REPO,
    "TOP_ROWS": sample_rows(os.path.join(OUTS, "top_results.csv")),
}
# Everything not in Tiers 1-4 (out of scope, not this cycle, screened), so the routing slip adds up.
fill["REST"] = f"{p['meta']['source_rows'] - sum(c.get(f'tier{k}', 0) for k in range(1, 5)):,}"
# Funnel bar widths, drawn to scale against the full file.
for k, n in {"W_OPEN": p["golden"]["fact_universe_count"], "W_NIH": p["golden"]["fact_nih_count"], "W_SIX": 6}.items():
    fill[k] = f"{100 * n / p['meta']['source_rows']:.2f}%"
vet, rur = p["populations"]["veterans"]["county"], p["community"]["county_rurality"]
vet_total = sum(vet.values())
fill["VET_TOTAL"] = f"{round(vet_total):,}"
fill["VET_RURAL"] = f"{sum(n for f, n in vet.items() if rur.get(f) == 'rural') / vet_total:.0%}"
page = open(os.path.join(ROOT, "src", "site", "index.html"), encoding="utf-8").read()
for k, v in fill.items():
    page = page.replace("{{" + k + "}}", v)
page = label_cells(page)
if "{{" in page:
    raise SystemExit("Unfilled placeholder in the landing page.")
open(os.path.join(DOCS, "index.html"), "w", encoding="utf-8").write(page)
open(os.path.join(DOCS, ".nojekyll"), "w").close()   # serve files as-is, no Jekyll processing

size = sum(os.path.getsize(os.path.join(dp, f)) for dp, _, fs in os.walk(DOCS) for f in fs)
print(f"Built {DOCS} ({size / 1e6:.1f} MB): " + ", ".join(sorted(["index.html"] + list(COPIES.values()))))
