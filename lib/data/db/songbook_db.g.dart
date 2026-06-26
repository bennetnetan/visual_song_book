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
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
    isActive,
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
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
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
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
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
  final bool isActive;
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
    required this.isActive,
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
    map['is_active'] = Variable<bool>(isActive);
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
      isActive: Value(isActive),
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
      isActive: serializer.fromJson<bool>(json['isActive']),
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
      'isActive': serializer.toJson<bool>(isActive),
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
    bool? isActive,
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
    isActive: isActive ?? this.isActive,
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
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
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
          ..write('sourceFormat: $sourceFormat, ')
          ..write('isActive: $isActive')
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
    isActive,
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
          other.sourceFormat == this.sourceFormat &&
          other.isActive == this.isActive);
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
  final Value<bool> isActive;
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
    this.isActive = const Value.absent(),
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
    this.isActive = const Value.absent(),
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
    Expression<bool>? isActive,
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
      if (isActive != null) 'is_active': isActive,
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
    Value<bool>? isActive,
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
      isActive: isActive ?? this.isActive,
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
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
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
          ..write('sourceFormat: $sourceFormat, ')
          ..write('isActive: $isActive')
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

class $SongSetsTable extends SongSets with TableInfo<$SongSetsTable, SongSet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongSetsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 200),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occasionMeta = const VerificationMeta(
    'occasion',
  );
  @override
  late final GeneratedColumn<String> occasion = GeneratedColumn<String>(
    'occasion',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    notes,
    occasion,
    createdAt,
    uuid,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'song_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<SongSet> instance, {
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
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('occasion')) {
      context.handle(
        _occasionMeta,
        occasion.isAcceptableOrUnknown(data['occasion']!, _occasionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SongSet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SongSet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      occasion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occasion'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      ),
    );
  }

  @override
  $SongSetsTable createAlias(String alias) {
    return $SongSetsTable(attachedDatabase, alias);
  }
}

class SongSet extends DataClass implements Insertable<SongSet> {
  final int id;
  final String name;
  final String? notes;
  final String? occasion;
  final DateTime createdAt;
  final String? uuid;
  const SongSet({
    required this.id,
    required this.name,
    this.notes,
    this.occasion,
    required this.createdAt,
    this.uuid,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || occasion != null) {
      map['occasion'] = Variable<String>(occasion);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || uuid != null) {
      map['uuid'] = Variable<String>(uuid);
    }
    return map;
  }

  SongSetsCompanion toCompanion(bool nullToAbsent) {
    return SongSetsCompanion(
      id: Value(id),
      name: Value(name),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      occasion: occasion == null && nullToAbsent
          ? const Value.absent()
          : Value(occasion),
      createdAt: Value(createdAt),
      uuid: uuid == null && nullToAbsent ? const Value.absent() : Value(uuid),
    );
  }

  factory SongSet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SongSet(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      notes: serializer.fromJson<String?>(json['notes']),
      occasion: serializer.fromJson<String?>(json['occasion']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      uuid: serializer.fromJson<String?>(json['uuid']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'notes': serializer.toJson<String?>(notes),
      'occasion': serializer.toJson<String?>(occasion),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'uuid': serializer.toJson<String?>(uuid),
    };
  }

  SongSet copyWith({
    int? id,
    String? name,
    Value<String?> notes = const Value.absent(),
    Value<String?> occasion = const Value.absent(),
    DateTime? createdAt,
    Value<String?> uuid = const Value.absent(),
  }) => SongSet(
    id: id ?? this.id,
    name: name ?? this.name,
    notes: notes.present ? notes.value : this.notes,
    occasion: occasion.present ? occasion.value : this.occasion,
    createdAt: createdAt ?? this.createdAt,
    uuid: uuid.present ? uuid.value : this.uuid,
  );
  SongSet copyWithCompanion(SongSetsCompanion data) {
    return SongSet(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      notes: data.notes.present ? data.notes.value : this.notes,
      occasion: data.occasion.present ? data.occasion.value : this.occasion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SongSet(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('notes: $notes, ')
          ..write('occasion: $occasion, ')
          ..write('createdAt: $createdAt, ')
          ..write('uuid: $uuid')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, notes, occasion, createdAt, uuid);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SongSet &&
          other.id == this.id &&
          other.name == this.name &&
          other.notes == this.notes &&
          other.occasion == this.occasion &&
          other.createdAt == this.createdAt &&
          other.uuid == this.uuid);
}

class SongSetsCompanion extends UpdateCompanion<SongSet> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> notes;
  final Value<String?> occasion;
  final Value<DateTime> createdAt;
  final Value<String?> uuid;
  const SongSetsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.notes = const Value.absent(),
    this.occasion = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.uuid = const Value.absent(),
  });
  SongSetsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.notes = const Value.absent(),
    this.occasion = const Value.absent(),
    required DateTime createdAt,
    this.uuid = const Value.absent(),
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<SongSet> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? notes,
    Expression<String>? occasion,
    Expression<DateTime>? createdAt,
    Expression<String>? uuid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (notes != null) 'notes': notes,
      if (occasion != null) 'occasion': occasion,
      if (createdAt != null) 'created_at': createdAt,
      if (uuid != null) 'uuid': uuid,
    });
  }

  SongSetsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? notes,
    Value<String?>? occasion,
    Value<DateTime>? createdAt,
    Value<String?>? uuid,
  }) {
    return SongSetsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      occasion: occasion ?? this.occasion,
      createdAt: createdAt ?? this.createdAt,
      uuid: uuid ?? this.uuid,
    );
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
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (occasion.present) {
      map['occasion'] = Variable<String>(occasion.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SongSetsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('notes: $notes, ')
          ..write('occasion: $occasion, ')
          ..write('createdAt: $createdAt, ')
          ..write('uuid: $uuid')
          ..write(')'))
        .toString();
  }
}

class $SongSetItemsTable extends SongSetItems
    with TableInfo<$SongSetItemsTable, SongSetItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongSetItemsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _setIdMeta = const VerificationMeta('setId');
  @override
  late final GeneratedColumn<int> setId = GeneratedColumn<int>(
    'set_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES song_sets (id)',
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
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, setId, songId, position, notes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'song_set_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<SongSetItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('set_id')) {
      context.handle(
        _setIdMeta,
        setId.isAcceptableOrUnknown(data['set_id']!, _setIdMeta),
      );
    } else if (isInserting) {
      context.missing(_setIdMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SongSetItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SongSetItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      setId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}set_id'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}song_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $SongSetItemsTable createAlias(String alias) {
    return $SongSetItemsTable(attachedDatabase, alias);
  }
}

