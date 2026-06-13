// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'songbook_db.dart';

// ignore_for_file: type=lint
class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 100),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final int id;
  final String name;
  const Category({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(id: Value(id), name: Value(name));
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  Category copyWith({int? id, String? name}) =>
      Category(id: id ?? this.id, name: name ?? this.name);
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category && other.id == this.id && other.name == this.name);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<int> id;
  final Value<String> name;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  CategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
  }) : name = Value(name);
  static Insertable<Category> custom({
    Expression<int>? id,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  CategoriesCompanion copyWith({Value<int>? id, Value<String>? name}) {
    return CategoriesCompanion(id: id ?? this.id, name: name ?? this.name);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $SongsTable extends Songs with TableInfo<$SongsTable, Song> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _songNumMeta = const VerificationMeta(
    'songNum',
  );
  @override
  late final GeneratedColumn<int> songNum = GeneratedColumn<int>(
    'song_num',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 200),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 100),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modifiedMeta = const VerificationMeta(
    'modified',
  );
  @override
  late final GeneratedColumn<DateTime> modified = GeneratedColumn<DateTime>(
    'modified',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _searchMeta = const VerificationMeta('search');
  @override
  late final GeneratedColumn<String> search = GeneratedColumn<String>(
    'search',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _copyrightMeta = const VerificationMeta(
    'copyright',
  );
  @override
  late final GeneratedColumn<String> copyright = GeneratedColumn<String>(
    'copyright',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 200),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 200),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _sourceSongIdMeta = const VerificationMeta(
    'sourceSongId',
  );
  @override
  late final GeneratedColumn<int> sourceSongId = GeneratedColumn<int>(
    'source_song_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourcePathMeta = const VerificationMeta(
    'sourcePath',
  );
  @override
  late final GeneratedColumn<String> sourcePath = GeneratedColumn<String>(
    'source_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceFormatMeta = const VerificationMeta(
    'sourceFormat',
  );
  @override
  late final GeneratedColumn<String> sourceFormat = GeneratedColumn<String>(
    'source_format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    songNum,
    title,
    key,
    body,
    modified,
    search,
    copyright,
    author,
    categoryId,
    sourceSongId,
    sourcePath,
    sourceFormat,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'songs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Song> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('song_num')) {
      context.handle(
        _songNumMeta,
        songNum.isAcceptableOrUnknown(data['song_num']!, _songNumMeta),
      );
    } else if (isInserting) {
      context.missing(_songNumMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('modified')) {
      context.handle(
        _modifiedMeta,
        modified.isAcceptableOrUnknown(data['modified']!, _modifiedMeta),
      );
    }
    if (data.containsKey('search')) {
      context.handle(
        _searchMeta,
        search.isAcceptableOrUnknown(data['search']!, _searchMeta),
      );
    }
    if (data.containsKey('copyright')) {
      context.handle(
        _copyrightMeta,
        copyright.isAcceptableOrUnknown(data['copyright']!, _copyrightMeta),
      );
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('source_song_id')) {
      context.handle(
        _sourceSongIdMeta,
        sourceSongId.isAcceptableOrUnknown(
          data['source_song_id']!,
          _sourceSongIdMeta,
        ),
      );
    }
    if (data.containsKey('source_path')) {
      context.handle(
        _sourcePathMeta,
        sourcePath.isAcceptableOrUnknown(data['source_path']!, _sourcePathMeta),
      );
    }
    if (data.containsKey('source_format')) {
      context.handle(
        _sourceFormatMeta,
        sourceFormat.isAcceptableOrUnknown(
          data['source_format']!,
          _sourceFormatMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Song map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Song(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      songNum: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}song_num'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      modified: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modified'],
      ),
      search: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search'],
      ),
      copyright: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}copyright'],
      ),
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      ),
      sourceSongId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_song_id'],
      ),
      sourcePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_path'],
      ),
      sourceFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_format'],
      ),
    );
  }

  @override
  $SongsTable createAlias(String alias) {
    return $SongsTable(attachedDatabase, alias);
  }
}

