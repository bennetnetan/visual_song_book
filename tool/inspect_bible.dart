import 'package:sqlite3/sqlite3.dart';
void main() {
  final db = sqlite3.open('/home/benjanetan/Documents/Holy Bible/kjv.sqlite');
  final tables = db.select("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name");
  print('Tables:');
  for (var row in tables) print('  ${row[0]}');
  for (var row in tables) {
    final name = row[0];
    final schema = db.select("SELECT sql FROM sqlite_master WHERE name = '$name'");
    for (var s in schema) {
      print('\n${s[0]}');
    }
  }
  for (var row in tables) {
    final name = row[0];
    final count = db.select("SELECT COUNT(*) FROM '$name'");
    print('\n$name: ${count.first[0]} rows');
    final sample = db.select("SELECT * FROM '$name' LIMIT 2");
    print('  columns: ${sample.columnNames}');
    for (var r in sample) print('  $r');
  }
  db.dispose();
}
