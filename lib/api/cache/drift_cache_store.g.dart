// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drift_cache_store.dart';

// ignore_for_file: type=lint
class $ResponseCacheRowsTable extends ResponseCacheRows
    with TableInfo<$ResponseCacheRowsTable, ResponseCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResponseCacheRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<String> cachedAt = GeneratedColumn<String>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, data, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'response_cache_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<ResponseCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  ResponseCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ResponseCacheRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $ResponseCacheRowsTable createAlias(String alias) {
    return $ResponseCacheRowsTable(attachedDatabase, alias);
  }
}

class ResponseCacheRow extends DataClass
    implements Insertable<ResponseCacheRow> {
  final String key;

  /// wire JSON 原樣序列化（`Object?` → 可能是 map/list/純量/null）。
  final String data;

  /// ISO8601 字串而非 drift 的 DateTimeColumn —— 後者預設存 unix 秒，會把毫秒
  /// 截掉，TTL 判斷跟著失準。sembast 版也是存字串，行為對齊。
  final String cachedAt;
  const ResponseCacheRow({
    required this.key,
    required this.data,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['data'] = Variable<String>(data);
    map['cached_at'] = Variable<String>(cachedAt);
    return map;
  }

  ResponseCacheRowsCompanion toCompanion(bool nullToAbsent) {
    return ResponseCacheRowsCompanion(
      key: Value(key),
      data: Value(data),
      cachedAt: Value(cachedAt),
    );
  }

  factory ResponseCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ResponseCacheRow(
      key: serializer.fromJson<String>(json['key']),
      data: serializer.fromJson<String>(json['data']),
      cachedAt: serializer.fromJson<String>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'data': serializer.toJson<String>(data),
      'cachedAt': serializer.toJson<String>(cachedAt),
    };
  }

  ResponseCacheRow copyWith({String? key, String? data, String? cachedAt}) =>
      ResponseCacheRow(
        key: key ?? this.key,
        data: data ?? this.data,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  ResponseCacheRow copyWithCompanion(ResponseCacheRowsCompanion data) {
    return ResponseCacheRow(
      key: data.key.present ? data.key.value : this.key,
      data: data.data.present ? data.data.value : this.data,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ResponseCacheRow(')
          ..write('key: $key, ')
          ..write('data: $data, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, data, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResponseCacheRow &&
          other.key == this.key &&
          other.data == this.data &&
          other.cachedAt == this.cachedAt);
}

class ResponseCacheRowsCompanion extends UpdateCompanion<ResponseCacheRow> {
  final Value<String> key;
  final Value<String> data;
  final Value<String> cachedAt;
  final Value<int> rowid;
  const ResponseCacheRowsCompanion({
    this.key = const Value.absent(),
    this.data = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ResponseCacheRowsCompanion.insert({
    required String key,
    required String data,
    required String cachedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       data = Value(data),
       cachedAt = Value(cachedAt);
  static Insertable<ResponseCacheRow> custom({
    Expression<String>? key,
    Expression<String>? data,
    Expression<String>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (data != null) 'data': data,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ResponseCacheRowsCompanion copyWith({
    Value<String>? key,
    Value<String>? data,
    Value<String>? cachedAt,
    Value<int>? rowid,
  }) {
    return ResponseCacheRowsCompanion(
      key: key ?? this.key,
      data: data ?? this.data,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<String>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResponseCacheRowsCompanion(')
          ..write('key: $key, ')
          ..write('data: $data, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MutationQueueRowsTable extends MutationQueueRows
    with TableInfo<$MutationQueueRowsTable, MutationQueueRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MutationQueueRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _mutationIdMeta = const VerificationMeta(
    'mutationId',
  );
  @override
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [seq, mutationId, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mutation_queue_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<MutationQueueRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('mutation_id')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutation_id']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  MutationQueueRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MutationQueueRow(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $MutationQueueRowsTable createAlias(String alias) {
    return $MutationQueueRowsTable(attachedDatabase, alias);
  }
}

class MutationQueueRow extends DataClass
    implements Insertable<MutationQueueRow> {
  final int seq;
  final String mutationId;
  final String payload;
  const MutationQueueRow({
    required this.seq,
    required this.mutationId,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['mutation_id'] = Variable<String>(mutationId);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  MutationQueueRowsCompanion toCompanion(bool nullToAbsent) {
    return MutationQueueRowsCompanion(
      seq: Value(seq),
      mutationId: Value(mutationId),
      payload: Value(payload),
    );
  }

  factory MutationQueueRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MutationQueueRow(
      seq: serializer.fromJson<int>(json['seq']),
      mutationId: serializer.fromJson<String>(json['mutationId']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'mutationId': serializer.toJson<String>(mutationId),
      'payload': serializer.toJson<String>(payload),
    };
  }

  MutationQueueRow copyWith({int? seq, String? mutationId, String? payload}) =>
      MutationQueueRow(
        seq: seq ?? this.seq,
        mutationId: mutationId ?? this.mutationId,
        payload: payload ?? this.payload,
      );
  MutationQueueRow copyWithCompanion(MutationQueueRowsCompanion data) {
    return MutationQueueRow(
      seq: data.seq.present ? data.seq.value : this.seq,
      mutationId: data.mutationId.present
          ? data.mutationId.value
          : this.mutationId,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MutationQueueRow(')
          ..write('seq: $seq, ')
          ..write('mutationId: $mutationId, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(seq, mutationId, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MutationQueueRow &&
          other.seq == this.seq &&
          other.mutationId == this.mutationId &&
          other.payload == this.payload);
}

class MutationQueueRowsCompanion extends UpdateCompanion<MutationQueueRow> {
  final Value<int> seq;
  final Value<String> mutationId;
  final Value<String> payload;
  const MutationQueueRowsCompanion({
    this.seq = const Value.absent(),
    this.mutationId = const Value.absent(),
    this.payload = const Value.absent(),
  });
  MutationQueueRowsCompanion.insert({
    this.seq = const Value.absent(),
    required String mutationId,
    required String payload,
  }) : mutationId = Value(mutationId),
       payload = Value(payload);
  static Insertable<MutationQueueRow> custom({
    Expression<int>? seq,
    Expression<String>? mutationId,
    Expression<String>? payload,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (mutationId != null) 'mutation_id': mutationId,
      if (payload != null) 'payload': payload,
    });
  }

  MutationQueueRowsCompanion copyWith({
    Value<int>? seq,
    Value<String>? mutationId,
    Value<String>? payload,
  }) {
    return MutationQueueRowsCompanion(
      seq: seq ?? this.seq,
      mutationId: mutationId ?? this.mutationId,
      payload: payload ?? this.payload,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (mutationId.present) {
      map['mutation_id'] = Variable<String>(mutationId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MutationQueueRowsCompanion(')
          ..write('seq: $seq, ')
          ..write('mutationId: $mutationId, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }
}

class $ConflictRowsTable extends ConflictRows
    with TableInfo<$ConflictRowsTable, ConflictRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConflictRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _conflictIdMeta = const VerificationMeta(
    'conflictId',
  );
  @override
  late final GeneratedColumn<String> conflictId = GeneratedColumn<String>(
    'conflict_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [seq, conflictId, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conflict_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConflictRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('conflict_id')) {
      context.handle(
        _conflictIdMeta,
        conflictId.isAcceptableOrUnknown(data['conflict_id']!, _conflictIdMeta),
      );
    } else if (isInserting) {
      context.missing(_conflictIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  ConflictRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConflictRow(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      conflictId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conflict_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $ConflictRowsTable createAlias(String alias) {
    return $ConflictRowsTable(attachedDatabase, alias);
  }
}

class ConflictRow extends DataClass implements Insertable<ConflictRow> {
  final int seq;
  final String conflictId;
  final String payload;
  const ConflictRow({
    required this.seq,
    required this.conflictId,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['conflict_id'] = Variable<String>(conflictId);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  ConflictRowsCompanion toCompanion(bool nullToAbsent) {
    return ConflictRowsCompanion(
      seq: Value(seq),
      conflictId: Value(conflictId),
      payload: Value(payload),
    );
  }

  factory ConflictRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConflictRow(
      seq: serializer.fromJson<int>(json['seq']),
      conflictId: serializer.fromJson<String>(json['conflictId']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'conflictId': serializer.toJson<String>(conflictId),
      'payload': serializer.toJson<String>(payload),
    };
  }

  ConflictRow copyWith({int? seq, String? conflictId, String? payload}) =>
      ConflictRow(
        seq: seq ?? this.seq,
        conflictId: conflictId ?? this.conflictId,
        payload: payload ?? this.payload,
      );
  ConflictRow copyWithCompanion(ConflictRowsCompanion data) {
    return ConflictRow(
      seq: data.seq.present ? data.seq.value : this.seq,
      conflictId: data.conflictId.present
          ? data.conflictId.value
          : this.conflictId,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConflictRow(')
          ..write('seq: $seq, ')
          ..write('conflictId: $conflictId, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(seq, conflictId, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConflictRow &&
          other.seq == this.seq &&
          other.conflictId == this.conflictId &&
          other.payload == this.payload);
}

class ConflictRowsCompanion extends UpdateCompanion<ConflictRow> {
  final Value<int> seq;
  final Value<String> conflictId;
  final Value<String> payload;
  const ConflictRowsCompanion({
    this.seq = const Value.absent(),
    this.conflictId = const Value.absent(),
    this.payload = const Value.absent(),
  });
  ConflictRowsCompanion.insert({
    this.seq = const Value.absent(),
    required String conflictId,
    required String payload,
  }) : conflictId = Value(conflictId),
       payload = Value(payload);
  static Insertable<ConflictRow> custom({
    Expression<int>? seq,
    Expression<String>? conflictId,
    Expression<String>? payload,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (conflictId != null) 'conflict_id': conflictId,
      if (payload != null) 'payload': payload,
    });
  }

  ConflictRowsCompanion copyWith({
    Value<int>? seq,
    Value<String>? conflictId,
    Value<String>? payload,
  }) {
    return ConflictRowsCompanion(
      seq: seq ?? this.seq,
      conflictId: conflictId ?? this.conflictId,
      payload: payload ?? this.payload,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (conflictId.present) {
      map['conflict_id'] = Variable<String>(conflictId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConflictRowsCompanion(')
          ..write('seq: $seq, ')
          ..write('conflictId: $conflictId, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }
}

abstract class _$CacheDatabase extends GeneratedDatabase {
  _$CacheDatabase(QueryExecutor e) : super(e);
  $CacheDatabaseManager get managers => $CacheDatabaseManager(this);
  late final $ResponseCacheRowsTable responseCacheRows =
      $ResponseCacheRowsTable(this);
  late final $MutationQueueRowsTable mutationQueueRows =
      $MutationQueueRowsTable(this);
  late final $ConflictRowsTable conflictRows = $ConflictRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    responseCacheRows,
    mutationQueueRows,
    conflictRows,
  ];
}

typedef $$ResponseCacheRowsTableCreateCompanionBuilder =
    ResponseCacheRowsCompanion Function({
      required String key,
      required String data,
      required String cachedAt,
      Value<int> rowid,
    });
typedef $$ResponseCacheRowsTableUpdateCompanionBuilder =
    ResponseCacheRowsCompanion Function({
      Value<String> key,
      Value<String> data,
      Value<String> cachedAt,
      Value<int> rowid,
    });

class $$ResponseCacheRowsTableFilterComposer
    extends Composer<_$CacheDatabase, $ResponseCacheRowsTable> {
  $$ResponseCacheRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ResponseCacheRowsTableOrderingComposer
    extends Composer<_$CacheDatabase, $ResponseCacheRowsTable> {
  $$ResponseCacheRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ResponseCacheRowsTableAnnotationComposer
    extends Composer<_$CacheDatabase, $ResponseCacheRowsTable> {
  $$ResponseCacheRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<String> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$ResponseCacheRowsTableTableManager
    extends
        RootTableManager<
          _$CacheDatabase,
          $ResponseCacheRowsTable,
          ResponseCacheRow,
          $$ResponseCacheRowsTableFilterComposer,
          $$ResponseCacheRowsTableOrderingComposer,
          $$ResponseCacheRowsTableAnnotationComposer,
          $$ResponseCacheRowsTableCreateCompanionBuilder,
          $$ResponseCacheRowsTableUpdateCompanionBuilder,
          (
            ResponseCacheRow,
            BaseReferences<
              _$CacheDatabase,
              $ResponseCacheRowsTable,
              ResponseCacheRow
            >,
          ),
          ResponseCacheRow,
          PrefetchHooks Function()
        > {
  $$ResponseCacheRowsTableTableManager(
    _$CacheDatabase db,
    $ResponseCacheRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResponseCacheRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ResponseCacheRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ResponseCacheRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<String> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ResponseCacheRowsCompanion(
                key: key,
                data: data,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String data,
                required String cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => ResponseCacheRowsCompanion.insert(
                key: key,
                data: data,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ResponseCacheRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$CacheDatabase,
      $ResponseCacheRowsTable,
      ResponseCacheRow,
      $$ResponseCacheRowsTableFilterComposer,
      $$ResponseCacheRowsTableOrderingComposer,
      $$ResponseCacheRowsTableAnnotationComposer,
      $$ResponseCacheRowsTableCreateCompanionBuilder,
      $$ResponseCacheRowsTableUpdateCompanionBuilder,
      (
        ResponseCacheRow,
        BaseReferences<
          _$CacheDatabase,
          $ResponseCacheRowsTable,
          ResponseCacheRow
        >,
      ),
      ResponseCacheRow,
      PrefetchHooks Function()
    >;
typedef $$MutationQueueRowsTableCreateCompanionBuilder =
    MutationQueueRowsCompanion Function({
      Value<int> seq,
      required String mutationId,
      required String payload,
    });
typedef $$MutationQueueRowsTableUpdateCompanionBuilder =
    MutationQueueRowsCompanion Function({
      Value<int> seq,
      Value<String> mutationId,
      Value<String> payload,
    });

class $$MutationQueueRowsTableFilterComposer
    extends Composer<_$CacheDatabase, $MutationQueueRowsTable> {
  $$MutationQueueRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MutationQueueRowsTableOrderingComposer
    extends Composer<_$CacheDatabase, $MutationQueueRowsTable> {
  $$MutationQueueRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MutationQueueRowsTableAnnotationComposer
    extends Composer<_$CacheDatabase, $MutationQueueRowsTable> {
  $$MutationQueueRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$MutationQueueRowsTableTableManager
    extends
        RootTableManager<
          _$CacheDatabase,
          $MutationQueueRowsTable,
          MutationQueueRow,
          $$MutationQueueRowsTableFilterComposer,
          $$MutationQueueRowsTableOrderingComposer,
          $$MutationQueueRowsTableAnnotationComposer,
          $$MutationQueueRowsTableCreateCompanionBuilder,
          $$MutationQueueRowsTableUpdateCompanionBuilder,
          (
            MutationQueueRow,
            BaseReferences<
              _$CacheDatabase,
              $MutationQueueRowsTable,
              MutationQueueRow
            >,
          ),
          MutationQueueRow,
          PrefetchHooks Function()
        > {
  $$MutationQueueRowsTableTableManager(
    _$CacheDatabase db,
    $MutationQueueRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MutationQueueRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MutationQueueRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MutationQueueRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> mutationId = const Value.absent(),
                Value<String> payload = const Value.absent(),
              }) => MutationQueueRowsCompanion(
                seq: seq,
                mutationId: mutationId,
                payload: payload,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String mutationId,
                required String payload,
              }) => MutationQueueRowsCompanion.insert(
                seq: seq,
                mutationId: mutationId,
                payload: payload,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MutationQueueRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$CacheDatabase,
      $MutationQueueRowsTable,
      MutationQueueRow,
      $$MutationQueueRowsTableFilterComposer,
      $$MutationQueueRowsTableOrderingComposer,
      $$MutationQueueRowsTableAnnotationComposer,
      $$MutationQueueRowsTableCreateCompanionBuilder,
      $$MutationQueueRowsTableUpdateCompanionBuilder,
      (
        MutationQueueRow,
        BaseReferences<
          _$CacheDatabase,
          $MutationQueueRowsTable,
          MutationQueueRow
        >,
      ),
      MutationQueueRow,
      PrefetchHooks Function()
    >;
typedef $$ConflictRowsTableCreateCompanionBuilder =
    ConflictRowsCompanion Function({
      Value<int> seq,
      required String conflictId,
      required String payload,
    });
typedef $$ConflictRowsTableUpdateCompanionBuilder =
    ConflictRowsCompanion Function({
      Value<int> seq,
      Value<String> conflictId,
      Value<String> payload,
    });

class $$ConflictRowsTableFilterComposer
    extends Composer<_$CacheDatabase, $ConflictRowsTable> {
  $$ConflictRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conflictId => $composableBuilder(
    column: $table.conflictId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConflictRowsTableOrderingComposer
    extends Composer<_$CacheDatabase, $ConflictRowsTable> {
  $$ConflictRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conflictId => $composableBuilder(
    column: $table.conflictId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConflictRowsTableAnnotationComposer
    extends Composer<_$CacheDatabase, $ConflictRowsTable> {
  $$ConflictRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get conflictId => $composableBuilder(
    column: $table.conflictId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$ConflictRowsTableTableManager
    extends
        RootTableManager<
          _$CacheDatabase,
          $ConflictRowsTable,
          ConflictRow,
          $$ConflictRowsTableFilterComposer,
          $$ConflictRowsTableOrderingComposer,
          $$ConflictRowsTableAnnotationComposer,
          $$ConflictRowsTableCreateCompanionBuilder,
          $$ConflictRowsTableUpdateCompanionBuilder,
          (
            ConflictRow,
            BaseReferences<_$CacheDatabase, $ConflictRowsTable, ConflictRow>,
          ),
          ConflictRow,
          PrefetchHooks Function()
        > {
  $$ConflictRowsTableTableManager(_$CacheDatabase db, $ConflictRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConflictRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConflictRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConflictRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> conflictId = const Value.absent(),
                Value<String> payload = const Value.absent(),
              }) => ConflictRowsCompanion(
                seq: seq,
                conflictId: conflictId,
                payload: payload,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String conflictId,
                required String payload,
              }) => ConflictRowsCompanion.insert(
                seq: seq,
                conflictId: conflictId,
                payload: payload,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConflictRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$CacheDatabase,
      $ConflictRowsTable,
      ConflictRow,
      $$ConflictRowsTableFilterComposer,
      $$ConflictRowsTableOrderingComposer,
      $$ConflictRowsTableAnnotationComposer,
      $$ConflictRowsTableCreateCompanionBuilder,
      $$ConflictRowsTableUpdateCompanionBuilder,
      (
        ConflictRow,
        BaseReferences<_$CacheDatabase, $ConflictRowsTable, ConflictRow>,
      ),
      ConflictRow,
      PrefetchHooks Function()
    >;

class $CacheDatabaseManager {
  final _$CacheDatabase _db;
  $CacheDatabaseManager(this._db);
  $$ResponseCacheRowsTableTableManager get responseCacheRows =>
      $$ResponseCacheRowsTableTableManager(_db, _db.responseCacheRows);
  $$MutationQueueRowsTableTableManager get mutationQueueRows =>
      $$MutationQueueRowsTableTableManager(_db, _db.mutationQueueRows);
  $$ConflictRowsTableTableManager get conflictRows =>
      $$ConflictRowsTableTableManager(_db, _db.conflictRows);
}
