"""Run with Python + pymupdf. Keeps page numbers for source verification."""
import json
from pathlib import Path
import pymupdf
names = [('fiqh','مراجعة الفقه محدث-1.pdf','مراجعة الفقه','الطهارة وأحكامها'),('prayer','مراجعة كتاب الصلاة.pdf','كتاب الصلاة','شروط الصلاة وأحكامها'),('belief','مراجعة_العقيدة_مرتبة_بدون_اسم_المعلمة.pdf','مراجعة العقيدة','الأصول الإيمانية')]
books=[]
for id,file,title,subtitle in names:
    doc=pymupdf.open(file)
    books.append(dict(id=id,file=file,title=title,subtitle=subtitle,pages=[dict(number=i+1,text=p.get_text()) for i,p in enumerate(doc)]))
Path('assets/data/books.json').write_text(json.dumps(books,ensure_ascii=False,indent=2))
