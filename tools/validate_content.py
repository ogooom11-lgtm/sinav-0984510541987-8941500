"""Validate all question interactions, source references and Dart type parity."""
import json
from hashlib import sha256
from import_sorular import parse_source
from pathlib import Path
root = Path(__file__).resolve().parent.parent
load = lambda name: json.loads((root / 'assets/data' / name).read_text())
books, questions, types = load('books.json'), load('questions.json'), load('types.json')
lookup = {b['id']: b for b in books}
coverage = load('coverage.json')
raw = (root/'sorular.txt').read_bytes()
records = parse_source(raw)
assert len(books) == 1 and books[0]['id'] == 'sorular'
assert coverage['sourceSha256'] == sha256(raw).hexdigest()
assert coverage['sourceBytes'] == len(raw)
assert coverage['sourceLines'] == len(raw.decode('utf-8').splitlines())
assert books[0]['pages'] == records
assert ''.join(p['text'] for p in books[0]['pages']).encode('utf-8') == raw
assert coverage['questionCount'] == len(questions)
all_questions=questions
questions=[q for q in all_questions if q['sourceId']=='sorular']
originals = [q for q in questions if q['kind'] == 'verbatim']
populated = [r for r in records if not r['empty']]
assert len(originals) == len(populated) == coverage['importedQuestions'] == 189
assert coverage['emptyBlocks'] == 34
assert all(q['id'] > 100000 for q in questions), 'Old question IDs must not survive'
assert all(q['book'] == 'sorular' for q in questions)
assert set(q['sourceSha256'] for q in questions) == {coverage['sourceSha256']}
for r in records:
    imported = [q for q in originals if q['page'] == r['number']]
    if r['empty']:
        assert not imported
        assert not any(r['number'] in q['sourceBlocks'] for q in questions)
    else:
        assert len(imported) == 1
        assert imported[0]['prompt'] == r['prompt'], 'No silent source edits'
        assert imported[0]['answer'] == r['answer'], 'No truncated original answers'
        assert imported[0]['lineStart'] == r['lineStart']
        assert imported[0]['lineEnd'] == r['lineEnd']
for item in coverage['blocks']:
    assert item['questionIds'] == [q['id'] for q in questions if item['number'] in q['sourceBlocks']]
content_lines = [i for i, line in enumerate(raw.decode('utf-8').splitlines(), 1)
    if line.strip() and line.strip() not in ('*سؤال*', '*الاجابة او التعريف*')]
assert coverage['contentLines'] == coverage['coveredContentLines'] == len(content_lines)
assert not coverage['uncoveredContentLines']
assert all(any(r['lineStart'] <= i <= r['lineEnd'] for r in populated) for i in content_lines)
critical = next(q for q in originals if q['page'] == 176)
assert critical['reviewOnly'] and critical['warning']
assert not any(176 in q['sourceBlocks'] for q in questions if q['kind'] == 'adapted')
assert len(types) == 19
assert not {'blank','missing_word','correct_word','correction','sentence'} & set(types)
assert len({q['id'] for q in questions}) == len(questions)
assert {q['type'] for q in all_questions} <= set(types)
dart_types = (root / 'lib/question_types.dart').read_text()
for key, config in types.items():
    assert f"'{key}': '{config['label']}'" in dart_types
    assert f"'{key}': '{config['mode']}'" in dart_types
for q in all_questions:
    if q['sourceId']!='sorular':
        continue
    assert q['book'] in lookup
    assert q['sourceBlocks'] and q['page'] == q['sourceBlocks'][0]
    for n in q['sourceBlocks']:
        assert 1 <= n <= len(records) and not records[n-1]['empty']
    assert 1 <= q['page'] <= len(lookup[q['book']]['pages'])
    assert q['prompt'] and q['answer'] and q['origin']
    assert q['type'] in types
    mode = types[q['type']]['mode']
    assert len(set(q['options'])) == len(q['options'])
    if mode == 'single':
        assert q['answer'] in q['options']
    elif mode in ('multi', 'order'):
        assert len(q['correct']) >= 2
        assert len(set(q['correct'])) == len(q['correct'])
        assert set(q['correct']) <= set(q['options'])
        if mode == 'order':
            assert set(q['correct']) == set(q['options'])
    elif mode == 'text':
        assert q['accepted'] and q['answer'] in q['accepted']
    elif mode == 'match':
        assert len(q['pairs']) >= 2
        assert len({p['left'] for p in q['pairs']}) == len(q['pairs'])
        assert len({p['right'] for p in q['pairs']}) == len(q['pairs'])
    elif mode == 'group':
        assert q['passage'] and len(q['parts']) >= 2
        for part in q['parts']:
            assert part['prompt'] and part['answer'] in part['accepted']
    else:
        assert mode == 'self' and not q['options']
    if q['type'] == 'hints':
        assert len(q['hints']) >= 2
    if q['type'] in ('passage_question', 'read_answer', 'passage_group'):
        assert q['passage']
