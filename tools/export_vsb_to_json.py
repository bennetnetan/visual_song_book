#!/usr/bin/env python3
"""Converts VSB (Microsoft Access MDB) songbooks to JSON for platform-agnostic Flutter bundling."""

import csv
import io
import json
import os
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
OUT_DIR = os.path.join(ROOT, 'assets', 'songbooks', 'data')
os.makedirs(OUT_DIR, exist_ok=True)

BOOKS = [
    {
        'vsb': os.path.join(ROOT, 'assets', 'songbooks', 'Full Song Book.vsb'),
        'out': 'full_song_book',
        'default_category': 'Full Song Book',
    },
    {
        'vsb': os.path.join(ROOT, 'assets', 'songbooks', 'Injili Song Book.vsb'),
        'out': 'injili_song_book',
        'default_category': 'Injili Song Book',
    },
]


def mdb_export(vsb_path: str, table: str) -> str:
    """Run mdb-export and return the CSV string."""
    try:
        result = subprocess.run(
            ['mdb-export', vsb_path, table],
            capture_output=True, text=True, timeout=30,
        )
        if result.returncode == 0:
            return result.stdout
    except Exception as e:
        print(f'  Warning: mdb-export {table} failed: {e}', file=sys.stderr)
    return ''


def parse_categories(csv_text: str, default_name: str):
    categories = []
    if csv_text.strip():
        reader = csv.DictReader(io.StringIO(csv_text))
        for row in reader:
            cat_id = row.get('ID') or row.get('id')
            cat_name = row.get('Name') or row.get('name') or ''
            if cat_id and cat_name.strip():
                categories.append({'id': int(cat_id), 'name': cat_name.strip()})
    if not categories:
        categories = [{'id': 1, 'name': default_name}]
    return categories


def parse_songs(csv_text: str, source_name: str):
    songs = []
    if not csv_text.strip():
        return songs
    reader = csv.DictReader(io.StringIO(csv_text))
    for row in reader:
        song_num = row.get('SongNum') or row.get('song_num') or row.get('SongID') or ''
        title = row.get('Title') or row.get('title') or ''
        body = row.get('Body') or row.get('body') or ''
        if not (song_num and title and body):
            continue
        # Clean up line endings: \r\r\n -> \n
        clean_body = body.replace('\r\r\n', '\n').replace('\r\n', '\n').replace('\r', '\n')
        songs.append({
            'song_num': int(song_num),
            'title': title.strip(),
            'key': (row.get('Key') or row.get('key') or '').strip() or None,
            'body': clean_body,
            'author': (row.get('Author') or row.get('author') or '').strip() or None,
            'copyright': (row.get('Copyright') or row.get('copyright') or '').strip() or None,
            'search': (row.get('Search') or row.get('search') or '').strip() or None,
            'category_id': int(row['CategoryId']) if (row.get('CategoryId') or '').strip() else None,
        })
    return songs


def export_book(book_info: dict):
    vsb = book_info['vsb']
    out_name = book_info['out']
    default_cat = book_info['default_category']

    print(f'Exporting: {os.path.basename(vsb)} -> {out_name}.json')

    cat_csv = mdb_export(vsb, 'Categories')
    songs_csv = mdb_export(vsb, 'Songs')

    categories = parse_categories(cat_csv, default_cat)
    songs = parse_songs(songs_csv, out_name)

    out_path = os.path.join(OUT_DIR, f'{out_name}.json')
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump({'categories': categories, 'songs': songs}, f, ensure_ascii=False, indent=2)

    print(f'  -> {len(songs)} songs, {len(categories)} categories written to {out_path}')


if __name__ == '__main__':
    for book in BOOKS:
        export_book(book)
    print('\nDone.')
