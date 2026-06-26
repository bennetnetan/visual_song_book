#!/usr/bin/env bash
# Converts VSB (Microsoft Access MDB) songbooks to JSON for platform-agnostic bundling.
# Requires: mdb-export (mdbtools), python3

set -e
SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPTDIR/.."
OUTDIR="$ROOT/assets/songbooks/data"
mkdir -p "$OUTDIR"

export_book() {
  local vsb="$1"
  local out_name="$2"
  local category_name="$3"

  echo "Exporting: $vsb -> $out_name"

  # Export raw CSVs
  local cat_csv
  cat_csv=$(mdb-export "$vsb" Categories 2>/dev/null || echo "")
  local songs_csv
  songs_csv=$(mdb-export "$vsb" Songs 2>/dev/null || echo "")

  # Convert to JSON via python3 (no extra deps)
  python3 - "$out_name" "$category_name" "$OUTDIR" <<'PYEOF'
import sys, csv, json, io, os

out_name = sys.argv[1]
default_cat_name = sys.argv[2]
outdir = sys.argv[3]

cat_csv = sys.stdin.readline()   # sentinel — we read via heredoc trick below
PYEOF

  # Write via python with stdin piped properly
  python3 <<PYEOF
import csv, json, io, sys, os

cat_csv = """$cat_csv"""
songs_csv = """$songs_csv"""
out_name = "$out_name"
default_cat_name = "$category_name"
outdir = "$OUTDIR"

# Parse categories
categories = []
if cat_csv.strip():
    reader = csv.DictReader(io.StringIO(cat_csv))
    for row in reader:
        cat_id = row.get('ID') or row.get('id')
        cat_name = row.get('Name') or row.get('name') or ''
        if cat_id and cat_name.strip():
            categories.append({'id': int(cat_id), 'name': cat_name.strip()})

if not categories:
    categories = [{'id': 1, 'name': default_cat_name}]

# Parse songs
songs = []
if songs_csv.strip():
    reader = csv.DictReader(io.StringIO(songs_csv))
    for row in reader:
        song_num = row.get('SongNum') or row.get('song_num') or row.get('SongID') or ''
        title = row.get('Title') or row.get('title') or ''
        body = row.get('Body') or row.get('body') or ''
        if not (song_num and title and body):
            continue
        songs.append({
            'song_num': int(song_num),
            'title': title.strip(),
            'key': (row.get('Key') or row.get('key') or '').strip() or None,
            'body': body,
            'author': (row.get('Author') or row.get('author') or '').strip() or None,
            'copyright': (row.get('Copyright') or row.get('copyright') or '').strip() or None,
            'search': (row.get('Search') or row.get('search') or '').strip() or None,
            'category_id': int(row['CategoryId']) if (row.get('CategoryId') or '').strip() else None,
            'source_path': out_name,
            'source_format': 'vsb',
        })

out = {'categories': categories, 'songs': songs}
path = os.path.join(outdir, out_name + '.json')
with open(path, 'w', encoding='utf-8') as f:
    json.dump(out, f, ensure_ascii=False, indent=2)

print(f"  Written {len(songs)} songs, {len(categories)} categories -> {path}")
PYEOF
}

export_book "$ROOT/assets/songbooks/Full Song Book.vsb" "full_song_book" "Full Song Book"
export_book "$ROOT/assets/songbooks/Injili Song Book.vsb" "injili_song_book" "Injili Song Book"

echo ""
echo "Done. JSON files written to $OUTDIR"
ls -lh "$OUTDIR"
