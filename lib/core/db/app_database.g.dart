// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SettingEntriesTable extends SettingEntries
    with TableInfo<$SettingEntriesTable, SettingEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'setting_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingEntry> instance, {
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
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingEntriesTable createAlias(String alias) {
    return $SettingEntriesTable(attachedDatabase, alias);
  }
}

class SettingEntry extends DataClass implements Insertable<SettingEntry> {
  final String key;
  final String value;
  const SettingEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingEntriesCompanion toCompanion(bool nullToAbsent) {
    return SettingEntriesCompanion(key: Value(key), value: Value(value));
  }

  factory SettingEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingEntry copyWith({String? key, String? value}) =>
      SettingEntry(key: key ?? this.key, value: value ?? this.value);
  SettingEntry copyWithCompanion(SettingEntriesCompanion data) {
    return SettingEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingEntry &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingEntriesCompanion extends UpdateCompanion<SettingEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingEntriesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingEntriesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingEntriesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingEntriesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingEntriesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProviderEntriesTable extends ProviderEntries
    with TableInfo<$ProviderEntriesTable, ProviderEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProviderEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _apiKeyRefMeta = const VerificationMeta(
    'apiKeyRef',
  );
  @override
  late final GeneratedColumn<String> apiKeyRef = GeneratedColumn<String>(
    'api_key_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authMethodMeta = const VerificationMeta(
    'authMethod',
  );
  @override
  late final GeneratedColumn<String> authMethod = GeneratedColumn<String>(
    'auth_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('api_key'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    baseUrl,
    model,
    apiKeyRef,
    authMethod,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'providers';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProviderEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('api_key_ref')) {
      context.handle(
        _apiKeyRefMeta,
        apiKeyRef.isAcceptableOrUnknown(data['api_key_ref']!, _apiKeyRefMeta),
      );
    } else if (isInserting) {
      context.missing(_apiKeyRefMeta);
    }
    if (data.containsKey('auth_method')) {
      context.handle(
        _authMethodMeta,
        authMethod.isAcceptableOrUnknown(data['auth_method']!, _authMethodMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProviderEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProviderEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      apiKeyRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}api_key_ref'],
      )!,
      authMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}auth_method'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ProviderEntriesTable createAlias(String alias) {
    return $ProviderEntriesTable(attachedDatabase, alias);
  }
}

class ProviderEntry extends DataClass implements Insertable<ProviderEntry> {
  final String id;
  final String name;

