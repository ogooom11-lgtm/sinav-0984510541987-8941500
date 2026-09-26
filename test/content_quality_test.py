"""Release gate: audit findings cannot re-enter sessions through rebuilds."""
import copy,json,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'tools'))
from content_quality import apply,BLOCKED,REPAIRS
class QualityTest(unittest.TestCase):
    def setUp(self):
        self.bank=json.loads((ROOT/'assets/data/questions.json').read_text())
    def test_all_flagged_families_are_archival(self):
        for q in self.bank:
            if q.get('editorialRepair'):continue
            if q['kind']=='generated' or (q['sourceId']=='file2' and q['kind']=='verbatim') or set(q['sourceBlocks']) & BLOCKED.get(q['sourceId'],set()):
                self.assertTrue(q['reviewOnly'],q['id'])
                self.assertTrue(q['excludedReason'],q['id'])
    def test_idempotent_and_repairs_have_new_ids(self):
        rebuilt=apply(copy.deepcopy(self.bank))
        self.assertEqual(rebuilt,self.bank)
        repairs=[q for q in rebuilt if q.get('editorialRepair')]
        self.assertEqual(len(repairs),len(REPAIRS))
        byid={q['id']:q for q in rebuilt}
        for q in repairs:
            self.assertFalse(q['reviewOnly'])
            self.assertTrue(byid[q['replacesId']]['reviewOnly'])
            self.assertNotEqual(q['id'],q['replacesId'])
            self.assertEqual(q['variant'],'modified')
            self.assertTrue(q['evidence'])
    def test_published_counts(self):
        meta=json.loads((ROOT/'assets/data/coverage.json').read_text())
        self.assertEqual(meta['qualityReview']['active'],sum(not q['reviewOnly'] for q in self.bank))
        self.assertEqual(meta['activeGeneratedUnits'],0)
        for src in meta['sources']:
            for variant,key in [('original','originalCount'),('modified','modifiedCount')]:
                self.assertEqual(src[key],sum(q['sourceId']==src['id'] and q['variant']==variant and not q['reviewOnly'] for q in self.bank))
if __name__=='__main__':unittest.main()
