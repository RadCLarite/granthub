#!/usr/bin/env python3
"""build_feeds.py: static Atom and ICS feeds per agency, from payload.json. Stdlib only.
Usage: python3 app/build_feeds.py <payload.json> <out_dir>   (out_dir = the site's matchmaker/ folder)
Writes <out_dir>/feeds/<agency_id>.atom, <agency_id>.ics and index.html.
Atom = the agency's top-10 posted grants. ICS = one all-day event per posted top-10 grant on its close date.
SITE_URL (env) is the public address of the tool; default is the assumed Pages URL [uncertain].
Numbers and dates come from the payload only; nothing is computed beyond filtering."""
import html, json, os, sys, datetime as dt

SITE = os.environ.get("SITE_URL", "https://radclarite.github.io/granthub/matchmaker/").rstrip("/") + "/"
payload, out = sys.argv[1], os.path.join(sys.argv[2], "feeds")
p = json.load(open(payload, encoding="utf-8"))
os.makedirs(out, exist_ok=True)
x = lambda s: html.escape(str(s if s is not None else ""), quote=True)
asof = p["data_as_of"]
upd = asof if "T" in asof else asof + "T00:00:00Z"

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
    open(os.path.join(out, aid + ".ics"), "w", encoding="utf-8", newline="").write("\r\n".join(cal) + "\r\n")
    index.append((aid, a["agency_name"], len(rows), n))

li = "".join(f'<li>{x(nm)}: <a href="{x(i)}.atom">feed</a> ({k} grants), <a href="{x(i)}.ics">calendar</a> ({n} deadlines)</li>'
             for i, nm, k, n in index)
open(os.path.join(out, "index.html"), "w", encoding="utf-8").write(
    '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
    f'<title>Grant feeds</title><h1>Grant feeds by agency</h1><p>Data as of {x(asof)}. Top-10 open grants per agency. '
    f'Add a link to a feed reader or calendar app. <a href="../">Back to the tool</a>.</p><ul>{li}</ul>')
print(f"feeds: {len(index)} agencies in {out}")
