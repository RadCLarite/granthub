"""The hidden answer keys, labeler sheets, and every file that repeats the hand labels are kept out of the public repository.
They stay on the owner's machine (ignored by git): archive/label_check/ and the round-one hand labels and the team's review sheets in archive/qualifier/data/, and R/40_label_check.R says so when they are missing."""
import os
import re
import subprocess
import unittest

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
KEPT_LOCAL = [
    'archive/label_check/eval/sheets/key_hidden_DO_NOT_SHARE.csv',
    'archive/label_check/eval/sheets/labels_department_of_environmental_quality_labelerA.csv',
    'archive/label_check/eval/sheets/labels_department_of_environmental_quality_labelerB.csv',
    'archive/label_check/eval/sheets/labels_department_of_health_and_human_services_labelerA.csv',
    'archive/label_check/eval/sheets/labels_department_of_health_and_human_services_labelerB.csv',
    'archive/label_check/eval/sheets/labels_department_of_public_schools_labelerA.csv',
    'archive/label_check/eval/sheets/labels_department_of_public_schools_labelerB.csv',
    'archive/label_check/holdout/holdout_key_DO_NOT_OPEN.csv',
    'archive/label_check/holdout/holdout_labeler_A.csv',
    'archive/label_check/holdout/holdout_labeler_B.csv',
    'data/label_check/holdout/label_check_items.csv',
    'data/manual/label_holdout.csv',
    'data/label_check/eval/model_labels/validate_labels.csv',
    'archive/qualifier/data/manual/handlabels_60.csv',
    'archive/qualifier/data/manual/handlabels_60_template.csv',
    'archive/qualifier/data/manual/spotcheck.csv',
    'archive/qualifier/data/manual/spotcheck_template.csv',
    'archive/qualifier/data/processed/grants_rule_review_sample.csv',
]
R_SOURCE = os.path.join(ROOT, 'R', '40_label_check.R')


def git(*args):
    return subprocess.run(['git', '-C', ROOT, *args], capture_output=True, text=True)


class LabelCheckKeysNotPublic(unittest.TestCase):
    def test_none_of_the_keys_or_labels_is_tracked(self):
        tracked = set(git('ls-files', '--', 'archive/label_check', *KEPT_LOCAL).stdout.split())
        self.assertEqual(sorted(tracked & set(KEPT_LOCAL)), [])
        self.assertEqual(sorted(t for t in tracked if t.startswith('archive/label_check/')), [])
        elsewhere = set(git('ls-files', '--', 'data/manual', 'data/label_check/eval/model_labels').stdout.split())
        self.assertEqual(sorted(elsewhere & set(KEPT_LOCAL)), [])

    def test_no_tracked_csv_under_data_carries_hand_labels(self):
        hand = re.compile(r'(^|,)"?(hand_label|label_A|label_B)"?(,|$)')
        found = []
        for f in git('ls-files', '--', 'data/*.csv').stdout.split():
            with open(os.path.join(ROOT, f), encoding='utf-8-sig', errors='replace') as fh:
                if hand.search(fh.readline()):
                    found.append(f)
        self.assertEqual(found, [])

    def test_each_one_is_ignored_so_a_local_copy_cannot_be_added_by_accident(self):
        not_ignored = [f for f in KEPT_LOCAL if git('check-ignore', '-q', f).returncode != 0]
        self.assertEqual(not_ignored, [])

    def test_r_script_says_what_to_do_when_the_files_are_missing(self):
        with open(R_SOURCE, encoding='utf-8') as fh:
            src = fh.read()
        self.assertIn('not in the public repository', src)
        self.assertEqual(src.count('need_local('), 2, 'one call in the score stage, one in the draw stage')
        self.assertIn('archive/label_check/eval/sheets', src)
        self.assertIn('archive/label_check/holdout', src)
        self.assertNotIn('data/label_check/eval/sheets', src)


if __name__ == '__main__':
    unittest.main()
