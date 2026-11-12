"""The built site asks search engines not to index it: robots.txt at the site root, noindex meta on every page."""
import os, re, subprocess, tempfile, unittest

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


class SiteNoIndex(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = tempfile.mkdtemp()
        subprocess.run(["sh", os.path.join(REPO, "app", "build_pages.sh"), cls.out], check=True, capture_output=True)

    def read(self, *p):
        with open(os.path.join(self.out, *p), encoding="utf-8") as f:
            return f.read()

    def test_robots_txt_disallows_everything(self):
        t = self.read("robots.txt")
        self.assertRegex(t, r"(?m)^User-agent: \*\s*$")
        self.assertRegex(t, r"(?m)^Disallow: /\s*$")

    def test_every_html_page_has_noindex_meta(self):
        pages = [os.path.join(d, f) for d, _, fs in os.walk(self.out) for f in fs if f.endswith(".html")]
        self.assertGreaterEqual(len(pages), 2)
        for p in pages:
            with open(p, encoding="utf-8") as f:
                head = f.read(20000)
            self.assertRegex(head, r'<meta name="robots" content="noindex, nofollow">', p)


if __name__ == "__main__":
    unittest.main()