for b in books:
    assert (root / b['file']).is_file()
    assert [p['number'] for p in b['pages']] == list(range(1, len(b['pages']) + 1))
print(f"OK: {len(originals)} complete original Q/A, {len(questions)-len(originals)} derived activities, {len({q['type'] for q in all_questions})} active types; every source byte and content line accounted for; no legacy questions")

# Every trainable answer line is represented by at least one generated activity.
assert coverage['learningUnits'] == len(coverage['units']) == 504
assert coverage['trainedUnits'] == sum(bool(u['generatedIds']) for u in coverage['units']) and coverage['criticalUnits'] == 2
by_id = {q['id']:q for q in questions}
for unit in coverage['units']:
    original = records[unit['block']-1]['answer'].replace('\r\n','\n').splitlines()[unit['line']-1]
    assert original == unit['text']
    if unit['reviewOnly']:
        assert not unit['generatedIds']
    else:
        assert len(unit['generatedIds']) >= 1
        for id in unit['generatedIds']:
            assert by_id[id]['unitKey'] == unit['key']
            assert by_id[id]['evidence'] == original
assert coverage['generatedQuestions'] == sum(q['kind']=='generated' for q in questions)
print('OK: source-unit ledger and removal of generated completions')

from build_courses import qa_records,notes_records
archive=load('course_sources.json')
for sid in ['file2','file3']:
    raw=(root/archive[sid]['file']).read_bytes()
    assert sha256(raw).hexdigest()==archive[sid]['sha256']
    assert (archive[sid]['prefix']+''.join(r['text'] for r in archive[sid]['records'])).encode()==raw
    parsed=notes_records(raw) if sid=='file2' else qa_records(raw)[1]
    assert parsed==archive[sid]['records']
    for q in [q for q in all_questions if q['sourceId']==sid]:
        refs=[parsed[n-1] for n in q['sourceBlocks']]
        assert q['sourceSha256']==archive[sid]['sha256']
        assert q['sourceFile']==archive[sid]['file']
        assert q['lineStart']==min(r['lineStart'] for r in refs)
        assert q['lineEnd']==max(r['lineEnd'] for r in refs)
        if q['variant']=='original':
            assert q['prompt']==refs[0]['prompt'] and q['answer']==refs[0]['answer']
            assert q['originalFormat']==archive[sid]['format']
        else:
            assert q['difficulty']=='متقدم'
            assert [e['quote'] for e in q['evidence']]==[r['answer'] for r in refs]
            assert not(sid=='file3' and 8 in q['sourceBlocks'])
        assert q['type'] in types and q['prompt'] and q['answer']
        mode=types[q['type']]['mode']
        if mode=='single':assert q['answer'] in q['options'] and len(set(q['options']))==len(q['options'])
        if mode in ('multi','order'):assert len(q['correct'])>=2 and set(q['correct'])<=set(q['options'])
assert len({q['id'] for q in all_questions})==len(all_questions)
assert not any(q['type'] in {'blank','missing_word','sentence'} for q in all_questions if q['variant']=='modified')
assert not any('___' in json.dumps([q['prompt'],q.get('parts',[])]) for q in all_questions if q['variant']=='modified')
assert next(q for q in all_questions if q['id']==3000008)['reviewOnly']
assert set(coverage['retiredQuestionIds']).isdisjoint(q['id'] for q in all_questions if not q['reviewOnly'])
print('OK: both new source files byte-exact; all original cards and adapted evidence verified, no cross-source references')