class Song extends DataClass implements Insertable<Song> {
  final int id;
  final int songNum;
  final String title;
  final String? key;
  final String body;
  final DateTime? modified;
  final String? search;
  final String? copyright;
  final String? author;
  final int? categoryId;
  final int? sourceSongId;
  final String? sourcePath;
  final String? sourceFormat;
  const Song({
    required this.id,
    required this.songNum,
    required this.title,
    this.key,
    required this.body,
    this.modified,
    this.search,
    this.copyright,
    this.author,
    this.categoryId,
    this.sourceSongId,
    this.sourcePath,
    this.sourceFormat,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['song_num'] = Variable<int>(songNum);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || key != null) {
      map['key'] = Variable<String>(key);
    }
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || modified != null) {
      map['modified'] = Variable<DateTime>(modified);
    }
    if (!nullToAbsent || search != null) {
      map['search'] = Variable<String>(search);
    }
    if (!nullToAbsent || copyright != null) {
      map['copyright'] = Variable<String>(copyright);
    }
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    if (!nullToAbsent || sourceSongId != null) {
      map['source_song_id'] = Variable<int>(sourceSongId);
    }
    if (!nullToAbsent || sourcePath != null) {
      map['source_path'] = Variable<String>(sourcePath);
    }
    if (!nullToAbsent || sourceFormat != null) {
      map['source_format'] = Variable<String>(sourceFormat);
    }
    return map;
  }

  SongsCompanion toCompanion(bool nullToAbsent) {
    return SongsCompanion(
      id: Value(id),
      songNum: Value(songNum),
      title: Value(title),
      key: key == null && nullToAbsent ? const Value.absent() : Value(key),
      body: Value(body),
      modified: modified == null && nullToAbsent
          ? const Value.absent()
          : Value(modified),
      search: search == null && nullToAbsent
          ? const Value.absent()
          : Value(search),
      copyright: copyright == null && nullToAbsent
          ? const Value.absent()
          : Value(copyright),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      sourceSongId: sourceSongId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceSongId),
      sourcePath: sourcePath == null && nullToAbsent
          ? const Value.absent()
          : Value(sourcePath),
      sourceFormat: sourceFormat == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceFormat),
    );
  }

  factory Song.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Song(
      id: serializer.fromJson<int>(json['id']),
      songNum: serializer.fromJson<int>(json['songNum']),
      title: serializer.fromJson<String>(json['title']),
      key: serializer.fromJson<String?>(json['key']),
      body: serializer.fromJson<String>(json['body']),
      modified: serializer.fromJson<DateTime?>(json['modified']),
      search: serializer.fromJson<String?>(json['search']),
      copyright: serializer.fromJson<String?>(json['copyright']),
      author: serializer.fromJson<String?>(json['author']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      sourceSongId: serializer.fromJson<int?>(json['sourceSongId']),
      sourcePath: serializer.fromJson<String?>(json['sourcePath']),
      sourceFormat: serializer.fromJson<String?>(json['sourceFormat']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'songNum': serializer.toJson<int>(songNum),
      'title': serializer.toJson<String>(title),
      'key': serializer.toJson<String?>(key),
      'body': serializer.toJson<String>(body),
      'modified': serializer.toJson<DateTime?>(modified),
      'search': serializer.toJson<String?>(search),
      'copyright': serializer.toJson<String?>(copyright),
      'author': serializer.toJson<String?>(author),
      'categoryId': serializer.toJson<int?>(categoryId),
      'sourceSongId': serializer.toJson<int?>(sourceSongId),
      'sourcePath': serializer.toJson<String?>(sourcePath),
      'sourceFormat': serializer.toJson<String?>(sourceFormat),
    };
  }

  Song copyWith({
    int? id,
    int? songNum,
    String? title,
    Value<String?> key = const Value.absent(),
    String? body,
    Value<DateTime?> modified = const Value.absent(),
    Value<String?> search = const Value.absent(),
    Value<String?> copyright = const Value.absent(),
    Value<String?> author = const Value.absent(),
    Value<int?> categoryId = const Value.absent(),
    Value<int?> sourceSongId = const Value.absent(),
    Value<String?> sourcePath = const Value.absent(),
    Value<String?> sourceFormat = const Value.absent(),
  }) => Song(
    id: id ?? this.id,
    songNum: songNum ?? this.songNum,
    title: title ?? this.title,
    key: key.present ? key.value : this.key,
    body: body ?? this.body,
    modified: modified.present ? modified.value : this.modified,
    search: search.present ? search.value : this.search,
    copyright: copyright.present ? copyright.value : this.copyright,
    author: author.present ? author.value : this.author,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    sourceSongId: sourceSongId.present ? sourceSongId.value : this.sourceSongId,
    sourcePath: sourcePath.present ? sourcePath.value : this.sourcePath,
    sourceFormat: sourceFormat.present ? sourceFormat.value : this.sourceFormat,
  );
  Song copyWithCompanion(SongsCompanion data) {
    return Song(
      id: data.id.present ? data.id.value : this.id,
      songNum: data.songNum.present ? data.songNum.value : this.songNum,
      title: data.title.present ? data.title.value : this.title,
      key: data.key.present ? data.key.value : this.key,
      body: data.body.present ? data.body.value : this.body,
      modified: data.modified.present ? data.modified.value : this.modified,
      search: data.search.present ? data.search.value : this.search,
      copyright: data.copyright.present ? data.copyright.value : this.copyright,
      author: data.author.present ? data.author.value : this.author,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      sourceSongId: data.sourceSongId.present
          ? data.sourceSongId.value
          : this.sourceSongId,
      sourcePath: data.sourcePath.present
          ? data.sourcePath.value
          : this.sourcePath,
      sourceFormat: data.sourceFormat.present
          ? data.sourceFormat.value
          : this.sourceFormat,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Song(')
          ..write('id: $id, ')
          ..write('songNum: $songNum, ')
          ..write('title: $title, ')
          ..write('key: $key, ')
          ..write('body: $body, ')
          ..write('modified: $modified, ')
          ..write('search: $search, ')
          ..write('copyright: $copyright, ')
          ..write('author: $author, ')
          ..write('categoryId: $categoryId, ')
          ..write('sourceSongId: $sourceSongId, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('sourceFormat: $sourceFormat')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    songNum,
    title,
    key,
    body,
    modified,
    search,
    copyright,
    author,
    categoryId,
    sourceSongId,
    sourcePath,
    sourceFormat,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Song &&
          other.id == this.id &&
          other.songNum == this.songNum &&
          other.title == this.title &&
          other.key == this.key &&
          other.body == this.body &&
          other.modified == this.modified &&
          other.search == this.search &&
          other.copyright == this.copyright &&
          other.author == this.author &&
          other.categoryId == this.categoryId &&
          other.sourceSongId == this.sourceSongId &&
          other.sourcePath == this.sourcePath &&
          other.sourceFormat == this.sourceFormat);
}

class SongsCompanion extends UpdateCompanion<Song> {
  final Value<int> id;
  final Value<int> songNum;
  final Value<String> title;
  final Value<String?> key;
  final Value<String> body;
  final Value<DateTime?> modified;
  final Value<String?> search;
  final Value<String?> copyright;
  final Value<String?> author;
  final Value<int?> categoryId;
  final Value<int?> sourceSongId;
  final Value<String?> sourcePath;
  final Value<String?> sourceFormat;
  const SongsCompanion({
    this.id = const Value.absent(),
    this.songNum = const Value.absent(),
    this.title = const Value.absent(),
    this.key = const Value.absent(),
    this.body = const Value.absent(),
    this.modified = const Value.absent(),
    this.search = const Value.absent(),
    this.copyright = const Value.absent(),
    this.author = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.sourceSongId = const Value.absent(),
    this.sourcePath = const Value.absent(),
    this.sourceFormat = const Value.absent(),
  });
  SongsCompanion.insert({
    this.id = const Value.absent(),
    required int songNum,
    required String title,
    this.key = const Value.absent(),
    required String body,
    this.modified = const Value.absent(),
    this.search = const Value.absent(),
    this.copyright = const Value.absent(),
    this.author = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.sourceSongId = const Value.absent(),
    this.sourcePath = const Value.absent(),
    this.sourceFormat = const Value.absent(),
  }) : songNum = Value(songNum),
       title = Value(title),
       body = Value(body);
  static Insertable<Song> custom({
    Expression<int>? id,
    Expression<int>? songNum,
    Expression<String>? title,
    Expression<String>? key,
    Expression<String>? body,
    Expression<DateTime>? modified,
    Expression<String>? search,
    Expression<String>? copyright,
    Expression<String>? author,
    Expression<int>? categoryId,
    Expression<int>? sourceSongId,
    Expression<String>? sourcePath,
    Expression<String>? sourceFormat,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (songNum != null) 'song_num': songNum,
      if (title != null) 'title': title,
      if (key != null) 'key': key,
      if (body != null) 'body': body,
      if (modified != null) 'modified': modified,
      if (search != null) 'search': search,
      if (copyright != null) 'copyright': copyright,
      if (author != null) 'author': author,
      if (categoryId != null) 'category_id': categoryId,
      if (sourceSongId != null) 'source_song_id': sourceSongId,
      if (sourcePath != null) 'source_path': sourcePath,
      if (sourceFormat != null) 'source_format': sourceFormat,
    });
  }

  SongsCompanion copyWith({
    Value<int>? id,
    Value<int>? songNum,
    Value<String>? title,
    Value<String?>? key,
    Value<String>? body,
    Value<DateTime?>? modified,
    Value<String?>? search,
    Value<String?>? copyright,
    Value<String?>? author,
    Value<int?>? categoryId,
    Value<int?>? sourceSongId,
    Value<String?>? sourcePath,
    Value<String?>? sourceFormat,
  }) {
    return SongsCompanion(
      id: id ?? this.id,
      songNum: songNum ?? this.songNum,
      title: title ?? this.title,
      key: key ?? this.key,
      body: body ?? this.body,
      modified: modified ?? this.modified,
      search: search ?? this.search,
      copyright: copyright ?? this.copyright,
      author: author ?? this.author,
      categoryId: categoryId ?? this.categoryId,
      sourceSongId: sourceSongId ?? this.sourceSongId,
      sourcePath: sourcePath ?? this.sourcePath,
      sourceFormat: sourceFormat ?? this.sourceFormat,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (songNum.present) {
      map['song_num'] = Variable<int>(songNum.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (modified.present) {
      map['modified'] = Variable<DateTime>(modified.value);
    }
    if (search.present) {
      map['search'] = Variable<String>(search.value);
    }
    if (copyright.present) {
      map['copyright'] = Variable<String>(copyright.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (sourceSongId.present) {
      map['source_song_id'] = Variable<int>(sourceSongId.value);
    }
    if (sourcePath.present) {
      map['source_path'] = Variable<String>(sourcePath.value);
    }
    if (sourceFormat.present) {
      map['source_format'] = Variable<String>(sourceFormat.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SongsCompanion(')
          ..write('id: $id, ')
          ..write('songNum: $songNum, ')
          ..write('title: $title, ')
          ..write('key: $key, ')
          ..write('body: $body, ')
          ..write('modified: $modified, ')
          ..write('search: $search, ')
          ..write('copyright: $copyright, ')
          ..write('author: $author, ')
          ..write('categoryId: $categoryId, ')
          ..write('sourceSongId: $sourceSongId, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('sourceFormat: $sourceFormat')
          ..write(')'))
        .toString();
  }
}

class $SongBooksTable extends SongBooks
    with TableInfo<$SongBooksTable, SongBook> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongBooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 100),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startingNumberMeta = const VerificationMeta(
    'startingNumber',
  );
  @override
  late final GeneratedColumn<int> startingNumber = GeneratedColumn<int>(
    'starting_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endingNumberMeta = const VerificationMeta(
    'endingNumber',
  );
  @override
  late final GeneratedColumn<int> endingNumber = GeneratedColumn<int>(
    'ending_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    startingNumber,
    endingNumber,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'song_books';
  @override
  VerificationContext validateIntegrity(
    Insertable<SongBook> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('starting_number')) {
      context.handle(
        _startingNumberMeta,
        startingNumber.isAcceptableOrUnknown(
          data['starting_number']!,
          _startingNumberMeta,
        ),
      );
    }
    if (data.containsKey('ending_number')) {
      context.handle(
        _endingNumberMeta,
        endingNumber.isAcceptableOrUnknown(
          data['ending_number']!,
          _endingNumberMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SongBook map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SongBook(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      startingNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}starting_number'],
      ),
      endingNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ending_number'],
      ),
    );
  }

  @override
  $SongBooksTable createAlias(String alias) {
    return $SongBooksTable(attachedDatabase, alias);
  }
}

class SongBook extends DataClass implements Insertable<SongBook> {
  final int id;
  final String title;
  final int? startingNumber;
  final int? endingNumber;
  const SongBook({
    required this.id,
    required this.title,
    this.startingNumber,
    this.endingNumber,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || startingNumber != null) {
      map['starting_number'] = Variable<int>(startingNumber);
    }
    if (!nullToAbsent || endingNumber != null) {
      map['ending_number'] = Variable<int>(endingNumber);
    }
    return map;
  }

  SongBooksCompanion toCompanion(bool nullToAbsent) {
    return SongBooksCompanion(
      id: Value(id),
      title: Value(title),
      startingNumber: startingNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(startingNumber),
      endingNumber: endingNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(endingNumber),
    );
  }

  factory SongBook.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SongBook(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      startingNumber: serializer.fromJson<int?>(json['startingNumber']),
      endingNumber: serializer.fromJson<int?>(json['endingNumber']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'startingNumber': serializer.toJson<int?>(startingNumber),
      'endingNumber': serializer.toJson<int?>(endingNumber),
    };
  }

  SongBook copyWith({
    int? id,
    String? title,
    Value<int?> startingNumber = const Value.absent(),
    Value<int?> endingNumber = const Value.absent(),
  }) => SongBook(
    id: id ?? this.id,
    title: title ?? this.title,
    startingNumber: startingNumber.present
        ? startingNumber.value
        : this.startingNumber,
    endingNumber: endingNumber.present ? endingNumber.value : this.endingNumber,
  );
  SongBook copyWithCompanion(SongBooksCompanion data) {
    return SongBook(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      startingNumber: data.startingNumber.present
          ? data.startingNumber.value
          : this.startingNumber,
      endingNumber: data.endingNumber.present
          ? data.endingNumber.value
          : this.endingNumber,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SongBook(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('startingNumber: $startingNumber, ')
          ..write('endingNumber: $endingNumber')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, startingNumber, endingNumber);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SongBook &&
          other.id == this.id &&
          other.title == this.title &&
          other.startingNumber == this.startingNumber &&
          other.endingNumber == this.endingNumber);
}

class SongBooksCompanion extends UpdateCompanion<SongBook> {
  final Value<int> id;
  final Value<String> title;
  final Value<int?> startingNumber;
  final Value<int?> endingNumber;
  const SongBooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.startingNumber = const Value.absent(),
    this.endingNumber = const Value.absent(),
  });
  SongBooksCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.startingNumber = const Value.absent(),
    this.endingNumber = const Value.absent(),
  }) : title = Value(title);
  static Insertable<SongBook> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<int>? startingNumber,
    Expression<int>? endingNumber,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (startingNumber != null) 'starting_number': startingNumber,
      if (endingNumber != null) 'ending_number': endingNumber,
    });
  }

  SongBooksCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<int?>? startingNumber,
    Value<int?>? endingNumber,
  }) {
    return SongBooksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      startingNumber: startingNumber ?? this.startingNumber,
      endingNumber: endingNumber ?? this.endingNumber,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (startingNumber.present) {
      map['starting_number'] = Variable<int>(startingNumber.value);
    }
    if (endingNumber.present) {
      map['ending_number'] = Variable<int>(endingNumber.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SongBooksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('startingNumber: $startingNumber, ')
          ..write('endingNumber: $endingNumber')
          ..write(')'))
        .toString();
  }
}

class $HistoryTable extends History with TableInfo<$HistoryTable, HistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<int> songId = GeneratedColumn<int>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id)',
    ),
  );
  static const VerificationMeta _accessedAtMeta = const VerificationMeta(
    'accessedAt',
  );
  @override
  late final GeneratedColumn<DateTime> accessedAt = GeneratedColumn<DateTime>(
    'accessed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, songId, accessedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'history';
  @override
  VerificationContext validateIntegrity(
    Insertable<HistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('accessed_at')) {
      context.handle(
        _accessedAtMeta,
        accessedAt.isAcceptableOrUnknown(data['accessed_at']!, _accessedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_accessedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}song_id'],
      )!,
      accessedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}accessed_at'],
      )!,
    );
  }

  @override
  $HistoryTable createAlias(String alias) {
    return $HistoryTable(attachedDatabase, alias);
  }
}