  /// `deepseek` or `openai`.
  final String type;
  final String baseUrl;
  final String model;
  final String apiKeyRef;
  final String authMethod;
  final int createdAt;
  const ProviderEntry({
    required this.id,
    required this.name,
    required this.type,
    required this.baseUrl,
    required this.model,
    required this.apiKeyRef,
    required this.authMethod,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['base_url'] = Variable<String>(baseUrl);
    map['model'] = Variable<String>(model);
    map['api_key_ref'] = Variable<String>(apiKeyRef);
    map['auth_method'] = Variable<String>(authMethod);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  ProviderEntriesCompanion toCompanion(bool nullToAbsent) {
    return ProviderEntriesCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      baseUrl: Value(baseUrl),
      model: Value(model),
      apiKeyRef: Value(apiKeyRef),
      authMethod: Value(authMethod),
      createdAt: Value(createdAt),
    );
  }

  factory ProviderEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProviderEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      model: serializer.fromJson<String>(json['model']),
      apiKeyRef: serializer.fromJson<String>(json['apiKeyRef']),
      authMethod: serializer.fromJson<String>(json['authMethod']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'model': serializer.toJson<String>(model),
      'apiKeyRef': serializer.toJson<String>(apiKeyRef),
      'authMethod': serializer.toJson<String>(authMethod),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  ProviderEntry copyWith({
    String? id,
    String? name,
    String? type,
    String? baseUrl,
    String? model,
    String? apiKeyRef,
    String? authMethod,
    int? createdAt,
  }) => ProviderEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    apiKeyRef: apiKeyRef ?? this.apiKeyRef,
    authMethod: authMethod ?? this.authMethod,
    createdAt: createdAt ?? this.createdAt,
  );
  ProviderEntry copyWithCompanion(ProviderEntriesCompanion data) {
    return ProviderEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      model: data.model.present ? data.model.value : this.model,
      apiKeyRef: data.apiKeyRef.present ? data.apiKeyRef.value : this.apiKeyRef,
      authMethod: data.authMethod.present
          ? data.authMethod.value
          : this.authMethod,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProviderEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('model: $model, ')
          ..write('apiKeyRef: $apiKeyRef, ')
          ..write('authMethod: $authMethod, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    baseUrl,
    model,
    apiKeyRef,
    authMethod,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.baseUrl == this.baseUrl &&
          other.model == this.model &&
          other.apiKeyRef == this.apiKeyRef &&
          other.authMethod == this.authMethod &&
          other.createdAt == this.createdAt);
}

class ProviderEntriesCompanion extends UpdateCompanion<ProviderEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String> baseUrl;
  final Value<String> model;
  final Value<String> apiKeyRef;
  final Value<String> authMethod;
  final Value<int> createdAt;
  final Value<int> rowid;
  const ProviderEntriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.model = const Value.absent(),
    this.apiKeyRef = const Value.absent(),
    this.authMethod = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProviderEntriesCompanion.insert({
    required String id,
    required String name,
    required String type,
    required String baseUrl,
    required String model,
    required String apiKeyRef,
    this.authMethod = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       type = Value(type),
       baseUrl = Value(baseUrl),
       model = Value(model),
       apiKeyRef = Value(apiKeyRef),
       createdAt = Value(createdAt);
  static Insertable<ProviderEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? baseUrl,
    Expression<String>? model,
    Expression<String>? apiKeyRef,
    Expression<String>? authMethod,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (baseUrl != null) 'base_url': baseUrl,
      if (model != null) 'model': model,
      if (apiKeyRef != null) 'api_key_ref': apiKeyRef,
      if (authMethod != null) 'auth_method': authMethod,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProviderEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String>? baseUrl,
    Value<String>? model,
    Value<String>? apiKeyRef,
    Value<String>? authMethod,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return ProviderEntriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      apiKeyRef: apiKeyRef ?? this.apiKeyRef,
      authMethod: authMethod ?? this.authMethod,
      createdAt: createdAt ?? this.createdAt,
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
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (apiKeyRef.present) {
      map['api_key_ref'] = Variable<String>(apiKeyRef.value);
    }
    if (authMethod.present) {
      map['auth_method'] = Variable<String>(authMethod.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProviderEntriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('model: $model, ')
          ..write('apiKeyRef: $apiKeyRef, ')
          ..write('authMethod: $authMethod, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationsTable extends Conversations
    with TableInfo<$ConversationsTable, Conversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES providers (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _systemPromptMeta = const VerificationMeta(
    'systemPrompt',
  );
  @override
  late final GeneratedColumn<String> systemPrompt = GeneratedColumn<String>(
    'system_prompt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    providerId,
    model,
    systemPrompt,
    archived,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Conversation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('system_prompt')) {
      context.handle(
        _systemPromptMeta,
        systemPrompt.isAcceptableOrUnknown(
          data['system_prompt']!,
          _systemPromptMeta,
        ),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Conversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Conversation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
      systemPrompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}system_prompt'],
      ),
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ConversationsTable createAlias(String alias) {
    return $ConversationsTable(attachedDatabase, alias);
  }
}

class Conversation extends DataClass implements Insertable<Conversation> {
  final String id;

  /// Empty until the first user message arrives.
  final String title;
  final String? providerId;

  /// Optional per-conversation model override.
  final String? model;
  final String? systemPrompt;
  final bool archived;
  final int createdAt;
  final int updatedAt;
  const Conversation({
    required this.id,
    required this.title,
    this.providerId,
    this.model,
    this.systemPrompt,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || providerId != null) {
      map['provider_id'] = Variable<String>(providerId);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    if (!nullToAbsent || systemPrompt != null) {
      map['system_prompt'] = Variable<String>(systemPrompt);
    }
    map['archived'] = Variable<bool>(archived);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: Value(id),
      title: Value(title),
      providerId: providerId == null && nullToAbsent
          ? const Value.absent()
          : Value(providerId),
      model: model == null && nullToAbsent
          ? const Value.absent()
          : Value(model),
      systemPrompt: systemPrompt == null && nullToAbsent
          ? const Value.absent()
          : Value(systemPrompt),
      archived: Value(archived),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Conversation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Conversation(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      providerId: serializer.fromJson<String?>(json['providerId']),
      model: serializer.fromJson<String?>(json['model']),
      systemPrompt: serializer.fromJson<String?>(json['systemPrompt']),
      archived: serializer.fromJson<bool>(json['archived']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'providerId': serializer.toJson<String?>(providerId),
      'model': serializer.toJson<String?>(model),
      'systemPrompt': serializer.toJson<String?>(systemPrompt),
      'archived': serializer.toJson<bool>(archived),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  Conversation copyWith({
    String? id,
    String? title,
    Value<String?> providerId = const Value.absent(),
    Value<String?> model = const Value.absent(),
    Value<String?> systemPrompt = const Value.absent(),
    bool? archived,
    int? createdAt,
    int? updatedAt,
  }) => Conversation(
    id: id ?? this.id,
    title: title ?? this.title,
    providerId: providerId.present ? providerId.value : this.providerId,
    model: model.present ? model.value : this.model,
    systemPrompt: systemPrompt.present ? systemPrompt.value : this.systemPrompt,
    archived: archived ?? this.archived,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Conversation copyWithCompanion(ConversationsCompanion data) {
    return Conversation(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      model: data.model.present ? data.model.value : this.model,
      systemPrompt: data.systemPrompt.present
          ? data.systemPrompt.value
          : this.systemPrompt,
      archived: data.archived.present ? data.archived.value : this.archived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Conversation(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('providerId: $providerId, ')
          ..write('model: $model, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('archived: $archived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    providerId,
    model,
    systemPrompt,
    archived,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Conversation &&
          other.id == this.id &&
          other.title == this.title &&
          other.providerId == this.providerId &&
          other.model == this.model &&
          other.systemPrompt == this.systemPrompt &&
          other.archived == this.archived &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ConversationsCompanion extends UpdateCompanion<Conversation> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> providerId;
  final Value<String?> model;
  final Value<String?> systemPrompt;
  final Value<bool> archived;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.providerId = const Value.absent(),
    this.model = const Value.absent(),
    this.systemPrompt = const Value.absent(),
    this.archived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationsCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    this.providerId = const Value.absent(),
    this.model = const Value.absent(),
    this.systemPrompt = const Value.absent(),
    this.archived = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Conversation> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? providerId,
    Expression<String>? model,
    Expression<String>? systemPrompt,
    Expression<bool>? archived,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (providerId != null) 'provider_id': providerId,
      if (model != null) 'model': model,
      if (systemPrompt != null) 'system_prompt': systemPrompt,
      if (archived != null) 'archived': archived,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? providerId,
    Value<String?>? model,
    Value<String?>? systemPrompt,
    Value<bool>? archived,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ConversationsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      providerId: providerId ?? this.providerId,
      model: model ?? this.model,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (systemPrompt.present) {
      map['system_prompt'] = Variable<String>(systemPrompt.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('providerId: $providerId, ')
          ..write('model: $model, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('archived: $archived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES conversations (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _reasoningMeta = const VerificationMeta(
    'reasoning',
  );
  @override
  late final GeneratedColumn<String> reasoning = GeneratedColumn<String>(
    'reasoning',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toolCallsJsonMeta = const VerificationMeta(
    'toolCallsJson',
  );
  @override
  late final GeneratedColumn<String> toolCallsJson = GeneratedColumn<String>(
    'tool_calls_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attachmentsJsonMeta = const VerificationMeta(
    'attachmentsJson',
  );
  @override
  late final GeneratedColumn<String> attachmentsJson = GeneratedColumn<String>(
    'attachments_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toolCallIdMeta = const VerificationMeta(
    'toolCallId',
  );
  @override
  late final GeneratedColumn<String> toolCallId = GeneratedColumn<String>(
    'tool_call_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('complete'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    role,
    content,
    reasoning,
    toolCallsJson,
    attachmentsJson,
    toolCallId,
    status,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Message> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('reasoning')) {
      context.handle(
        _reasoningMeta,
        reasoning.isAcceptableOrUnknown(data['reasoning']!, _reasoningMeta),
      );
    }
    if (data.containsKey('tool_calls_json')) {
      context.handle(
        _toolCallsJsonMeta,
        toolCallsJson.isAcceptableOrUnknown(
          data['tool_calls_json']!,
          _toolCallsJsonMeta,
        ),
      );
    }
    if (data.containsKey('attachments_json')) {
      context.handle(
        _attachmentsJsonMeta,
        attachmentsJson.isAcceptableOrUnknown(
          data['attachments_json']!,
          _attachmentsJsonMeta,
        ),
      );
    }
    if (data.containsKey('tool_call_id')) {
      context.handle(
        _toolCallIdMeta,
        toolCallId.isAcceptableOrUnknown(
          data['tool_call_id']!,
          _toolCallIdMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      reasoning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reasoning'],
      ),
      toolCallsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tool_calls_json'],
      ),
      attachmentsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachments_json'],
      ),
      toolCallId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tool_call_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final String id;
  final String conversationId;

  /// `system`, `user`, `assistant`, or `tool`.
  final String role;
  final String content;
  final String? reasoning;
  final String? toolCallsJson;

  /// JSON list of image or text-file attachments.
  final String? attachmentsJson;

  /// OpenAI `tool_call_id` for a tool-result message.
  final String? toolCallId;

  /// `complete`, `stopped`, or `error`.
  final String status;
  final int createdAt;
  const Message({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.reasoning,
    this.toolCallsJson,
    this.attachmentsJson,
    this.toolCallId,
    required this.status,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || reasoning != null) {
      map['reasoning'] = Variable<String>(reasoning);
    }
    if (!nullToAbsent || toolCallsJson != null) {
      map['tool_calls_json'] = Variable<String>(toolCallsJson);
    }
    if (!nullToAbsent || attachmentsJson != null) {
      map['attachments_json'] = Variable<String>(attachmentsJson);
    }
    if (!nullToAbsent || toolCallId != null) {
      map['tool_call_id'] = Variable<String>(toolCallId);
    }
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      role: Value(role),
      content: Value(content),
      reasoning: reasoning == null && nullToAbsent
          ? const Value.absent()
          : Value(reasoning),
      toolCallsJson: toolCallsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(toolCallsJson),
      attachmentsJson: attachmentsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentsJson),
      toolCallId: toolCallId == null && nullToAbsent
          ? const Value.absent()
          : Value(toolCallId),
      status: Value(status),
      createdAt: Value(createdAt),
    );
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      reasoning: serializer.fromJson<String?>(json['reasoning']),
      toolCallsJson: serializer.fromJson<String?>(json['toolCallsJson']),
      attachmentsJson: serializer.fromJson<String?>(json['attachmentsJson']),
      toolCallId: serializer.fromJson<String?>(json['toolCallId']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'reasoning': serializer.toJson<String?>(reasoning),
      'toolCallsJson': serializer.toJson<String?>(toolCallsJson),
      'attachmentsJson': serializer.toJson<String?>(attachmentsJson),
      'toolCallId': serializer.toJson<String?>(toolCallId),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  Message copyWith({
    String? id,
    String? conversationId,
    String? role,
    String? content,
    Value<String?> reasoning = const Value.absent(),
    Value<String?> toolCallsJson = const Value.absent(),
    Value<String?> attachmentsJson = const Value.absent(),
    Value<String?> toolCallId = const Value.absent(),
    String? status,
    int? createdAt,
  }) => Message(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    role: role ?? this.role,
    content: content ?? this.content,
    reasoning: reasoning.present ? reasoning.value : this.reasoning,
    toolCallsJson: toolCallsJson.present
        ? toolCallsJson.value
        : this.toolCallsJson,
    attachmentsJson: attachmentsJson.present
        ? attachmentsJson.value
        : this.attachmentsJson,
    toolCallId: toolCallId.present ? toolCallId.value : this.toolCallId,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
  );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      reasoning: data.reasoning.present ? data.reasoning.value : this.reasoning,
      toolCallsJson: data.toolCallsJson.present
          ? data.toolCallsJson.value
          : this.toolCallsJson,
      attachmentsJson: data.attachmentsJson.present
          ? data.attachmentsJson.value
          : this.attachmentsJson,
      toolCallId: data.toolCallId.present
          ? data.toolCallId.value
          : this.toolCallId,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('reasoning: $reasoning, ')
          ..write('toolCallsJson: $toolCallsJson, ')
          ..write('attachmentsJson: $attachmentsJson, ')
          ..write('toolCallId: $toolCallId, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    role,
    content,
    reasoning,
    toolCallsJson,
    attachmentsJson,
    toolCallId,
    status,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.role == this.role &&
          other.content == this.content &&
          other.reasoning == this.reasoning &&
          other.toolCallsJson == this.toolCallsJson &&
          other.attachmentsJson == this.attachmentsJson &&
          other.toolCallId == this.toolCallId &&
          other.status == this.status &&
          other.createdAt == this.createdAt);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> role;
  final Value<String> content;
  final Value<String?> reasoning;
  final Value<String?> toolCallsJson;
  final Value<String?> attachmentsJson;
  final Value<String?> toolCallId;
  final Value<String> status;
  final Value<int> createdAt;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.reasoning = const Value.absent(),
    this.toolCallsJson = const Value.absent(),
    this.attachmentsJson = const Value.absent(),
    this.toolCallId = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String conversationId,
    required String role,
    this.content = const Value.absent(),
    this.reasoning = const Value.absent(),
    this.toolCallsJson = const Value.absent(),
    this.attachmentsJson = const Value.absent(),
    this.toolCallId = const Value.absent(),
    this.status = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       role = Value(role),
       createdAt = Value(createdAt);
  static Insertable<Message> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? role,
    Expression<String>? content,
    Expression<String>? reasoning,
    Expression<String>? toolCallsJson,
    Expression<String>? attachmentsJson,
    Expression<String>? toolCallId,
    Expression<String>? status,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (reasoning != null) 'reasoning': reasoning,
      if (toolCallsJson != null) 'tool_calls_json': toolCallsJson,
      if (attachmentsJson != null) 'attachments_json': attachmentsJson,
      if (toolCallId != null) 'tool_call_id': toolCallId,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String>? role,
    Value<String>? content,
    Value<String?>? reasoning,
    Value<String?>? toolCallsJson,
    Value<String?>? attachmentsJson,
    Value<String?>? toolCallId,
    Value<String>? status,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      reasoning: reasoning ?? this.reasoning,
      toolCallsJson: toolCallsJson ?? this.toolCallsJson,
      attachmentsJson: attachmentsJson ?? this.attachmentsJson,
      toolCallId: toolCallId ?? this.toolCallId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (reasoning.present) {
      map['reasoning'] = Variable<String>(reasoning.value);
    }
    if (toolCallsJson.present) {
      map['tool_calls_json'] = Variable<String>(toolCallsJson.value);
    }
    if (attachmentsJson.present) {
      map['attachments_json'] = Variable<String>(attachmentsJson.value);
    }
    if (toolCallId.present) {
      map['tool_call_id'] = Variable<String>(toolCallId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('reasoning: $reasoning, ')
          ..write('toolCallsJson: $toolCallsJson, ')
          ..write('attachmentsJson: $attachmentsJson, ')
          ..write('toolCallId: $toolCallId, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MarketplaceEntriesTable extends MarketplaceEntries
    with TableInfo<$MarketplaceEntriesTable, MarketplaceEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MarketplaceEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _manifestUrlMeta = const VerificationMeta(
    'manifestUrl',
  );
  @override
  late final GeneratedColumn<String> manifestUrl = GeneratedColumn<String>(
    'manifest_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _builtInMeta = const VerificationMeta(
    'builtIn',
  );
  @override
  late final GeneratedColumn<bool> builtIn = GeneratedColumn<bool>(
    'built_in',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("built_in" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<int> lastSyncedAt = GeneratedColumn<int>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    sourceUrl,
    manifestUrl,
    builtIn,
    enabled,
    etag,
    lastSyncedAt,
    lastError,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'marketplaces';
  @override
  VerificationContext validateIntegrity(
    Insertable<MarketplaceEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceUrlMeta);
    }
    if (data.containsKey('manifest_url')) {
      context.handle(
        _manifestUrlMeta,
        manifestUrl.isAcceptableOrUnknown(
          data['manifest_url']!,
          _manifestUrlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_manifestUrlMeta);
    }
    if (data.containsKey('built_in')) {
      context.handle(
        _builtInMeta,
        builtIn.isAcceptableOrUnknown(data['built_in']!, _builtInMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MarketplaceEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MarketplaceEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      )!,
      manifestUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manifest_url'],
      )!,
      builtIn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}built_in'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_synced_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MarketplaceEntriesTable createAlias(String alias) {
    return $MarketplaceEntriesTable(attachedDatabase, alias);
  }
}

class MarketplaceEntry extends DataClass
    implements Insertable<MarketplaceEntry> {
  final String id;
  final String name;
  final String description;

  /// Repository or page the user added, for display and re-resolution.
  final String sourceUrl;

  /// Direct URL of `.claude-plugin/marketplace.json`.
  final String manifestUrl;
  final bool builtIn;
  final bool enabled;
  final String? etag;
  final int? lastSyncedAt;
  final String? lastError;
  final int createdAt;
  const MarketplaceEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.sourceUrl,
    required this.manifestUrl,
    required this.builtIn,
    required this.enabled,
    this.etag,
    this.lastSyncedAt,
    this.lastError,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['source_url'] = Variable<String>(sourceUrl);
    map['manifest_url'] = Variable<String>(manifestUrl);
    map['built_in'] = Variable<bool>(builtIn);
    map['enabled'] = Variable<bool>(enabled);
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<int>(lastSyncedAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  MarketplaceEntriesCompanion toCompanion(bool nullToAbsent) {
    return MarketplaceEntriesCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
      sourceUrl: Value(sourceUrl),
      manifestUrl: Value(manifestUrl),
      builtIn: Value(builtIn),
      enabled: Value(enabled),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
    );
  }

  factory MarketplaceEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MarketplaceEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      manifestUrl: serializer.fromJson<String>(json['manifestUrl']),
      builtIn: serializer.fromJson<bool>(json['builtIn']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      etag: serializer.fromJson<String?>(json['etag']),
      lastSyncedAt: serializer.fromJson<int?>(json['lastSyncedAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'manifestUrl': serializer.toJson<String>(manifestUrl),
      'builtIn': serializer.toJson<bool>(builtIn),
      'enabled': serializer.toJson<bool>(enabled),
      'etag': serializer.toJson<String?>(etag),
      'lastSyncedAt': serializer.toJson<int?>(lastSyncedAt),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  MarketplaceEntry copyWith({
    String? id,
    String? name,
    String? description,
    String? sourceUrl,
    String? manifestUrl,
    bool? builtIn,
    bool? enabled,
    Value<String?> etag = const Value.absent(),
    Value<int?> lastSyncedAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    int? createdAt,
  }) => MarketplaceEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    manifestUrl: manifestUrl ?? this.manifestUrl,
    builtIn: builtIn ?? this.builtIn,
    enabled: enabled ?? this.enabled,
    etag: etag.present ? etag.value : this.etag,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
  );
  MarketplaceEntry copyWithCompanion(MarketplaceEntriesCompanion data) {
    return MarketplaceEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      manifestUrl: data.manifestUrl.present
          ? data.manifestUrl.value
          : this.manifestUrl,
      builtIn: data.builtIn.present ? data.builtIn.value : this.builtIn,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      etag: data.etag.present ? data.etag.value : this.etag,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MarketplaceEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('manifestUrl: $manifestUrl, ')
          ..write('builtIn: $builtIn, ')
          ..write('enabled: $enabled, ')
          ..write('etag: $etag, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    sourceUrl,
    manifestUrl,
    builtIn,
    enabled,
    etag,
    lastSyncedAt,
    lastError,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MarketplaceEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.sourceUrl == this.sourceUrl &&
          other.manifestUrl == this.manifestUrl &&
          other.builtIn == this.builtIn &&
          other.enabled == this.enabled &&
          other.etag == this.etag &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt);
}

class MarketplaceEntriesCompanion extends UpdateCompanion<MarketplaceEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> description;
  final Value<String> sourceUrl;
  final Value<String> manifestUrl;
  final Value<bool> builtIn;
  final Value<bool> enabled;
  final Value<String?> etag;
  final Value<int?> lastSyncedAt;
  final Value<String?> lastError;
  final Value<int> createdAt;
  final Value<int> rowid;
  const MarketplaceEntriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.manifestUrl = const Value.absent(),
    this.builtIn = const Value.absent(),
    this.enabled = const Value.absent(),
    this.etag = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MarketplaceEntriesCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    required String sourceUrl,
    required String manifestUrl,
    this.builtIn = const Value.absent(),
    this.enabled = const Value.absent(),
    this.etag = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       sourceUrl = Value(sourceUrl),
       manifestUrl = Value(manifestUrl),
       createdAt = Value(createdAt);
  static Insertable<MarketplaceEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? sourceUrl,
    Expression<String>? manifestUrl,
    Expression<bool>? builtIn,
    Expression<bool>? enabled,
    Expression<String>? etag,
    Expression<int>? lastSyncedAt,
    Expression<String>? lastError,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (manifestUrl != null) 'manifest_url': manifestUrl,
      if (builtIn != null) 'built_in': builtIn,
      if (enabled != null) 'enabled': enabled,
      if (etag != null) 'etag': etag,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MarketplaceEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? description,
    Value<String>? sourceUrl,
    Value<String>? manifestUrl,
    Value<bool>? builtIn,
    Value<bool>? enabled,
    Value<String?>? etag,
    Value<int?>? lastSyncedAt,
    Value<String?>? lastError,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return MarketplaceEntriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      manifestUrl: manifestUrl ?? this.manifestUrl,
      builtIn: builtIn ?? this.builtIn,
      enabled: enabled ?? this.enabled,
      etag: etag ?? this.etag,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
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
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (manifestUrl.present) {
      map['manifest_url'] = Variable<String>(manifestUrl.value);
    }
    if (builtIn.present) {
      map['built_in'] = Variable<bool>(builtIn.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<int>(lastSyncedAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MarketplaceEntriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('manifestUrl: $manifestUrl, ')
          ..write('builtIn: $builtIn, ')
          ..write('enabled: $enabled, ')
          ..write('etag: $etag, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MarketplacePluginEntriesTable extends MarketplacePluginEntries
    with TableInfo<$MarketplacePluginEntriesTable, MarketplacePluginEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MarketplacePluginEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _marketplaceIdMeta = const VerificationMeta(
    'marketplaceId',
  );
  @override
  late final GeneratedColumn<String> marketplaceId = GeneratedColumn<String>(
    'marketplace_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES marketplaces (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _homepageMeta = const VerificationMeta(
    'homepage',
  );
  @override
  late final GeneratedColumn<String> homepage = GeneratedColumn<String>(
    'homepage',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceJsonMeta = const VerificationMeta(
    'sourceJson',
  );
  @override
  late final GeneratedColumn<String> sourceJson = GeneratedColumn<String>(
    'source_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceKindMeta = const VerificationMeta(
    'sourceKind',
  );
  @override
  late final GeneratedColumn<String> sourceKind = GeneratedColumn<String>(
    'source_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  static const VerificationMeta _sourceRefMeta = const VerificationMeta(
    'sourceRef',
  );
  @override
  late final GeneratedColumn<String> sourceRef = GeneratedColumn<String>(
    'source_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceShaMeta = const VerificationMeta(
    'sourceSha',
  );
  @override
  late final GeneratedColumn<String> sourceSha = GeneratedColumn<String>(
    'source_sha',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _installedMeta = const VerificationMeta(
    'installed',
  );
  @override
  late final GeneratedColumn<bool> installed = GeneratedColumn<bool>(
    'installed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("installed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _mcpStatusMeta = const VerificationMeta(
    'mcpStatus',
  );
  @override
  late final GeneratedColumn<String> mcpStatus = GeneratedColumn<String>(
    'mcp_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unknown'),
  );
  static const VerificationMeta _mcpConfigJsonMeta = const VerificationMeta(
    'mcpConfigJson',
  );
  @override
  late final GeneratedColumn<String> mcpConfigJson = GeneratedColumn<String>(
    'mcp_config_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mcpCheckedAtMeta = const VerificationMeta(
    'mcpCheckedAt',
  );
  @override
  late final GeneratedColumn<int> mcpCheckedAt = GeneratedColumn<int>(
    'mcp_checked_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _installedConfigJsonMeta =
      const VerificationMeta('installedConfigJson');
  @override
  late final GeneratedColumn<String> installedConfigJson =
      GeneratedColumn<String>(
        'installed_config_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _needsReconsentMeta = const VerificationMeta(
    'needsReconsent',
  );
  @override
  late final GeneratedColumn<bool> needsReconsent = GeneratedColumn<bool>(
    'needs_reconsent',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("needs_reconsent" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<int> lastSeenAt = GeneratedColumn<int>(
    'last_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    marketplaceId,
    name,
    displayName,
    description,
    author,
    category,
    homepage,
    version,
    sourceJson,
    sourceKind,
    sourceUrl,
    sourcePath,
    sourceRef,
    sourceSha,
    installed,
    enabled,
    mcpStatus,
    mcpConfigJson,
    mcpCheckedAt,
    installedConfigJson,
    needsReconsent,
    lastError,
    lastSeenAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'marketplace_plugins';
  @override
  VerificationContext validateIntegrity(
    Insertable<MarketplacePluginEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('marketplace_id')) {
      context.handle(
        _marketplaceIdMeta,
        marketplaceId.isAcceptableOrUnknown(
          data['marketplace_id']!,
          _marketplaceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_marketplaceIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('homepage')) {
      context.handle(
        _homepageMeta,
        homepage.isAcceptableOrUnknown(data['homepage']!, _homepageMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('source_json')) {
      context.handle(
        _sourceJsonMeta,
        sourceJson.isAcceptableOrUnknown(data['source_json']!, _sourceJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceJsonMeta);
    }
    if (data.containsKey('source_kind')) {
      context.handle(
        _sourceKindMeta,
        sourceKind.isAcceptableOrUnknown(data['source_kind']!, _sourceKindMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceKindMeta);
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    if (data.containsKey('source_path')) {
      context.handle(
        _sourcePathMeta,
        sourcePath.isAcceptableOrUnknown(data['source_path']!, _sourcePathMeta),
      );
    }
    if (data.containsKey('source_ref')) {
      context.handle(
        _sourceRefMeta,
        sourceRef.isAcceptableOrUnknown(data['source_ref']!, _sourceRefMeta),
      );
    }
    if (data.containsKey('source_sha')) {
      context.handle(
        _sourceShaMeta,
        sourceSha.isAcceptableOrUnknown(data['source_sha']!, _sourceShaMeta),
      );
    }
    if (data.containsKey('installed')) {
      context.handle(
        _installedMeta,
        installed.isAcceptableOrUnknown(data['installed']!, _installedMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('mcp_status')) {
      context.handle(
        _mcpStatusMeta,
        mcpStatus.isAcceptableOrUnknown(data['mcp_status']!, _mcpStatusMeta),
      );
    }
    if (data.containsKey('mcp_config_json')) {
      context.handle(
        _mcpConfigJsonMeta,
        mcpConfigJson.isAcceptableOrUnknown(
          data['mcp_config_json']!,
          _mcpConfigJsonMeta,
        ),
      );
    }
    if (data.containsKey('mcp_checked_at')) {
      context.handle(
        _mcpCheckedAtMeta,
        mcpCheckedAt.isAcceptableOrUnknown(
          data['mcp_checked_at']!,
          _mcpCheckedAtMeta,
        ),
      );
    }
    if (data.containsKey('installed_config_json')) {
      context.handle(
        _installedConfigJsonMeta,
        installedConfigJson.isAcceptableOrUnknown(
          data['installed_config_json']!,
          _installedConfigJsonMeta,
        ),
      );
    }
    if (data.containsKey('needs_reconsent')) {
      context.handle(
        _needsReconsentMeta,
        needsReconsent.isAcceptableOrUnknown(
          data['needs_reconsent']!,
          _needsReconsentMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
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
  MarketplacePluginEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MarketplacePluginEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      marketplaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}marketplace_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      homepage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}homepage'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      ),
      sourceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_json'],
      )!,
      sourceKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_kind'],
      )!,
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      ),
      sourcePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_path'],
      ),
      sourceRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_ref'],
      ),
      sourceSha: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_sha'],
      ),
      installed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}installed'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      mcpStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mcp_status'],
      )!,
      mcpConfigJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mcp_config_json'],
      ),
      mcpCheckedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mcp_checked_at'],
      ),
      installedConfigJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}installed_config_json'],
      ),
      needsReconsent: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}needs_reconsent'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MarketplacePluginEntriesTable createAlias(String alias) {
    return $MarketplacePluginEntriesTable(attachedDatabase, alias);
  }
}

class MarketplacePluginEntry extends DataClass
    implements Insertable<MarketplacePluginEntry> {
  final String id;
  final String marketplaceId;
  final String name;
  final String? displayName;
  final String description;
  final String? author;
  final String? category;
  final String? homepage;
  final String? version;

  /// Raw `source` value from the marketplace manifest.
  final String sourceJson;

  /// `path`, `git-subdir`, `url`, or `command`.
  final String sourceKind;
  final String? sourceUrl;
  final String? sourcePath;
  final String? sourceRef;
  final String? sourceSha;
  final bool installed;
  final bool enabled;

  /// `unknown`, `none`, `remote`, `stdio`, `mixed`, `unsupported`, or `error`.
  final String mcpStatus;

  /// Parsed server configurations, without secrets.
  final String? mcpConfigJson;
  final int? mcpCheckedAt;

  /// Remote server configs captured at install time for change detection.
  final String? installedConfigJson;
  final bool needsReconsent;
  final String? lastError;
  final int lastSeenAt;
  final int createdAt;
  const MarketplacePluginEntry({
    required this.id,
    required this.marketplaceId,
    required this.name,
    this.displayName,
    required this.description,
    this.author,
    this.category,
    this.homepage,
    this.version,
    required this.sourceJson,
    required this.sourceKind,
    this.sourceUrl,
    this.sourcePath,
    this.sourceRef,
    this.sourceSha,
    required this.installed,
    required this.enabled,
    required this.mcpStatus,
    this.mcpConfigJson,
    this.mcpCheckedAt,
    this.installedConfigJson,
    required this.needsReconsent,
    this.lastError,
    required this.lastSeenAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['marketplace_id'] = Variable<String>(marketplaceId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || homepage != null) {
      map['homepage'] = Variable<String>(homepage);
    }
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<String>(version);
    }
    map['source_json'] = Variable<String>(sourceJson);
    map['source_kind'] = Variable<String>(sourceKind);
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    if (!nullToAbsent || sourcePath != null) {
      map['source_path'] = Variable<String>(sourcePath);
    }
    if (!nullToAbsent || sourceRef != null) {
      map['source_ref'] = Variable<String>(sourceRef);
    }
    if (!nullToAbsent || sourceSha != null) {
      map['source_sha'] = Variable<String>(sourceSha);
    }
    map['installed'] = Variable<bool>(installed);
    map['enabled'] = Variable<bool>(enabled);
    map['mcp_status'] = Variable<String>(mcpStatus);
    if (!nullToAbsent || mcpConfigJson != null) {
      map['mcp_config_json'] = Variable<String>(mcpConfigJson);
    }
    if (!nullToAbsent || mcpCheckedAt != null) {
      map['mcp_checked_at'] = Variable<int>(mcpCheckedAt);
    }
    if (!nullToAbsent || installedConfigJson != null) {
      map['installed_config_json'] = Variable<String>(installedConfigJson);
    }
    map['needs_reconsent'] = Variable<bool>(needsReconsent);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['last_seen_at'] = Variable<int>(lastSeenAt);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  MarketplacePluginEntriesCompanion toCompanion(bool nullToAbsent) {
    return MarketplacePluginEntriesCompanion(
      id: Value(id),
      marketplaceId: Value(marketplaceId),
      name: Value(name),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      description: Value(description),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      homepage: homepage == null && nullToAbsent
          ? const Value.absent()
          : Value(homepage),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      sourceJson: Value(sourceJson),
      sourceKind: Value(sourceKind),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
      sourcePath: sourcePath == null && nullToAbsent
          ? const Value.absent()
          : Value(sourcePath),
      sourceRef: sourceRef == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceRef),
      sourceSha: sourceSha == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceSha),
      installed: Value(installed),
      enabled: Value(enabled),
      mcpStatus: Value(mcpStatus),
      mcpConfigJson: mcpConfigJson == null && nullToAbsent
          ? const Value.absent()
          : Value(mcpConfigJson),
      mcpCheckedAt: mcpCheckedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(mcpCheckedAt),
      installedConfigJson: installedConfigJson == null && nullToAbsent
          ? const Value.absent()
          : Value(installedConfigJson),
      needsReconsent: Value(needsReconsent),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      lastSeenAt: Value(lastSeenAt),
      createdAt: Value(createdAt),
    );
  }

  factory MarketplacePluginEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MarketplacePluginEntry(
      id: serializer.fromJson<String>(json['id']),
      marketplaceId: serializer.fromJson<String>(json['marketplaceId']),
      name: serializer.fromJson<String>(json['name']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      description: serializer.fromJson<String>(json['description']),
      author: serializer.fromJson<String?>(json['author']),
      category: serializer.fromJson<String?>(json['category']),
      homepage: serializer.fromJson<String?>(json['homepage']),
      version: serializer.fromJson<String?>(json['version']),
      sourceJson: serializer.fromJson<String>(json['sourceJson']),
      sourceKind: serializer.fromJson<String>(json['sourceKind']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      sourcePath: serializer.fromJson<String?>(json['sourcePath']),
      sourceRef: serializer.fromJson<String?>(json['sourceRef']),
      sourceSha: serializer.fromJson<String?>(json['sourceSha']),
      installed: serializer.fromJson<bool>(json['installed']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      mcpStatus: serializer.fromJson<String>(json['mcpStatus']),
      mcpConfigJson: serializer.fromJson<String?>(json['mcpConfigJson']),
      mcpCheckedAt: serializer.fromJson<int?>(json['mcpCheckedAt']),
      installedConfigJson: serializer.fromJson<String?>(
        json['installedConfigJson'],
      ),
      needsReconsent: serializer.fromJson<bool>(json['needsReconsent']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      lastSeenAt: serializer.fromJson<int>(json['lastSeenAt']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'marketplaceId': serializer.toJson<String>(marketplaceId),
      'name': serializer.toJson<String>(name),
      'displayName': serializer.toJson<String?>(displayName),
      'description': serializer.toJson<String>(description),
      'author': serializer.toJson<String?>(author),
      'category': serializer.toJson<String?>(category),
      'homepage': serializer.toJson<String?>(homepage),
      'version': serializer.toJson<String?>(version),
      'sourceJson': serializer.toJson<String>(sourceJson),
      'sourceKind': serializer.toJson<String>(sourceKind),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'sourcePath': serializer.toJson<String?>(sourcePath),
      'sourceRef': serializer.toJson<String?>(sourceRef),
      'sourceSha': serializer.toJson<String?>(sourceSha),
      'installed': serializer.toJson<bool>(installed),
      'enabled': serializer.toJson<bool>(enabled),
      'mcpStatus': serializer.toJson<String>(mcpStatus),
      'mcpConfigJson': serializer.toJson<String?>(mcpConfigJson),
      'mcpCheckedAt': serializer.toJson<int?>(mcpCheckedAt),
      'installedConfigJson': serializer.toJson<String?>(installedConfigJson),
      'needsReconsent': serializer.toJson<bool>(needsReconsent),
      'lastError': serializer.toJson<String?>(lastError),
      'lastSeenAt': serializer.toJson<int>(lastSeenAt),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  MarketplacePluginEntry copyWith({
    String? id,
    String? marketplaceId,
    String? name,
    Value<String?> displayName = const Value.absent(),
    String? description,
    Value<String?> author = const Value.absent(),
    Value<String?> category = const Value.absent(),
    Value<String?> homepage = const Value.absent(),
    Value<String?> version = const Value.absent(),
    String? sourceJson,
    String? sourceKind,
    Value<String?> sourceUrl = const Value.absent(),
    Value<String?> sourcePath = const Value.absent(),
    Value<String?> sourceRef = const Value.absent(),
    Value<String?> sourceSha = const Value.absent(),
    bool? installed,
    bool? enabled,
    String? mcpStatus,
    Value<String?> mcpConfigJson = const Value.absent(),
    Value<int?> mcpCheckedAt = const Value.absent(),
    Value<String?> installedConfigJson = const Value.absent(),
    bool? needsReconsent,
    Value<String?> lastError = const Value.absent(),
    int? lastSeenAt,
    int? createdAt,
  }) => MarketplacePluginEntry(
    id: id ?? this.id,
    marketplaceId: marketplaceId ?? this.marketplaceId,
    name: name ?? this.name,
    displayName: displayName.present ? displayName.value : this.displayName,
    description: description ?? this.description,
    author: author.present ? author.value : this.author,
    category: category.present ? category.value : this.category,
    homepage: homepage.present ? homepage.value : this.homepage,
    version: version.present ? version.value : this.version,
    sourceJson: sourceJson ?? this.sourceJson,
    sourceKind: sourceKind ?? this.sourceKind,
    sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
    sourcePath: sourcePath.present ? sourcePath.value : this.sourcePath,
    sourceRef: sourceRef.present ? sourceRef.value : this.sourceRef,
    sourceSha: sourceSha.present ? sourceSha.value : this.sourceSha,
    installed: installed ?? this.installed,
    enabled: enabled ?? this.enabled,
    mcpStatus: mcpStatus ?? this.mcpStatus,
    mcpConfigJson: mcpConfigJson.present
        ? mcpConfigJson.value
        : this.mcpConfigJson,
    mcpCheckedAt: mcpCheckedAt.present ? mcpCheckedAt.value : this.mcpCheckedAt,
    installedConfigJson: installedConfigJson.present
        ? installedConfigJson.value
        : this.installedConfigJson,
    needsReconsent: needsReconsent ?? this.needsReconsent,
    lastError: lastError.present ? lastError.value : this.lastError,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    createdAt: createdAt ?? this.createdAt,
  );
  MarketplacePluginEntry copyWithCompanion(
    MarketplacePluginEntriesCompanion data,
  ) {
    return MarketplacePluginEntry(
      id: data.id.present ? data.id.value : this.id,
      marketplaceId: data.marketplaceId.present
          ? data.marketplaceId.value
          : this.marketplaceId,
      name: data.name.present ? data.name.value : this.name,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      description: data.description.present
          ? data.description.value
          : this.description,
      author: data.author.present ? data.author.value : this.author,
      category: data.category.present ? data.category.value : this.category,
      homepage: data.homepage.present ? data.homepage.value : this.homepage,
      version: data.version.present ? data.version.value : this.version,
      sourceJson: data.sourceJson.present
          ? data.sourceJson.value
          : this.sourceJson,
      sourceKind: data.sourceKind.present
          ? data.sourceKind.value
          : this.sourceKind,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      sourcePath: data.sourcePath.present
          ? data.sourcePath.value
          : this.sourcePath,
      sourceRef: data.sourceRef.present ? data.sourceRef.value : this.sourceRef,
      sourceSha: data.sourceSha.present ? data.sourceSha.value : this.sourceSha,
      installed: data.installed.present ? data.installed.value : this.installed,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      mcpStatus: data.mcpStatus.present ? data.mcpStatus.value : this.mcpStatus,
      mcpConfigJson: data.mcpConfigJson.present
          ? data.mcpConfigJson.value
          : this.mcpConfigJson,
      mcpCheckedAt: data.mcpCheckedAt.present
          ? data.mcpCheckedAt.value
          : this.mcpCheckedAt,
      installedConfigJson: data.installedConfigJson.present
          ? data.installedConfigJson.value
          : this.installedConfigJson,
      needsReconsent: data.needsReconsent.present
          ? data.needsReconsent.value
          : this.needsReconsent,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MarketplacePluginEntry(')
          ..write('id: $id, ')
          ..write('marketplaceId: $marketplaceId, ')
          ..write('name: $name, ')
          ..write('displayName: $displayName, ')
          ..write('description: $description, ')
          ..write('author: $author, ')
          ..write('category: $category, ')
          ..write('homepage: $homepage, ')
          ..write('version: $version, ')
          ..write('sourceJson: $sourceJson, ')
          ..write('sourceKind: $sourceKind, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('sourceRef: $sourceRef, ')
          ..write('sourceSha: $sourceSha, ')
          ..write('installed: $installed, ')
          ..write('enabled: $enabled, ')
          ..write('mcpStatus: $mcpStatus, ')
          ..write('mcpConfigJson: $mcpConfigJson, ')
          ..write('mcpCheckedAt: $mcpCheckedAt, ')
          ..write('installedConfigJson: $installedConfigJson, ')
          ..write('needsReconsent: $needsReconsent, ')
          ..write('lastError: $lastError, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    marketplaceId,
    name,
    displayName,
    description,
    author,
    category,
    homepage,
    version,
    sourceJson,
    sourceKind,
    sourceUrl,
    sourcePath,
    sourceRef,
    sourceSha,
    installed,
    enabled,
    mcpStatus,
    mcpConfigJson,
    mcpCheckedAt,
    installedConfigJson,
    needsReconsent,
    lastError,
    lastSeenAt,
    createdAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MarketplacePluginEntry &&
          other.id == this.id &&
          other.marketplaceId == this.marketplaceId &&
          other.name == this.name &&
          other.displayName == this.displayName &&
          other.description == this.description &&
          other.author == this.author &&
          other.category == this.category &&
          other.homepage == this.homepage &&
          other.version == this.version &&
          other.sourceJson == this.sourceJson &&
          other.sourceKind == this.sourceKind &&
          other.sourceUrl == this.sourceUrl &&
          other.sourcePath == this.sourcePath &&
          other.sourceRef == this.sourceRef &&
          other.sourceSha == this.sourceSha &&
          other.installed == this.installed &&
          other.enabled == this.enabled &&
          other.mcpStatus == this.mcpStatus &&
          other.mcpConfigJson == this.mcpConfigJson &&
          other.mcpCheckedAt == this.mcpCheckedAt &&
          other.installedConfigJson == this.installedConfigJson &&
          other.needsReconsent == this.needsReconsent &&
          other.lastError == this.lastError &&
          other.lastSeenAt == this.lastSeenAt &&
          other.createdAt == this.createdAt);
}

class MarketplacePluginEntriesCompanion
    extends UpdateCompanion<MarketplacePluginEntry> {
  final Value<String> id;
  final Value<String> marketplaceId;
  final Value<String> name;
  final Value<String?> displayName;
  final Value<String> description;
  final Value<String?> author;
  final Value<String?> category;
  final Value<String?> homepage;
  final Value<String?> version;
  final Value<String> sourceJson;
  final Value<String> sourceKind;
  final Value<String?> sourceUrl;
  final Value<String?> sourcePath;
  final Value<String?> sourceRef;
  final Value<String?> sourceSha;
  final Value<bool> installed;
  final Value<bool> enabled;
  final Value<String> mcpStatus;
  final Value<String?> mcpConfigJson;
  final Value<int?> mcpCheckedAt;
  final Value<String?> installedConfigJson;
  final Value<bool> needsReconsent;
  final Value<String?> lastError;
  final Value<int> lastSeenAt;
  final Value<int> createdAt;
  final Value<int> rowid;
  const MarketplacePluginEntriesCompanion({
    this.id = const Value.absent(),
    this.marketplaceId = const Value.absent(),
    this.name = const Value.absent(),
    this.displayName = const Value.absent(),
    this.description = const Value.absent(),
    this.author = const Value.absent(),
    this.category = const Value.absent(),
    this.homepage = const Value.absent(),
    this.version = const Value.absent(),
    this.sourceJson = const Value.absent(),
    this.sourceKind = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.sourcePath = const Value.absent(),
    this.sourceRef = const Value.absent(),
    this.sourceSha = const Value.absent(),
    this.installed = const Value.absent(),
    this.enabled = const Value.absent(),
    this.mcpStatus = const Value.absent(),
    this.mcpConfigJson = const Value.absent(),
    this.mcpCheckedAt = const Value.absent(),
    this.installedConfigJson = const Value.absent(),
    this.needsReconsent = const Value.absent(),
    this.lastError = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MarketplacePluginEntriesCompanion.insert({
    required String id,
    required String marketplaceId,
    required String name,
    this.displayName = const Value.absent(),
    this.description = const Value.absent(),
    this.author = const Value.absent(),
    this.category = const Value.absent(),
    this.homepage = const Value.absent(),
    this.version = const Value.absent(),
    required String sourceJson,
    required String sourceKind,
    this.sourceUrl = const Value.absent(),
    this.sourcePath = const Value.absent(),
    this.sourceRef = const Value.absent(),
    this.sourceSha = const Value.absent(),
    this.installed = const Value.absent(),
    this.enabled = const Value.absent(),
    this.mcpStatus = const Value.absent(),
    this.mcpConfigJson = const Value.absent(),
    this.mcpCheckedAt = const Value.absent(),
    this.installedConfigJson = const Value.absent(),
    this.needsReconsent = const Value.absent(),
    this.lastError = const Value.absent(),
    required int lastSeenAt,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       marketplaceId = Value(marketplaceId),
       name = Value(name),
       sourceJson = Value(sourceJson),
       sourceKind = Value(sourceKind),
       lastSeenAt = Value(lastSeenAt),
       createdAt = Value(createdAt);
  static Insertable<MarketplacePluginEntry> custom({
    Expression<String>? id,
    Expression<String>? marketplaceId,
    Expression<String>? name,
    Expression<String>? displayName,
    Expression<String>? description,
    Expression<String>? author,
    Expression<String>? category,
    Expression<String>? homepage,
    Expression<String>? version,
    Expression<String>? sourceJson,
    Expression<String>? sourceKind,
    Expression<String>? sourceUrl,
    Expression<String>? sourcePath,
    Expression<String>? sourceRef,
    Expression<String>? sourceSha,
    Expression<bool>? installed,
    Expression<bool>? enabled,
    Expression<String>? mcpStatus,
    Expression<String>? mcpConfigJson,
    Expression<int>? mcpCheckedAt,
    Expression<String>? installedConfigJson,
    Expression<bool>? needsReconsent,
    Expression<String>? lastError,
    Expression<int>? lastSeenAt,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (marketplaceId != null) 'marketplace_id': marketplaceId,
      if (name != null) 'name': name,
      if (displayName != null) 'display_name': displayName,
      if (description != null) 'description': description,
      if (author != null) 'author': author,
      if (category != null) 'category': category,
      if (homepage != null) 'homepage': homepage,
      if (version != null) 'version': version,
      if (sourceJson != null) 'source_json': sourceJson,
      if (sourceKind != null) 'source_kind': sourceKind,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (sourcePath != null) 'source_path': sourcePath,
      if (sourceRef != null) 'source_ref': sourceRef,
      if (sourceSha != null) 'source_sha': sourceSha,
      if (installed != null) 'installed': installed,
      if (enabled != null) 'enabled': enabled,
      if (mcpStatus != null) 'mcp_status': mcpStatus,
      if (mcpConfigJson != null) 'mcp_config_json': mcpConfigJson,
      if (mcpCheckedAt != null) 'mcp_checked_at': mcpCheckedAt,
      if (installedConfigJson != null)
        'installed_config_json': installedConfigJson,
      if (needsReconsent != null) 'needs_reconsent': needsReconsent,
      if (lastError != null) 'last_error': lastError,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MarketplacePluginEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? marketplaceId,
    Value<String>? name,
    Value<String?>? displayName,
    Value<String>? description,
    Value<String?>? author,
    Value<String?>? category,
    Value<String?>? homepage,
    Value<String?>? version,
    Value<String>? sourceJson,
    Value<String>? sourceKind,
    Value<String?>? sourceUrl,
    Value<String?>? sourcePath,
    Value<String?>? sourceRef,
    Value<String?>? sourceSha,
    Value<bool>? installed,
    Value<bool>? enabled,
    Value<String>? mcpStatus,
    Value<String?>? mcpConfigJson,
    Value<int?>? mcpCheckedAt,
    Value<String?>? installedConfigJson,
    Value<bool>? needsReconsent,
    Value<String?>? lastError,
    Value<int>? lastSeenAt,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return MarketplacePluginEntriesCompanion(
      id: id ?? this.id,
      marketplaceId: marketplaceId ?? this.marketplaceId,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      author: author ?? this.author,
      category: category ?? this.category,
      homepage: homepage ?? this.homepage,
      version: version ?? this.version,
      sourceJson: sourceJson ?? this.sourceJson,
      sourceKind: sourceKind ?? this.sourceKind,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourcePath: sourcePath ?? this.sourcePath,
      sourceRef: sourceRef ?? this.sourceRef,
      sourceSha: sourceSha ?? this.sourceSha,
      installed: installed ?? this.installed,
      enabled: enabled ?? this.enabled,
      mcpStatus: mcpStatus ?? this.mcpStatus,
      mcpConfigJson: mcpConfigJson ?? this.mcpConfigJson,
      mcpCheckedAt: mcpCheckedAt ?? this.mcpCheckedAt,
      installedConfigJson: installedConfigJson ?? this.installedConfigJson,
      needsReconsent: needsReconsent ?? this.needsReconsent,
      lastError: lastError ?? this.lastError,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (marketplaceId.present) {
      map['marketplace_id'] = Variable<String>(marketplaceId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (homepage.present) {
      map['homepage'] = Variable<String>(homepage.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (sourceJson.present) {
      map['source_json'] = Variable<String>(sourceJson.value);
    }
    if (sourceKind.present) {
      map['source_kind'] = Variable<String>(sourceKind.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (sourcePath.present) {
      map['source_path'] = Variable<String>(sourcePath.value);
    }
    if (sourceRef.present) {
      map['source_ref'] = Variable<String>(sourceRef.value);
    }
    if (sourceSha.present) {
      map['source_sha'] = Variable<String>(sourceSha.value);
    }
    if (installed.present) {
      map['installed'] = Variable<bool>(installed.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (mcpStatus.present) {
      map['mcp_status'] = Variable<String>(mcpStatus.value);
    }
    if (mcpConfigJson.present) {
      map['mcp_config_json'] = Variable<String>(mcpConfigJson.value);
    }
    if (mcpCheckedAt.present) {
      map['mcp_checked_at'] = Variable<int>(mcpCheckedAt.value);
    }
    if (installedConfigJson.present) {
      map['installed_config_json'] = Variable<String>(
        installedConfigJson.value,
      );
    }
    if (needsReconsent.present) {
      map['needs_reconsent'] = Variable<bool>(needsReconsent.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<int>(lastSeenAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MarketplacePluginEntriesCompanion(')
          ..write('id: $id, ')
          ..write('marketplaceId: $marketplaceId, ')
          ..write('name: $name, ')
          ..write('displayName: $displayName, ')
          ..write('description: $description, ')
          ..write('author: $author, ')
          ..write('category: $category, ')
          ..write('homepage: $homepage, ')
          ..write('version: $version, ')
          ..write('sourceJson: $sourceJson, ')
          ..write('sourceKind: $sourceKind, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('sourceRef: $sourceRef, ')
          ..write('sourceSha: $sourceSha, ')
          ..write('installed: $installed, ')
          ..write('enabled: $enabled, ')
          ..write('mcpStatus: $mcpStatus, ')
          ..write('mcpConfigJson: $mcpConfigJson, ')
          ..write('mcpCheckedAt: $mcpCheckedAt, ')
          ..write('installedConfigJson: $installedConfigJson, ')
          ..write('needsReconsent: $needsReconsent, ')
          ..write('lastError: $lastError, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $McpServerEntriesTable extends McpServerEntries
    with TableInfo<$McpServerEntriesTable, McpServerEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $McpServerEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pluginIdMeta = const VerificationMeta(
    'pluginId',
  );
  @override
  late final GeneratedColumn<String> pluginId = GeneratedColumn<String>(
    'plugin_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES marketplace_plugins (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _marketplaceIdMeta = const VerificationMeta(
    'marketplaceId',
  );
  @override
  late final GeneratedColumn<String> marketplaceId = GeneratedColumn<String>(
    'marketplace_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transportMeta = const VerificationMeta(
    'transport',
  );
  @override
  late final GeneratedColumn<String> transport = GeneratedColumn<String>(
    'transport',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authTypeMeta = const VerificationMeta(
    'authType',
  );
  @override
  late final GeneratedColumn<String> authType = GeneratedColumn<String>(
    'auth_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _headerNamesJsonMeta = const VerificationMeta(
    'headerNamesJson',
  );
  @override
  late final GeneratedColumn<String> headerNamesJson = GeneratedColumn<String>(
    'header_names_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _configHashMeta = const VerificationMeta(
    'configHash',
  );
  @override
  late final GeneratedColumn<String> configHash = GeneratedColumn<String>(
    'config_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _needsReconsentMeta = const VerificationMeta(
    'needsReconsent',
  );
  @override
  late final GeneratedColumn<bool> needsReconsent = GeneratedColumn<bool>(
    'needs_reconsent',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("needs_reconsent" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    pluginId,
    marketplaceId,
    name,
    url,
    transport,
    authType,
    headerNamesJson,
    configHash,
    enabled,
    needsReconsent,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mcp_servers';
  @override
  VerificationContext validateIntegrity(
    Insertable<McpServerEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('plugin_id')) {
      context.handle(
        _pluginIdMeta,
        pluginId.isAcceptableOrUnknown(data['plugin_id']!, _pluginIdMeta),
      );
    }
    if (data.containsKey('marketplace_id')) {
      context.handle(
        _marketplaceIdMeta,
        marketplaceId.isAcceptableOrUnknown(
          data['marketplace_id']!,
          _marketplaceIdMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('transport')) {
      context.handle(
        _transportMeta,
        transport.isAcceptableOrUnknown(data['transport']!, _transportMeta),
      );
    } else if (isInserting) {
      context.missing(_transportMeta);
    }
    if (data.containsKey('auth_type')) {
      context.handle(
        _authTypeMeta,
        authType.isAcceptableOrUnknown(data['auth_type']!, _authTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_authTypeMeta);
    }
    if (data.containsKey('header_names_json')) {
      context.handle(
        _headerNamesJsonMeta,
        headerNamesJson.isAcceptableOrUnknown(
          data['header_names_json']!,
          _headerNamesJsonMeta,
        ),
      );
    }
    if (data.containsKey('config_hash')) {
      context.handle(
        _configHashMeta,
        configHash.isAcceptableOrUnknown(data['config_hash']!, _configHashMeta),
      );
    } else if (isInserting) {
      context.missing(_configHashMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('needs_reconsent')) {
      context.handle(
        _needsReconsentMeta,
        needsReconsent.isAcceptableOrUnknown(
          data['needs_reconsent']!,
          _needsReconsentMeta,
        ),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  McpServerEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return McpServerEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      pluginId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plugin_id'],
      ),
      marketplaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}marketplace_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      transport: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transport'],
      )!,
      authType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}auth_type'],
      )!,
      headerNamesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}header_names_json'],
      ),
      configHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_hash'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      needsReconsent: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}needs_reconsent'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $McpServerEntriesTable createAlias(String alias) {
    return $McpServerEntriesTable(attachedDatabase, alias);
  }
}

class McpServerEntry extends DataClass implements Insertable<McpServerEntry> {
  final String id;
  final String? pluginId;
  final String? marketplaceId;
  final String name;
  final String url;

  /// `http` or `sse`.
  final String transport;

  /// `oauth`, `api-key`, `none`, or `unknown`.
  final String authType;

  /// JSON array of header names that require values.
  final String? headerNamesJson;
  final String configHash;
  final bool enabled;
  final bool needsReconsent;
  final int createdAt;
  const McpServerEntry({
    required this.id,
    this.pluginId,
    this.marketplaceId,
    required this.name,
    required this.url,
    required this.transport,
    required this.authType,
    this.headerNamesJson,
    required this.configHash,
    required this.enabled,
    required this.needsReconsent,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || pluginId != null) {
      map['plugin_id'] = Variable<String>(pluginId);
    }
    if (!nullToAbsent || marketplaceId != null) {
      map['marketplace_id'] = Variable<String>(marketplaceId);
    }
    map['name'] = Variable<String>(name);
    map['url'] = Variable<String>(url);
    map['transport'] = Variable<String>(transport);
    map['auth_type'] = Variable<String>(authType);
    if (!nullToAbsent || headerNamesJson != null) {
      map['header_names_json'] = Variable<String>(headerNamesJson);
    }
    map['config_hash'] = Variable<String>(configHash);
    map['enabled'] = Variable<bool>(enabled);
    map['needs_reconsent'] = Variable<bool>(needsReconsent);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  McpServerEntriesCompanion toCompanion(bool nullToAbsent) {
    return McpServerEntriesCompanion(
      id: Value(id),
      pluginId: pluginId == null && nullToAbsent
          ? const Value.absent()
          : Value(pluginId),
      marketplaceId: marketplaceId == null && nullToAbsent
          ? const Value.absent()
          : Value(marketplaceId),
      name: Value(name),
      url: Value(url),
      transport: Value(transport),
      authType: Value(authType),
      headerNamesJson: headerNamesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(headerNamesJson),
      configHash: Value(configHash),
      enabled: Value(enabled),
      needsReconsent: Value(needsReconsent),
      createdAt: Value(createdAt),
    );
  }

  factory McpServerEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return McpServerEntry(
      id: serializer.fromJson<String>(json['id']),
      pluginId: serializer.fromJson<String?>(json['pluginId']),
      marketplaceId: serializer.fromJson<String?>(json['marketplaceId']),
      name: serializer.fromJson<String>(json['name']),
      url: serializer.fromJson<String>(json['url']),
      transport: serializer.fromJson<String>(json['transport']),
      authType: serializer.fromJson<String>(json['authType']),
      headerNamesJson: serializer.fromJson<String?>(json['headerNamesJson']),
      configHash: serializer.fromJson<String>(json['configHash']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      needsReconsent: serializer.fromJson<bool>(json['needsReconsent']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'pluginId': serializer.toJson<String?>(pluginId),
      'marketplaceId': serializer.toJson<String?>(marketplaceId),
      'name': serializer.toJson<String>(name),
      'url': serializer.toJson<String>(url),
      'transport': serializer.toJson<String>(transport),
      'authType': serializer.toJson<String>(authType),
      'headerNamesJson': serializer.toJson<String?>(headerNamesJson),
      'configHash': serializer.toJson<String>(configHash),
      'enabled': serializer.toJson<bool>(enabled),
      'needsReconsent': serializer.toJson<bool>(needsReconsent),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  McpServerEntry copyWith({
    String? id,
    Value<String?> pluginId = const Value.absent(),
    Value<String?> marketplaceId = const Value.absent(),
    String? name,
    String? url,
    String? transport,
    String? authType,
    Value<String?> headerNamesJson = const Value.absent(),
    String? configHash,
    bool? enabled,
    bool? needsReconsent,
    int? createdAt,
  }) => McpServerEntry(
    id: id ?? this.id,
    pluginId: pluginId.present ? pluginId.value : this.pluginId,
    marketplaceId: marketplaceId.present
        ? marketplaceId.value
        : this.marketplaceId,
    name: name ?? this.name,
    url: url ?? this.url,
    transport: transport ?? this.transport,
    authType: authType ?? this.authType,
    headerNamesJson: headerNamesJson.present
        ? headerNamesJson.value
        : this.headerNamesJson,
    configHash: configHash ?? this.configHash,
    enabled: enabled ?? this.enabled,
    needsReconsent: needsReconsent ?? this.needsReconsent,
    createdAt: createdAt ?? this.createdAt,
  );
  McpServerEntry copyWithCompanion(McpServerEntriesCompanion data) {
    return McpServerEntry(
      id: data.id.present ? data.id.value : this.id,
      pluginId: data.pluginId.present ? data.pluginId.value : this.pluginId,
      marketplaceId: data.marketplaceId.present
          ? data.marketplaceId.value
          : this.marketplaceId,
      name: data.name.present ? data.name.value : this.name,
      url: data.url.present ? data.url.value : this.url,
      transport: data.transport.present ? data.transport.value : this.transport,
      authType: data.authType.present ? data.authType.value : this.authType,
      headerNamesJson: data.headerNamesJson.present
          ? data.headerNamesJson.value
          : this.headerNamesJson,
      configHash: data.configHash.present
          ? data.configHash.value
          : this.configHash,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      needsReconsent: data.needsReconsent.present
          ? data.needsReconsent.value
          : this.needsReconsent,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('McpServerEntry(')
          ..write('id: $id, ')
          ..write('pluginId: $pluginId, ')
          ..write('marketplaceId: $marketplaceId, ')
          ..write('name: $name, ')
          ..write('url: $url, ')
          ..write('transport: $transport, ')
          ..write('authType: $authType, ')
          ..write('headerNamesJson: $headerNamesJson, ')
          ..write('configHash: $configHash, ')
          ..write('enabled: $enabled, ')
          ..write('needsReconsent: $needsReconsent, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    pluginId,
    marketplaceId,
    name,
    url,
    transport,
    authType,
    headerNamesJson,
    configHash,
    enabled,
    needsReconsent,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is McpServerEntry &&
          other.id == this.id &&
          other.pluginId == this.pluginId &&
          other.marketplaceId == this.marketplaceId &&
          other.name == this.name &&
          other.url == this.url &&
          other.transport == this.transport &&
          other.authType == this.authType &&
          other.headerNamesJson == this.headerNamesJson &&
          other.configHash == this.configHash &&
          other.enabled == this.enabled &&
          other.needsReconsent == this.needsReconsent &&
          other.createdAt == this.createdAt);
}

class McpServerEntriesCompanion extends UpdateCompanion<McpServerEntry> {
  final Value<String> id;
  final Value<String?> pluginId;
  final Value<String?> marketplaceId;
  final Value<String> name;
  final Value<String> url;
  final Value<String> transport;
  final Value<String> authType;
  final Value<String?> headerNamesJson;
  final Value<String> configHash;
  final Value<bool> enabled;
  final Value<bool> needsReconsent;
  final Value<int> createdAt;
  final Value<int> rowid;
  const McpServerEntriesCompanion({
    this.id = const Value.absent(),
    this.pluginId = const Value.absent(),
    this.marketplaceId = const Value.absent(),
    this.name = const Value.absent(),
    this.url = const Value.absent(),
    this.transport = const Value.absent(),
    this.authType = const Value.absent(),
    this.headerNamesJson = const Value.absent(),
    this.configHash = const Value.absent(),
    this.enabled = const Value.absent(),
    this.needsReconsent = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  McpServerEntriesCompanion.insert({
    required String id,
    this.pluginId = const Value.absent(),
    this.marketplaceId = const Value.absent(),
    required String name,
    required String url,
    required String transport,
    required String authType,
    this.headerNamesJson = const Value.absent(),
    required String configHash,
    this.enabled = const Value.absent(),
    this.needsReconsent = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       url = Value(url),
       transport = Value(transport),
       authType = Value(authType),
       configHash = Value(configHash),
       createdAt = Value(createdAt);
  static Insertable<McpServerEntry> custom({
    Expression<String>? id,
    Expression<String>? pluginId,
    Expression<String>? marketplaceId,
    Expression<String>? name,
    Expression<String>? url,
    Expression<String>? transport,
    Expression<String>? authType,
    Expression<String>? headerNamesJson,
    Expression<String>? configHash,
    Expression<bool>? enabled,
    Expression<bool>? needsReconsent,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pluginId != null) 'plugin_id': pluginId,
      if (marketplaceId != null) 'marketplace_id': marketplaceId,
      if (name != null) 'name': name,
      if (url != null) 'url': url,
      if (transport != null) 'transport': transport,
      if (authType != null) 'auth_type': authType,
      if (headerNamesJson != null) 'header_names_json': headerNamesJson,
      if (configHash != null) 'config_hash': configHash,
      if (enabled != null) 'enabled': enabled,
      if (needsReconsent != null) 'needs_reconsent': needsReconsent,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  McpServerEntriesCompanion copyWith({
    Value<String>? id,
    Value<String?>? pluginId,
    Value<String?>? marketplaceId,
    Value<String>? name,
    Value<String>? url,
    Value<String>? transport,
    Value<String>? authType,
    Value<String?>? headerNamesJson,
    Value<String>? configHash,
    Value<bool>? enabled,
    Value<bool>? needsReconsent,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return McpServerEntriesCompanion(
      id: id ?? this.id,
      pluginId: pluginId ?? this.pluginId,
      marketplaceId: marketplaceId ?? this.marketplaceId,
      name: name ?? this.name,
      url: url ?? this.url,
      transport: transport ?? this.transport,
      authType: authType ?? this.authType,
      headerNamesJson: headerNamesJson ?? this.headerNamesJson,
      configHash: configHash ?? this.configHash,
      enabled: enabled ?? this.enabled,
      needsReconsent: needsReconsent ?? this.needsReconsent,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (pluginId.present) {
      map['plugin_id'] = Variable<String>(pluginId.value);
    }
    if (marketplaceId.present) {
      map['marketplace_id'] = Variable<String>(marketplaceId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (transport.present) {
      map['transport'] = Variable<String>(transport.value);
    }
    if (authType.present) {
      map['auth_type'] = Variable<String>(authType.value);
    }
    if (headerNamesJson.present) {
      map['header_names_json'] = Variable<String>(headerNamesJson.value);
    }
    if (configHash.present) {
      map['config_hash'] = Variable<String>(configHash.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (needsReconsent.present) {
      map['needs_reconsent'] = Variable<bool>(needsReconsent.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('McpServerEntriesCompanion(')
          ..write('id: $id, ')
          ..write('pluginId: $pluginId, ')
          ..write('marketplaceId: $marketplaceId, ')
          ..write('name: $name, ')
          ..write('url: $url, ')
          ..write('transport: $transport, ')
          ..write('authType: $authType, ')
          ..write('headerNamesJson: $headerNamesJson, ')
          ..write('configHash: $configHash, ')
          ..write('enabled: $enabled, ')
          ..write('needsReconsent: $needsReconsent, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $McpToolEntriesTable extends McpToolEntries
    with TableInfo<$McpToolEntriesTable, McpToolEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $McpToolEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES mcp_servers (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _schemaJsonMeta = const VerificationMeta(
    'schemaJson',
  );
  @override
  late final GeneratedColumn<String> schemaJson = GeneratedColumn<String>(
    'schema_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _needsApprovalMeta = const VerificationMeta(
    'needsApproval',
  );
  @override
  late final GeneratedColumn<bool> needsApproval = GeneratedColumn<bool>(
    'needs_approval',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("needs_approval" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _discoveredAtMeta = const VerificationMeta(
    'discoveredAt',
  );
  @override
  late final GeneratedColumn<int> discoveredAt = GeneratedColumn<int>(
    'discovered_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    name,
    description,
    schemaJson,
    needsApproval,
    discoveredAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mcp_tools';
  @override
  VerificationContext validateIntegrity(
    Insertable<McpToolEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('schema_json')) {
      context.handle(
        _schemaJsonMeta,
        schemaJson.isAcceptableOrUnknown(data['schema_json']!, _schemaJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_schemaJsonMeta);
    }
    if (data.containsKey('needs_approval')) {
      context.handle(
        _needsApprovalMeta,
        needsApproval.isAcceptableOrUnknown(
          data['needs_approval']!,
          _needsApprovalMeta,
        ),
      );
    }
    if (data.containsKey('discovered_at')) {
      context.handle(
        _discoveredAtMeta,
        discoveredAt.isAcceptableOrUnknown(
          data['discovered_at']!,
          _discoveredAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_discoveredAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  McpToolEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return McpToolEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      schemaJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schema_json'],
      )!,
      needsApproval: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}needs_approval'],
      )!,
      discoveredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}discovered_at'],
      )!,
    );
  }

  @override
  $McpToolEntriesTable createAlias(String alias) {
    return $McpToolEntriesTable(attachedDatabase, alias);
  }
}

class McpToolEntry extends DataClass implements Insertable<McpToolEntry> {
  final String id;
  final String serverId;
  final String name;
  final String description;
  final String schemaJson;
  final bool needsApproval;
  final int discoveredAt;
  const McpToolEntry({
    required this.id,
    required this.serverId,
    required this.name,
    required this.description,
    required this.schemaJson,
    required this.needsApproval,
    required this.discoveredAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['server_id'] = Variable<String>(serverId);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['schema_json'] = Variable<String>(schemaJson);
    map['needs_approval'] = Variable<bool>(needsApproval);
    map['discovered_at'] = Variable<int>(discoveredAt);
    return map;
  }

  McpToolEntriesCompanion toCompanion(bool nullToAbsent) {
    return McpToolEntriesCompanion(
      id: Value(id),
      serverId: Value(serverId),
      name: Value(name),
      description: Value(description),
      schemaJson: Value(schemaJson),
      needsApproval: Value(needsApproval),
      discoveredAt: Value(discoveredAt),
    );
  }

  factory McpToolEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return McpToolEntry(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<String>(json['serverId']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      schemaJson: serializer.fromJson<String>(json['schemaJson']),
      needsApproval: serializer.fromJson<bool>(json['needsApproval']),
      discoveredAt: serializer.fromJson<int>(json['discoveredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<String>(serverId),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'schemaJson': serializer.toJson<String>(schemaJson),
      'needsApproval': serializer.toJson<bool>(needsApproval),
      'discoveredAt': serializer.toJson<int>(discoveredAt),
    };
  }

  McpToolEntry copyWith({
    String? id,
    String? serverId,
    String? name,
    String? description,
    String? schemaJson,
    bool? needsApproval,
    int? discoveredAt,
  }) => McpToolEntry(
    id: id ?? this.id,
    serverId: serverId ?? this.serverId,
    name: name ?? this.name,
    description: description ?? this.description,
    schemaJson: schemaJson ?? this.schemaJson,
    needsApproval: needsApproval ?? this.needsApproval,
    discoveredAt: discoveredAt ?? this.discoveredAt,
  );
  McpToolEntry copyWithCompanion(McpToolEntriesCompanion data) {
    return McpToolEntry(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      schemaJson: data.schemaJson.present
          ? data.schemaJson.value
          : this.schemaJson,
      needsApproval: data.needsApproval.present
          ? data.needsApproval.value
          : this.needsApproval,
      discoveredAt: data.discoveredAt.present
          ? data.discoveredAt.value
          : this.discoveredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('McpToolEntry(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('schemaJson: $schemaJson, ')
          ..write('needsApproval: $needsApproval, ')
          ..write('discoveredAt: $discoveredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    name,
    description,
    schemaJson,
    needsApproval,
    discoveredAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is McpToolEntry &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.name == this.name &&
          other.description == this.description &&
          other.schemaJson == this.schemaJson &&
          other.needsApproval == this.needsApproval &&
          other.discoveredAt == this.discoveredAt);
}

class McpToolEntriesCompanion extends UpdateCompanion<McpToolEntry> {
  final Value<String> id;
  final Value<String> serverId;
  final Value<String> name;
  final Value<String> description;
  final Value<String> schemaJson;
  final Value<bool> needsApproval;
  final Value<int> discoveredAt;
  final Value<int> rowid;
  const McpToolEntriesCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.schemaJson = const Value.absent(),
    this.needsApproval = const Value.absent(),
    this.discoveredAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  McpToolEntriesCompanion.insert({
    required String id,
    required String serverId,
    required String name,
    this.description = const Value.absent(),
    required String schemaJson,
    this.needsApproval = const Value.absent(),
    required int discoveredAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       serverId = Value(serverId),
       name = Value(name),
       schemaJson = Value(schemaJson),
       discoveredAt = Value(discoveredAt);
  static Insertable<McpToolEntry> custom({
    Expression<String>? id,
    Expression<String>? serverId,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? schemaJson,
    Expression<bool>? needsApproval,
    Expression<int>? discoveredAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (schemaJson != null) 'schema_json': schemaJson,
      if (needsApproval != null) 'needs_approval': needsApproval,
      if (discoveredAt != null) 'discovered_at': discoveredAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  McpToolEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? serverId,
    Value<String>? name,
    Value<String>? description,
    Value<String>? schemaJson,
    Value<bool>? needsApproval,
    Value<int>? discoveredAt,
    Value<int>? rowid,
  }) {
    return McpToolEntriesCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      description: description ?? this.description,
      schemaJson: schemaJson ?? this.schemaJson,
      needsApproval: needsApproval ?? this.needsApproval,
      discoveredAt: discoveredAt ?? this.discoveredAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (schemaJson.present) {
      map['schema_json'] = Variable<String>(schemaJson.value);
    }
    if (needsApproval.present) {
      map['needs_approval'] = Variable<bool>(needsApproval.value);
    }
    if (discoveredAt.present) {
      map['discovered_at'] = Variable<int>(discoveredAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('McpToolEntriesCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('schemaJson: $schemaJson, ')
          ..write('needsApproval: $needsApproval, ')
          ..write('discoveredAt: $discoveredAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OpenCodeConnectionEntriesTable extends OpenCodeConnectionEntries
    with TableInfo<$OpenCodeConnectionEntriesTable, OpenCodeConnectionEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OpenCodeConnectionEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('opencode'),
  );
  static const VerificationMeta _tokenRefMeta = const VerificationMeta(
    'tokenRef',
  );
  @override
  late final GeneratedColumn<String> tokenRef = GeneratedColumn<String>(
    'token_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<int> lastSeen = GeneratedColumn<int>(
    'last_seen',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    baseUrl,
    username,
    tokenRef,
    lastSeen,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'opencode_connections';
  @override
  VerificationContext validateIntegrity(
    Insertable<OpenCodeConnectionEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    }
    if (data.containsKey('token_ref')) {
      context.handle(
        _tokenRefMeta,
        tokenRef.isAcceptableOrUnknown(data['token_ref']!, _tokenRefMeta),
      );
    } else if (isInserting) {
      context.missing(_tokenRefMeta);
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OpenCodeConnectionEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OpenCodeConnectionEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      )!,
      tokenRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}token_ref'],
      )!,
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OpenCodeConnectionEntriesTable createAlias(String alias) {
    return $OpenCodeConnectionEntriesTable(attachedDatabase, alias);
  }
}

class OpenCodeConnectionEntry extends DataClass
    implements Insertable<OpenCodeConnectionEntry> {
  final String id;
  final String name;
  final String baseUrl;
  final String username;
  final String tokenRef;
  final int? lastSeen;
  final int createdAt;
  const OpenCodeConnectionEntry({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.username,
    required this.tokenRef,
    this.lastSeen,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['base_url'] = Variable<String>(baseUrl);
    map['username'] = Variable<String>(username);
    map['token_ref'] = Variable<String>(tokenRef);
    if (!nullToAbsent || lastSeen != null) {
      map['last_seen'] = Variable<int>(lastSeen);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  OpenCodeConnectionEntriesCompanion toCompanion(bool nullToAbsent) {
    return OpenCodeConnectionEntriesCompanion(
      id: Value(id),
      name: Value(name),
      baseUrl: Value(baseUrl),
      username: Value(username),
      tokenRef: Value(tokenRef),
      lastSeen: lastSeen == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeen),
      createdAt: Value(createdAt),
    );
  }

  factory OpenCodeConnectionEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OpenCodeConnectionEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      username: serializer.fromJson<String>(json['username']),
      tokenRef: serializer.fromJson<String>(json['tokenRef']),
      lastSeen: serializer.fromJson<int?>(json['lastSeen']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'username': serializer.toJson<String>(username),
      'tokenRef': serializer.toJson<String>(tokenRef),
      'lastSeen': serializer.toJson<int?>(lastSeen),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  OpenCodeConnectionEntry copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? username,
    String? tokenRef,
    Value<int?> lastSeen = const Value.absent(),
    int? createdAt,
  }) => OpenCodeConnectionEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    baseUrl: baseUrl ?? this.baseUrl,
    username: username ?? this.username,
    tokenRef: tokenRef ?? this.tokenRef,
    lastSeen: lastSeen.present ? lastSeen.value : this.lastSeen,
    createdAt: createdAt ?? this.createdAt,
  );
  OpenCodeConnectionEntry copyWithCompanion(
    OpenCodeConnectionEntriesCompanion data,
  ) {
    return OpenCodeConnectionEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      username: data.username.present ? data.username.value : this.username,
      tokenRef: data.tokenRef.present ? data.tokenRef.value : this.tokenRef,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OpenCodeConnectionEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('username: $username, ')
          ..write('tokenRef: $tokenRef, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, baseUrl, username, tokenRef, lastSeen, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OpenCodeConnectionEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.baseUrl == this.baseUrl &&
          other.username == this.username &&
          other.tokenRef == this.tokenRef &&
          other.lastSeen == this.lastSeen &&
          other.createdAt == this.createdAt);
}

class OpenCodeConnectionEntriesCompanion
    extends UpdateCompanion<OpenCodeConnectionEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> baseUrl;
  final Value<String> username;
  final Value<String> tokenRef;
  final Value<int?> lastSeen;
  final Value<int> createdAt;
  final Value<int> rowid;
  const OpenCodeConnectionEntriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.username = const Value.absent(),
    this.tokenRef = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OpenCodeConnectionEntriesCompanion.insert({
    required String id,
    required String name,
    required String baseUrl,
    this.username = const Value.absent(),
    required String tokenRef,
    this.lastSeen = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       baseUrl = Value(baseUrl),
       tokenRef = Value(tokenRef),
       createdAt = Value(createdAt);
  static Insertable<OpenCodeConnectionEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? baseUrl,
    Expression<String>? username,
    Expression<String>? tokenRef,
    Expression<int>? lastSeen,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (baseUrl != null) 'base_url': baseUrl,
      if (username != null) 'username': username,
      if (tokenRef != null) 'token_ref': tokenRef,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OpenCodeConnectionEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? baseUrl,
    Value<String>? username,
    Value<String>? tokenRef,
    Value<int?>? lastSeen,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return OpenCodeConnectionEntriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      username: username ?? this.username,
      tokenRef: tokenRef ?? this.tokenRef,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
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
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (tokenRef.present) {
      map['token_ref'] = Variable<String>(tokenRef.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<int>(lastSeen.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OpenCodeConnectionEntriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('username: $username, ')
          ..write('tokenRef: $tokenRef, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SettingEntriesTable settingEntries = $SettingEntriesTable(this);
  late final $ProviderEntriesTable providerEntries = $ProviderEntriesTable(
    this,
  );
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $MarketplaceEntriesTable marketplaceEntries =
      $MarketplaceEntriesTable(this);
  late final $MarketplacePluginEntriesTable marketplacePluginEntries =
      $MarketplacePluginEntriesTable(this);
  late final $McpServerEntriesTable mcpServerEntries = $McpServerEntriesTable(
    this,
  );
  late final $McpToolEntriesTable mcpToolEntries = $McpToolEntriesTable(this);
  late final $OpenCodeConnectionEntriesTable openCodeConnectionEntries =
      $OpenCodeConnectionEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    settingEntries,
    providerEntries,
    conversations,
    messages,
    marketplaceEntries,
    marketplacePluginEntries,
    mcpServerEntries,
    mcpToolEntries,
    openCodeConnectionEntries,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'providers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('conversations', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'conversations',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('messages', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'marketplaces',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('marketplace_plugins', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'marketplace_plugins',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('mcp_servers', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'mcp_servers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('mcp_tools', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$SettingEntriesTableCreateCompanionBuilder =
    SettingEntriesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingEntriesTableUpdateCompanionBuilder =
    SettingEntriesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SettingEntriesTable> {
  $$SettingEntriesTableFilterComposer({
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

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingEntriesTable> {
  $$SettingEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingEntriesTable> {
  $$SettingEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingEntriesTable,
          SettingEntry,
          $$SettingEntriesTableFilterComposer,
          $$SettingEntriesTableOrderingComposer,
          $$SettingEntriesTableAnnotationComposer,
          $$SettingEntriesTableCreateCompanionBuilder,
          $$SettingEntriesTableUpdateCompanionBuilder,
          (
            SettingEntry,
            BaseReferences<_$AppDatabase, $SettingEntriesTable, SettingEntry>,
          ),
          SettingEntry,
          PrefetchHooks Function()
        > {
  $$SettingEntriesTableTableManager(
    _$AppDatabase db,
    $SettingEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingEntriesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingEntriesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingEntriesTable, SettingEntry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SettingEntriesTable,
                    SettingEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingEntriesTable,
      SettingEntry,
      $$SettingEntriesTableFilterComposer,
      $$SettingEntriesTableOrderingComposer,
      $$SettingEntriesTableAnnotationComposer,
      $$SettingEntriesTableCreateCompanionBuilder,
      $$SettingEntriesTableUpdateCompanionBuilder,
      (
        SettingEntry,
        BaseReferences<_$AppDatabase, $SettingEntriesTable, SettingEntry>,
      ),
      SettingEntry,
      PrefetchHooks Function()
    >;
typedef $$ProviderEntriesTableCreateCompanionBuilder =
    ProviderEntriesCompanion Function({
      required String id,
      required String name,
      required String type,
      required String baseUrl,
      required String model,
      required String apiKeyRef,
      Value<String> authMethod,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$ProviderEntriesTableUpdateCompanionBuilder =
    ProviderEntriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> type,
      Value<String> baseUrl,
      Value<String> model,
      Value<String> apiKeyRef,
      Value<String> authMethod,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$ProviderEntriesTableReferences
    extends
        BaseReferences<_$AppDatabase, $ProviderEntriesTable, ProviderEntry> {
  $$ProviderEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$ConversationsTable, List<Conversation>>
  _conversationsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.conversations,
    aliasName: 'providers__id__conversations__provider_id',
  );

  $$ConversationsTableProcessedTableManager get conversationsRefs {
    final manager = $$ConversationsTableTableManager(
      $_db,
      $_db.conversations,
    ).filter((f) => f.providerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_conversationsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProviderEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ProviderEntriesTable> {
  $$ProviderEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get apiKeyRef => $composableBuilder(
    column: $table.apiKeyRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authMethod => $composableBuilder(
    column: $table.authMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> conversationsRefs(
    Expression<bool> Function($$ConversationsTableFilterComposer f) f,
  ) {
    final $$ConversationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.providerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableFilterComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProviderEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProviderEntriesTable> {
  $$ProviderEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get apiKeyRef => $composableBuilder(
    column: $table.apiKeyRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authMethod => $composableBuilder(
    column: $table.authMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProviderEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProviderEntriesTable> {
  $$ProviderEntriesTableAnnotationComposer({
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

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get apiKeyRef =>
      $composableBuilder(column: $table.apiKeyRef, builder: (column) => column);

  GeneratedColumn<String> get authMethod => $composableBuilder(
    column: $table.authMethod,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> conversationsRefs<T extends Object>(
    Expression<T> Function($$ConversationsTableAnnotationComposer a) f,
  ) {
    final $$ConversationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.providerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableAnnotationComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProviderEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProviderEntriesTable,
          ProviderEntry,
          $$ProviderEntriesTableFilterComposer,
          $$ProviderEntriesTableOrderingComposer,
          $$ProviderEntriesTableAnnotationComposer,
          $$ProviderEntriesTableCreateCompanionBuilder,
          $$ProviderEntriesTableUpdateCompanionBuilder,
          (ProviderEntry, $$ProviderEntriesTableReferences),
          ProviderEntry,
          PrefetchHooks Function({bool conversationsRefs})
        > {
  $$ProviderEntriesTableTableManager(
    _$AppDatabase db,
    $ProviderEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProviderEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProviderEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProviderEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<String> apiKeyRef = const Value.absent(),
                Value<String> authMethod = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderEntriesCompanion(
                id: id,
                name: name,
                type: type,
                baseUrl: baseUrl,
                model: model,
                apiKeyRef: apiKeyRef,
                authMethod: authMethod,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String type,
                required String baseUrl,
                required String model,
                required String apiKeyRef,
                Value<String> authMethod = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ProviderEntriesCompanion.insert(
                id: id,
                name: name,
                type: type,
                baseUrl: baseUrl,
                model: model,
                apiKeyRef: apiKeyRef,
                authMethod: authMethod,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProviderEntriesTable, ProviderEntry>(table),
                  $$ProviderEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({conversationsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (conversationsRefs) db.conversations,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (conversationsRefs)
                    await $_getPrefetchedDataByColumns<
                      ProviderEntry,
                      $ProviderEntriesTable,
                      Conversation,
                      $ConversationsTable
                    >(
                      currentTable: table,
                      referencedTable: $$ProviderEntriesTableReferences
                          ._conversationsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ProviderEntriesTableReferences(
                            db,
                            table,
                            p0,
                          ).conversationsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'provider_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ProviderEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProviderEntriesTable,
      ProviderEntry,
      $$ProviderEntriesTableFilterComposer,
      $$ProviderEntriesTableOrderingComposer,
      $$ProviderEntriesTableAnnotationComposer,
      $$ProviderEntriesTableCreateCompanionBuilder,
      $$ProviderEntriesTableUpdateCompanionBuilder,
      (ProviderEntry, $$ProviderEntriesTableReferences),
      ProviderEntry,
      PrefetchHooks Function({bool conversationsRefs})
    >;
typedef $$ConversationsTableCreateCompanionBuilder =
    ConversationsCompanion Function({
      required String id,
      Value<String> title,
      Value<String?> providerId,
      Value<String?> model,
      Value<String?> systemPrompt,
      Value<bool> archived,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$ConversationsTableUpdateCompanionBuilder =
    ConversationsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> providerId,
      Value<String?> model,
      Value<String?> systemPrompt,
      Value<bool> archived,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$ConversationsTableReferences
    extends BaseReferences<_$AppDatabase, $ConversationsTable, Conversation> {
  $$ConversationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProviderEntriesTable _providerIdTable(_$AppDatabase db) => db
      .providerEntries
      .createAlias('conversations__provider_id__providers__id');

  $$ProviderEntriesTableProcessedTableManager? get providerId {
    final $_column = $_itemColumn<String>('provider_id');
    if ($_column == null) return null;
    final manager = $$ProviderEntriesTableTableManager(
      $_db,
      $_db.providerEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_providerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MessagesTable, List<Message>> _messagesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.messages,
    aliasName: 'conversations__id__messages__conversation_id',
  );

  $$MessagesTableProcessedTableManager get messagesRefs {
    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.conversationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_messagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProviderEntriesTableFilterComposer get providerId {
    final $$ProviderEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.providerId,
      referencedTable: $db.providerEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProviderEntriesTableFilterComposer(
            $db: $db,
            $table: $db.providerEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> messagesRefs(
    Expression<bool> Function($$MessagesTableFilterComposer f) f,
  ) {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProviderEntriesTableOrderingComposer get providerId {
    final $$ProviderEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.providerId,
      referencedTable: $db.providerEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProviderEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.providerEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ProviderEntriesTableAnnotationComposer get providerId {
    final $$ProviderEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.providerId,
      referencedTable: $db.providerEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProviderEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.providerEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> messagesRefs<T extends Object>(
    Expression<T> Function($$MessagesTableAnnotationComposer a) f,
  ) {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConversationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversationsTable,
          Conversation,
          $$ConversationsTableFilterComposer,
          $$ConversationsTableOrderingComposer,
          $$ConversationsTableAnnotationComposer,
          $$ConversationsTableCreateCompanionBuilder,
          $$ConversationsTableUpdateCompanionBuilder,
          (Conversation, $$ConversationsTableReferences),
          Conversation,
          PrefetchHooks Function({bool providerId, bool messagesRefs})
        > {
  $$ConversationsTableTableManager(_$AppDatabase db, $ConversationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> providerId = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> systemPrompt = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion(
                id: id,
                title: title,
                providerId: providerId,
                model: model,
                systemPrompt: systemPrompt,
                archived: archived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> title = const Value.absent(),
                Value<String?> providerId = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> systemPrompt = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion.insert(
                id: id,
                title: title,
                providerId: providerId,
                model: model,
                systemPrompt: systemPrompt,
                archived: archived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ConversationsTable, Conversation>(table),
                  $$ConversationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({providerId = false, messagesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (messagesRefs) db.messages],
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
                    if (providerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.providerId,
                        referencedTable: $$ConversationsTableReferences
                            ._providerIdTable(db),
                        referencedColumn: $$ConversationsTableReferences
                            ._providerIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (messagesRefs)
                    await $_getPrefetchedDataByColumns<
                      Conversation,
                      $ConversationsTable,
                      Message,
                      $MessagesTable
                    >(
                      currentTable: table,
                      referencedTable: $$ConversationsTableReferences
                          ._messagesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ConversationsTableReferences(
                            db,
                            table,
                            p0,
                          ).messagesRefs,
                      currentColumn: 'id',
                      referencedColumn: 'conversation_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversationsTable,
      Conversation,
      $$ConversationsTableFilterComposer,
      $$ConversationsTableOrderingComposer,
      $$ConversationsTableAnnotationComposer,
      $$ConversationsTableCreateCompanionBuilder,
      $$ConversationsTableUpdateCompanionBuilder,
      (Conversation, $$ConversationsTableReferences),
      Conversation,
      PrefetchHooks Function({bool providerId, bool messagesRefs})
    >;
typedef $$MessagesTableCreateCompanionBuilder = MessagesCompanion Function({
  required String id,
  required String conversationId,
  required String role,
  Value<String> content,
  Value<String?> reasoning,
  Value<String?> toolCallsJson,
  Value<String?> attachmentsJson,
  Value<String?> toolCallId,
  Value<String> status,
  required int createdAt,
  Value<int> rowid,
});
typedef $$MessagesTableUpdateCompanionBuilder = MessagesCompanion Function({
  Value<String> id,
  Value<String> conversationId,
  Value<String> role,
  Value<String> content,
  Value<String?> reasoning,
  Value<String?> toolCallsJson,
  Value<String?> attachmentsJson,
  Value<String?> toolCallId,
  Value<String> status,
  Value<int> createdAt,
  Value<int> rowid,
});

final class $$MessagesTableReferences
    extends BaseReferences<_$AppDatabase, $MessagesTable, Message> {
  $$MessagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ConversationsTable _conversationIdTable(_$AppDatabase db) => db
      .conversations
      .createAlias('messages__conversation_id__conversations__id');

  $$ConversationsTableProcessedTableManager get conversationId {
    final $_column = $_itemColumn<String>('conversation_id')!;

    final manager = $$ConversationsTableTableManager(
      $_db,
      $_db.conversations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_conversationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reasoning => $composableBuilder(
    column: $table.reasoning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toolCallsJson => $composableBuilder(
    column: $table.toolCallsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentsJson => $composableBuilder(
    column: $table.attachmentsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toolCallId => $composableBuilder(
    column: $table.toolCallId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ConversationsTableFilterComposer get conversationId {
    final $$ConversationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableFilterComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reasoning => $composableBuilder(
    column: $table.reasoning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toolCallsJson => $composableBuilder(
    column: $table.toolCallsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentsJson => $composableBuilder(
    column: $table.attachmentsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toolCallId => $composableBuilder(
    column: $table.toolCallId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ConversationsTableOrderingComposer get conversationId {
    final $$ConversationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableOrderingComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get reasoning =>
      $composableBuilder(column: $table.reasoning, builder: (column) => column);

  GeneratedColumn<String> get toolCallsJson => $composableBuilder(
    column: $table.toolCallsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attachmentsJson => $composableBuilder(
    column: $table.attachmentsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toolCallId => $composableBuilder(
    column: $table.toolCallId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ConversationsTableAnnotationComposer get conversationId {
    final $$ConversationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableAnnotationComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessagesTable,
          Message,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (Message, $$MessagesTableReferences),
          Message,
          PrefetchHooks Function({bool conversationId})
        > {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> reasoning = const Value.absent(),
                Value<String?> toolCallsJson = const Value.absent(),
                Value<String?> attachmentsJson = const Value.absent(),
                Value<String?> toolCallId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                conversationId: conversationId,
                role: role,
                content: content,
                reasoning: reasoning,
                toolCallsJson: toolCallsJson,
                attachmentsJson: attachmentsJson,
                toolCallId: toolCallId,
                status: status,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                required String role,
                Value<String> content = const Value.absent(),
                Value<String?> reasoning = const Value.absent(),
                Value<String?> toolCallsJson = const Value.absent(),
                Value<String?> attachmentsJson = const Value.absent(),
                Value<String?> toolCallId = const Value.absent(),
                Value<String> status = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                conversationId: conversationId,
                role: role,
                content: content,
                reasoning: reasoning,
                toolCallsJson: toolCallsJson,
                attachmentsJson: attachmentsJson,
                toolCallId: toolCallId,
                status: status,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MessagesTable, Message>(table),
                  $$MessagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({conversationId = false}) {
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
                    if (conversationId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.conversationId,
                        referencedTable: $$MessagesTableReferences
                            ._conversationIdTable(db),
                        referencedColumn: $$MessagesTableReferences
                            ._conversationIdTable(db)
                            .id,
                      ) as T;
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

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessagesTable,
      Message,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (Message, $$MessagesTableReferences),
      Message,
      PrefetchHooks Function({bool conversationId})
    >;
typedef $$MarketplaceEntriesTableCreateCompanionBuilder =
    MarketplaceEntriesCompanion Function({
      required String id,
      required String name,
      Value<String> description,
      required String sourceUrl,
      required String manifestUrl,
      Value<bool> builtIn,
      Value<bool> enabled,
      Value<String?> etag,
      Value<int?> lastSyncedAt,
      Value<String?> lastError,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$MarketplaceEntriesTableUpdateCompanionBuilder =
    MarketplaceEntriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> description,
      Value<String> sourceUrl,
      Value<String> manifestUrl,
      Value<bool> builtIn,
      Value<bool> enabled,
      Value<String?> etag,
      Value<int?> lastSyncedAt,
      Value<String?> lastError,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$MarketplaceEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MarketplaceEntriesTable,
          MarketplaceEntry
        > {
  $$MarketplaceEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $MarketplacePluginEntriesTable,
    List<MarketplacePluginEntry>
  >
  _marketplacePluginEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.marketplacePluginEntries,
        aliasName: 'marketplaces__id__marketplace_plugins__marketplace_id',
      );

  $$MarketplacePluginEntriesTableProcessedTableManager
  get marketplacePluginEntriesRefs {
    final manager = $$MarketplacePluginEntriesTableTableManager(
      $_db,
      $_db.marketplacePluginEntries,
    ).filter((f) => f.marketplaceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _marketplacePluginEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MarketplaceEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $MarketplaceEntriesTable> {
  $$MarketplaceEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manifestUrl => $composableBuilder(
    column: $table.manifestUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get builtIn => $composableBuilder(
    column: $table.builtIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> marketplacePluginEntriesRefs(
    Expression<bool> Function($$MarketplacePluginEntriesTableFilterComposer f)
    f,
  ) {
    final $$MarketplacePluginEntriesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.marketplacePluginEntries,
          getReferencedColumn: (t) => t.marketplaceId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MarketplacePluginEntriesTableFilterComposer(
                $db: $db,
                $table: $db.marketplacePluginEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$MarketplaceEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MarketplaceEntriesTable> {
  $$MarketplaceEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manifestUrl => $composableBuilder(
    column: $table.manifestUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get builtIn => $composableBuilder(
    column: $table.builtIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MarketplaceEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MarketplaceEntriesTable> {
  $$MarketplaceEntriesTableAnnotationComposer({
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

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get manifestUrl => $composableBuilder(
    column: $table.manifestUrl,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get builtIn =>
      $composableBuilder(column: $table.builtIn, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> marketplacePluginEntriesRefs<T extends Object>(
    Expression<T> Function($$MarketplacePluginEntriesTableAnnotationComposer a)
    f,
  ) {
    final $$MarketplacePluginEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.marketplacePluginEntries,
          getReferencedColumn: (t) => t.marketplaceId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MarketplacePluginEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.marketplacePluginEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$MarketplaceEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MarketplaceEntriesTable,
          MarketplaceEntry,
          $$MarketplaceEntriesTableFilterComposer,
          $$MarketplaceEntriesTableOrderingComposer,
          $$MarketplaceEntriesTableAnnotationComposer,
          $$MarketplaceEntriesTableCreateCompanionBuilder,
          $$MarketplaceEntriesTableUpdateCompanionBuilder,
          (MarketplaceEntry, $$MarketplaceEntriesTableReferences),
          MarketplaceEntry,
          PrefetchHooks Function({bool marketplacePluginEntriesRefs})
        > {
  $$MarketplaceEntriesTableTableManager(
    _$AppDatabase db,
    $MarketplaceEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MarketplaceEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MarketplaceEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MarketplaceEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> sourceUrl = const Value.absent(),
                Value<String> manifestUrl = const Value.absent(),
                Value<bool> builtIn = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<int?> lastSyncedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MarketplaceEntriesCompanion(
                id: id,
                name: name,
                description: description,
                sourceUrl: sourceUrl,
                manifestUrl: manifestUrl,
                builtIn: builtIn,
                enabled: enabled,
                etag: etag,
                lastSyncedAt: lastSyncedAt,
                lastError: lastError,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> description = const Value.absent(),
                required String sourceUrl,
                required String manifestUrl,
                Value<bool> builtIn = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<int?> lastSyncedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MarketplaceEntriesCompanion.insert(
                id: id,
                name: name,
                description: description,
                sourceUrl: sourceUrl,
                manifestUrl: manifestUrl,
                builtIn: builtIn,
                enabled: enabled,
                etag: etag,
                lastSyncedAt: lastSyncedAt,
                lastError: lastError,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MarketplaceEntriesTable, MarketplaceEntry>(
                    table,
                  ),
                  $$MarketplaceEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({marketplacePluginEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (marketplacePluginEntriesRefs) db.marketplacePluginEntries,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (marketplacePluginEntriesRefs)
                    await $_getPrefetchedDataByColumns<
                      MarketplaceEntry,
                      $MarketplaceEntriesTable,
                      MarketplacePluginEntry,
                      $MarketplacePluginEntriesTable
                    >(
                      currentTable: table,
                      referencedTable: $$MarketplaceEntriesTableReferences
                          ._marketplacePluginEntriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$MarketplaceEntriesTableReferences(
                            db,
                            table,
                            p0,
                          ).marketplacePluginEntriesRefs,
                      currentColumn: 'id',
                      referencedColumn: 'marketplace_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MarketplaceEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MarketplaceEntriesTable,
      MarketplaceEntry,
      $$MarketplaceEntriesTableFilterComposer,
      $$MarketplaceEntriesTableOrderingComposer,
      $$MarketplaceEntriesTableAnnotationComposer,
      $$MarketplaceEntriesTableCreateCompanionBuilder,
      $$MarketplaceEntriesTableUpdateCompanionBuilder,
      (MarketplaceEntry, $$MarketplaceEntriesTableReferences),
      MarketplaceEntry,
      PrefetchHooks Function({bool marketplacePluginEntriesRefs})
    >;
typedef $$MarketplacePluginEntriesTableCreateCompanionBuilder =
    MarketplacePluginEntriesCompanion Function({
      required String id,
      required String marketplaceId,
      required String name,
      Value<String?> displayName,
      Value<String> description,
      Value<String?> author,
      Value<String?> category,
      Value<String?> homepage,
      Value<String?> version,
      required String sourceJson,
      required String sourceKind,
      Value<String?> sourceUrl,
      Value<String?> sourcePath,
      Value<String?> sourceRef,
      Value<String?> sourceSha,
      Value<bool> installed,
      Value<bool> enabled,
      Value<String> mcpStatus,
      Value<String?> mcpConfigJson,
      Value<int?> mcpCheckedAt,
      Value<String?> installedConfigJson,
      Value<bool> needsReconsent,
      Value<String?> lastError,
      required int lastSeenAt,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$MarketplacePluginEntriesTableUpdateCompanionBuilder =
    MarketplacePluginEntriesCompanion Function({
      Value<String> id,
      Value<String> marketplaceId,
      Value<String> name,
      Value<String?> displayName,
      Value<String> description,
      Value<String?> author,
      Value<String?> category,
      Value<String?> homepage,
      Value<String?> version,
      Value<String> sourceJson,
      Value<String> sourceKind,
      Value<String?> sourceUrl,
      Value<String?> sourcePath,
      Value<String?> sourceRef,
      Value<String?> sourceSha,
      Value<bool> installed,
      Value<bool> enabled,
      Value<String> mcpStatus,
      Value<String?> mcpConfigJson,
      Value<int?> mcpCheckedAt,
      Value<String?> installedConfigJson,
      Value<bool> needsReconsent,
      Value<String?> lastError,
      Value<int> lastSeenAt,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$MarketplacePluginEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MarketplacePluginEntriesTable,
          MarketplacePluginEntry
        > {
  $$MarketplacePluginEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MarketplaceEntriesTable _marketplaceIdTable(_$AppDatabase db) => db
      .marketplaceEntries
      .createAlias('marketplace_plugins__marketplace_id__marketplaces__id');

  $$MarketplaceEntriesTableProcessedTableManager get marketplaceId {
    final $_column = $_itemColumn<String>('marketplace_id')!;

    final manager = $$MarketplaceEntriesTableTableManager(
      $_db,
      $_db.marketplaceEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_marketplaceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$McpServerEntriesTable, List<McpServerEntry>>
  _mcpServerEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.mcpServerEntries,
    aliasName: 'marketplace_plugins__id__mcp_servers__plugin_id',
  );

  $$McpServerEntriesTableProcessedTableManager get mcpServerEntriesRefs {
    final manager = $$McpServerEntriesTableTableManager(
      $_db,
      $_db.mcpServerEntries,
    ).filter((f) => f.pluginId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _mcpServerEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MarketplacePluginEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $MarketplacePluginEntriesTable> {
  $$MarketplacePluginEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get homepage => $composableBuilder(
    column: $table.homepage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceJson => $composableBuilder(
    column: $table.sourceJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceRef => $composableBuilder(
    column: $table.sourceRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceSha => $composableBuilder(
    column: $table.sourceSha,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get installed => $composableBuilder(
    column: $table.installed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mcpStatus => $composableBuilder(
    column: $table.mcpStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mcpConfigJson => $composableBuilder(
    column: $table.mcpConfigJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mcpCheckedAt => $composableBuilder(
    column: $table.mcpCheckedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get installedConfigJson => $composableBuilder(
    column: $table.installedConfigJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get needsReconsent => $composableBuilder(
    column: $table.needsReconsent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MarketplaceEntriesTableFilterComposer get marketplaceId {
    final $$MarketplaceEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.marketplaceId,
      referencedTable: $db.marketplaceEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MarketplaceEntriesTableFilterComposer(
            $db: $db,
            $table: $db.marketplaceEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> mcpServerEntriesRefs(
    Expression<bool> Function($$McpServerEntriesTableFilterComposer f) f,
  ) {
    final $$McpServerEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mcpServerEntries,
      getReferencedColumn: (t) => t.pluginId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$McpServerEntriesTableFilterComposer(
            $db: $db,
            $table: $db.mcpServerEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MarketplacePluginEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MarketplacePluginEntriesTable> {
  $$MarketplacePluginEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get homepage => $composableBuilder(
    column: $table.homepage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceJson => $composableBuilder(
    column: $table.sourceJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceRef => $composableBuilder(
    column: $table.sourceRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceSha => $composableBuilder(
    column: $table.sourceSha,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get installed => $composableBuilder(
    column: $table.installed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mcpStatus => $composableBuilder(
    column: $table.mcpStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mcpConfigJson => $composableBuilder(
    column: $table.mcpConfigJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mcpCheckedAt => $composableBuilder(
    column: $table.mcpCheckedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get installedConfigJson => $composableBuilder(
    column: $table.installedConfigJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get needsReconsent => $composableBuilder(
    column: $table.needsReconsent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MarketplaceEntriesTableOrderingComposer get marketplaceId {
    final $$MarketplaceEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.marketplaceId,
      referencedTable: $db.marketplaceEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MarketplaceEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.marketplaceEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MarketplacePluginEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MarketplacePluginEntriesTable> {
  $$MarketplacePluginEntriesTableAnnotationComposer({
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

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get homepage =>
      $composableBuilder(column: $table.homepage, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get sourceJson => $composableBuilder(
    column: $table.sourceJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceRef =>
      $composableBuilder(column: $table.sourceRef, builder: (column) => column);

  GeneratedColumn<String> get sourceSha =>
      $composableBuilder(column: $table.sourceSha, builder: (column) => column);

  GeneratedColumn<bool> get installed =>
      $composableBuilder(column: $table.installed, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get mcpStatus =>
      $composableBuilder(column: $table.mcpStatus, builder: (column) => column);

  GeneratedColumn<String> get mcpConfigJson => $composableBuilder(
    column: $table.mcpConfigJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get mcpCheckedAt => $composableBuilder(
    column: $table.mcpCheckedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get installedConfigJson => $composableBuilder(
    column: $table.installedConfigJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get needsReconsent => $composableBuilder(
    column: $table.needsReconsent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$MarketplaceEntriesTableAnnotationComposer get marketplaceId {
    final $$MarketplaceEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.marketplaceId,
          referencedTable: $db.marketplaceEntries,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MarketplaceEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.marketplaceEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<T> mcpServerEntriesRefs<T extends Object>(
    Expression<T> Function($$McpServerEntriesTableAnnotationComposer a) f,
  ) {
    final $$McpServerEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mcpServerEntries,
      getReferencedColumn: (t) => t.pluginId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$McpServerEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.mcpServerEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MarketplacePluginEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MarketplacePluginEntriesTable,
          MarketplacePluginEntry,
          $$MarketplacePluginEntriesTableFilterComposer,
          $$MarketplacePluginEntriesTableOrderingComposer,
          $$MarketplacePluginEntriesTableAnnotationComposer,
          $$MarketplacePluginEntriesTableCreateCompanionBuilder,
          $$MarketplacePluginEntriesTableUpdateCompanionBuilder,
          (MarketplacePluginEntry, $$MarketplacePluginEntriesTableReferences),
          MarketplacePluginEntry,
          PrefetchHooks Function({
            bool marketplaceId,
            bool mcpServerEntriesRefs,
          })
        > {
  $$MarketplacePluginEntriesTableTableManager(
    _$AppDatabase db,
    $MarketplacePluginEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MarketplacePluginEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$MarketplacePluginEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MarketplacePluginEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> marketplaceId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> homepage = const Value.absent(),
                Value<String?> version = const Value.absent(),
                Value<String> sourceJson = const Value.absent(),
                Value<String> sourceKind = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<String?> sourcePath = const Value.absent(),
                Value<String?> sourceRef = const Value.absent(),
                Value<String?> sourceSha = const Value.absent(),
                Value<bool> installed = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String> mcpStatus = const Value.absent(),
                Value<String?> mcpConfigJson = const Value.absent(),
                Value<int?> mcpCheckedAt = const Value.absent(),
                Value<String?> installedConfigJson = const Value.absent(),
                Value<bool> needsReconsent = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> lastSeenAt = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MarketplacePluginEntriesCompanion(
                id: id,
                marketplaceId: marketplaceId,
                name: name,
                displayName: displayName,
                description: description,
                author: author,
                category: category,
                homepage: homepage,
                version: version,
                sourceJson: sourceJson,
                sourceKind: sourceKind,
                sourceUrl: sourceUrl,
                sourcePath: sourcePath,
                sourceRef: sourceRef,
                sourceSha: sourceSha,
                installed: installed,
                enabled: enabled,
                mcpStatus: mcpStatus,
                mcpConfigJson: mcpConfigJson,
                mcpCheckedAt: mcpCheckedAt,
                installedConfigJson: installedConfigJson,
                needsReconsent: needsReconsent,
                lastError: lastError,
                lastSeenAt: lastSeenAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String marketplaceId,
                required String name,
                Value<String?> displayName = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> homepage = const Value.absent(),
                Value<String?> version = const Value.absent(),
                required String sourceJson,
                required String sourceKind,
                Value<String?> sourceUrl = const Value.absent(),
                Value<String?> sourcePath = const Value.absent(),
                Value<String?> sourceRef = const Value.absent(),
                Value<String?> sourceSha = const Value.absent(),
                Value<bool> installed = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String> mcpStatus = const Value.absent(),
                Value<String?> mcpConfigJson = const Value.absent(),
                Value<int?> mcpCheckedAt = const Value.absent(),
                Value<String?> installedConfigJson = const Value.absent(),
                Value<bool> needsReconsent = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required int lastSeenAt,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MarketplacePluginEntriesCompanion.insert(
                id: id,
                marketplaceId: marketplaceId,
                name: name,
                displayName: displayName,
                description: description,
                author: author,
                category: category,
                homepage: homepage,
                version: version,
                sourceJson: sourceJson,
                sourceKind: sourceKind,
                sourceUrl: sourceUrl,
                sourcePath: sourcePath,
                sourceRef: sourceRef,
                sourceSha: sourceSha,
                installed: installed,
                enabled: enabled,
                mcpStatus: mcpStatus,
                mcpConfigJson: mcpConfigJson,
                mcpCheckedAt: mcpCheckedAt,
                installedConfigJson: installedConfigJson,
                needsReconsent: needsReconsent,
                lastError: lastError,
                lastSeenAt: lastSeenAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $MarketplacePluginEntriesTable,
                    MarketplacePluginEntry
                  >(table),
                  $$MarketplacePluginEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({marketplaceId = false, mcpServerEntriesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (mcpServerEntriesRefs) db.mcpServerEntries,
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
                        if (marketplaceId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.marketplaceId,
                            referencedTable:
                                $$MarketplacePluginEntriesTableReferences
                                    ._marketplaceIdTable(db),
                            referencedColumn:
                                $$MarketplacePluginEntriesTableReferences
                                    ._marketplaceIdTable(db)
                                    .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (mcpServerEntriesRefs)
                        await $_getPrefetchedDataByColumns<
                          MarketplacePluginEntry,
                          $MarketplacePluginEntriesTable,
                          McpServerEntry,
                          $McpServerEntriesTable
                        >(
                          currentTable: table,
                          referencedTable:
                              $$MarketplacePluginEntriesTableReferences
                                  ._mcpServerEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MarketplacePluginEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).mcpServerEntriesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'plugin_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MarketplacePluginEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MarketplacePluginEntriesTable,
      MarketplacePluginEntry,
      $$MarketplacePluginEntriesTableFilterComposer,
      $$MarketplacePluginEntriesTableOrderingComposer,
      $$MarketplacePluginEntriesTableAnnotationComposer,
      $$MarketplacePluginEntriesTableCreateCompanionBuilder,
      $$MarketplacePluginEntriesTableUpdateCompanionBuilder,
      (MarketplacePluginEntry, $$MarketplacePluginEntriesTableReferences),
      MarketplacePluginEntry,
      PrefetchHooks Function({bool marketplaceId, bool mcpServerEntriesRefs})
    >;
typedef $$McpServerEntriesTableCreateCompanionBuilder =
    McpServerEntriesCompanion Function({
      required String id,
      Value<String?> pluginId,
      Value<String?> marketplaceId,
      required String name,
      required String url,
      required String transport,
      required String authType,
      Value<String?> headerNamesJson,
      required String configHash,
      Value<bool> enabled,
      Value<bool> needsReconsent,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$McpServerEntriesTableUpdateCompanionBuilder =
    McpServerEntriesCompanion Function({
      Value<String> id,
      Value<String?> pluginId,
      Value<String?> marketplaceId,
      Value<String> name,
      Value<String> url,
      Value<String> transport,
      Value<String> authType,
      Value<String?> headerNamesJson,
      Value<String> configHash,
      Value<bool> enabled,
      Value<bool> needsReconsent,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$McpServerEntriesTableReferences
    extends
        BaseReferences<_$AppDatabase, $McpServerEntriesTable, McpServerEntry> {
  $$McpServerEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MarketplacePluginEntriesTable _pluginIdTable(_$AppDatabase db) => db
      .marketplacePluginEntries
      .createAlias('mcp_servers__plugin_id__marketplace_plugins__id');

  $$MarketplacePluginEntriesTableProcessedTableManager? get pluginId {
    final $_column = $_itemColumn<String>('plugin_id');
    if ($_column == null) return null;
    final manager = $$MarketplacePluginEntriesTableTableManager(
      $_db,
      $_db.marketplacePluginEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pluginIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$McpToolEntriesTable, List<McpToolEntry>>
  _mcpToolEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.mcpToolEntries,
    aliasName: 'mcp_servers__id__mcp_tools__server_id',
  );

  $$McpToolEntriesTableProcessedTableManager get mcpToolEntriesRefs {
    final manager = $$McpToolEntriesTableTableManager(
      $_db,
      $_db.mcpToolEntries,
    ).filter((f) => f.serverId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_mcpToolEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$McpServerEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $McpServerEntriesTable> {
  $$McpServerEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get marketplaceId => $composableBuilder(
    column: $table.marketplaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transport => $composableBuilder(
    column: $table.transport,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authType => $composableBuilder(
    column: $table.authType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get headerNamesJson => $composableBuilder(
    column: $table.headerNamesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configHash => $composableBuilder(
    column: $table.configHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get needsReconsent => $composableBuilder(
    column: $table.needsReconsent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MarketplacePluginEntriesTableFilterComposer get pluginId {
    final $$MarketplacePluginEntriesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.pluginId,
          referencedTable: $db.marketplacePluginEntries,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MarketplacePluginEntriesTableFilterComposer(
                $db: $db,
                $table: $db.marketplacePluginEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<bool> mcpToolEntriesRefs(
    Expression<bool> Function($$McpToolEntriesTableFilterComposer f) f,
  ) {
    final $$McpToolEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mcpToolEntries,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$McpToolEntriesTableFilterComposer(
            $db: $db,
            $table: $db.mcpToolEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$McpServerEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $McpServerEntriesTable> {
  $$McpServerEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get marketplaceId => $composableBuilder(
    column: $table.marketplaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transport => $composableBuilder(
    column: $table.transport,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authType => $composableBuilder(
    column: $table.authType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headerNamesJson => $composableBuilder(
    column: $table.headerNamesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configHash => $composableBuilder(
    column: $table.configHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get needsReconsent => $composableBuilder(
    column: $table.needsReconsent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MarketplacePluginEntriesTableOrderingComposer get pluginId {
    final $$MarketplacePluginEntriesTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.pluginId,
          referencedTable: $db.marketplacePluginEntries,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MarketplacePluginEntriesTableOrderingComposer(
                $db: $db,
                $table: $db.marketplacePluginEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$McpServerEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $McpServerEntriesTable> {
  $$McpServerEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get marketplaceId => $composableBuilder(
    column: $table.marketplaceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get transport =>
      $composableBuilder(column: $table.transport, builder: (column) => column);

  GeneratedColumn<String> get authType =>
      $composableBuilder(column: $table.authType, builder: (column) => column);

  GeneratedColumn<String> get headerNamesJson => $composableBuilder(
    column: $table.headerNamesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get configHash => $composableBuilder(
    column: $table.configHash,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<bool> get needsReconsent => $composableBuilder(
    column: $table.needsReconsent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$MarketplacePluginEntriesTableAnnotationComposer get pluginId {
    final $$MarketplacePluginEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.pluginId,
          referencedTable: $db.marketplacePluginEntries,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MarketplacePluginEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.marketplacePluginEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<T> mcpToolEntriesRefs<T extends Object>(
    Expression<T> Function($$McpToolEntriesTableAnnotationComposer a) f,
  ) {
    final $$McpToolEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mcpToolEntries,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$McpToolEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.mcpToolEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$McpServerEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $McpServerEntriesTable,
          McpServerEntry,
          $$McpServerEntriesTableFilterComposer,
          $$McpServerEntriesTableOrderingComposer,
          $$McpServerEntriesTableAnnotationComposer,
          $$McpServerEntriesTableCreateCompanionBuilder,
          $$McpServerEntriesTableUpdateCompanionBuilder,
          (McpServerEntry, $$McpServerEntriesTableReferences),
          McpServerEntry,
          PrefetchHooks Function({bool pluginId, bool mcpToolEntriesRefs})
        > {
  $$McpServerEntriesTableTableManager(
    _$AppDatabase db,
    $McpServerEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$McpServerEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$McpServerEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$McpServerEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> pluginId = const Value.absent(),
                Value<String?> marketplaceId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> transport = const Value.absent(),
                Value<String> authType = const Value.absent(),
                Value<String?> headerNamesJson = const Value.absent(),
                Value<String> configHash = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<bool> needsReconsent = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => McpServerEntriesCompanion(
                id: id,
                pluginId: pluginId,
                marketplaceId: marketplaceId,
                name: name,
                url: url,
                transport: transport,
                authType: authType,
                headerNamesJson: headerNamesJson,
                configHash: configHash,
                enabled: enabled,
                needsReconsent: needsReconsent,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> pluginId = const Value.absent(),
                Value<String?> marketplaceId = const Value.absent(),
                required String name,
                required String url,
                required String transport,
                required String authType,
                Value<String?> headerNamesJson = const Value.absent(),
                required String configHash,
                Value<bool> enabled = const Value.absent(),
                Value<bool> needsReconsent = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => McpServerEntriesCompanion.insert(
                id: id,
                pluginId: pluginId,
                marketplaceId: marketplaceId,
                name: name,
                url: url,
                transport: transport,
                authType: authType,
                headerNamesJson: headerNamesJson,
                configHash: configHash,
                enabled: enabled,
                needsReconsent: needsReconsent,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$McpServerEntriesTable, McpServerEntry>(table),
                  $$McpServerEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({pluginId = false, mcpToolEntriesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (mcpToolEntriesRefs) db.mcpToolEntries,
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
                        if (pluginId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.pluginId,
                            referencedTable: $$McpServerEntriesTableReferences
                                ._pluginIdTable(db),
                            referencedColumn: $$McpServerEntriesTableReferences
                                ._pluginIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (mcpToolEntriesRefs)
                        await $_getPrefetchedDataByColumns<
                          McpServerEntry,
                          $McpServerEntriesTable,
                          McpToolEntry,
                          $McpToolEntriesTable
                        >(
                          currentTable: table,
                          referencedTable: $$McpServerEntriesTableReferences
                              ._mcpToolEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$McpServerEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).mcpToolEntriesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'server_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$McpServerEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $McpServerEntriesTable,
      McpServerEntry,
      $$McpServerEntriesTableFilterComposer,
      $$McpServerEntriesTableOrderingComposer,
      $$McpServerEntriesTableAnnotationComposer,
      $$McpServerEntriesTableCreateCompanionBuilder,
      $$McpServerEntriesTableUpdateCompanionBuilder,
      (McpServerEntry, $$McpServerEntriesTableReferences),
      McpServerEntry,
      PrefetchHooks Function({bool pluginId, bool mcpToolEntriesRefs})
    >;
typedef $$McpToolEntriesTableCreateCompanionBuilder =
    McpToolEntriesCompanion Function({
      required String id,
      required String serverId,
      required String name,
      Value<String> description,
      required String schemaJson,
      Value<bool> needsApproval,
      required int discoveredAt,
      Value<int> rowid,
    });
typedef $$McpToolEntriesTableUpdateCompanionBuilder =
    McpToolEntriesCompanion Function({
      Value<String> id,
      Value<String> serverId,
      Value<String> name,
      Value<String> description,
      Value<String> schemaJson,
      Value<bool> needsApproval,
      Value<int> discoveredAt,
      Value<int> rowid,
    });

final class $$McpToolEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $McpToolEntriesTable, McpToolEntry> {
  $$McpToolEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $McpServerEntriesTable _serverIdTable(_$AppDatabase db) =>
      db.mcpServerEntries.createAlias('mcp_tools__server_id__mcp_servers__id');

  $$McpServerEntriesTableProcessedTableManager get serverId {
    final $_column = $_itemColumn<String>('server_id')!;

    final manager = $$McpServerEntriesTableTableManager(
      $_db,
      $_db.mcpServerEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_serverIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$McpToolEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $McpToolEntriesTable> {
  $$McpToolEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schemaJson => $composableBuilder(
    column: $table.schemaJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get needsApproval => $composableBuilder(
    column: $table.needsApproval,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discoveredAt => $composableBuilder(
    column: $table.discoveredAt,
    builder: (column) => ColumnFilters(column),
  );

  $$McpServerEntriesTableFilterComposer get serverId {
    final $$McpServerEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serverId,
      referencedTable: $db.mcpServerEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$McpServerEntriesTableFilterComposer(
            $db: $db,
            $table: $db.mcpServerEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$McpToolEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $McpToolEntriesTable> {
  $$McpToolEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schemaJson => $composableBuilder(
    column: $table.schemaJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get needsApproval => $composableBuilder(
    column: $table.needsApproval,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discoveredAt => $composableBuilder(
    column: $table.discoveredAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$McpServerEntriesTableOrderingComposer get serverId {
    final $$McpServerEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serverId,
      referencedTable: $db.mcpServerEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$McpServerEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.mcpServerEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$McpToolEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $McpToolEntriesTable> {
  $$McpToolEntriesTableAnnotationComposer({
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

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get schemaJson => $composableBuilder(
    column: $table.schemaJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get needsApproval => $composableBuilder(
    column: $table.needsApproval,
    builder: (column) => column,
  );

  GeneratedColumn<int> get discoveredAt => $composableBuilder(
    column: $table.discoveredAt,
    builder: (column) => column,
  );

  $$McpServerEntriesTableAnnotationComposer get serverId {
    final $$McpServerEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serverId,
      referencedTable: $db.mcpServerEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$McpServerEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.mcpServerEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$McpToolEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $McpToolEntriesTable,
          McpToolEntry,
          $$McpToolEntriesTableFilterComposer,
          $$McpToolEntriesTableOrderingComposer,
          $$McpToolEntriesTableAnnotationComposer,
          $$McpToolEntriesTableCreateCompanionBuilder,
          $$McpToolEntriesTableUpdateCompanionBuilder,
          (McpToolEntry, $$McpToolEntriesTableReferences),
          McpToolEntry,
          PrefetchHooks Function({bool serverId})
        > {
  $$McpToolEntriesTableTableManager(
    _$AppDatabase db,
    $McpToolEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$McpToolEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$McpToolEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$McpToolEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> serverId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> schemaJson = const Value.absent(),
                Value<bool> needsApproval = const Value.absent(),
                Value<int> discoveredAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => McpToolEntriesCompanion(
                id: id,
                serverId: serverId,
                name: name,
                description: description,
                schemaJson: schemaJson,
                needsApproval: needsApproval,
                discoveredAt: discoveredAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String serverId,
                required String name,
                Value<String> description = const Value.absent(),
                required String schemaJson,
                Value<bool> needsApproval = const Value.absent(),
                required int discoveredAt,
                Value<int> rowid = const Value.absent(),
              }) => McpToolEntriesCompanion.insert(
                id: id,
                serverId: serverId,
                name: name,
                description: description,
                schemaJson: schemaJson,
                needsApproval: needsApproval,
                discoveredAt: discoveredAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$McpToolEntriesTable, McpToolEntry>(table),
                  $$McpToolEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({serverId = false}) {
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
                    if (serverId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.serverId,
                        referencedTable: $$McpToolEntriesTableReferences
                            ._serverIdTable(db),
                        referencedColumn: $$McpToolEntriesTableReferences
                            ._serverIdTable(db)
                            .id,
                      ) as T;
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

typedef $$McpToolEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $McpToolEntriesTable,
      McpToolEntry,
      $$McpToolEntriesTableFilterComposer,
      $$McpToolEntriesTableOrderingComposer,
      $$McpToolEntriesTableAnnotationComposer,
      $$McpToolEntriesTableCreateCompanionBuilder,
      $$McpToolEntriesTableUpdateCompanionBuilder,
      (McpToolEntry, $$McpToolEntriesTableReferences),
      McpToolEntry,
      PrefetchHooks Function({bool serverId})
    >;
typedef $$OpenCodeConnectionEntriesTableCreateCompanionBuilder =
    OpenCodeConnectionEntriesCompanion Function({
      required String id,
      required String name,
      required String baseUrl,
      Value<String> username,
      required String tokenRef,
      Value<int?> lastSeen,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$OpenCodeConnectionEntriesTableUpdateCompanionBuilder =
    OpenCodeConnectionEntriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> baseUrl,
      Value<String> username,
      Value<String> tokenRef,
      Value<int?> lastSeen,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$OpenCodeConnectionEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $OpenCodeConnectionEntriesTable> {
  $$OpenCodeConnectionEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tokenRef => $composableBuilder(
    column: $table.tokenRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OpenCodeConnectionEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $OpenCodeConnectionEntriesTable> {
  $$OpenCodeConnectionEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tokenRef => $composableBuilder(
    column: $table.tokenRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OpenCodeConnectionEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OpenCodeConnectionEntriesTable> {
  $$OpenCodeConnectionEntriesTableAnnotationComposer({
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

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get tokenRef =>
      $composableBuilder(column: $table.tokenRef, builder: (column) => column);

  GeneratedColumn<int> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OpenCodeConnectionEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OpenCodeConnectionEntriesTable,
          OpenCodeConnectionEntry,
          $$OpenCodeConnectionEntriesTableFilterComposer,
          $$OpenCodeConnectionEntriesTableOrderingComposer,
          $$OpenCodeConnectionEntriesTableAnnotationComposer,
          $$OpenCodeConnectionEntriesTableCreateCompanionBuilder,
          $$OpenCodeConnectionEntriesTableUpdateCompanionBuilder,
          (
            OpenCodeConnectionEntry,
            BaseReferences<
              _$AppDatabase,
              $OpenCodeConnectionEntriesTable,
              OpenCodeConnectionEntry
            >,
          ),
          OpenCodeConnectionEntry,
          PrefetchHooks Function()
        > {
  $$OpenCodeConnectionEntriesTableTableManager(
    _$AppDatabase db,
    $OpenCodeConnectionEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OpenCodeConnectionEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$OpenCodeConnectionEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$OpenCodeConnectionEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<String> username = const Value.absent(),
                Value<String> tokenRef = const Value.absent(),
                Value<int?> lastSeen = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OpenCodeConnectionEntriesCompanion(
                id: id,
                name: name,
                baseUrl: baseUrl,
                username: username,
                tokenRef: tokenRef,
                lastSeen: lastSeen,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String baseUrl,
                Value<String> username = const Value.absent(),
                required String tokenRef,
                Value<int?> lastSeen = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => OpenCodeConnectionEntriesCompanion.insert(
                id: id,
                name: name,
                baseUrl: baseUrl,
                username: username,
                tokenRef: tokenRef,
                lastSeen: lastSeen,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $OpenCodeConnectionEntriesTable,
                    OpenCodeConnectionEntry
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $OpenCodeConnectionEntriesTable,
                    OpenCodeConnectionEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OpenCodeConnectionEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OpenCodeConnectionEntriesTable,
      OpenCodeConnectionEntry,
      $$OpenCodeConnectionEntriesTableFilterComposer,
      $$OpenCodeConnectionEntriesTableOrderingComposer,
      $$OpenCodeConnectionEntriesTableAnnotationComposer,
      $$OpenCodeConnectionEntriesTableCreateCompanionBuilder,
      $$OpenCodeConnectionEntriesTableUpdateCompanionBuilder,
      (
        OpenCodeConnectionEntry,
        BaseReferences<
          _$AppDatabase,
          $OpenCodeConnectionEntriesTable,
          OpenCodeConnectionEntry
        >,
      ),
      OpenCodeConnectionEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SettingEntriesTableTableManager get settingEntries =>
      $$SettingEntriesTableTableManager(_db, _db.settingEntries);
  $$ProviderEntriesTableTableManager get providerEntries =>
      $$ProviderEntriesTableTableManager(_db, _db.providerEntries);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db, _db.conversations);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$MarketplaceEntriesTableTableManager get marketplaceEntries =>
      $$MarketplaceEntriesTableTableManager(_db, _db.marketplaceEntries);
  $$MarketplacePluginEntriesTableTableManager get marketplacePluginEntries =>
      $$MarketplacePluginEntriesTableTableManager(
        _db,
        _db.marketplacePluginEntries,
      );
  $$McpServerEntriesTableTableManager get mcpServerEntries =>
      $$McpServerEntriesTableTableManager(_db, _db.mcpServerEntries);
  $$McpToolEntriesTableTableManager get mcpToolEntries =>
      $$McpToolEntriesTableTableManager(_db, _db.mcpToolEntries);
  $$OpenCodeConnectionEntriesTableTableManager get openCodeConnectionEntries =>
      $$OpenCodeConnectionEntriesTableTableManager(
        _db,
        _db.openCodeConnectionEntries,
      );
}
