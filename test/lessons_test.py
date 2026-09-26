import json,hashlib,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'tools'))
from build_lessons import build
class LessonsTest(unittest.TestCase):
 def test_provenance_and_choices(self):
  data=json.loads((ROOT/'assets/data/lessons.json').read_text())
  bank=json.loads((ROOT/'assets/data/questions.json').read_text())
  originals={(q['sourceId'],q['page']):q for q in bank if q['kind']=='verbatim'}
  ids=set()
  for lesson in data['lessons']:
   facts={f['id']:f for f in lesson['facts']}
   for f in facts.values():
    original=originals[lesson['sourceId'],f['sourceBlock']]
    self.assertIn(f['text'],original['answer'])
    self.assertEqual(hashlib.sha256((ROOT/f['sourceFile']).read_bytes()).hexdigest(),f['sourceSha256'])
   for q in lesson['questions']:
    self.assertNotIn(q['id'],ids);ids.add(q['id'])
    self.assertGreaterEqual(len(q['options']),3)
    self.assertEqual(len(q['options']),len(set(q['options'])))
    self.assertEqual(q['options'].count(q['answer']),1)
    self.assertIn(q['answer'],[facts[q['factId']]['title'],facts[q['factId']]['text']])
    for option in q['options']:self.assertIn(option,[v for f in facts.values() for v in [f['title'],f['text']]])
  self.assertEqual(len(data['lessons']),11)
  self.assertEqual(len(ids),84)
 def test_determinism(self):
  file=ROOT/'assets/data/lessons.json';before=file.read_bytes();build();self.assertEqual(before,file.read_bytes())
if __name__=='__main__':unittest.main()
