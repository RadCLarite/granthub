"""The hidden answer keys and labeler sheets live under archive/label_check/, and R/40_label_check.R reads them from there."""
import os
import re
import unittest

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
OLD = os.path.join(ROOT, 'data', 'label_check')
NEW = os.path.join(ROOT, 'archive', 'label_check')
MOVED = [
    'eval/sheets/key_hidden_DO_NOT_SHARE.csv',
    'eval/sheets/labels_department_of_environmental_quality_labelerA.csv',
    'eval/sheets/labels_department_of_environmental_quality_labelerB.csv',
    'eval/sheets/labels_department_of_health_and_human_services_labelerA.csv',
    'eval/sheets/labels_department_of_health_and_human_services_labelerB.csv',
    'eval/sheets/labels_department_of_public_schools_labelerA.csv',
    'eval/sheets/labels_department_of_public_schools_labelerB.csv',
    'holdout/holdout_key_DO_NOT_OPEN.csv',
    'holdout/holdout_labeler_A.csv',
    'holdout/holdout_labeler_B.csv',
]
R_SOURCE = os.path.join(ROOT, 'R', '40_label_check.R')


class LabelCheckPaths(unittest.TestCase):
    def test_keys_and_labeler_sheets_moved_to_archive(self):
        still_in_data = [f for f in MOVED if os.path.exists(os.path.join(OLD, f))]
        missing_in_archive = [f for f in MOVED if not os.path.isfile(os.path.join(NEW, f))]
        self.assertEqual(still_in_data, [], 'still under data/label_check')
        self.assertEqual(missing_in_archive, [], 'missing under archive/label_check')

    def test_r_script_names_resolve_in_archive(self):
        with open(R_SOURCE, encoding='utf-8') as fh:
            src = fh.read()
        names = set(re.findall(r'holdout_labeler_[AB]\.csv|holdout_key_DO_NOT_OPEN\.csv|key_hidden_DO_NOT_SHARE\.csv', src))
        self.assertTrue(names, 'script no longer mentions the sheets; update this test')
        for n in sorted(names):
            self.assertTrue(any(os.path.isfile(os.path.join(NEW, d, n)) for d in ('eval/sheets', 'holdout')), n)

    def test_r_script_no_longer_points_at_data_for_the_moved_files(self):
        with open(R_SOURCE, encoding='utf-8') as fh:
            src = fh.read()
        self.assertNotIn('data/label_check/eval/sheets', src)
        self.assertIn('archive/label_check/eval/sheets', src)
        self.assertIn('archive/label_check/holdout', src)


if __name__ == '__main__':
    unittest.main()
