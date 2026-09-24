"""Validate bank structure and references without third-party dependencies."""
import json
from pathlib import Path
root = Path(__file__).resolve().parent.parent
books = json.loads((root / 'assets/data/books.json').read_text())
questions = json.loads((root / 'assets/data/questions.json').read_text())
lookup = {b['id']: b for b in books}
assert len({q['id'] for q in questions}) == len(questions)
for q in questions:
    assert q['book'] in lookup
    assert 1 <= q['page'] <= len(lookup[q['book']]['pages'])
    assert q['prompt'] and q['answer'] and q['origin']
    assert q['type'] in {'choice', 'boolean', 'short'}
    if q['type'] != 'short':
        assert q['answer'] in q['options']
        assert len(set(q['options'])) == len(q['options'])
    else:
        assert not q['options']
for b in books:
    assert (root / b['file']).is_file()
    assert [p['number'] for p in b['pages']] == list(range(1, len(b['pages']) + 1))
print(f"OK: {len(books)} books, {sum(len(b['pages']) for b in books)} pages, {len(questions)} questions")
