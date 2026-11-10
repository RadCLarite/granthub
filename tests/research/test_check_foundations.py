"""Tests for app/check_foundations.py, the stdlib gate the site build runs on foundations.csv and its JSON.
Run from the repo root: python3 -m unittest tests/research/test_check_foundations.py"""
import csv, json, os, subprocess, sys, tempfile, unittest

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SCRIPT = os.path.join(ROOT, "app", "check_foundations.py")
COLS = ["id", "name", "focus", "career_stage", "award_note", "url", "verified_on"]
GOOD = [
    {"id": "a", "name": "Fund A", "focus": "Funds stroke imaging.", "career_stage": "early", "award_note": "", "url": "https://example.org/a", "verified_on": "2026-11-01"},
    {"id": "b", "name": "Fund B", "focus": "Funds cancer screening.", "career_stage": "", "award_note": "", "url": "https://example.org/b", "verified_on": "2026-10-15"},
]


def run(rows, json_ids=None):
    tmp = tempfile.mkdtemp()
    cp, jp = os.path.join(tmp, "f.csv"), os.path.join(tmp, "f.json")
    with open(cp, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=COLS)
        w.writeheader()
        w.writerows(rows)
    ids = [r["id"] for r in rows] if json_ids is None else json_ids
    json.dump({"as_of": "2026-11-10", "n": len(ids), "rows": [{"id": i} for i in ids]}, open(jp, "w"))
    p = subprocess.run([sys.executable, SCRIPT, cp, jp], capture_output=True, text=True, env=dict(os.environ, FOUNDATIONS_TODAY="2026-11-10"))
    return p.returncode, p.stdout + p.stderr


def bad(**kw):
    rows = [dict(r) for r in GOOD]
    rows[0].update(kw)
    return rows


class CheckFoundations(unittest.TestCase):
    def test_valid_and_header_only_pass(self):
        self.assertEqual(run(GOOD)[0], 0)
        self.assertEqual(run([])[0], 0)

    def test_missing_url_or_date_fails_and_names_the_problem(self):
        code, out = run(bad(url=""))
        self.assertNotEqual(code, 0); self.assertIn("url", out)
        code, out = run(bad(verified_on=""))
        self.assertNotEqual(code, 0); self.assertIn("verified_on", out)

    def test_http_url_fails(self):
        self.assertNotEqual(run(bad(url="http://example.org/a"))[0], 0)

    def test_dates_must_be_strict_iso_and_not_in_the_future(self):
        for v in ("2026-1-5", "2026-11-01 (approx)", "last week", "2027-01-01"):
            self.assertNotEqual(run(bad(verified_on=v))[0], 0, v)

    def test_duplicate_or_blank_name_focus_id_fails(self):
        rows = [dict(r) for r in GOOD]; rows[1]["id"] = "a"
        self.assertNotEqual(run(rows)[0], 0)
        for col in ("name", "focus", "id"):
            self.assertNotEqual(run(bad(**{col: ""}))[0], 0, col)

    def test_json_must_match_the_csv(self):
        code, out = run(GOOD, json_ids=["a"])
        self.assertNotEqual(code, 0); self.assertIn("Rscript R/15_build_foundations.R", out)
        self.assertNotEqual(run(GOOD, json_ids=["a", "zzz"])[0], 0)


if __name__ == "__main__":
    unittest.main()
