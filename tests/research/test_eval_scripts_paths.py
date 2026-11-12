"""The eval scripts in data/label_check/eval read and write the sheets and hidden key under archive/label_check/eval/sheets.
Static check: the scripts need data.table, which CI does not install, so they are not run here."""
import os
import re
import unittest

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
EVAL = os.path.join(ROOT, 'data', 'label_check', 'eval')
SCRIPTS = ['make_label_sheets.R', 'model_label.R', 'score_labels.R']
ARCHIVE_PATH = re.compile(r'file\.path\(([^"]*?)"archive",\s*"label_check",\s*"eval",\s*"sheets"((?:,\s*"[^"]+")*)\)')
OLD_STYLE = [
    re.compile(r'file\.path\(here(_dir)?,\s*"sheets"'),
    re.compile(r'else\s+"sheets"'),
]


def source(name):
    with open(os.path.join(EVAL, name), encoding='utf-8') as fh:
        return fh.read()


class EvalScriptPaths(unittest.TestCase):
    def test_each_script_builds_an_archive_sheets_path_that_exists(self):
        for name in SCRIPTS:
            matches = ARCHIVE_PATH.findall(source(name))
            self.assertTrue(matches, name + ' does not build a path under archive/label_check/eval/sheets')
            for _, tail in matches:
                parts = re.findall(r'"([^"]+)"', tail)
                path = os.path.join(ROOT, 'archive', 'label_check', 'eval', 'sheets', *parts)
                self.assertTrue(os.path.exists(path), name + ' points at a missing path: ' + path)

    def test_no_script_still_defaults_to_the_old_sheets_folder(self):
        for name in SCRIPTS:
            text = source(name)
            for pat in OLD_STYLE:
                self.assertIsNone(pat.search(text), name + ' still uses ' + pat.pattern)

    def test_readme_no_longer_says_scripts_default_to_old_path(self):
        with open(os.path.join(EVAL, 'README.md'), encoding='utf-8') as fh:
            text = fh.read()
        self.assertNotIn('still default to', text)


if __name__ == '__main__':
    unittest.main()
