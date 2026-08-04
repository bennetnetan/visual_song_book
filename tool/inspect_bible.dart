import 'package:sqlite3/sqlite3.dart';
void main() {
  final db = sqlite3.open('/home/benjanetan/Documents/Holy Bible/kjv.sqlite');
  final tables = db.select("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name");
  // ignore: avoid_print
  print('Tables:');
  for (Row row in tables) {
    // ignore: avoid_print
    print('  ${row[0].toString()}');
  }
  for (Row row in tables) {
    final name = row[0].toString();
    final schema = db.select("SELECT sql FROM sqlite_master WHERE name = '$name'");
    for (Row s in schema) {
      // ignore: avoid_print
      print('\n${s[0].toString()}');
    }
  }
  for (Row row in tables) {
    final name = row[0].toString();
    final count = db.select("SELECT COUNT(*) FROM '$name'");
    // ignore: avoid_print
    print('\n$name: ${count.first[0].toString()} rows');
    final sample = db.select("SELECT * FROM '$name' LIMIT 2");
    // ignore: avoid_print
    print('  columns: ${sample.columnNames}');
    for (Row r in sample) {
      // ignore: avoid_print
      print('  $r');
    }
  }
  db.dispose();
}
