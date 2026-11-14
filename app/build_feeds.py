#!/usr/bin/env python3
"""build_feeds.py: static Atom and ICS feeds per agency, from payload.json. Stdlib only.
Usage: python3 app/build_feeds.py <payload.json> <out_dir> [research.json]   (out_dir = the site's matchmaker/ folder)
Writes <out_dir>/feeds/<agency_id>.atom, <agency_id>.ics and index.html.
Atom = the agency's top-10 posted grants. ICS = one all-day event per posted top-10 grant on its close date.
SITE_URL (env) is the public address of the tool; default is the assumed Pages URL [uncertain].
Numbers and dates come from the payload only; nothing is computed beyond filtering."""
import html, json, os, sys, datetime as dt

CRLF = chr(13) + chr(10)

SITE = os.environ.get("SITE_URL", "https://radclarite.github.io/granthub/matchmaker/").rstrip("/") + "/"
payload, out = sys.argv[1], os.path.join(sys.argv[2], "feeds")
p = json.load(open(payload, encoding="utf-8"))
os.makedirs(out, exist_ok=True)
def row_url(r):  # research.json leaves out the grants.gov link when the numeric id implies it
    if r.get("url"):
        return r["url"]
    return "https://www.grants.gov/search-results-detail/" + r["id"] if str(r.get("id", "")).isdigit() else ""


x = lambda s: html.escape(str(s if s is not None else ""), quote=True)
asof = p["data_as_of"]
ts = lambda d: d if "T" in d else d + "T00:00:00Z"  # Atom wants an RFC 3339 date-time, never a bare date
upd = ts(asof)

def fold(line):
    """RFC 5545 section 3.1: at most 75 octets per line; continuation lines start with one space. Never splits a character."""
    out, cur, n = [], "", 0
    for ch in line:
        b = len(ch.encode("utf-8"))
        if n + b > (74 if out else 75):
            out.append(cur); cur, n = "", 0
        cur += ch; n += b
    out.append(cur)
    return (CRLF + " ").join(out)

def ics_text(s):
    return str(s or "").replace("\\", "\\\\").replace(";", "\\;").replace(",", "\\,").replace("\n", " ")

index = []
for a in p["agencies"]:
    aid = a["agency_id"]
    rows = [r for r in p["rows"] if r["agency_id"] == aid and r.get("status") == "posted" and r.get("in_top10")]
    rows.sort(key=lambda r: r.get("rank") or 99)
    ent = []
    for r in rows:
        due = r.get("close_date") or "no close date listed"
        ent.append(
            f'<entry><title>{x("#%s %s" % (r.get("rank"), r["title"]))}</title>'
            f'<id>tag:ffm,{x(aid)}:{x(r["opp_id"])}</id><updated>{x(upd)}</updated>'
            f'<link href="{x(r.get("url"))}"/>'
            f'<summary>{x("%s. Closes %s. Fit %s." % (r.get("opp_number"), due, r.get("fit_score")))}</summary></entry>')
    feed = ('<?xml version="1.0" encoding="utf-8"?><feed xmlns="http://www.w3.org/2005/Atom">'
            f'<title>{x(a["agency_name"])}: top open federal grants</title>'
            f'<id>tag:ffm,{x(aid)}</id><updated>{x(upd)}</updated><link href="{x(SITE)}"/>'
            f'<subtitle>Data as of {x(asof)}. Screening aid; confirm on Grants.gov.</subtitle>' + "".join(ent) + "</feed>")
    open(os.path.join(out, aid + ".atom"), "w", encoding="utf-8").write(feed)

    cal = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//FFM//EN", "CALSCALE:GREGORIAN",
           "X-WR-CALNAME:" + ics_text(a["agency_name"] + " grant deadlines")]
    n = 0
    for r in rows:
        cd = r.get("close_date")
        if not cd: continue
        d = dt.date.fromisoformat(cd)
        cal += ["BEGIN:VEVENT", f"UID:{aid}-{r['opp_id']}@ffm",
                "DTSTAMP:" + dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ"),
                "DTSTART;VALUE=DATE:" + d.strftime("%Y%m%d"),
                "DTEND;VALUE=DATE:" + (d + dt.timedelta(days=1)).strftime("%Y%m%d"),
                "SUMMARY:" + ics_text("Closes: " + r["title"]),
                "DESCRIPTION:" + ics_text("%s. %s" % (r.get("opp_number"), r.get("url"))), "END:VEVENT"]
        n += 1
    cal.append("END:VCALENDAR")
    open(os.path.join(out, aid + ".ics"), "w", encoding="utf-8", newline="").write(CRLF.join(fold(l) for l in cal) + CRLF)
    index.append((aid, a["agency_name"], len(rows), n))

