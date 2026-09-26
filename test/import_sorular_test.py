"""Importer regressions: preserve the original source, never silently fill gaps."""
import hashlib
import importlib.util
from pathlib import Path
import unittest
import sys

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('import_sorular', ROOT / 'tools/import_sorular.py')
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)

class ImportTest(unittest.TestCase):
    def test_complete_byte_fidelity_and_blank_templates(self):
        raw = (ROOT / 'sorular.txt').read_bytes()
        records = importer.parse_source(raw)
        self.assertEqual(''.join(r['text'] for r in records).encode(), raw)
        self.assertEqual(len(records), 223)
        self.assertEqual(sum(not r['empty'] for r in records), 189)
        self.assertEqual(sum(r['empty'] for r in records), 34)
        self.assertIn('عرفي الرُقى', records[188]['prompt'])
        self.assertIn('لا بَأْسَ', records[188]['answer'])

    def test_missing_answer_rejected(self):
        with self.assertRaises(AssertionError):
            importer.parse_source('*سؤال*\nسؤال بلا جواب\n*الاجابة او التعريف*\n'.encode())

    def test_orphan_content_rejected(self):
        with self.assertRaises(AssertionError):
            importer.parse_source('مقدمة غير معالجة\n*سؤال*\nس\n*الاجابة او التعريف*\nج\n'.encode())

    def test_multiline_answers_and_crlf_preserved(self):
        raw = '*سؤال*\r\nسؤال\r\nثان\r\n*الاجابة او التعريف*\r\nأول الجواب\r\n\r\nآخر الجواب\r\n'.encode()
        r = importer.parse_source(raw)[0]
        self.assertEqual(r['prompt'], 'سؤال\r\nثان')
        self.assertEqual(r['answer'], 'أول الجواب\r\n\r\nآخر الجواب')
        self.assertEqual(r['lineStart'], 1)
        self.assertEqual(r['lineEnd'], 7)

    def test_regeneration_is_deterministic(self):
        files = [ROOT/'assets/data'/name for name in ['books.json','questions.json','coverage.json','sources.json','course_sources.json']]
        files.append(ROOT/'docs/sorular-coverage.md')
        files.append(ROOT/'docs/courses-2-3.md')
        before = [hashlib.sha256(p.read_bytes()).hexdigest() for p in files]
        sys.path.insert(0,str(ROOT/'tools'))
        from expand_learning import expand
        expand()
        self.assertEqual(before, [hashlib.sha256(p.read_bytes()).hexdigest() for p in files])

if __name__ == '__main__':
    unittest.main()
