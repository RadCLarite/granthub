"""The public tree must not name the team's Azure resources. Past AI_USAGE_LOG.md rows are an append-only record and are exempt."""
import os
import re
import subprocess
import unittest

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
# Built from pieces so this file does not match itself.
NAMES = ['ffm' + 'acr', 'ffm' + 'data', 'ffm-' + 'aoai', 'ffm-' + 'env', 'ffm-' + 'logs', 'ffm-' + 'guard',
         'ffm-' + 'daily', 'ffm-' + 'app', 'ffm-' + 'data', 'blue' + 'pebble', 'team' + '15',
         'rg-' + 'primary']
PATTERN = re.compile('|'.join(re.escape(n) for n in NAMES), re.I)
LEGACY_APP_FILES = ['Dockerfile', 'Dockerfile.job', 'entrypoint.sh', 'app.R', 'read_feedback.sh', 'pilot_scorecard.sh']


def tracked():
    out = subprocess.run(['git', 'ls-files', '-z'], cwd=ROOT, capture_output=True, check=True).stdout
    return [p for p in out.decode('utf-8').split('\0') if p]


class NoAzureNames(unittest.TestCase):
    def test_no_resource_names_in_tracked_files(self):
        hits = []
        for rel in tracked():
            if rel == 'AI_USAGE_LOG.md':
                continue
            path = os.path.join(ROOT, rel)
            if not os.path.isfile(path):
                continue
            with open(path, 'rb') as fh:
                text = fh.read().decode('utf-8', 'replace')
            if PATTERN.search(text):
                hits.append(rel)
        self.assertEqual(hits, [], 'Azure resource names found in: ' + ', '.join(hits))

    def test_azure_era_files_are_gone_from_app(self):
        left = [f for f in LEGACY_APP_FILES if os.path.exists(os.path.join(ROOT, 'app', f))]
        self.assertEqual(left, [])


if __name__ == '__main__':
    unittest.main()