# ---- researcher feeds (optional third argument: research.json) ----
# One Atom and one ICS per NIH institute with at least one posted row, plus all.* for every posted row.
# Atom lists dated rows first (by close date), then rows with no close date; ICS has dated rows only. Forecasted rows are in neither.
rindex = []
if len(sys.argv) > 3:
    rp = json.load(open(sys.argv[3], encoding="utf-8"))
    rout = os.path.join(out, "research")
    os.makedirs(rout, exist_ok=True)
    today = os.environ.get("FEEDS_TODAY") or dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d")  # feeds are rebuilt daily, research.json by hand: drop what has closed since
    posted = [r for r in rp["rows"] if r.get("status") == "posted" and not (r.get("close") and r["close"] < today)]
    groups = {"all": ("All open opportunities", posted)}
    for code in sorted({r["ic"] for r in posted if r.get("ic")}):
        groups[code] = ("NIH institute " + code, [r for r in posted if r.get("ic") == code])
    rasof = rp.get("as_of") or asof
    rupd = ts(rasof)
    for gid, (gname, grows) in groups.items():
        grows = sorted(grows, key=lambda r: (r.get("close") is None, r.get("close") or ""))
        ent = []
        for r in grows:
            due = r.get("close") or "no close date listed"
            ent.append(
                f'<entry><title>{x(r["title"])}</title><id>tag:ffm,research:{x(r["id"])}</id><updated>{x(ts(r["post"]) if r.get("post") else rupd)}</updated>'
                f'<link href="{x(row_url(r))}"/><summary>{x("%s. Closes %s. Screening aid; confirm on Grants.gov." % (r.get("num"), due))}</summary></entry>')
        feed = ('<?xml version="1.0" encoding="utf-8"?><feed xmlns="http://www.w3.org/2005/Atom">'
                f'<title>{x(gname)}: open federal research opportunities</title><id>tag:ffm,research:{x(gid)}</id><updated>{x(rupd)}</updated>'
                f'<link href="{x(SITE)}"/><subtitle>Data as of {x(rasof)}. Screening aid; confirm on Grants.gov.</subtitle>' + "".join(ent) + "</feed>")
        open(os.path.join(rout, gid + ".atom"), "w", encoding="utf-8").write(feed)
        cal = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//FFM//EN", "CALSCALE:GREGORIAN", "X-WR-CALNAME:" + ics_text(gname + " grant deadlines")]
        n = 0
        for r in grows:
            if not r.get("close"): continue
            d = dt.date.fromisoformat(r["close"])
            cal += ["BEGIN:VEVENT", f"UID:research-{r['id']}@ffm", "DTSTAMP:" + dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ"),
                    "DTSTART;VALUE=DATE:" + d.strftime("%Y%m%d"), "DTEND;VALUE=DATE:" + (d + dt.timedelta(days=1)).strftime("%Y%m%d"),
                    "SUMMARY:" + ics_text("Closes: " + r["title"]), "DESCRIPTION:" + ics_text("%s. %s" % (r.get("num"), row_url(r))), "END:VEVENT"]
            n += 1
        cal.append("END:VCALENDAR")
        open(os.path.join(rout, gid + ".ics"), "w", encoding="utf-8", newline="").write(CRLF.join(fold(l) for l in cal) + CRLF)
        rindex.append((gid, gname, len(grows), n))
INDEX_TOKENS_DARK = ("--paper:#111a1f;--surface-2:#18242a;--border:#2c3b42;--text-primary:#e8eeec;--text-secondary:#b7c2c0;"
                     "--accent:#7cc4ad;--accent-soft:#1d3a33;color-scheme:dark")
# Same tokens and dark-mode switches as tool/matchmaker.html, so the page matches the app. Nothing loads from another host.
INDEX_CSS = (
    ':root{--paper:#f6f7f5;--surface-2:#ffffff;--border:#d8ddd8;--text-primary:#16232e;--text-secondary:#46525c;'
    '--accent:#1d5a4c;--accent-soft:#e2eee9;--radius:10px;color-scheme:light;'
    '--font:"Public Sans","Helvetica Neue",Arial,sans-serif}'
    '@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){' + INDEX_TOKENS_DARK + '}}'
    ':root[data-theme="dark"]{' + INDEX_TOKENS_DARK + '}'
    'body{margin:0;background:var(--paper);color:var(--text-primary);font:16px/1.5 var(--font)}'
    'main{max-width:860px;margin:0 auto;padding:12px 16px 32px}'
    'h1{font-size:1.5rem;line-height:1.25;margin:8px 0}'
    'h2{font-size:1.2rem;margin:28px 0 4px}'
    'p{color:var(--text-secondary);margin:6px 0 12px}'
    'a{color:var(--accent);font-weight:600}'
    'a:focus-visible{outline:2px solid var(--accent);outline-offset:2px;border-radius:4px}'
    '.top a{display:inline-flex;align-items:center;min-height:44px}'
    'ul{list-style:none;margin:12px 0;padding:0;display:grid;gap:8px}'
    'li{background:var(--surface-2);border:1px solid var(--border);border-radius:var(--radius);padding:8px 14px;overflow-wrap:anywhere}'
    '.nm{display:block;font-weight:650}'
    '.feeds{display:flex;flex-wrap:wrap;gap:0 20px}'
    '.feeds a{display:inline-flex;align-items:center;min-height:44px}'
)
INDEX_THEME_JS = ('try{var t=localStorage.getItem("ffm_theme_v1");'
                  'if(t==="light"||t==="dark")document.documentElement.setAttribute("data-theme",t)}catch(e){}')


def index_items(rows, prefix, noun):
    return "".join(f'<li><span class="nm">{x(nm)}</span><span class="feeds">'
                   f'<a href="{prefix}{x(i)}.atom">Feed ({k} {noun})</a><a href="{prefix}{x(i)}.ics">Calendar ({n} deadlines)</a></span></li>'
                   for i, nm, k, n in rows)


rsec = (f'<h2>Researcher feeds</h2><p>Open federal research opportunities by NIH institute.</p>'
        f'<ul>{index_items(rindex, "research/", "opportunities")}</ul>') if rindex else ""
open(os.path.join(out, "index.html"), "w", encoding="utf-8").write(
    '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
    '<meta name="robots" content="noindex, nofollow"><title>Grant feeds</title>'
    f'<style>{INDEX_CSS}</style><script>{INDEX_THEME_JS}</script></head><body><main>'
    '<p class="top"><a href="../">Back to the tool</a></p><h1>Grant feeds by agency</h1>'
    f'<p>Data as of {x(asof)}. Top-10 open grants per agency. Add a link to a feed reader or calendar app.</p>'
    f'<ul>{index_items(index, "", "grants")}</ul>{rsec}</main></body></html>')
print(f"feeds: {len(index)} agencies in {out}")