class HistoryData extends DataClass implements Insertable<HistoryData> {
  final int id;
  final int songId;
  final DateTime accessedAt;
  const HistoryData({
    required this.id,
    required this.songId,
    required this.accessedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['song_id'] = Variable<int>(songId);
    map['accessed_at'] = Variable<DateTime>(accessedAt);
    return map;
  }

  HistoryCompanion toCompanion(bool nullToAbsent) {
    return HistoryCompanion(
      id: Value(id),
      songId: Value(songId),
      accessedAt: Value(accessedAt),
    );
  }

  factory HistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoryData(
      id: serializer.fromJson<int>(json['id']),
      songId: serializer.fromJson<int>(json['songId']),
      accessedAt: serializer.fromJson<DateTime>(json['accessedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'songId': serializer.toJson<int>(songId),
      'accessedAt': serializer.toJson<DateTime>(accessedAt),
    };
  }

  HistoryData copyWith({int? id, int? songId, DateTime? accessedAt}) =>
      HistoryData(
        id: id ?? this.id,
        songId: songId ?? this.songId,
        accessedAt: accessedAt ?? this.accessedAt,
      );
  HistoryData copyWithCompanion(HistoryCompanion data) {
    return HistoryData(
      id: data.id.present ? data.id.value : this.id,
      songId: data.songId.present ? data.songId.value : this.songId,
      accessedAt: data.accessedAt.present
          ? data.accessedAt.value
          : this.accessedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoryData(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('accessedAt: $accessedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, songId, accessedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryData &&
          other.id == this.id &&
          other.songId == this.songId &&
          other.accessedAt == this.accessedAt);
}

class HistoryCompanion extends UpdateCompanion<HistoryData> {
  final Value<int> id;
  final Value<int> songId;
  final Value<DateTime> accessedAt;
  const HistoryCompanion({
    this.id = const Value.absent(),
    this.songId = const Value.absent(),
    this.accessedAt = const Value.absent(),
  });
  HistoryCompanion.insert({
    this.id = const Value.absent(),
    required int songId,
    required DateTime accessedAt,
  }) : songId = Value(songId),
       accessedAt = Value(accessedAt);
  static Insertable<HistoryData> custom({
    Expression<int>? id,
    Expression<int>? songId,
    Expression<DateTime>? accessedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (songId != null) 'song_id': songId,
      if (accessedAt != null) 'accessed_at': accessedAt,
    });
  }

  HistoryCompanion copyWith({
    Value<int>? id,
    Value<int>? songId,
    Value<DateTime>? accessedAt,
  }) {
    return HistoryCompanion(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      accessedAt: accessedAt ?? this.accessedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<int>(songId.value);
    }
    if (accessedAt.present) {
      map['accessed_at'] = Variable<DateTime>(accessedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoryCompanion(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('accessedAt: $accessedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $SongsTable songs = $SongsTable(this);
  late final $SongBooksTable songBooks = $SongBooksTable(this);
  late final $HistoryTable history = $HistoryTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    categories,
    songs,
    songBooks,
    history,
  ];
}

typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({Value<int> id, required String name});
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({Value<int> id, Value<String> name});

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SongsTable, List<Song>> _songsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.songs,
    aliasName: $_aliasNameGenerator(db.categories.id, db.songs.categoryId),
  );

  $$SongsTableProcessedTableManager get songsRefs {
    final manager = $$SongsTableTableManager(
      $_db,
      $_db.songs,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_songsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> songsRefs(
    Expression<bool> Function($$SongsTableFilterComposer f) f,
  ) {
    final $$SongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableFilterComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  Expression<T> songsRefs<T extends Object>(
    Expression<T> Function($$SongsTableAnnotationComposer a) f,
  ) {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableAnnotationComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, $$CategoriesTableReferences),
          Category,
          PrefetchHooks Function({bool songsRefs})
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
              }) => CategoriesCompanion(id: id, name: name),
          createCompanionCallback:
              ({Value<int> id = const Value.absent(), required String name}) =>
                  CategoriesCompanion.insert(id: id, name: name),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({songsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (songsRefs) db.songs],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (songsRefs)
                    await $_getPrefetchedData<Category, $CategoriesTable, Song>(
                      currentTable: table,
                      referencedTable: $$CategoriesTableReferences
                          ._songsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CategoriesTableReferences(db, table, p0).songsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.categoryId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, $$CategoriesTableReferences),
      Category,
      PrefetchHooks Function({bool songsRefs})
    >;
typedef $$SongsTableCreateCompanionBuilder =
    SongsCompanion Function({
      Value<int> id,
      required int songNum,
      required String title,
      Value<String?> key,
      required String body,
      Value<DateTime?> modified,
      Value<String?> search,
      Value<String?> copyright,
      Value<String?> author,
      Value<int?> categoryId,
      Value<int?> sourceSongId,
      Value<String?> sourcePath,
      Value<String?> sourceFormat,
    });
typedef $$SongsTableUpdateCompanionBuilder =
    SongsCompanion Function({
      Value<int> id,
      Value<int> songNum,
      Value<String> title,
      Value<String?> key,
      Value<String> body,
      Value<DateTime?> modified,
      Value<String?> search,
      Value<String?> copyright,
      Value<String?> author,
      Value<int?> categoryId,
      Value<int?> sourceSongId,
      Value<String?> sourcePath,
      Value<String?> sourceFormat,
    });

final class $$SongsTableReferences
    extends BaseReferences<_$AppDatabase, $SongsTable, Song> {
  $$SongsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) => db.categories
      .createAlias($_aliasNameGenerator(db.songs.categoryId, db.categories.id));

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<int>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$HistoryTable, List<HistoryData>>
  _historyRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.history,
    aliasName: $_aliasNameGenerator(db.songs.id, db.history.songId),
  );

  $$HistoryTableProcessedTableManager get historyRefs {
    final manager = $$HistoryTableTableManager(
      $_db,
      $_db.history,
    ).filter((f) => f.songId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_historyRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SongsTableFilterComposer extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get songNum => $composableBuilder(
    column: $table.songNum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modified => $composableBuilder(
    column: $table.modified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get search => $composableBuilder(
    column: $table.search,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get copyright => $composableBuilder(
    column: $table.copyright,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceSongId => $composableBuilder(
    column: $table.sourceSongId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceFormat => $composableBuilder(
    column: $table.sourceFormat,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> historyRefs(
    Expression<bool> Function($$HistoryTableFilterComposer f) f,
  ) {
    final $$HistoryTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.history,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HistoryTableFilterComposer(
            $db: $db,
            $table: $db.history,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SongsTableOrderingComposer
    extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get songNum => $composableBuilder(
    column: $table.songNum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modified => $composableBuilder(
    column: $table.modified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get search => $composableBuilder(
    column: $table.search,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get copyright => $composableBuilder(
    column: $table.copyright,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceSongId => $composableBuilder(
    column: $table.sourceSongId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceFormat => $composableBuilder(
    column: $table.sourceFormat,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SongsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get songNum =>
      $composableBuilder(column: $table.songNum, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get modified =>
      $composableBuilder(column: $table.modified, builder: (column) => column);

  GeneratedColumn<String> get search =>
      $composableBuilder(column: $table.search, builder: (column) => column);

  GeneratedColumn<String> get copyright =>
      $composableBuilder(column: $table.copyright, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<int> get sourceSongId => $composableBuilder(
    column: $table.sourceSongId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceFormat => $composableBuilder(
    column: $table.sourceFormat,
    builder: (column) => column,
  );

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> historyRefs<T extends Object>(
    Expression<T> Function($$HistoryTableAnnotationComposer a) f,
  ) {
    final $$HistoryTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.history,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HistoryTableAnnotationComposer(
            $db: $db,
            $table: $db.history,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SongsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SongsTable,
          Song,
          $$SongsTableFilterComposer,
          $$SongsTableOrderingComposer,
          $$SongsTableAnnotationComposer,
          $$SongsTableCreateCompanionBuilder,
          $$SongsTableUpdateCompanionBuilder,
          (Song, $$SongsTableReferences),
          Song,
          PrefetchHooks Function({bool categoryId, bool historyRefs})
        > {
  $$SongsTableTableManager(_$AppDatabase db, $SongsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SongsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SongsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SongsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> songNum = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> key = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<DateTime?> modified = const Value.absent(),
                Value<String?> search = const Value.absent(),
                Value<String?> copyright = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<int?> sourceSongId = const Value.absent(),
                Value<String?> sourcePath = const Value.absent(),
                Value<String?> sourceFormat = const Value.absent(),
              }) => SongsCompanion(
                id: id,
                songNum: songNum,
                title: title,
                key: key,
                body: body,
                modified: modified,
                search: search,
                copyright: copyright,
                author: author,
                categoryId: categoryId,
                sourceSongId: sourceSongId,
                sourcePath: sourcePath,
                sourceFormat: sourceFormat,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int songNum,
                required String title,
                Value<String?> key = const Value.absent(),
                required String body,
                Value<DateTime?> modified = const Value.absent(),
                Value<String?> search = const Value.absent(),
                Value<String?> copyright = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<int?> sourceSongId = const Value.absent(),
                Value<String?> sourcePath = const Value.absent(),
                Value<String?> sourceFormat = const Value.absent(),
              }) => SongsCompanion.insert(
                id: id,
                songNum: songNum,
                title: title,
                key: key,
                body: body,
                modified: modified,
                search: search,
                copyright: copyright,
                author: author,
                categoryId: categoryId,
                sourceSongId: sourceSongId,
                sourcePath: sourcePath,
                sourceFormat: sourceFormat,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$SongsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false, historyRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (historyRefs) db.history],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (categoryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.categoryId,
                                referencedTable: $$SongsTableReferences
                                    ._categoryIdTable(db),
                                referencedColumn: $$SongsTableReferences
                                    ._categoryIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (historyRefs)
                    await $_getPrefetchedData<Song, $SongsTable, HistoryData>(
                      currentTable: table,
                      referencedTable: $$SongsTableReferences._historyRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$SongsTableReferences(db, table, p0).historyRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.songId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SongsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SongsTable,
      Song,
      $$SongsTableFilterComposer,
      $$SongsTableOrderingComposer,
      $$SongsTableAnnotationComposer,
      $$SongsTableCreateCompanionBuilder,
      $$SongsTableUpdateCompanionBuilder,
      (Song, $$SongsTableReferences),
      Song,
      PrefetchHooks Function({bool categoryId, bool historyRefs})
    >;
typedef $$SongBooksTableCreateCompanionBuilder =
    SongBooksCompanion Function({
      Value<int> id,
      required String title,
      Value<int?> startingNumber,
      Value<int?> endingNumber,
    });
typedef $$SongBooksTableUpdateCompanionBuilder =
    SongBooksCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<int?> startingNumber,
      Value<int?> endingNumber,
    });

class $$SongBooksTableFilterComposer
    extends Composer<_$AppDatabase, $SongBooksTable> {
  $$SongBooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startingNumber => $composableBuilder(
    column: $table.startingNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endingNumber => $composableBuilder(
    column: $table.endingNumber,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SongBooksTableOrderingComposer
    extends Composer<_$AppDatabase, $SongBooksTable> {
  $$SongBooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startingNumber => $composableBuilder(
    column: $table.startingNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endingNumber => $composableBuilder(
    column: $table.endingNumber,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SongBooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $SongBooksTable> {
  $$SongBooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get startingNumber => $composableBuilder(
    column: $table.startingNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endingNumber => $composableBuilder(
    column: $table.endingNumber,
    builder: (column) => column,
  );
}

class $$SongBooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SongBooksTable,
          SongBook,
          $$SongBooksTableFilterComposer,
          $$SongBooksTableOrderingComposer,
          $$SongBooksTableAnnotationComposer,
          $$SongBooksTableCreateCompanionBuilder,
          $$SongBooksTableUpdateCompanionBuilder,
          (SongBook, BaseReferences<_$AppDatabase, $SongBooksTable, SongBook>),
          SongBook,
          PrefetchHooks Function()
        > {
  $$SongBooksTableTableManager(_$AppDatabase db, $SongBooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SongBooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SongBooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SongBooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int?> startingNumber = const Value.absent(),
                Value<int?> endingNumber = const Value.absent(),
              }) => SongBooksCompanion(
                id: id,
                title: title,
                startingNumber: startingNumber,
                endingNumber: endingNumber,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                Value<int?> startingNumber = const Value.absent(),
                Value<int?> endingNumber = const Value.absent(),
              }) => SongBooksCompanion.insert(
                id: id,
                title: title,
                startingNumber: startingNumber,
                endingNumber: endingNumber,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SongBooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SongBooksTable,
      SongBook,
      $$SongBooksTableFilterComposer,
      $$SongBooksTableOrderingComposer,
      $$SongBooksTableAnnotationComposer,
      $$SongBooksTableCreateCompanionBuilder,
      $$SongBooksTableUpdateCompanionBuilder,
      (SongBook, BaseReferences<_$AppDatabase, $SongBooksTable, SongBook>),
      SongBook,
      PrefetchHooks Function()
    >;
typedef $$HistoryTableCreateCompanionBuilder =
    HistoryCompanion Function({
      Value<int> id,
      required int songId,
      required DateTime accessedAt,
    });
typedef $$HistoryTableUpdateCompanionBuilder =
    HistoryCompanion Function({
      Value<int> id,
      Value<int> songId,
      Value<DateTime> accessedAt,
    });

final class $$HistoryTableReferences
    extends BaseReferences<_$AppDatabase, $HistoryTable, HistoryData> {
  $$HistoryTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SongsTable _songIdTable(_$AppDatabase db) => db.songs.createAlias(
    $_aliasNameGenerator(db.history.songId, db.songs.id),
  );

  $$SongsTableProcessedTableManager get songId {
    final $_column = $_itemColumn<int>('song_id')!;

    final manager = $$SongsTableTableManager(
      $_db,
      $_db.songs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_songIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$HistoryTableFilterComposer
    extends Composer<_$AppDatabase, $HistoryTable> {
  $$HistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get accessedAt => $composableBuilder(
    column: $table.accessedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SongsTableFilterComposer get songId {
    final $$SongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableFilterComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $HistoryTable> {
  $$HistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get accessedAt => $composableBuilder(
    column: $table.accessedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SongsTableOrderingComposer get songId {
    final $$SongsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableOrderingComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $HistoryTable> {
  $$HistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get accessedAt => $composableBuilder(
    column: $table.accessedAt,
    builder: (column) => column,
  );

  $$SongsTableAnnotationComposer get songId {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableAnnotationComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HistoryTable,
          HistoryData,
          $$HistoryTableFilterComposer,
          $$HistoryTableOrderingComposer,
          $$HistoryTableAnnotationComposer,
          $$HistoryTableCreateCompanionBuilder,
          $$HistoryTableUpdateCompanionBuilder,
          (HistoryData, $$HistoryTableReferences),
          HistoryData,
          PrefetchHooks Function({bool songId})
        > {
  $$HistoryTableTableManager(_$AppDatabase db, $HistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> songId = const Value.absent(),
                Value<DateTime> accessedAt = const Value.absent(),
              }) => HistoryCompanion(
                id: id,
                songId: songId,
                accessedAt: accessedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int songId,
                required DateTime accessedAt,
              }) => HistoryCompanion.insert(
                id: id,
                songId: songId,
                accessedAt: accessedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HistoryTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({songId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (songId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.songId,
                                referencedTable: $$HistoryTableReferences
                                    ._songIdTable(db),
                                referencedColumn: $$HistoryTableReferences
                                    ._songIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$HistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HistoryTable,
      HistoryData,
      $$HistoryTableFilterComposer,
      $$HistoryTableOrderingComposer,
      $$HistoryTableAnnotationComposer,
      $$HistoryTableCreateCompanionBuilder,
      $$HistoryTableUpdateCompanionBuilder,
      (HistoryData, $$HistoryTableReferences),
      HistoryData,
      PrefetchHooks Function({bool songId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db, _db.songs);
  $$SongBooksTableTableManager get songBooks =>
      $$SongBooksTableTableManager(_db, _db.songBooks);
  $$HistoryTableTableManager get history =>
      $$HistoryTableTableManager(_db, _db.history);
}
