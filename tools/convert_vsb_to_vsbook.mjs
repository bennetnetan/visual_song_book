#!/usr/bin/env node
/**
 * convert_vsb_to_vsbook.js
 *
 * Converts a .vsb/.mdb (Microsoft Access) file to .vsbook format.
 * Uses mdb-reader (pure JS, no native deps) — works on Windows
 * without mdb-tools.
 *
 * Usage:
 *   node tools/convert_vsb_to_vsbook.js <input.vsb> [output.vsbook]
 *
 * Output: a ZIP archive containing:
 *   - metadata.json
 *   - songs.json
 *   - categories.json
 */

import fs from 'fs';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
import MDBReader from 'mdb-reader';
const archiver = require('archiver');

// ── Parse args ──────────────────────────────────────────────────────────────
const inputPath = process.argv[2];
if (!inputPath) {
  console.error('Usage: node convert_vsb_to_vsbook.js <input.vsb> [output.vsbook]');
  process.exit(1);
}

const outputPath = process.argv[3] || inputPath.replace(/\.(vsb|mdb)$/i, '.vsbook');

if (!fs.existsSync(inputPath)) {
  console.error(`File not found: ${inputPath}`);
  process.exit(1);
}

// ── Read MDB ────────────────────────────────────────────────────────────────
const buffer = fs.readFileSync(inputPath);
const db = new MDBReader(buffer);

const tableNames = db.getTableNames();
console.log(`Tables found: ${tableNames.join(', ')}`);

// ── Extract Categories ──────────────────────────────────────────────────────
const categories = [];
const categoriesTable = db.getTable('Categories');
if (categoriesTable) {
  const rows = categoriesTable.getData();
  for (const row of rows) {
    const id = parseInt(row['ID'] ?? row['id'], 10);
    const name = (row['Name'] ?? row['name'] ?? '').toString().trim();
    if (!isNaN(id) && name) {
      categories.push({ id, name });
    }
  }
  console.log(`Extracted ${categories.length} categories`);
} else {
  console.log('No Categories table found (will proceed without categories)');
}

// ── Extract Songs ───────────────────────────────────────────────────────────
const songs = [];
const songsTable = db.getTable('Songs');
if (!songsTable) {
  console.error('No Songs table found in the database');
  process.exit(1);
}

const rows = songsTable.getData();
for (const row of rows) {
  const songNum = parseInt(row['SongNum'] ?? '0', 10);
  const title = (row['Title'] ?? '').toString().trim();
  const body = (row['Body'] ?? '').toString().trim();

  if (!title || !body) continue;

  const key = row['Key']?.toString().trim() || null;
  const author = row['Author']?.toString().trim() || null;
  const copyright = row['Copyright']?.toString().trim() || null;
  const search = row['Search']?.toString().trim() || null;
  const rawCategoryId = parseInt(row['CategoryId'] ?? '0', 10);
  const songId = parseInt(row['SongID'] ?? '0', 10);

  // Parse modified date — MDB stores as "MM/DD/YY HH:MM:SS"
  let modified = null;
  const rawModified = row['Modified']?.toString().trim();
  if (rawModified && rawModified !== 'null') {
    modified = parseMdbDate(rawModified);
  }

  songs.push({
    song_num: songNum,
    title,
    body,
    key,
    modified,
    search,
    copyright,
    author,
    category_id: rawCategoryId || null,
    source_song_id: songId || null,
    source_path: null,
    source_format: 'vsb',
  });
}

console.log(`Extracted ${songs.length} songs`);

// ── Write .vsbook (ZIP with JSON) ──────────────────────────────────────────
function writeVsbook() {
  return new Promise((resolve, reject) => {
    const output = fs.createWriteStream(outputPath);
    const archive = new archiver.ZipArchive({ zlib: { level: 9 } });

    output.on('close', () => {
      const sizeKB = (archive.pointer() / 1024).toFixed(1);
      console.log(`\nOutput: ${outputPath} (${sizeKB} KB)`);
      resolve();
    });

    archive.on('error', reject);
    archive.pipe(output);

    // metadata.json
    archive.append(
      JSON.stringify({
        app: 'Visual Song Book',
        version: '2.2.0',
        exported_at: new Date().toISOString(),
        format: 'json',
        song_count: songs.length,
        category_count: categories.length,
      }, null, 2),
      { name: 'metadata.json' }
    );

    // songs.json
    archive.append(JSON.stringify(songs, null, 2), { name: 'songs.json' });

    // categories.json
    archive.append(JSON.stringify(categories, null, 2), { name: 'categories.json' });

    archive.finalize();
  });
}

// ── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Parses MDB date format "MM/DD/YY HH:MM:SS" to ISO string.
 */
function parseMdbDate(dateStr) {
  try {
    const parts = dateStr.split(' ');
    if (parts.length === 0) return null;

    const dateParts = parts[0].split('/');
    if (dateParts.length !== 3) return null;

    let month = parseInt(dateParts[0], 10);
    let day = parseInt(dateParts[1], 10);
    let year = parseInt(dateParts[2], 10);

    // Handle 2-digit years
    if (year < 70) year += 2000;
    else if (year < 100) year += 1900;

    let hour = 0, minute = 0, second = 0;
    if (parts.length > 1) {
      const timeParts = parts[1].split(':');
      if (timeParts.length >= 2) {
        hour = parseInt(timeParts[0], 10);
        minute = parseInt(timeParts[1], 10);
      }
      if (timeParts.length >= 3) {
        second = parseInt(timeParts[2], 10);
      }
    }

    const dt = new Date(year, month - 1, day, hour, minute, second);
    return dt.toISOString();
  } catch {
    return null;
  }
}

// ── Run ─────────────────────────────────────────────────────────────────────
writeVsbook().catch((err) => {
  console.error('Error writing .vsbook:', err);
  process.exit(1);
});
