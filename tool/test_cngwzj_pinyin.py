"""Check obfuscated webpage annotations without guessing polyphonic readings."""

import unittest

from collect_cngwzj_shijing import decode_reading, page_mask_mapping, parse_page
from audit_poetry_pinyin_coverage import patterns_to_trie, runtime_coverage


class CngwzjPinyinTest(unittest.TestCase):
    def test_coverage_does_not_join_phrases_across_punctuation(self):
        phrase = patterns_to_trie({'夫': ['夫何']})
        self.assertEqual(runtime_coverage({'content': '夫，何'}, {}, phrase, {}), (0, 0, 2))

    def test_coverage_keeps_exact_locks_ahead_of_overlapping_phrases(self):
        exact = patterns_to_trie({'海': ['海内']})
        phrase = patterns_to_trie({'内': ['内存']})
        self.assertEqual(runtime_coverage({'content': '海内存'}, exact, phrase, {}), (2, 2, 3))

    def test_coverage_normalizes_traditional_phrase_characters(self):
        phrase = patterns_to_trie({'银': ['银行']})
        self.assertEqual(runtime_coverage({'content': '銀行'}, {}, phrase, {ord('銀'): '银'}), (0, 2, 2))

    def test_masked_tone_is_restored_from_distinct_page_anchors(self):
        pairs = [('mγng', '孟'), ('tγ', '特'), ('sγ', '色')]
        inventory = {'孟': ['mèng'], '特': ['tè'], '色': ['sè'], '得': ['dé', 'děi', 'de']}
        mapping = page_mask_mapping(pairs, {}, inventory)
        self.assertEqual(mapping, {'γ': 'è'})
        self.assertEqual(decode_reading('mγng', '孟', inventory, mapping), 'mèng')
        # A wildcard could incorrectly select dé. The page says dè, which is
        # not a known reading of 得, so this annotation must be withheld.
        self.assertIsNone(decode_reading('dγ', '得', inventory, mapping))

    def test_repeated_single_character_does_not_prove_substitution(self):
        pairs = [('mγng', '孟')] * 10
        self.assertEqual(page_mask_mapping(pairs, {}, {'孟': ['mèng']}), {})

    def test_conflicting_page_anchors_are_withheld(self):
        pairs = [('mγng', '孟'), ('tγ', '特'), ('sγ', '色'), ('dγ', '德')]
        inventory = {'孟': ['mèng'], '特': ['tè'], '色': ['sè'], '德': ['dé']}
        self.assertEqual(page_mask_mapping(pairs, {}, inventory), {})

    def test_explicit_polyphonic_annotation_keeps_source_reading(self):
        inventory = {'行': ['xíng', 'háng']}
        self.assertEqual(decode_reading('háng', '行', inventory), 'háng')
        self.assertIsNone(decode_reading('hγng', '行', inventory))
        self.assertIsNone(decode_reading('xyz', '行', inventory))

    def test_malformed_span_does_not_discard_or_shift_other_annotations(self):
        page = '<div class="strbox t-l" id="gsbox"><div class="g_box">' + (
            '<span>tiān<br>天</span><span>cháng<br>尚鸟</span>'
            '<span>dì<br>地</span></div></div>'
        )
        text, readings = parse_page(page, {}, {'天': ['tiān'], '地': ['dì']})
        self.assertEqual(text, '天尚鸟地')
        self.assertEqual(readings, ['tiān', None, None, 'dì'])


if __name__ == '__main__':
    unittest.main()
