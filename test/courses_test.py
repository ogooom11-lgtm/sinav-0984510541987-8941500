"""Regressions for the exact/adapted course split and completion retirement."""
import unittest,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'tools'))
from build_courses import notes_records,qa_records
class CourseTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bank=json.loads((ROOT/'assets/data/questions.json').read_text())
    def test_file2_is_not_mislabeled_as_original_questions(self):
        raw=(ROOT/'2.txt').read_bytes();records=notes_records(raw)
        self.assertEqual(''.join(r['text'] for r in records).encode(),raw)
        originals=[q for q in self.bank if q['sourceId']=='file2' and q['variant']=='original']
        self.assertEqual(len(originals),38)
        for q in originals:
            self.assertEqual(q['originalFormat'],'notes')
            self.assertEqual(q['prompt'],records[q['page']-1]['prompt'])
            self.assertEqual(q['answer'],records[q['page']-1]['answer'])
    def test_file3_exact_qa_and_critical_exclusion(self):
        raw=(ROOT/'3.txt').read_bytes();prefix,records=qa_records(raw)
        self.assertEqual((prefix+''.join(r['text'] for r in records)).encode(),raw)
        originals=[q for q in self.bank if q['sourceId']=='file3' and q['variant']=='original']
        self.assertEqual(len(originals),61)
        for q in originals:
            self.assertEqual(q['prompt'],records[q['page']-1]['prompt'])
            self.assertEqual(q['answer'],records[q['page']-1]['answer'])
            self.assertEqual(q['reviewOnly'],q['page']==8)
    def test_modified_references_belong_only_to_selected_file(self):
        archive=json.loads((ROOT/'assets/data/course_sources.json').read_text())
        for q in self.bank:
            if q['sourceId']=='sorular' or q['variant']=='original':continue
            refs=[archive[q['sourceId']]['records'][n-1] for n in q['sourceBlocks']]
            self.assertEqual([r['answer'] for r in refs],[e['quote'] for e in q['evidence']])
            if q['sourceId']=='file3':self.assertNotIn(8,q['sourceBlocks'])
        for sid,count in [('file2',62),('file3',80)]:
            self.assertEqual(sum(q['sourceId']==sid and q['variant']=='modified' for q in self.bank),count)
    def test_no_synthetic_completion_and_old_ids_retired(self):
        for q in self.bank:
            if q['variant']=='original':continue
            self.assertNotIn(q['type'],['blank','missing_word','sentence'])
            self.assertNotIn('___',json.dumps([q['prompt'],q.get('parts',[])]))
        meta=json.loads((ROOT/'assets/data/coverage.json').read_text())
        self.assertEqual(len(meta['retiredQuestionIds']),3792)
        self.assertTrue(set(meta['retiredQuestionIds']).isdisjoint(q['id'] for q in self.bank))
if __name__=='__main__':unittest.main()
