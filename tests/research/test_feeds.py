"""Tests for the researcher feeds written by app/build_feeds.py (stdlib only).
Run from the repo root: python3 -m unittest tests/research/test_feeds.py"""
import json, os, subprocess, sys, tempfile, unittest, xml.dom.minidom as minidom

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SCRIPT = os.path.join(ROOT, "app", "build_feeds.py")
TITLE_A = "Cancer, imaging; R01 & <b>"
ROWS = [
    {"id": "1", "num": "PAR-1", "title": TITLE_A, "ic": "CA", "status": "posted", "close": "2026-12-01", "post": "2026-10-01", "url": "https://example.org/1"},
    {"id": "2", "num": "PAR-2", "title": "No close date", "ic": "CA", "status": "posted", "close": None, "post": "2026-10-02", "url": "https://example.org/2"},
    {"id": "4", "num": "PAR-4", "title": "Already closed", "ic": "CA", "status": "posted", "close": "2026-11-01", "post": "2026-09-01", "url": "https://example.org/4"},
    {"id": "3", "num": "PAR-3", "title": "Forecast only", "ic": "AG", "status": "forecasted", "close": None, "post": None, "url": "https://example.org/3"},
]


def build(with_research=True):
    tmp = tempfile.mkdtemp()
    payload = os.path.join(tmp, "payload.json")
    json.dump({"data_as_of": "2026-11-10", "agencies": [], "rows": []}, open(payload, "w"))
    research = os.path.join(tmp, "research.json")
    json.dump({"as_of": "2026-11-10", "n": len(ROWS), "rows": ROWS}, open(research, "w"))
    out = os.path.join(tmp, "site")
    os.makedirs(out)
    args = [sys.executable, SCRIPT, payload, out] + ([research] if with_research else [])
    subprocess.run(args, check=True, capture_output=True, env=dict(os.environ, FEEDS_TODAY="2026-11-10"))
    return out


def read(path):
    return open(path, encoding="utf-8", newline="").read()


class ResearchFeeds(unittest.TestCase):
    def test_files_for_institutes_with_posted_rows_and_all(self):
        d = os.path.join(build(), "feeds", "research")
        for name in ("CA.atom", "CA.ics", "all.atom", "all.ics"):
            self.assertTrue(os.path.exists(os.path.join(d, name)), name)
        self.assertFalse(os.path.exists(os.path.join(d, "AG.atom")))

    def test_atom_parses_escapes_and_lists_dateless_rows(self):
        d = os.path.join(build(), "feeds", "research")
        for name in ("CA.atom", "all.atom"):
            minidom.parse(os.path.join(d, name))
        text = read(os.path.join(d, "CA.atom"))
        self.assertIn("R01 &amp; &lt;b&gt;", text)
        self.assertIn("No close date", text)
        self.assertNotIn("Forecast only", read(os.path.join(d, "all.atom")))
        self.assertLess(text.index("Cancer"), text.index("No close date"))  # dated rows first

    def test_ics_has_dated_rows_only_and_escapes(self):
        d = os.path.join(build(), "feeds", "research")
        text = read(os.path.join(d, "CA.ics"))
        self.assertTrue(text.startswith("BEGIN:VCALENDAR"))
        self.assertTrue(text.rstrip().endswith("END:VCALENDAR"))
        self.assertEqual(text.count("BEGIN:VEVENT"), 1)
        self.assertIn("DTSTART;VALUE=DATE:20261201", text)
        self.assertIn("DTEND;VALUE=DATE:20261202", text)
        self.assertIn("Cancer\, imaging\; R01 & <b>", text)
        self.assertNotIn("No close date", text)
        self.assertIn("\r\n", text)

    def test_closed_rows_are_left_out_of_both_feeds(self):
        d = os.path.join(build(), "feeds", "research")
        for name in ("CA.atom", "all.atom", "CA.ics", "all.ics"):
            self.assertNotIn("Already closed", read(os.path.join(d, name)), name)

    def test_row_closing_today_is_kept(self):
        tmp = tempfile.mkdtemp()
        json.dump({"data_as_of": "2026-11-10", "agencies": [], "rows": []}, open(os.path.join(tmp, "p.json"), "w"))
        row = dict(ROWS[0], close="2026-11-10")
        json.dump({"as_of": "2026-11-10", "rows": [row]}, open(os.path.join(tmp, "r.json"), "w"))
        out = os.path.join(tmp, "site"); os.makedirs(out)
        subprocess.run([sys.executable, SCRIPT, os.path.join(tmp, "p.json"), out, os.path.join(tmp, "r.json")], check=True, capture_output=True, env=dict(os.environ, FEEDS_TODAY="2026-11-10"))
        self.assertIn("DTSTART;VALUE=DATE:20261110", read(os.path.join(out, "feeds", "research", "all.ics")))

    def test_index_links_research_feeds(self):
        out = build()
        self.assertIn("research/CA.atom", read(os.path.join(out, "feeds", "index.html")))

    def test_no_research_argument_means_no_research_folder(self):
        out = build(with_research=False)
        self.assertFalse(os.path.exists(os.path.join(out, "feeds", "research")))


if __name__ == "__main__":
    unittest.main()