class SongSetItem extends DataClass implements Insertable<SongSetItem> {
  final int id;
  final int setId;
  final int songId;
  final int position;
  final String? notes;
  const SongSetItem({
    required this.id,
    required this.setId,
    required this.songId,
    required this.position,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['set_id'] = Variable<int>(setId);
    map['song_id'] = Variable<int>(songId);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  SongSetItemsCompanion toCompanion(bool nullToAbsent) {
    return SongSetItemsCompanion(
      id: Value(id),
      setId: Value(setId),
      songId: Value(songId),
      position: Value(position),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory SongSetItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SongSetItem(
      id: serializer.fromJson<int>(json['id']),
      setId: serializer.fromJson<int>(json['setId']),
      songId: serializer.fromJson<int>(json['songId']),
      position: serializer.fromJson<int>(json['position']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'setId': serializer.toJson<int>(setId),
      'songId': serializer.toJson<int>(songId),
      'position': serializer.toJson<int>(position),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  SongSetItem copyWith({
    int? id,
    int? setId,
    int? songId,
    int? position,
    Value<String?> notes = const Value.absent(),
  }) => SongSetItem(
    id: id ?? this.id,
    setId: setId ?? this.setId,
    songId: songId ?? this.songId,
    position: position ?? this.position,
    notes: notes.present ? notes.value : this.notes,
  );
  SongSetItem copyWithCompanion(SongSetItemsCompanion data) {
    return SongSetItem(
      id: data.id.present ? data.id.value : this.id,
      setId: data.setId.present ? data.setId.value : this.setId,
      songId: data.songId.present ? data.songId.value : this.songId,
      position: data.position.present ? data.position.value : this.position,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SongSetItem(')
          ..write('id: $id, ')
          ..write('setId: $setId, ')
          ..write('songId: $songId, ')
          ..write('position: $position, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, setId, songId, position, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SongSetItem &&
          other.id == this.id &&
          other.setId == this.setId &&
          other.songId == this.songId &&
          other.position == this.position &&
          other.notes == this.notes);
}

class SongSetItemsCompanion extends UpdateCompanion<SongSetItem> {
  final Value<int> id;
  final Value<int> setId;
  final Value<int> songId;
  final Value<int> position;
  final Value<String?> notes;
  const SongSetItemsCompanion({
    this.id = const Value.absent(),
    this.setId = const Value.absent(),
    this.songId = const Value.absent(),
    this.position = const Value.absent(),
    this.notes = const Value.absent(),
  });
  SongSetItemsCompanion.insert({
    this.id = const Value.absent(),
    required int setId,
    required int songId,
    required int position,
    this.notes = const Value.absent(),
  }) : setId = Value(setId),
       songId = Value(songId),
       position = Value(position);
  static Insertable<SongSetItem> custom({
    Expression<int>? id,
    Expression<int>? setId,
    Expression<int>? songId,
    Expression<int>? position,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (setId != null) 'set_id': setId,
      if (songId != null) 'song_id': songId,
      if (position != null) 'position': position,
      if (notes != null) 'notes': notes,
    });
  }

  SongSetItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? setId,
    Value<int>? songId,
    Value<int>? position,
    Value<String?>? notes,
  }) {
    return SongSetItemsCompanion(
      id: id ?? this.id,
      setId: setId ?? this.setId,
      songId: songId ?? this.songId,
      position: position ?? this.position,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (setId.present) {
      map['set_id'] = Variable<int>(setId.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<int>(songId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SongSetItemsCompanion(')
          ..write('id: $id, ')
          ..write('setId: $setId, ')
          ..write('songId: $songId, ')
          ..write('position: $position, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $SetHistoryTable extends SetHistory
    with TableInfo<$SetHistoryTable, SetHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SetHistoryTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _setIdMeta = const VerificationMeta('setId');
  @override
  late final GeneratedColumn<int> setId = GeneratedColumn<int>(
    'set_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES song_sets (id)',
    ),
  );
  static const VerificationMeta _setNameMeta = const VerificationMeta(
    'setName',
  );
  @override
  late final GeneratedColumn<String> setName = GeneratedColumn<String>(
    'set_name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 200),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  List<GeneratedColumn> get $columns => [id, setId, setName, accessedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'set_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<SetHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('set_id')) {
      context.handle(
        _setIdMeta,
        setId.isAcceptableOrUnknown(data['set_id']!, _setIdMeta),
      );
    } else if (isInserting) {
      context.missing(_setIdMeta);
    }
    if (data.containsKey('set_name')) {
      context.handle(
        _setNameMeta,
        setName.isAcceptableOrUnknown(data['set_name']!, _setNameMeta),
      );
    } else if (isInserting) {
      context.missing(_setNameMeta);
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
  SetHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SetHistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      setId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}set_id'],
      )!,
      setName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}set_name'],
      )!,
      accessedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}accessed_at'],
      )!,
    );
  }

  @override
  $SetHistoryTable createAlias(String alias) {
    return $SetHistoryTable(attachedDatabase, alias);
  }
}

class SetHistoryData extends DataClass implements Insertable<SetHistoryData> {
  final int id;
  final int setId;
  final String setName;
  final DateTime accessedAt;
  const SetHistoryData({
    required this.id,
    required this.setId,
    required this.setName,
    required this.accessedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['set_id'] = Variable<int>(setId);
    map['set_name'] = Variable<String>(setName);
    map['accessed_at'] = Variable<DateTime>(accessedAt);
    return map;
  }

  SetHistoryCompanion toCompanion(bool nullToAbsent) {
    return SetHistoryCompanion(
      id: Value(id),
      setId: Value(setId),
      setName: Value(setName),
      accessedAt: Value(accessedAt),
    );
  }

  factory SetHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SetHistoryData(
      id: serializer.fromJson<int>(json['id']),
      setId: serializer.fromJson<int>(json['setId']),
      setName: serializer.fromJson<String>(json['setName']),
      accessedAt: serializer.fromJson<DateTime>(json['accessedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'setId': serializer.toJson<int>(setId),
      'setName': serializer.toJson<String>(setName),
      'accessedAt': serializer.toJson<DateTime>(accessedAt),
    };
  }

  SetHistoryData copyWith({
    int? id,
    int? setId,
    String? setName,
    DateTime? accessedAt,
  }) => SetHistoryData(
    id: id ?? this.id,
    setId: setId ?? this.setId,
    setName: setName ?? this.setName,
    accessedAt: accessedAt ?? this.accessedAt,
  );
  SetHistoryData copyWithCompanion(SetHistoryCompanion data) {
    return SetHistoryData(
      id: data.id.present ? data.id.value : this.id,
      setId: data.setId.present ? data.setId.value : this.setId,
      setName: data.setName.present ? data.setName.value : this.setName,
      accessedAt: data.accessedAt.present
          ? data.accessedAt.value
          : this.accessedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SetHistoryData(')
          ..write('id: $id, ')
          ..write('setId: $setId, ')
          ..write('setName: $setName, ')
          ..write('accessedAt: $accessedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, setId, setName, accessedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SetHistoryData &&
          other.id == this.id &&
          other.setId == this.setId &&
          other.setName == this.setName &&
          other.accessedAt == this.accessedAt);
}

class SetHistoryCompanion extends UpdateCompanion<SetHistoryData> {
  final Value<int> id;
  final Value<int> setId;
  final Value<String> setName;
  final Value<DateTime> accessedAt;
  const SetHistoryCompanion({
    this.id = const Value.absent(),
    this.setId = const Value.absent(),
    this.setName = const Value.absent(),
    this.accessedAt = const Value.absent(),
  });
  SetHistoryCompanion.insert({
    this.id = const Value.absent(),
    required int setId,
    required String setName,
    required DateTime accessedAt,
  }) : setId = Value(setId),
       setName = Value(setName),
       accessedAt = Value(accessedAt);
  static Insertable<SetHistoryData> custom({
    Expression<int>? id,
    Expression<int>? setId,
    Expression<String>? setName,
    Expression<DateTime>? accessedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (setId != null) 'set_id': setId,
      if (setName != null) 'set_name': setName,
      if (accessedAt != null) 'accessed_at': accessedAt,
    });
  }

  SetHistoryCompanion copyWith({
    Value<int>? id,
    Value<int>? setId,
    Value<String>? setName,
    Value<DateTime>? accessedAt,
  }) {
    return SetHistoryCompanion(
      id: id ?? this.id,
      setId: setId ?? this.setId,
      setName: setName ?? this.setName,
      accessedAt: accessedAt ?? this.accessedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (setId.present) {
      map['set_id'] = Variable<int>(setId.value);
    }
    if (setName.present) {
      map['set_name'] = Variable<String>(setName.value);
    }
    if (accessedAt.present) {
      map['accessed_at'] = Variable<DateTime>(accessedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SetHistoryCompanion(')
          ..write('id: $id, ')
          ..write('setId: $setId, ')
          ..write('setName: $setName, ')
          ..write('accessedAt: $accessedAt')
          ..write(')'))
        .toString();
  }
}

class $BibleHistoryTable extends BibleHistory
    with TableInfo<$BibleHistoryTable, BibleHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BibleHistoryTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _referenceMeta = const VerificationMeta(
    'reference',
  );
  @override
  late final GeneratedColumn<String> reference = GeneratedColumn<String>(
    'reference',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 100),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _passageMeta = const VerificationMeta(
    'passage',
  );
  @override
  late final GeneratedColumn<String> passage = GeneratedColumn<String>(
    'passage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  List<GeneratedColumn> get $columns => [id, reference, passage, accessedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bible_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<BibleHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('reference')) {
      context.handle(
        _referenceMeta,
        reference.isAcceptableOrUnknown(data['reference']!, _referenceMeta),
      );
    } else if (isInserting) {
      context.missing(_referenceMeta);
    }
    if (data.containsKey('passage')) {
      context.handle(
        _passageMeta,
        passage.isAcceptableOrUnknown(data['passage']!, _passageMeta),
      );
    } else if (isInserting) {
      context.missing(_passageMeta);
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
  BibleHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BibleHistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      reference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference'],
      )!,
      passage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}passage'],
      )!,
      accessedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}accessed_at'],
      )!,
    );
  }

  @override
  $BibleHistoryTable createAlias(String alias) {
    return $BibleHistoryTable(attachedDatabase, alias);
  }
}

class BibleHistoryData extends DataClass
    implements Insertable<BibleHistoryData> {
  final int id;
  final String reference;
  final String passage;
  final DateTime accessedAt;
  const BibleHistoryData({
    required this.id,
    required this.reference,
    required this.passage,
    required this.accessedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['reference'] = Variable<String>(reference);
    map['passage'] = Variable<String>(passage);
    map['accessed_at'] = Variable<DateTime>(accessedAt);
    return map;
  }

  BibleHistoryCompanion toCompanion(bool nullToAbsent) {
    return BibleHistoryCompanion(
      id: Value(id),
      reference: Value(reference),
      passage: Value(passage),
      accessedAt: Value(accessedAt),
    );
  }

  factory BibleHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BibleHistoryData(
      id: serializer.fromJson<int>(json['id']),
      reference: serializer.fromJson<String>(json['reference']),
      passage: serializer.fromJson<String>(json['passage']),
      accessedAt: serializer.fromJson<DateTime>(json['accessedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'reference': serializer.toJson<String>(reference),
      'passage': serializer.toJson<String>(passage),
      'accessedAt': serializer.toJson<DateTime>(accessedAt),
    };
  }

  BibleHistoryData copyWith({
    int? id,
    String? reference,
    String? passage,
    DateTime? accessedAt,
  }) => BibleHistoryData(
    id: id ?? this.id,
    reference: reference ?? this.reference,
    passage: passage ?? this.passage,
    accessedAt: accessedAt ?? this.accessedAt,
  );
  BibleHistoryData copyWithCompanion(BibleHistoryCompanion data) {
    return BibleHistoryData(
      id: data.id.present ? data.id.value : this.id,
      reference: data.reference.present ? data.reference.value : this.reference,
      passage: data.passage.present ? data.passage.value : this.passage,
      accessedAt: data.accessedAt.present
          ? data.accessedAt.value
          : this.accessedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BibleHistoryData(')
          ..write('id: $id, ')
          ..write('reference: $reference, ')
          ..write('passage: $passage, ')
          ..write('accessedAt: $accessedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, reference, passage, accessedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BibleHistoryData &&
          other.id == this.id &&
          other.reference == this.reference &&
          other.passage == this.passage &&
          other.accessedAt == this.accessedAt);
}

class BibleHistoryCompanion extends UpdateCompanion<BibleHistoryData> {
  final Value<int> id;
  final Value<String> reference;
  final Value<String> passage;
  final Value<DateTime> accessedAt;
  const BibleHistoryCompanion({
    this.id = const Value.absent(),
    this.reference = const Value.absent(),
    this.passage = const Value.absent(),
    this.accessedAt = const Value.absent(),
  });
  BibleHistoryCompanion.insert({
    this.id = const Value.absent(),
    required String reference,
    required String passage,
    required DateTime accessedAt,
  }) : reference = Value(reference),
       passage = Value(passage),
       accessedAt = Value(accessedAt);
  static Insertable<BibleHistoryData> custom({
    Expression<int>? id,
    Expression<String>? reference,
    Expression<String>? passage,
    Expression<DateTime>? accessedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (reference != null) 'reference': reference,
      if (passage != null) 'passage': passage,
      if (accessedAt != null) 'accessed_at': accessedAt,
    });
  }

  BibleHistoryCompanion copyWith({
    Value<int>? id,
    Value<String>? reference,
    Value<String>? passage,
    Value<DateTime>? accessedAt,
  }) {
    return BibleHistoryCompanion(
      id: id ?? this.id,
      reference: reference ?? this.reference,
      passage: passage ?? this.passage,
      accessedAt: accessedAt ?? this.accessedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (reference.present) {
      map['reference'] = Variable<String>(reference.value);
    }
    if (passage.present) {
      map['passage'] = Variable<String>(passage.value);
    }
    if (accessedAt.present) {
      map['accessed_at'] = Variable<DateTime>(accessedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BibleHistoryCompanion(')
          ..write('id: $id, ')
          ..write('reference: $reference, ')
          ..write('passage: $passage, ')
          ..write('accessedAt: $accessedAt')
          ..write(')'))
        .toString();
  }
}

class $BibleBookmarksTable extends BibleBookmarks
    with TableInfo<$BibleBookmarksTable, BibleBookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BibleBookmarksTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterMeta = const VerificationMeta(
    'chapter',
  );
  @override
  late final GeneratedColumn<int> chapter = GeneratedColumn<int>(
    'chapter',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _verseNumMeta = const VerificationMeta(
    'verseNum',
  );
  @override
  late final GeneratedColumn<int> verseNum = GeneratedColumn<int>(
    'verse_num',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _referenceMeta = const VerificationMeta(
    'reference',
  );
  @override
  late final GeneratedColumn<String> reference = GeneratedColumn<String>(
    'reference',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _verseTextMeta = const VerificationMeta(
    'verseText',
  );
  @override
  late final GeneratedColumn<String> verseText = GeneratedColumn<String>(
    'verse_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookNameMeta = const VerificationMeta(
    'bookName',
  );
  @override
  late final GeneratedColumn<String> bookName = GeneratedColumn<String>(
    'book_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    chapter,
    verseNum,
    reference,
    verseText,
    bookName,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bible_bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<BibleBookmark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('chapter')) {
      context.handle(
        _chapterMeta,
        chapter.isAcceptableOrUnknown(data['chapter']!, _chapterMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterMeta);
    }
    if (data.containsKey('verse_num')) {
      context.handle(
        _verseNumMeta,
        verseNum.isAcceptableOrUnknown(data['verse_num']!, _verseNumMeta),
      );
    } else if (isInserting) {
      context.missing(_verseNumMeta);
    }
    if (data.containsKey('reference')) {
      context.handle(
        _referenceMeta,
        reference.isAcceptableOrUnknown(data['reference']!, _referenceMeta),
      );
    } else if (isInserting) {
      context.missing(_referenceMeta);
    }
    if (data.containsKey('verse_text')) {
      context.handle(
        _verseTextMeta,
        verseText.isAcceptableOrUnknown(data['verse_text']!, _verseTextMeta),
      );
    } else if (isInserting) {
      context.missing(_verseTextMeta);
    }
    if (data.containsKey('book_name')) {
      context.handle(
        _bookNameMeta,
        bookName.isAcceptableOrUnknown(data['book_name']!, _bookNameMeta),
      );
    } else if (isInserting) {
      context.missing(_bookNameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BibleBookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BibleBookmark(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}book_id'],
      )!,
      chapter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter'],
      )!,
      verseNum: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}verse_num'],
      )!,
      reference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference'],
      )!,
      verseText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verse_text'],
      )!,
      bookName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BibleBookmarksTable createAlias(String alias) {
    return $BibleBookmarksTable(attachedDatabase, alias);
  }
}

class BibleBookmark extends DataClass implements Insertable<BibleBookmark> {
  final int id;
  final int bookId;
  final int chapter;
  final int verseNum;
  final String reference;
  final String verseText;
  final String bookName;
  final DateTime createdAt;
  const BibleBookmark({
    required this.id,
    required this.bookId,
    required this.chapter,
    required this.verseNum,
    required this.reference,
    required this.verseText,
    required this.bookName,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<int>(bookId);
    map['chapter'] = Variable<int>(chapter);
    map['verse_num'] = Variable<int>(verseNum);
    map['reference'] = Variable<String>(reference);
    map['verse_text'] = Variable<String>(verseText);
    map['book_name'] = Variable<String>(bookName);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BibleBookmarksCompanion toCompanion(bool nullToAbsent) {
    return BibleBookmarksCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapter: Value(chapter),
      verseNum: Value(verseNum),
      reference: Value(reference),
      verseText: Value(verseText),
      bookName: Value(bookName),
      createdAt: Value(createdAt),
    );
  }

  factory BibleBookmark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BibleBookmark(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<int>(json['bookId']),
      chapter: serializer.fromJson<int>(json['chapter']),
      verseNum: serializer.fromJson<int>(json['verseNum']),
      reference: serializer.fromJson<String>(json['reference']),
      verseText: serializer.fromJson<String>(json['verseText']),
      bookName: serializer.fromJson<String>(json['bookName']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<int>(bookId),
      'chapter': serializer.toJson<int>(chapter),
      'verseNum': serializer.toJson<int>(verseNum),
      'reference': serializer.toJson<String>(reference),
      'verseText': serializer.toJson<String>(verseText),
      'bookName': serializer.toJson<String>(bookName),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BibleBookmark copyWith({
    int? id,
    int? bookId,
    int? chapter,
    int? verseNum,
    String? reference,
    String? verseText,
    String? bookName,
    DateTime? createdAt,
  }) => BibleBookmark(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    chapter: chapter ?? this.chapter,
    verseNum: verseNum ?? this.verseNum,
    reference: reference ?? this.reference,
    verseText: verseText ?? this.verseText,
    bookName: bookName ?? this.bookName,
    createdAt: createdAt ?? this.createdAt,
  );
  BibleBookmark copyWithCompanion(BibleBookmarksCompanion data) {
    return BibleBookmark(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapter: data.chapter.present ? data.chapter.value : this.chapter,
      verseNum: data.verseNum.present ? data.verseNum.value : this.verseNum,
      reference: data.reference.present ? data.reference.value : this.reference,
      verseText: data.verseText.present ? data.verseText.value : this.verseText,
      bookName: data.bookName.present ? data.bookName.value : this.bookName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BibleBookmark(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapter: $chapter, ')
          ..write('verseNum: $verseNum, ')
          ..write('reference: $reference, ')
          ..write('verseText: $verseText, ')
          ..write('bookName: $bookName, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    chapter,
    verseNum,
    reference,
    verseText,
    bookName,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BibleBookmark &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.chapter == this.chapter &&
          other.verseNum == this.verseNum &&
          other.reference == this.reference &&
          other.verseText == this.verseText &&
          other.bookName == this.bookName &&
          other.createdAt == this.createdAt);
}

class BibleBookmarksCompanion extends UpdateCompanion<BibleBookmark> {
  final Value<int> id;
  final Value<int> bookId;
  final Value<int> chapter;
  final Value<int> verseNum;
  final Value<String> reference;
  final Value<String> verseText;
  final Value<String> bookName;
  final Value<DateTime> createdAt;
  const BibleBookmarksCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapter = const Value.absent(),
    this.verseNum = const Value.absent(),
    this.reference = const Value.absent(),
    this.verseText = const Value.absent(),
    this.bookName = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  BibleBookmarksCompanion.insert({
    this.id = const Value.absent(),
    required int bookId,
    required int chapter,
    required int verseNum,
    required String reference,
    required String verseText,
    required String bookName,
    required DateTime createdAt,
  }) : bookId = Value(bookId),
       chapter = Value(chapter),
       verseNum = Value(verseNum),
       reference = Value(reference),
       verseText = Value(verseText),
       bookName = Value(bookName),
       createdAt = Value(createdAt);
  static Insertable<BibleBookmark> custom({
    Expression<int>? id,
    Expression<int>? bookId,
    Expression<int>? chapter,
    Expression<int>? verseNum,
    Expression<String>? reference,
    Expression<String>? verseText,
    Expression<String>? bookName,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (chapter != null) 'chapter': chapter,
      if (verseNum != null) 'verse_num': verseNum,
      if (reference != null) 'reference': reference,
      if (verseText != null) 'verse_text': verseText,
      if (bookName != null) 'book_name': bookName,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  BibleBookmarksCompanion copyWith({
    Value<int>? id,
    Value<int>? bookId,
    Value<int>? chapter,
    Value<int>? verseNum,
    Value<String>? reference,
    Value<String>? verseText,
    Value<String>? bookName,
    Value<DateTime>? createdAt,
  }) {
    return BibleBookmarksCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapter: chapter ?? this.chapter,
      verseNum: verseNum ?? this.verseNum,
      reference: reference ?? this.reference,
      verseText: verseText ?? this.verseText,
      bookName: bookName ?? this.bookName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (chapter.present) {
      map['chapter'] = Variable<int>(chapter.value);
    }
    if (verseNum.present) {
      map['verse_num'] = Variable<int>(verseNum.value);
    }
    if (reference.present) {
      map['reference'] = Variable<String>(reference.value);
    }
    if (verseText.present) {
      map['verse_text'] = Variable<String>(verseText.value);
    }
    if (bookName.present) {
      map['book_name'] = Variable<String>(bookName.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BibleBookmarksCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapter: $chapter, ')
          ..write('verseNum: $verseNum, ')
          ..write('reference: $reference, ')
          ..write('verseText: $verseText, ')
          ..write('bookName: $bookName, ')
          ..write('createdAt: $createdAt')
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
  late final $SongSetsTable songSets = $SongSetsTable(this);
  late final $SongSetItemsTable songSetItems = $SongSetItemsTable(this);
  late final $SetHistoryTable setHistory = $SetHistoryTable(this);
  late final $BibleHistoryTable bibleHistory = $BibleHistoryTable(this);
  late final $BibleBookmarksTable bibleBookmarks = $BibleBookmarksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    categories,
    songs,
    songBooks,
    history,
    songSets,
    songSetItems,
    setHistory,
    bibleHistory,
    bibleBookmarks,
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
      Value<bool> isActive,
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
      Value<bool> isActive,
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

  static MultiTypedResultKey<$SongSetItemsTable, List<SongSetItem>>
  _songSetItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.songSetItems,
    aliasName: $_aliasNameGenerator(db.songs.id, db.songSetItems.songId),
  );

  $$SongSetItemsTableProcessedTableManager get songSetItemsRefs {
    final manager = $$SongSetItemsTableTableManager(
      $_db,
      $_db.songSetItems,
    ).filter((f) => f.songId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_songSetItemsRefsTable($_db));
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

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
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

  Expression<bool> songSetItemsRefs(
    Expression<bool> Function($$SongSetItemsTableFilterComposer f) f,
  ) {
    final $$SongSetItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.songSetItems,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongSetItemsTableFilterComposer(
            $db: $db,
            $table: $db.songSetItems,
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

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
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

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

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

  Expression<T> songSetItemsRefs<T extends Object>(
    Expression<T> Function($$SongSetItemsTableAnnotationComposer a) f,
  ) {
    final $$SongSetItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.songSetItems,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongSetItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.songSetItems,
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
          PrefetchHooks Function({
            bool categoryId,
            bool historyRefs,
            bool songSetItemsRefs,
          })
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
                Value<bool> isActive = const Value.absent(),
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
                isActive: isActive,
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
                Value<bool> isActive = const Value.absent(),
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
                isActive: isActive,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$SongsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                categoryId = false,
                historyRefs = false,
                songSetItemsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (historyRefs) db.history,
                    if (songSetItemsRefs) db.songSetItems,
                  ],
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
                        await $_getPrefetchedData<
                          Song,
                          $SongsTable,
                          HistoryData
                        >(
                          currentTable: table,
                          referencedTable: $$SongsTableReferences
                              ._historyRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SongsTableReferences(db, table, p0).historyRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.songId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (songSetItemsRefs)
                        await $_getPrefetchedData<
                          Song,
                          $SongsTable,
                          SongSetItem
                        >(
                          currentTable: table,
                          referencedTable: $$SongsTableReferences
                              ._songSetItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SongsTableReferences(
                                db,
                                table,
                                p0,
                              ).songSetItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.songId == item.id,
                              ),
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
      PrefetchHooks Function({
        bool categoryId,
        bool historyRefs,
        bool songSetItemsRefs,
      })
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
typedef $$SongSetsTableCreateCompanionBuilder =
    SongSetsCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> notes,
      Value<String?> occasion,
      required DateTime createdAt,
      Value<String?> uuid,
    });
typedef $$SongSetsTableUpdateCompanionBuilder =
    SongSetsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> notes,
      Value<String?> occasion,
      Value<DateTime> createdAt,
      Value<String?> uuid,
    });

final class $$SongSetsTableReferences
    extends BaseReferences<_$AppDatabase, $SongSetsTable, SongSet> {
  $$SongSetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SongSetItemsTable, List<SongSetItem>>
  _songSetItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.songSetItems,
    aliasName: $_aliasNameGenerator(db.songSets.id, db.songSetItems.setId),
  );

  $$SongSetItemsTableProcessedTableManager get songSetItemsRefs {
    final manager = $$SongSetItemsTableTableManager(
      $_db,
      $_db.songSetItems,
    ).filter((f) => f.setId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_songSetItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SetHistoryTable, List<SetHistoryData>>
  _setHistoryRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.setHistory,
    aliasName: $_aliasNameGenerator(db.songSets.id, db.setHistory.setId),
  );

  $$SetHistoryTableProcessedTableManager get setHistoryRefs {
    final manager = $$SetHistoryTableTableManager(
      $_db,
      $_db.setHistory,
    ).filter((f) => f.setId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_setHistoryRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SongSetsTableFilterComposer
    extends Composer<_$AppDatabase, $SongSetsTable> {
  $$SongSetsTableFilterComposer({
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

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occasion => $composableBuilder(
    column: $table.occasion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> songSetItemsRefs(
    Expression<bool> Function($$SongSetItemsTableFilterComposer f) f,
  ) {
    final $$SongSetItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.songSetItems,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongSetItemsTableFilterComposer(
            $db: $db,
            $table: $db.songSetItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> setHistoryRefs(
    Expression<bool> Function($$SetHistoryTableFilterComposer f) f,
  ) {
    final $$SetHistoryTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.setHistory,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetHistoryTableFilterComposer(
            $db: $db,
            $table: $db.setHistory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SongSetsTableOrderingComposer
    extends Composer<_$AppDatabase, $SongSetsTable> {
  $$SongSetsTableOrderingComposer({
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

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occasion => $composableBuilder(
    column: $table.occasion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SongSetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SongSetsTable> {
  $$SongSetsTableAnnotationComposer({
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

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get occasion =>
      $composableBuilder(column: $table.occasion, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  Expression<T> songSetItemsRefs<T extends Object>(
    Expression<T> Function($$SongSetItemsTableAnnotationComposer a) f,
  ) {
    final $$SongSetItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.songSetItems,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongSetItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.songSetItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> setHistoryRefs<T extends Object>(
    Expression<T> Function($$SetHistoryTableAnnotationComposer a) f,
  ) {
    final $$SetHistoryTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.setHistory,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetHistoryTableAnnotationComposer(
            $db: $db,
            $table: $db.setHistory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SongSetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SongSetsTable,
          SongSet,
          $$SongSetsTableFilterComposer,
          $$SongSetsTableOrderingComposer,
          $$SongSetsTableAnnotationComposer,
          $$SongSetsTableCreateCompanionBuilder,
          $$SongSetsTableUpdateCompanionBuilder,
          (SongSet, $$SongSetsTableReferences),
          SongSet,
          PrefetchHooks Function({bool songSetItemsRefs, bool setHistoryRefs})
        > {
  $$SongSetsTableTableManager(_$AppDatabase db, $SongSetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SongSetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SongSetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SongSetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> occasion = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> uuid = const Value.absent(),
              }) => SongSetsCompanion(
                id: id,
                name: name,
                notes: notes,
                occasion: occasion,
                createdAt: createdAt,
                uuid: uuid,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> notes = const Value.absent(),
                Value<String?> occasion = const Value.absent(),
                required DateTime createdAt,
                Value<String?> uuid = const Value.absent(),
              }) => SongSetsCompanion.insert(
                id: id,
                name: name,
                notes: notes,
                occasion: occasion,
                createdAt: createdAt,
                uuid: uuid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SongSetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({songSetItemsRefs = false, setHistoryRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (songSetItemsRefs) db.songSetItems,
                    if (setHistoryRefs) db.setHistory,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (songSetItemsRefs)
                        await $_getPrefetchedData<
                          SongSet,
                          $SongSetsTable,
                          SongSetItem
                        >(
                          currentTable: table,
                          referencedTable: $$SongSetsTableReferences
                              ._songSetItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SongSetsTableReferences(
                                db,
                                table,
                                p0,
                              ).songSetItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.setId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (setHistoryRefs)
                        await $_getPrefetchedData<
                          SongSet,
                          $SongSetsTable,
                          SetHistoryData
                        >(
                          currentTable: table,
                          referencedTable: $$SongSetsTableReferences
                              ._setHistoryRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SongSetsTableReferences(
                                db,
                                table,
                                p0,
                              ).setHistoryRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.setId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SongSetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SongSetsTable,
      SongSet,
      $$SongSetsTableFilterComposer,
      $$SongSetsTableOrderingComposer,
      $$SongSetsTableAnnotationComposer,
      $$SongSetsTableCreateCompanionBuilder,
      $$SongSetsTableUpdateCompanionBuilder,
      (SongSet, $$SongSetsTableReferences),
      SongSet,
      PrefetchHooks Function({bool songSetItemsRefs, bool setHistoryRefs})
    >;
typedef $$SongSetItemsTableCreateCompanionBuilder =
    SongSetItemsCompanion Function({
      Value<int> id,
      required int setId,
      required int songId,
      required int position,
      Value<String?> notes,
    });
typedef $$SongSetItemsTableUpdateCompanionBuilder =
    SongSetItemsCompanion Function({
      Value<int> id,
      Value<int> setId,
      Value<int> songId,
      Value<int> position,
      Value<String?> notes,
    });

final class $$SongSetItemsTableReferences
    extends BaseReferences<_$AppDatabase, $SongSetItemsTable, SongSetItem> {
  $$SongSetItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SongSetsTable _setIdTable(_$AppDatabase db) => db.songSets
      .createAlias($_aliasNameGenerator(db.songSetItems.setId, db.songSets.id));

  $$SongSetsTableProcessedTableManager get setId {
    final $_column = $_itemColumn<int>('set_id')!;

    final manager = $$SongSetsTableTableManager(
      $_db,
      $_db.songSets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_setIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SongsTable _songIdTable(_$AppDatabase db) => db.songs.createAlias(
    $_aliasNameGenerator(db.songSetItems.songId, db.songs.id),
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

class $$SongSetItemsTableFilterComposer
    extends Composer<_$AppDatabase, $SongSetItemsTable> {
  $$SongSetItemsTableFilterComposer({
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

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$SongSetsTableFilterComposer get setId {
    final $$SongSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.songSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongSetsTableFilterComposer(
            $db: $db,
            $table: $db.songSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

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

class $$SongSetItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $SongSetItemsTable> {
  $$SongSetItemsTableOrderingComposer({
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

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$SongSetsTableOrderingComposer get setId {
    final $$SongSetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.songSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongSetsTableOrderingComposer(
            $db: $db,
            $table: $db.songSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

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

class $$SongSetItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SongSetItemsTable> {
  $$SongSetItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$SongSetsTableAnnotationComposer get setId {
    final $$SongSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.songSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.songSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

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

class $$SongSetItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SongSetItemsTable,
          SongSetItem,
          $$SongSetItemsTableFilterComposer,
          $$SongSetItemsTableOrderingComposer,
          $$SongSetItemsTableAnnotationComposer,
          $$SongSetItemsTableCreateCompanionBuilder,
          $$SongSetItemsTableUpdateCompanionBuilder,
          (SongSetItem, $$SongSetItemsTableReferences),
          SongSetItem,
          PrefetchHooks Function({bool setId, bool songId})
        > {
  $$SongSetItemsTableTableManager(_$AppDatabase db, $SongSetItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SongSetItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SongSetItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SongSetItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> setId = const Value.absent(),
                Value<int> songId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => SongSetItemsCompanion(
                id: id,
                setId: setId,
                songId: songId,
                position: position,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int setId,
                required int songId,
                required int position,
                Value<String?> notes = const Value.absent(),
              }) => SongSetItemsCompanion.insert(
                id: id,
                setId: setId,
                songId: songId,
                position: position,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SongSetItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({setId = false, songId = false}) {
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
                    if (setId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.setId,
                                referencedTable: $$SongSetItemsTableReferences
                                    ._setIdTable(db),
                                referencedColumn: $$SongSetItemsTableReferences
                                    ._setIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (songId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.songId,
                                referencedTable: $$SongSetItemsTableReferences
                                    ._songIdTable(db),
                                referencedColumn: $$SongSetItemsTableReferences
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

typedef $$SongSetItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SongSetItemsTable,
      SongSetItem,
      $$SongSetItemsTableFilterComposer,
      $$SongSetItemsTableOrderingComposer,
      $$SongSetItemsTableAnnotationComposer,
      $$SongSetItemsTableCreateCompanionBuilder,
      $$SongSetItemsTableUpdateCompanionBuilder,
      (SongSetItem, $$SongSetItemsTableReferences),
      SongSetItem,
      PrefetchHooks Function({bool setId, bool songId})
    >;
typedef $$SetHistoryTableCreateCompanionBuilder =
    SetHistoryCompanion Function({
      Value<int> id,
      required int setId,
      required String setName,
      required DateTime accessedAt,
    });
typedef $$SetHistoryTableUpdateCompanionBuilder =
    SetHistoryCompanion Function({
      Value<int> id,
      Value<int> setId,
      Value<String> setName,
      Value<DateTime> accessedAt,
    });

final class $$SetHistoryTableReferences
    extends BaseReferences<_$AppDatabase, $SetHistoryTable, SetHistoryData> {
  $$SetHistoryTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SongSetsTable _setIdTable(_$AppDatabase db) => db.songSets
      .createAlias($_aliasNameGenerator(db.setHistory.setId, db.songSets.id));

  $$SongSetsTableProcessedTableManager get setId {
    final $_column = $_itemColumn<int>('set_id')!;

    final manager = $$SongSetsTableTableManager(
      $_db,
      $_db.songSets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_setIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SetHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $SetHistoryTable> {
  $$SetHistoryTableFilterComposer({
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

  ColumnFilters<String> get setName => $composableBuilder(
    column: $table.setName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get accessedAt => $composableBuilder(
    column: $table.accessedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SongSetsTableFilterComposer get setId {
    final $$SongSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.songSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongSetsTableFilterComposer(
            $db: $db,
            $table: $db.songSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $SetHistoryTable> {
  $$SetHistoryTableOrderingComposer({
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

  ColumnOrderings<String> get setName => $composableBuilder(
    column: $table.setName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get accessedAt => $composableBuilder(
    column: $table.accessedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SongSetsTableOrderingComposer get setId {
    final $$SongSetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.songSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongSetsTableOrderingComposer(
            $db: $db,
            $table: $db.songSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $SetHistoryTable> {
  $$SetHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get setName =>
      $composableBuilder(column: $table.setName, builder: (column) => column);

  GeneratedColumn<DateTime> get accessedAt => $composableBuilder(
    column: $table.accessedAt,
    builder: (column) => column,
  );

  $$SongSetsTableAnnotationComposer get setId {
    final $$SongSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.songSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.songSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SetHistoryTable,
          SetHistoryData,
          $$SetHistoryTableFilterComposer,
          $$SetHistoryTableOrderingComposer,
          $$SetHistoryTableAnnotationComposer,
          $$SetHistoryTableCreateCompanionBuilder,
          $$SetHistoryTableUpdateCompanionBuilder,
          (SetHistoryData, $$SetHistoryTableReferences),
          SetHistoryData,
          PrefetchHooks Function({bool setId})
        > {
  $$SetHistoryTableTableManager(_$AppDatabase db, $SetHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SetHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SetHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SetHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> setId = const Value.absent(),
                Value<String> setName = const Value.absent(),
                Value<DateTime> accessedAt = const Value.absent(),
              }) => SetHistoryCompanion(
                id: id,
                setId: setId,
                setName: setName,
                accessedAt: accessedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int setId,
                required String setName,
                required DateTime accessedAt,
              }) => SetHistoryCompanion.insert(
                id: id,
                setId: setId,
                setName: setName,
                accessedAt: accessedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SetHistoryTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({setId = false}) {
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
                    if (setId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.setId,
                                referencedTable: $$SetHistoryTableReferences
                                    ._setIdTable(db),
                                referencedColumn: $$SetHistoryTableReferences
                                    ._setIdTable(db)
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

typedef $$SetHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SetHistoryTable,
      SetHistoryData,
      $$SetHistoryTableFilterComposer,
      $$SetHistoryTableOrderingComposer,
      $$SetHistoryTableAnnotationComposer,
      $$SetHistoryTableCreateCompanionBuilder,
      $$SetHistoryTableUpdateCompanionBuilder,
      (SetHistoryData, $$SetHistoryTableReferences),
      SetHistoryData,
      PrefetchHooks Function({bool setId})
    >;
typedef $$BibleHistoryTableCreateCompanionBuilder =
    BibleHistoryCompanion Function({
      Value<int> id,
      required String reference,
      required String passage,
      required DateTime accessedAt,
    });
typedef $$BibleHistoryTableUpdateCompanionBuilder =
    BibleHistoryCompanion Function({
      Value<int> id,
      Value<String> reference,
      Value<String> passage,
      Value<DateTime> accessedAt,
    });

class $$BibleHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $BibleHistoryTable> {
  $$BibleHistoryTableFilterComposer({
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

  ColumnFilters<String> get reference => $composableBuilder(
    column: $table.reference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passage => $composableBuilder(
    column: $table.passage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get accessedAt => $composableBuilder(
    column: $table.accessedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BibleHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $BibleHistoryTable> {
  $$BibleHistoryTableOrderingComposer({
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

  ColumnOrderings<String> get reference => $composableBuilder(
    column: $table.reference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passage => $composableBuilder(
    column: $table.passage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get accessedAt => $composableBuilder(
    column: $table.accessedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BibleHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $BibleHistoryTable> {
  $$BibleHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get reference =>
      $composableBuilder(column: $table.reference, builder: (column) => column);

  GeneratedColumn<String> get passage =>
      $composableBuilder(column: $table.passage, builder: (column) => column);

  GeneratedColumn<DateTime> get accessedAt => $composableBuilder(
    column: $table.accessedAt,
    builder: (column) => column,
  );
}

class $$BibleHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BibleHistoryTable,
          BibleHistoryData,
          $$BibleHistoryTableFilterComposer,
          $$BibleHistoryTableOrderingComposer,
          $$BibleHistoryTableAnnotationComposer,
          $$BibleHistoryTableCreateCompanionBuilder,
          $$BibleHistoryTableUpdateCompanionBuilder,
          (
            BibleHistoryData,
            BaseReferences<_$AppDatabase, $BibleHistoryTable, BibleHistoryData>,
          ),
          BibleHistoryData,
          PrefetchHooks Function()
        > {
  $$BibleHistoryTableTableManager(_$AppDatabase db, $BibleHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BibleHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BibleHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BibleHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> reference = const Value.absent(),
                Value<String> passage = const Value.absent(),
                Value<DateTime> accessedAt = const Value.absent(),
              }) => BibleHistoryCompanion(
                id: id,
                reference: reference,
                passage: passage,
                accessedAt: accessedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String reference,
                required String passage,
                required DateTime accessedAt,
              }) => BibleHistoryCompanion.insert(
                id: id,
                reference: reference,
                passage: passage,
                accessedAt: accessedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BibleHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BibleHistoryTable,
      BibleHistoryData,
      $$BibleHistoryTableFilterComposer,
      $$BibleHistoryTableOrderingComposer,
      $$BibleHistoryTableAnnotationComposer,
      $$BibleHistoryTableCreateCompanionBuilder,
      $$BibleHistoryTableUpdateCompanionBuilder,
      (
        BibleHistoryData,
        BaseReferences<_$AppDatabase, $BibleHistoryTable, BibleHistoryData>,
      ),
      BibleHistoryData,
      PrefetchHooks Function()
    >;
typedef $$BibleBookmarksTableCreateCompanionBuilder =
    BibleBookmarksCompanion Function({
      Value<int> id,
      required int bookId,
      required int chapter,
      required int verseNum,
      required String reference,
      required String verseText,
      required String bookName,
      required DateTime createdAt,
    });
typedef $$BibleBookmarksTableUpdateCompanionBuilder =
    BibleBookmarksCompanion Function({
      Value<int> id,
      Value<int> bookId,
      Value<int> chapter,
      Value<int> verseNum,
      Value<String> reference,
      Value<String> verseText,
      Value<String> bookName,
      Value<DateTime> createdAt,
    });

class $$BibleBookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $BibleBookmarksTable> {
  $$BibleBookmarksTableFilterComposer({
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

  ColumnFilters<int> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapter => $composableBuilder(
    column: $table.chapter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get verseNum => $composableBuilder(
    column: $table.verseNum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reference => $composableBuilder(
    column: $table.reference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verseText => $composableBuilder(
    column: $table.verseText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookName => $composableBuilder(
    column: $table.bookName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BibleBookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $BibleBookmarksTable> {
  $$BibleBookmarksTableOrderingComposer({
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

  ColumnOrderings<int> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapter => $composableBuilder(
    column: $table.chapter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get verseNum => $composableBuilder(
    column: $table.verseNum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reference => $composableBuilder(
    column: $table.reference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verseText => $composableBuilder(
    column: $table.verseText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookName => $composableBuilder(
    column: $table.bookName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BibleBookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BibleBookmarksTable> {
  $$BibleBookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get chapter =>
      $composableBuilder(column: $table.chapter, builder: (column) => column);

  GeneratedColumn<int> get verseNum =>
      $composableBuilder(column: $table.verseNum, builder: (column) => column);

  GeneratedColumn<String> get reference =>
      $composableBuilder(column: $table.reference, builder: (column) => column);

  GeneratedColumn<String> get verseText =>
      $composableBuilder(column: $table.verseText, builder: (column) => column);

  GeneratedColumn<String> get bookName =>
      $composableBuilder(column: $table.bookName, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BibleBookmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BibleBookmarksTable,
          BibleBookmark,
          $$BibleBookmarksTableFilterComposer,
          $$BibleBookmarksTableOrderingComposer,
          $$BibleBookmarksTableAnnotationComposer,
          $$BibleBookmarksTableCreateCompanionBuilder,
          $$BibleBookmarksTableUpdateCompanionBuilder,
          (
            BibleBookmark,
            BaseReferences<_$AppDatabase, $BibleBookmarksTable, BibleBookmark>,
          ),
          BibleBookmark,
          PrefetchHooks Function()
        > {
  $$BibleBookmarksTableTableManager(
    _$AppDatabase db,
    $BibleBookmarksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BibleBookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BibleBookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BibleBookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> bookId = const Value.absent(),
                Value<int> chapter = const Value.absent(),
                Value<int> verseNum = const Value.absent(),
                Value<String> reference = const Value.absent(),
                Value<String> verseText = const Value.absent(),
                Value<String> bookName = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => BibleBookmarksCompanion(
                id: id,
                bookId: bookId,
                chapter: chapter,
                verseNum: verseNum,
                reference: reference,
                verseText: verseText,
                bookName: bookName,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int bookId,
                required int chapter,
                required int verseNum,
                required String reference,
                required String verseText,
                required String bookName,
                required DateTime createdAt,
              }) => BibleBookmarksCompanion.insert(
                id: id,
                bookId: bookId,
                chapter: chapter,
                verseNum: verseNum,
                reference: reference,
                verseText: verseText,
                bookName: bookName,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BibleBookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BibleBookmarksTable,
      BibleBookmark,
      $$BibleBookmarksTableFilterComposer,
      $$BibleBookmarksTableOrderingComposer,
      $$BibleBookmarksTableAnnotationComposer,
      $$BibleBookmarksTableCreateCompanionBuilder,
      $$BibleBookmarksTableUpdateCompanionBuilder,
      (
        BibleBookmark,
        BaseReferences<_$AppDatabase, $BibleBookmarksTable, BibleBookmark>,
      ),
      BibleBookmark,
      PrefetchHooks Function()
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
  $$SongSetsTableTableManager get songSets =>
      $$SongSetsTableTableManager(_db, _db.songSets);
  $$SongSetItemsTableTableManager get songSetItems =>
      $$SongSetItemsTableTableManager(_db, _db.songSetItems);
  $$SetHistoryTableTableManager get setHistory =>
      $$SetHistoryTableTableManager(_db, _db.setHistory);
  $$BibleHistoryTableTableManager get bibleHistory =>
      $$BibleHistoryTableTableManager(_db, _db.bibleHistory);
  $$BibleBookmarksTableTableManager get bibleBookmarks =>
      $$BibleBookmarksTableTableManager(_db, _db.bibleBookmarks);
}
