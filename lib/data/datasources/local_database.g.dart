// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_database.dart';

// ignore_for_file: type=lint
class $TodosTable extends Todos with TableInfo<$TodosTable, TodoData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
      'price', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _isCompletedMeta =
      const VerificationMeta('isCompleted');
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
      'is_completed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_completed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _vectorClockJsonMeta =
      const VerificationMeta('vectorClockJson');
  @override
  late final GeneratedColumn<String> vectorClockJson = GeneratedColumn<String>(
      'vector_clock_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
      'sync_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _needsSyncMeta =
      const VerificationMeta('needsSync');
  @override
  late final GeneratedColumn<bool> needsSync = GeneratedColumn<bool>(
      'needs_sync', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("needs_sync" IN (0, 1))'),
      defaultValue: const Constant(true));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        price,
        isCompleted,
        createdAt,
        updatedAt,
        vectorClockJson,
        deviceId,
        version,
        isDeleted,
        syncId,
        needsSync
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todos';
  @override
  VerificationContext validateIntegrity(Insertable<TodoData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
          _priceMeta, price.isAcceptableOrUnknown(data['price']!, _priceMeta));
    } else if (isInserting) {
      context.missing(_priceMeta);
    }
    if (data.containsKey('is_completed')) {
      context.handle(
          _isCompletedMeta,
          isCompleted.isAcceptableOrUnknown(
              data['is_completed']!, _isCompletedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('vector_clock_json')) {
      context.handle(
          _vectorClockJsonMeta,
          vectorClockJson.isAcceptableOrUnknown(
              data['vector_clock_json']!, _vectorClockJsonMeta));
    } else if (isInserting) {
      context.missing(_vectorClockJsonMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('sync_id')) {
      context.handle(_syncIdMeta,
          syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta));
    }
    if (data.containsKey('needs_sync')) {
      context.handle(_needsSyncMeta,
          needsSync.isAcceptableOrUnknown(data['needs_sync']!, _needsSyncMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      price: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}price'])!,
      isCompleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_completed'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      vectorClockJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}vector_clock_json'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      syncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_id']),
      needsSync: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}needs_sync'])!,
    );
  }

  @override
  $TodosTable createAlias(String alias) {
    return $TodosTable(attachedDatabase, alias);
  }
}

