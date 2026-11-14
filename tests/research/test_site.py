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


class ResearcherTabLinksToFeeds(unittest.TestCase):
    """The feeds exist only at matchmaker/feeds/, so the researcher tab must link to that index."""

    @classmethod
    def setUpClass(cls):
        cls.out = tempfile.mkdtemp()
        subprocess.run(["sh", os.path.join(REPO, "app", "build_pages.sh"), cls.out], check=True, capture_output=True)

    def read(self, *p):
        with open(os.path.join(self.out, *p), encoding="utf-8") as f:
            return f.read()

    def test_feeds_index_is_in_the_built_site(self):
        self.assertTrue(os.path.isfile(os.path.join(self.out, "matchmaker", "feeds", "index.html")))

    def test_tab_script_links_to_the_feeds_index_relative_to_matchmaker(self):
        js = self.read("matchmaker", "research", "research_tab.js")
        self.assertRegex(js, r"""\.href\s*=\s*['"]feeds/['"]""")

    def test_stylesheet_styles_the_link(self):
        self.assertIn("#v-research .rt-feeds", self.read("matchmaker", "research", "research.css"))


if __name__ == "__main__":
    unittest.main()