class TodoData extends DataClass implements Insertable<TodoData> {
  final String id;
  final String name;
  final double price;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String vectorClockJson;
  final String deviceId;
  final int version;
  final bool isDeleted;
  final String? syncId;
  final bool needsSync;
  const TodoData(
      {required this.id,
      required this.name,
      required this.price,
      required this.isCompleted,
      required this.createdAt,
      required this.updatedAt,
      required this.vectorClockJson,
      required this.deviceId,
      required this.version,
      required this.isDeleted,
      this.syncId,
      required this.needsSync});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['price'] = Variable<double>(price);
    map['is_completed'] = Variable<bool>(isCompleted);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['vector_clock_json'] = Variable<String>(vectorClockJson);
    map['device_id'] = Variable<String>(deviceId);
    map['version'] = Variable<int>(version);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || syncId != null) {
      map['sync_id'] = Variable<String>(syncId);
    }
    map['needs_sync'] = Variable<bool>(needsSync);
    return map;
  }

  TodosCompanion toCompanion(bool nullToAbsent) {
    return TodosCompanion(
      id: Value(id),
      name: Value(name),
      price: Value(price),
      isCompleted: Value(isCompleted),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      vectorClockJson: Value(vectorClockJson),
      deviceId: Value(deviceId),
      version: Value(version),
      isDeleted: Value(isDeleted),
      syncId:
          syncId == null && nullToAbsent ? const Value.absent() : Value(syncId),
      needsSync: Value(needsSync),
    );
  }

  factory TodoData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoData(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      price: serializer.fromJson<double>(json['price']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      vectorClockJson: serializer.fromJson<String>(json['vectorClockJson']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      version: serializer.fromJson<int>(json['version']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      syncId: serializer.fromJson<String?>(json['syncId']),
      needsSync: serializer.fromJson<bool>(json['needsSync']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'price': serializer.toJson<double>(price),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'vectorClockJson': serializer.toJson<String>(vectorClockJson),
      'deviceId': serializer.toJson<String>(deviceId),
      'version': serializer.toJson<int>(version),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'syncId': serializer.toJson<String?>(syncId),
      'needsSync': serializer.toJson<bool>(needsSync),
    };
  }

  TodoData copyWith(
          {String? id,
          String? name,
          double? price,
          bool? isCompleted,
          DateTime? createdAt,
          DateTime? updatedAt,
          String? vectorClockJson,
          String? deviceId,
          int? version,
          bool? isDeleted,
          Value<String?> syncId = const Value.absent(),
          bool? needsSync}) =>
      TodoData(
        id: id ?? this.id,
        name: name ?? this.name,
        price: price ?? this.price,
        isCompleted: isCompleted ?? this.isCompleted,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        vectorClockJson: vectorClockJson ?? this.vectorClockJson,
        deviceId: deviceId ?? this.deviceId,
        version: version ?? this.version,
        isDeleted: isDeleted ?? this.isDeleted,
        syncId: syncId.present ? syncId.value : this.syncId,
        needsSync: needsSync ?? this.needsSync,
      );
  TodoData copyWithCompanion(TodosCompanion data) {
    return TodoData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      price: data.price.present ? data.price.value : this.price,
      isCompleted:
          data.isCompleted.present ? data.isCompleted.value : this.isCompleted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      vectorClockJson: data.vectorClockJson.present
          ? data.vectorClockJson.value
          : this.vectorClockJson,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      version: data.version.present ? data.version.value : this.version,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
      needsSync: data.needsSync.present ? data.needsSync.value : this.needsSync,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('price: $price, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('vectorClockJson: $vectorClockJson, ')
          ..write('deviceId: $deviceId, ')
          ..write('version: $version, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('syncId: $syncId, ')
          ..write('needsSync: $needsSync')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      price,
      isCompleted,
      createdAt,
      updatedAt,
      vectorClockJson,
      deviceId,
      version,
      isDeleted,
      syncId,
      needsSync);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoData &&
          other.id == this.id &&
          other.name == this.name &&
          other.price == this.price &&
          other.isCompleted == this.isCompleted &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.vectorClockJson == this.vectorClockJson &&
          other.deviceId == this.deviceId &&
          other.version == this.version &&
          other.isDeleted == this.isDeleted &&
          other.syncId == this.syncId &&
          other.needsSync == this.needsSync);
}

class TodosCompanion extends UpdateCompanion<TodoData> {
  final Value<String> id;
  final Value<String> name;
  final Value<double> price;
  final Value<bool> isCompleted;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> vectorClockJson;
  final Value<String> deviceId;
  final Value<int> version;
  final Value<bool> isDeleted;
  final Value<String?> syncId;
  final Value<bool> needsSync;
  final Value<int> rowid;
  const TodosCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.price = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.vectorClockJson = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.version = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.syncId = const Value.absent(),
    this.needsSync = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodosCompanion.insert({
    required String id,
    required String name,
    required double price,
    this.isCompleted = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    required String vectorClockJson,
    required String deviceId,
    required int version,
    this.isDeleted = const Value.absent(),
    this.syncId = const Value.absent(),
    this.needsSync = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        price = Value(price),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        vectorClockJson = Value(vectorClockJson),
        deviceId = Value(deviceId),
        version = Value(version);
  static Insertable<TodoData> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<double>? price,
    Expression<bool>? isCompleted,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? vectorClockJson,
    Expression<String>? deviceId,
    Expression<int>? version,
    Expression<bool>? isDeleted,
    Expression<String>? syncId,
    Expression<bool>? needsSync,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (price != null) 'price': price,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (vectorClockJson != null) 'vector_clock_json': vectorClockJson,
      if (deviceId != null) 'device_id': deviceId,
      if (version != null) 'version': version,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (syncId != null) 'sync_id': syncId,
      if (needsSync != null) 'needs_sync': needsSync,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodosCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<double>? price,
      Value<bool>? isCompleted,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<String>? vectorClockJson,
      Value<String>? deviceId,
      Value<int>? version,
      Value<bool>? isDeleted,
      Value<String?>? syncId,
      Value<bool>? needsSync,
      Value<int>? rowid}) {
    return TodosCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      vectorClockJson: vectorClockJson ?? this.vectorClockJson,
      deviceId: deviceId ?? this.deviceId,
      version: version ?? this.version,
      isDeleted: isDeleted ?? this.isDeleted,
      syncId: syncId ?? this.syncId,
      needsSync: needsSync ?? this.needsSync,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (vectorClockJson.present) {
      map['vector_clock_json'] = Variable<String>(vectorClockJson.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    if (needsSync.present) {
      map['needs_sync'] = Variable<bool>(needsSync.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodosCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('price: $price, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('vectorClockJson: $vectorClockJson, ')
          ..write('deviceId: $deviceId, ')
          ..write('version: $version, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('syncId: $syncId, ')
          ..write('needsSync: $needsSync, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConflictsTable extends Conflicts
    with TableInfo<$ConflictsTable, ConflictData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConflictsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _todoIdMeta = const VerificationMeta('todoId');
  @override
  late final GeneratedColumn<String> todoId = GeneratedColumn<String>(
      'todo_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionsJsonMeta =
      const VerificationMeta('versionsJson');
  @override
  late final GeneratedColumn<String> versionsJson = GeneratedColumn<String>(
      'versions_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _detectedAtMeta =
      const VerificationMeta('detectedAt');
  @override
  late final GeneratedColumn<DateTime> detectedAt = GeneratedColumn<DateTime>(
      'detected_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _conflictTypeMeta =
      const VerificationMeta('conflictType');
  @override
  late final GeneratedColumn<int> conflictType = GeneratedColumn<int>(
      'conflict_type', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _isResolvedMeta =
      const VerificationMeta('isResolved');
  @override
  late final GeneratedColumn<bool> isResolved = GeneratedColumn<bool>(
      'is_resolved', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_resolved" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _resolvedByMeta =
      const VerificationMeta('resolvedBy');
  @override
  late final GeneratedColumn<String> resolvedBy = GeneratedColumn<String>(
      'resolved_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _resolvedAtMeta =
      const VerificationMeta('resolvedAt');
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
      'resolved_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        todoId,
        versionsJson,
        detectedAt,
        conflictType,
        isResolved,
        resolvedBy,
        resolvedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conflicts';
  @override
  VerificationContext validateIntegrity(Insertable<ConflictData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('todo_id')) {
      context.handle(_todoIdMeta,
          todoId.isAcceptableOrUnknown(data['todo_id']!, _todoIdMeta));
    } else if (isInserting) {
      context.missing(_todoIdMeta);
    }
    if (data.containsKey('versions_json')) {
      context.handle(
          _versionsJsonMeta,
          versionsJson.isAcceptableOrUnknown(
              data['versions_json']!, _versionsJsonMeta));
    } else if (isInserting) {
      context.missing(_versionsJsonMeta);
    }
    if (data.containsKey('detected_at')) {
      context.handle(
          _detectedAtMeta,
          detectedAt.isAcceptableOrUnknown(
              data['detected_at']!, _detectedAtMeta));
    } else if (isInserting) {
      context.missing(_detectedAtMeta);
    }
    if (data.containsKey('conflict_type')) {
      context.handle(
          _conflictTypeMeta,
          conflictType.isAcceptableOrUnknown(
              data['conflict_type']!, _conflictTypeMeta));
    } else if (isInserting) {
      context.missing(_conflictTypeMeta);
    }
    if (data.containsKey('is_resolved')) {
      context.handle(
          _isResolvedMeta,
          isResolved.isAcceptableOrUnknown(
              data['is_resolved']!, _isResolvedMeta));
    }
    if (data.containsKey('resolved_by')) {
      context.handle(
          _resolvedByMeta,
          resolvedBy.isAcceptableOrUnknown(
              data['resolved_by']!, _resolvedByMeta));
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
          _resolvedAtMeta,
          resolvedAt.isAcceptableOrUnknown(
              data['resolved_at']!, _resolvedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConflictData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConflictData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      todoId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}todo_id'])!,
      versionsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}versions_json'])!,
      detectedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}detected_at'])!,
      conflictType: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}conflict_type'])!,
      isResolved: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_resolved'])!,
      resolvedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}resolved_by']),
      resolvedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}resolved_at']),
    );
  }

  @override
  $ConflictsTable createAlias(String alias) {
    return $ConflictsTable(attachedDatabase, alias);
  }
}

class ConflictData extends DataClass implements Insertable<ConflictData> {
  final String id;
  final String todoId;
  final String versionsJson;
  final DateTime detectedAt;
  final int conflictType;
  final bool isResolved;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  const ConflictData(
      {required this.id,
      required this.todoId,
      required this.versionsJson,
      required this.detectedAt,
      required this.conflictType,
      required this.isResolved,
      this.resolvedBy,
      this.resolvedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['todo_id'] = Variable<String>(todoId);
    map['versions_json'] = Variable<String>(versionsJson);
    map['detected_at'] = Variable<DateTime>(detectedAt);
    map['conflict_type'] = Variable<int>(conflictType);
    map['is_resolved'] = Variable<bool>(isResolved);
    if (!nullToAbsent || resolvedBy != null) {
      map['resolved_by'] = Variable<String>(resolvedBy);
    }
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    return map;
  }

  ConflictsCompanion toCompanion(bool nullToAbsent) {
    return ConflictsCompanion(
      id: Value(id),
      todoId: Value(todoId),
      versionsJson: Value(versionsJson),
      detectedAt: Value(detectedAt),
      conflictType: Value(conflictType),
      isResolved: Value(isResolved),
      resolvedBy: resolvedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedBy),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
    );
  }

  factory ConflictData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConflictData(
      id: serializer.fromJson<String>(json['id']),
      todoId: serializer.fromJson<String>(json['todoId']),
      versionsJson: serializer.fromJson<String>(json['versionsJson']),
      detectedAt: serializer.fromJson<DateTime>(json['detectedAt']),
      conflictType: serializer.fromJson<int>(json['conflictType']),
      isResolved: serializer.fromJson<bool>(json['isResolved']),
      resolvedBy: serializer.fromJson<String?>(json['resolvedBy']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'todoId': serializer.toJson<String>(todoId),
      'versionsJson': serializer.toJson<String>(versionsJson),
      'detectedAt': serializer.toJson<DateTime>(detectedAt),
      'conflictType': serializer.toJson<int>(conflictType),
      'isResolved': serializer.toJson<bool>(isResolved),
      'resolvedBy': serializer.toJson<String?>(resolvedBy),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
    };
  }

  ConflictData copyWith(
          {String? id,
          String? todoId,
          String? versionsJson,
          DateTime? detectedAt,
          int? conflictType,
          bool? isResolved,
          Value<String?> resolvedBy = const Value.absent(),
          Value<DateTime?> resolvedAt = const Value.absent()}) =>
      ConflictData(
        id: id ?? this.id,
        todoId: todoId ?? this.todoId,
        versionsJson: versionsJson ?? this.versionsJson,
        detectedAt: detectedAt ?? this.detectedAt,
        conflictType: conflictType ?? this.conflictType,
        isResolved: isResolved ?? this.isResolved,
        resolvedBy: resolvedBy.present ? resolvedBy.value : this.resolvedBy,
        resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
      );
  ConflictData copyWithCompanion(ConflictsCompanion data) {
    return ConflictData(
      id: data.id.present ? data.id.value : this.id,
      todoId: data.todoId.present ? data.todoId.value : this.todoId,
      versionsJson: data.versionsJson.present
          ? data.versionsJson.value
          : this.versionsJson,
      detectedAt:
          data.detectedAt.present ? data.detectedAt.value : this.detectedAt,
      conflictType: data.conflictType.present
          ? data.conflictType.value
          : this.conflictType,
      isResolved:
          data.isResolved.present ? data.isResolved.value : this.isResolved,
      resolvedBy:
          data.resolvedBy.present ? data.resolvedBy.value : this.resolvedBy,
      resolvedAt:
          data.resolvedAt.present ? data.resolvedAt.value : this.resolvedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConflictData(')
          ..write('id: $id, ')
          ..write('todoId: $todoId, ')
          ..write('versionsJson: $versionsJson, ')
          ..write('detectedAt: $detectedAt, ')
          ..write('conflictType: $conflictType, ')
          ..write('isResolved: $isResolved, ')
          ..write('resolvedBy: $resolvedBy, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, todoId, versionsJson, detectedAt,
      conflictType, isResolved, resolvedBy, resolvedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConflictData &&
          other.id == this.id &&
          other.todoId == this.todoId &&
          other.versionsJson == this.versionsJson &&
          other.detectedAt == this.detectedAt &&
          other.conflictType == this.conflictType &&
          other.isResolved == this.isResolved &&
          other.resolvedBy == this.resolvedBy &&
          other.resolvedAt == this.resolvedAt);
}

class ConflictsCompanion extends UpdateCompanion<ConflictData> {
  final Value<String> id;
  final Value<String> todoId;
  final Value<String> versionsJson;
  final Value<DateTime> detectedAt;
  final Value<int> conflictType;
  final Value<bool> isResolved;
  final Value<String?> resolvedBy;
  final Value<DateTime?> resolvedAt;
  final Value<int> rowid;
  const ConflictsCompanion({
    this.id = const Value.absent(),
    this.todoId = const Value.absent(),
    this.versionsJson = const Value.absent(),
    this.detectedAt = const Value.absent(),
    this.conflictType = const Value.absent(),
    this.isResolved = const Value.absent(),
    this.resolvedBy = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConflictsCompanion.insert({
    required String id,
    required String todoId,
    required String versionsJson,
    required DateTime detectedAt,
    required int conflictType,
    this.isResolved = const Value.absent(),
    this.resolvedBy = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        todoId = Value(todoId),
        versionsJson = Value(versionsJson),
        detectedAt = Value(detectedAt),
        conflictType = Value(conflictType);
  static Insertable<ConflictData> custom({
    Expression<String>? id,
    Expression<String>? todoId,
    Expression<String>? versionsJson,
    Expression<DateTime>? detectedAt,
    Expression<int>? conflictType,
    Expression<bool>? isResolved,
    Expression<String>? resolvedBy,
    Expression<DateTime>? resolvedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (todoId != null) 'todo_id': todoId,
      if (versionsJson != null) 'versions_json': versionsJson,
      if (detectedAt != null) 'detected_at': detectedAt,
      if (conflictType != null) 'conflict_type': conflictType,
      if (isResolved != null) 'is_resolved': isResolved,
      if (resolvedBy != null) 'resolved_by': resolvedBy,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConflictsCompanion copyWith(
      {Value<String>? id,
      Value<String>? todoId,
      Value<String>? versionsJson,
      Value<DateTime>? detectedAt,
      Value<int>? conflictType,
      Value<bool>? isResolved,
      Value<String?>? resolvedBy,
      Value<DateTime?>? resolvedAt,
      Value<int>? rowid}) {
    return ConflictsCompanion(
      id: id ?? this.id,
      todoId: todoId ?? this.todoId,
      versionsJson: versionsJson ?? this.versionsJson,
      detectedAt: detectedAt ?? this.detectedAt,
      conflictType: conflictType ?? this.conflictType,
      isResolved: isResolved ?? this.isResolved,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (todoId.present) {
      map['todo_id'] = Variable<String>(todoId.value);
    }
    if (versionsJson.present) {
      map['versions_json'] = Variable<String>(versionsJson.value);
    }
    if (detectedAt.present) {
      map['detected_at'] = Variable<DateTime>(detectedAt.value);
    }
    if (conflictType.present) {
      map['conflict_type'] = Variable<int>(conflictType.value);
    }
    if (isResolved.present) {
      map['is_resolved'] = Variable<bool>(isResolved.value);
    }
    if (resolvedBy.present) {
      map['resolved_by'] = Variable<String>(resolvedBy.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConflictsCompanion(')
          ..write('id: $id, ')
          ..write('todoId: $todoId, ')
          ..write('versionsJson: $versionsJson, ')
          ..write('detectedAt: $detectedAt, ')
          ..write('conflictType: $conflictType, ')
          ..write('isResolved: $isResolved, ')
          ..write('resolvedBy: $resolvedBy, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DevicesTable extends Devices with TableInfo<$DevicesTable, DeviceData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastSeenMeta =
      const VerificationMeta('lastSeen');
  @override
  late final GeneratedColumn<DateTime> lastSeen = GeneratedColumn<DateTime>(
      'last_seen', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _isCurrentDeviceMeta =
      const VerificationMeta('isCurrentDevice');
  @override
  late final GeneratedColumn<bool> isCurrentDevice = GeneratedColumn<bool>(
      'is_current_device', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_current_device" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [id, name, lastSeen, isCurrentDevice];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'devices';
  @override
  VerificationContext validateIntegrity(Insertable<DeviceData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('last_seen')) {
      context.handle(_lastSeenMeta,
          lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta));
    } else if (isInserting) {
      context.missing(_lastSeenMeta);
    }
    if (data.containsKey('is_current_device')) {
      context.handle(
          _isCurrentDeviceMeta,
          isCurrentDevice.isAcceptableOrUnknown(
              data['is_current_device']!, _isCurrentDeviceMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeviceData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      lastSeen: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_seen'])!,
      isCurrentDevice: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}is_current_device'])!,
    );
  }

  @override
  $DevicesTable createAlias(String alias) {
    return $DevicesTable(attachedDatabase, alias);
  }
}

class DeviceData extends DataClass implements Insertable<DeviceData> {
  final String id;
  final String name;
  final DateTime lastSeen;
  final bool isCurrentDevice;
  const DeviceData(
      {required this.id,
      required this.name,
      required this.lastSeen,
      required this.isCurrentDevice});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['last_seen'] = Variable<DateTime>(lastSeen);
    map['is_current_device'] = Variable<bool>(isCurrentDevice);
    return map;
  }

  DevicesCompanion toCompanion(bool nullToAbsent) {
    return DevicesCompanion(
      id: Value(id),
      name: Value(name),
      lastSeen: Value(lastSeen),
      isCurrentDevice: Value(isCurrentDevice),
    );
  }

  factory DeviceData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceData(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      lastSeen: serializer.fromJson<DateTime>(json['lastSeen']),
      isCurrentDevice: serializer.fromJson<bool>(json['isCurrentDevice']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'lastSeen': serializer.toJson<DateTime>(lastSeen),
      'isCurrentDevice': serializer.toJson<bool>(isCurrentDevice),
    };
  }

  DeviceData copyWith(
          {String? id,
          String? name,
          DateTime? lastSeen,
          bool? isCurrentDevice}) =>
      DeviceData(
        id: id ?? this.id,
        name: name ?? this.name,
        lastSeen: lastSeen ?? this.lastSeen,
        isCurrentDevice: isCurrentDevice ?? this.isCurrentDevice,
      );
  DeviceData copyWithCompanion(DevicesCompanion data) {
    return DeviceData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
      isCurrentDevice: data.isCurrentDevice.present
          ? data.isCurrentDevice.value
          : this.isCurrentDevice,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('isCurrentDevice: $isCurrentDevice')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, lastSeen, isCurrentDevice);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceData &&
          other.id == this.id &&
          other.name == this.name &&
          other.lastSeen == this.lastSeen &&
          other.isCurrentDevice == this.isCurrentDevice);
}

class DevicesCompanion extends UpdateCompanion<DeviceData> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> lastSeen;
  final Value<bool> isCurrentDevice;
  final Value<int> rowid;
  const DevicesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.isCurrentDevice = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DevicesCompanion.insert({
    required String id,
    required String name,
    required DateTime lastSeen,
    this.isCurrentDevice = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        lastSeen = Value(lastSeen);
  static Insertable<DeviceData> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? lastSeen,
    Expression<bool>? isCurrentDevice,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (isCurrentDevice != null) 'is_current_device': isCurrentDevice,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DevicesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<DateTime>? lastSeen,
      Value<bool>? isCurrentDevice,
      Value<int>? rowid}) {
    return DevicesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      lastSeen: lastSeen ?? this.lastSeen,
      isCurrentDevice: isCurrentDevice ?? this.isCurrentDevice,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<DateTime>(lastSeen.value);
    }
    if (isCurrentDevice.present) {
      map['is_current_device'] = Variable<bool>(isCurrentDevice.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DevicesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('isCurrentDevice: $isCurrentDevice, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDatabase extends GeneratedDatabase {
  _$LocalDatabase(QueryExecutor e) : super(e);
  $LocalDatabaseManager get managers => $LocalDatabaseManager(this);
  late final $TodosTable todos = $TodosTable(this);
  late final $ConflictsTable conflicts = $ConflictsTable(this);
  late final $DevicesTable devices = $DevicesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [todos, conflicts, devices];
}

typedef $$TodosTableCreateCompanionBuilder = TodosCompanion Function({
  required String id,
  required String name,
  required double price,
  Value<bool> isCompleted,
  required DateTime createdAt,
  required DateTime updatedAt,
  required String vectorClockJson,
  required String deviceId,
  required int version,
  Value<bool> isDeleted,
  Value<String?> syncId,
  Value<bool> needsSync,
  Value<int> rowid,
});
typedef $$TodosTableUpdateCompanionBuilder = TodosCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<double> price,
  Value<bool> isCompleted,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<String> vectorClockJson,
  Value<String> deviceId,
  Value<int> version,
  Value<bool> isDeleted,
  Value<String?> syncId,
  Value<bool> needsSync,
  Value<int> rowid,
});

class $$TodosTableFilterComposer
    extends Composer<_$LocalDatabase, $TodosTable> {
  $$TodosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get price => $composableBuilder(
      column: $table.price, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get vectorClockJson => $composableBuilder(
      column: $table.vectorClockJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get needsSync => $composableBuilder(
      column: $table.needsSync, builder: (column) => ColumnFilters(column));
}

class $$TodosTableOrderingComposer
    extends Composer<_$LocalDatabase, $TodosTable> {
  $$TodosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get price => $composableBuilder(
      column: $table.price, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get vectorClockJson => $composableBuilder(
      column: $table.vectorClockJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get needsSync => $composableBuilder(
      column: $table.needsSync, builder: (column) => ColumnOrderings(column));
}

class $$TodosTableAnnotationComposer
    extends Composer<_$LocalDatabase, $TodosTable> {
  $$TodosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get vectorClockJson => $composableBuilder(
      column: $table.vectorClockJson, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<bool> get needsSync =>
      $composableBuilder(column: $table.needsSync, builder: (column) => column);
}

class $$TodosTableTableManager extends RootTableManager<
    _$LocalDatabase,
    $TodosTable,
    TodoData,
    $$TodosTableFilterComposer,
    $$TodosTableOrderingComposer,
    $$TodosTableAnnotationComposer,
    $$TodosTableCreateCompanionBuilder,
    $$TodosTableUpdateCompanionBuilder,
    (TodoData, BaseReferences<_$LocalDatabase, $TodosTable, TodoData>),
    TodoData,
    PrefetchHooks Function()> {
  $$TodosTableTableManager(_$LocalDatabase db, $TodosTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<double> price = const Value.absent(),
            Value<bool> isCompleted = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String> vectorClockJson = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
            Value<bool> needsSync = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TodosCompanion(
            id: id,
            name: name,
            price: price,
            isCompleted: isCompleted,
            createdAt: createdAt,
            updatedAt: updatedAt,
            vectorClockJson: vectorClockJson,
            deviceId: deviceId,
            version: version,
            isDeleted: isDeleted,
            syncId: syncId,
            needsSync: needsSync,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required double price,
            Value<bool> isCompleted = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            required String vectorClockJson,
            required String deviceId,
            required int version,
            Value<bool> isDeleted = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
            Value<bool> needsSync = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TodosCompanion.insert(
            id: id,
            name: name,
            price: price,
            isCompleted: isCompleted,
            createdAt: createdAt,
            updatedAt: updatedAt,
            vectorClockJson: vectorClockJson,
            deviceId: deviceId,
            version: version,
            isDeleted: isDeleted,
            syncId: syncId,
            needsSync: needsSync,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TodosTableProcessedTableManager = ProcessedTableManager<
    _$LocalDatabase,
    $TodosTable,
    TodoData,
    $$TodosTableFilterComposer,
    $$TodosTableOrderingComposer,
    $$TodosTableAnnotationComposer,
    $$TodosTableCreateCompanionBuilder,
    $$TodosTableUpdateCompanionBuilder,
    (TodoData, BaseReferences<_$LocalDatabase, $TodosTable, TodoData>),
    TodoData,
    PrefetchHooks Function()>;
typedef $$ConflictsTableCreateCompanionBuilder = ConflictsCompanion Function({
  required String id,
  required String todoId,
  required String versionsJson,
  required DateTime detectedAt,
  required int conflictType,
  Value<bool> isResolved,
  Value<String?> resolvedBy,
  Value<DateTime?> resolvedAt,
  Value<int> rowid,
});
typedef $$ConflictsTableUpdateCompanionBuilder = ConflictsCompanion Function({
  Value<String> id,
  Value<String> todoId,
  Value<String> versionsJson,
  Value<DateTime> detectedAt,
  Value<int> conflictType,
  Value<bool> isResolved,
  Value<String?> resolvedBy,
  Value<DateTime?> resolvedAt,
  Value<int> rowid,
});

class $$ConflictsTableFilterComposer
    extends Composer<_$LocalDatabase, $ConflictsTable> {
  $$ConflictsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get todoId => $composableBuilder(
      column: $table.todoId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get versionsJson => $composableBuilder(
      column: $table.versionsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get detectedAt => $composableBuilder(
      column: $table.detectedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get conflictType => $composableBuilder(
      column: $table.conflictType, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isResolved => $composableBuilder(
      column: $table.isResolved, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resolvedBy => $composableBuilder(
      column: $table.resolvedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
      column: $table.resolvedAt, builder: (column) => ColumnFilters(column));
}

class $$ConflictsTableOrderingComposer
    extends Composer<_$LocalDatabase, $ConflictsTable> {
  $$ConflictsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get todoId => $composableBuilder(
      column: $table.todoId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get versionsJson => $composableBuilder(
      column: $table.versionsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get detectedAt => $composableBuilder(
      column: $table.detectedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get conflictType => $composableBuilder(
      column: $table.conflictType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isResolved => $composableBuilder(
      column: $table.isResolved, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resolvedBy => $composableBuilder(
      column: $table.resolvedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
      column: $table.resolvedAt, builder: (column) => ColumnOrderings(column));
}

class $$ConflictsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $ConflictsTable> {
  $$ConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get todoId =>
      $composableBuilder(column: $table.todoId, builder: (column) => column);

  GeneratedColumn<String> get versionsJson => $composableBuilder(
      column: $table.versionsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get detectedAt => $composableBuilder(
      column: $table.detectedAt, builder: (column) => column);

  GeneratedColumn<int> get conflictType => $composableBuilder(
      column: $table.conflictType, builder: (column) => column);

  GeneratedColumn<bool> get isResolved => $composableBuilder(
      column: $table.isResolved, builder: (column) => column);

  GeneratedColumn<String> get resolvedBy => $composableBuilder(
      column: $table.resolvedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
      column: $table.resolvedAt, builder: (column) => column);
}

class $$ConflictsTableTableManager extends RootTableManager<
    _$LocalDatabase,
    $ConflictsTable,
    ConflictData,
    $$ConflictsTableFilterComposer,
    $$ConflictsTableOrderingComposer,
    $$ConflictsTableAnnotationComposer,
    $$ConflictsTableCreateCompanionBuilder,
    $$ConflictsTableUpdateCompanionBuilder,
    (
      ConflictData,
      BaseReferences<_$LocalDatabase, $ConflictsTable, ConflictData>
    ),
    ConflictData,
    PrefetchHooks Function()> {
  $$ConflictsTableTableManager(_$LocalDatabase db, $ConflictsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConflictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConflictsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> todoId = const Value.absent(),
            Value<String> versionsJson = const Value.absent(),
            Value<DateTime> detectedAt = const Value.absent(),
            Value<int> conflictType = const Value.absent(),
            Value<bool> isResolved = const Value.absent(),
            Value<String?> resolvedBy = const Value.absent(),
            Value<DateTime?> resolvedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConflictsCompanion(
            id: id,
            todoId: todoId,
            versionsJson: versionsJson,
            detectedAt: detectedAt,
            conflictType: conflictType,
            isResolved: isResolved,
            resolvedBy: resolvedBy,
            resolvedAt: resolvedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String todoId,
            required String versionsJson,
            required DateTime detectedAt,
            required int conflictType,
            Value<bool> isResolved = const Value.absent(),
            Value<String?> resolvedBy = const Value.absent(),
            Value<DateTime?> resolvedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConflictsCompanion.insert(
            id: id,
            todoId: todoId,
            versionsJson: versionsJson,
            detectedAt: detectedAt,
            conflictType: conflictType,
            isResolved: isResolved,
            resolvedBy: resolvedBy,
            resolvedAt: resolvedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ConflictsTableProcessedTableManager = ProcessedTableManager<
    _$LocalDatabase,
    $ConflictsTable,
    ConflictData,
    $$ConflictsTableFilterComposer,
    $$ConflictsTableOrderingComposer,
    $$ConflictsTableAnnotationComposer,
    $$ConflictsTableCreateCompanionBuilder,
    $$ConflictsTableUpdateCompanionBuilder,
    (
      ConflictData,
      BaseReferences<_$LocalDatabase, $ConflictsTable, ConflictData>
    ),
    ConflictData,
    PrefetchHooks Function()>;
typedef $$DevicesTableCreateCompanionBuilder = DevicesCompanion Function({
  required String id,
  required String name,
  required DateTime lastSeen,
  Value<bool> isCurrentDevice,
  Value<int> rowid,
});
typedef $$DevicesTableUpdateCompanionBuilder = DevicesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<DateTime> lastSeen,
  Value<bool> isCurrentDevice,
  Value<int> rowid,
});

class $$DevicesTableFilterComposer
    extends Composer<_$LocalDatabase, $DevicesTable> {
  $$DevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSeen => $composableBuilder(
      column: $table.lastSeen, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isCurrentDevice => $composableBuilder(
      column: $table.isCurrentDevice,
      builder: (column) => ColumnFilters(column));
}

class $$DevicesTableOrderingComposer
    extends Composer<_$LocalDatabase, $DevicesTable> {
  $$DevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSeen => $composableBuilder(
      column: $table.lastSeen, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isCurrentDevice => $composableBuilder(
      column: $table.isCurrentDevice,
      builder: (column) => ColumnOrderings(column));
}

class $$DevicesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $DevicesTable> {
  $$DevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);

  GeneratedColumn<bool> get isCurrentDevice => $composableBuilder(
      column: $table.isCurrentDevice, builder: (column) => column);
}

class $$DevicesTableTableManager extends RootTableManager<
    _$LocalDatabase,
    $DevicesTable,
    DeviceData,
    $$DevicesTableFilterComposer,
    $$DevicesTableOrderingComposer,
    $$DevicesTableAnnotationComposer,
    $$DevicesTableCreateCompanionBuilder,
    $$DevicesTableUpdateCompanionBuilder,
    (DeviceData, BaseReferences<_$LocalDatabase, $DevicesTable, DeviceData>),
    DeviceData,
    PrefetchHooks Function()> {
  $$DevicesTableTableManager(_$LocalDatabase db, $DevicesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime> lastSeen = const Value.absent(),
            Value<bool> isCurrentDevice = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DevicesCompanion(
            id: id,
            name: name,
            lastSeen: lastSeen,
            isCurrentDevice: isCurrentDevice,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required DateTime lastSeen,
            Value<bool> isCurrentDevice = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DevicesCompanion.insert(
            id: id,
            name: name,
            lastSeen: lastSeen,
            isCurrentDevice: isCurrentDevice,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DevicesTableProcessedTableManager = ProcessedTableManager<
    _$LocalDatabase,
    $DevicesTable,
    DeviceData,
    $$DevicesTableFilterComposer,
    $$DevicesTableOrderingComposer,
    $$DevicesTableAnnotationComposer,
    $$DevicesTableCreateCompanionBuilder,
    $$DevicesTableUpdateCompanionBuilder,
    (DeviceData, BaseReferences<_$LocalDatabase, $DevicesTable, DeviceData>),
    DeviceData,
    PrefetchHooks Function()>;

class $LocalDatabaseManager {
  final _$LocalDatabase _db;
  $LocalDatabaseManager(this._db);
  $$TodosTableTableManager get todos =>
      $$TodosTableTableManager(_db, _db.todos);
  $$ConflictsTableTableManager get conflicts =>
      $$ConflictsTableTableManager(_db, _db.conflicts);
  $$DevicesTableTableManager get devices =>
      $$DevicesTableTableManager(_db, _db.devices);
}
