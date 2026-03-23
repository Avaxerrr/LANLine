// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalIdentityTableTable extends LocalIdentityTable
    with TableInfo<$LocalIdentityTableTable, LocalIdentityRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalIdentityTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _peerIdMeta = const VerificationMeta('peerId');
  @override
  late final GeneratedColumn<String> peerId = GeneratedColumn<String>(
    'peer_id',
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceLabelMeta = const VerificationMeta(
    'deviceLabel',
  );
  @override
  late final GeneratedColumn<String> deviceLabel = GeneratedColumn<String>(
    'device_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta(
    'fingerprint',
  );
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
    peerId,
    displayName,
    deviceLabel,
    fingerprint,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_identity_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalIdentityRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('peer_id')) {
      context.handle(
        _peerIdMeta,
        peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_peerIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('device_label')) {
      context.handle(
        _deviceLabelMeta,
        deviceLabel.isAcceptableOrUnknown(
          data['device_label']!,
          _deviceLabelMeta,
        ),
      );
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
        _fingerprintMeta,
        fingerprint.isAcceptableOrUnknown(
          data['fingerprint']!,
          _fingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fingerprintMeta);
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
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {peerId},
  ];
  @override
  LocalIdentityRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalIdentityRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      peerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      deviceLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_label'],
      ),
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint'],
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
  $LocalIdentityTableTable createAlias(String alias) {
    return $LocalIdentityTableTable(attachedDatabase, alias);
  }
}

class LocalIdentityRow extends DataClass
    implements Insertable<LocalIdentityRow> {
  final String id;
  final String peerId;
  final String displayName;
  final String? deviceLabel;
  final String fingerprint;
  final int createdAt;
  final int updatedAt;
  const LocalIdentityRow({
    required this.id,
    required this.peerId,
    required this.displayName,
    this.deviceLabel,
    required this.fingerprint,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['peer_id'] = Variable<String>(peerId);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || deviceLabel != null) {
      map['device_label'] = Variable<String>(deviceLabel);
    }
    map['fingerprint'] = Variable<String>(fingerprint);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  LocalIdentityTableCompanion toCompanion(bool nullToAbsent) {
    return LocalIdentityTableCompanion(
      id: Value(id),
      peerId: Value(peerId),
      displayName: Value(displayName),
      deviceLabel: deviceLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceLabel),
      fingerprint: Value(fingerprint),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalIdentityRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalIdentityRow(
      id: serializer.fromJson<String>(json['id']),
      peerId: serializer.fromJson<String>(json['peerId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      deviceLabel: serializer.fromJson<String?>(json['deviceLabel']),
      fingerprint: serializer.fromJson<String>(json['fingerprint']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'peerId': serializer.toJson<String>(peerId),
      'displayName': serializer.toJson<String>(displayName),
      'deviceLabel': serializer.toJson<String?>(deviceLabel),
      'fingerprint': serializer.toJson<String>(fingerprint),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  LocalIdentityRow copyWith({
    String? id,
    String? peerId,
    String? displayName,
    Value<String?> deviceLabel = const Value.absent(),
    String? fingerprint,
    int? createdAt,
    int? updatedAt,
  }) => LocalIdentityRow(
    id: id ?? this.id,
    peerId: peerId ?? this.peerId,
    displayName: displayName ?? this.displayName,
    deviceLabel: deviceLabel.present ? deviceLabel.value : this.deviceLabel,
    fingerprint: fingerprint ?? this.fingerprint,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalIdentityRow copyWithCompanion(LocalIdentityTableCompanion data) {
    return LocalIdentityRow(
      id: data.id.present ? data.id.value : this.id,
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      deviceLabel: data.deviceLabel.present
          ? data.deviceLabel.value
          : this.deviceLabel,
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalIdentityRow(')
          ..write('id: $id, ')
          ..write('peerId: $peerId, ')
          ..write('displayName: $displayName, ')
          ..write('deviceLabel: $deviceLabel, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    peerId,
    displayName,
    deviceLabel,
    fingerprint,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalIdentityRow &&
          other.id == this.id &&
          other.peerId == this.peerId &&
          other.displayName == this.displayName &&
          other.deviceLabel == this.deviceLabel &&
          other.fingerprint == this.fingerprint &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalIdentityTableCompanion extends UpdateCompanion<LocalIdentityRow> {
  final Value<String> id;
  final Value<String> peerId;
  final Value<String> displayName;
  final Value<String?> deviceLabel;
  final Value<String> fingerprint;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const LocalIdentityTableCompanion({
    this.id = const Value.absent(),
    this.peerId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.deviceLabel = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalIdentityTableCompanion.insert({
    required String id,
    required String peerId,
    required String displayName,
    this.deviceLabel = const Value.absent(),
    required String fingerprint,
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       peerId = Value(peerId),
       displayName = Value(displayName),
       fingerprint = Value(fingerprint),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalIdentityRow> custom({
    Expression<String>? id,
    Expression<String>? peerId,
    Expression<String>? displayName,
    Expression<String>? deviceLabel,
    Expression<String>? fingerprint,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (peerId != null) 'peer_id': peerId,
      if (displayName != null) 'display_name': displayName,
      if (deviceLabel != null) 'device_label': deviceLabel,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalIdentityTableCompanion copyWith({
    Value<String>? id,
    Value<String>? peerId,
    Value<String>? displayName,
    Value<String?>? deviceLabel,
    Value<String>? fingerprint,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalIdentityTableCompanion(
      id: id ?? this.id,
      peerId: peerId ?? this.peerId,
      displayName: displayName ?? this.displayName,
      deviceLabel: deviceLabel ?? this.deviceLabel,
      fingerprint: fingerprint ?? this.fingerprint,
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
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (deviceLabel.present) {
      map['device_label'] = Variable<String>(deviceLabel.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
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
    return (StringBuffer('LocalIdentityTableCompanion(')
          ..write('id: $id, ')
          ..write('peerId: $peerId, ')
          ..write('displayName: $displayName, ')
          ..write('deviceLabel: $deviceLabel, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PeersTableTable extends PeersTable
    with TableInfo<$PeersTableTable, PeerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeersTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _peerIdMeta = const VerificationMeta('peerId');
  @override
  late final GeneratedColumn<String> peerId = GeneratedColumn<String>(
    'peer_id',
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceLabelMeta = const VerificationMeta(
    'deviceLabel',
  );
  @override
  late final GeneratedColumn<String> deviceLabel = GeneratedColumn<String>(
    'device_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta(
    'fingerprint',
  );
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _relationshipStateMeta = const VerificationMeta(
    'relationshipState',
  );
  @override
  late final GeneratedColumn<String> relationshipState =
      GeneratedColumn<String>(
        'relationship_state',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _isBlockedMeta = const VerificationMeta(
    'isBlocked',
  );
  @override
  late final GeneratedColumn<bool> isBlocked = GeneratedColumn<bool>(
    'is_blocked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_blocked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<int> lastSeenAt = GeneratedColumn<int>(
    'last_seen_at',
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
    peerId,
    displayName,
    deviceLabel,
    fingerprint,
    relationshipState,
    isBlocked,
    lastSeenAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'peers_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<PeerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('peer_id')) {
      context.handle(
        _peerIdMeta,
        peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_peerIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('device_label')) {
      context.handle(
        _deviceLabelMeta,
        deviceLabel.isAcceptableOrUnknown(
          data['device_label']!,
          _deviceLabelMeta,
        ),
      );
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
        _fingerprintMeta,
        fingerprint.isAcceptableOrUnknown(
          data['fingerprint']!,
          _fingerprintMeta,
        ),
      );
    }
    if (data.containsKey('relationship_state')) {
      context.handle(
        _relationshipStateMeta,
        relationshipState.isAcceptableOrUnknown(
          data['relationship_state']!,
          _relationshipStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relationshipStateMeta);
    }
    if (data.containsKey('is_blocked')) {
      context.handle(
        _isBlockedMeta,
        isBlocked.isAcceptableOrUnknown(data['is_blocked']!, _isBlockedMeta),
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
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {peerId},
  ];
  @override
  PeerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PeerRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      peerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      deviceLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_label'],
      ),
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint'],
      ),
      relationshipState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relationship_state'],
      )!,
      isBlocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_blocked'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen_at'],
      ),
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
  $PeersTableTable createAlias(String alias) {
    return $PeersTableTable(attachedDatabase, alias);
  }
}

class PeerRow extends DataClass implements Insertable<PeerRow> {
  final String id;
  final String peerId;
  final String displayName;
  final String? deviceLabel;
  final String? fingerprint;
  final String relationshipState;
  final bool isBlocked;
  final int? lastSeenAt;
  final int createdAt;
  final int updatedAt;
  const PeerRow({
    required this.id,
    required this.peerId,
    required this.displayName,
    this.deviceLabel,
    this.fingerprint,
    required this.relationshipState,
    required this.isBlocked,
    this.lastSeenAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['peer_id'] = Variable<String>(peerId);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || deviceLabel != null) {
      map['device_label'] = Variable<String>(deviceLabel);
    }
    if (!nullToAbsent || fingerprint != null) {
      map['fingerprint'] = Variable<String>(fingerprint);
    }
    map['relationship_state'] = Variable<String>(relationshipState);
    map['is_blocked'] = Variable<bool>(isBlocked);
    if (!nullToAbsent || lastSeenAt != null) {
      map['last_seen_at'] = Variable<int>(lastSeenAt);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  PeersTableCompanion toCompanion(bool nullToAbsent) {
    return PeersTableCompanion(
      id: Value(id),
      peerId: Value(peerId),
      displayName: Value(displayName),
      deviceLabel: deviceLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceLabel),
      fingerprint: fingerprint == null && nullToAbsent
          ? const Value.absent()
          : Value(fingerprint),
      relationshipState: Value(relationshipState),
      isBlocked: Value(isBlocked),
      lastSeenAt: lastSeenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeenAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PeerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PeerRow(
      id: serializer.fromJson<String>(json['id']),
      peerId: serializer.fromJson<String>(json['peerId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      deviceLabel: serializer.fromJson<String?>(json['deviceLabel']),
      fingerprint: serializer.fromJson<String?>(json['fingerprint']),
      relationshipState: serializer.fromJson<String>(json['relationshipState']),
      isBlocked: serializer.fromJson<bool>(json['isBlocked']),
      lastSeenAt: serializer.fromJson<int?>(json['lastSeenAt']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'peerId': serializer.toJson<String>(peerId),
      'displayName': serializer.toJson<String>(displayName),
      'deviceLabel': serializer.toJson<String?>(deviceLabel),
      'fingerprint': serializer.toJson<String?>(fingerprint),
      'relationshipState': serializer.toJson<String>(relationshipState),
      'isBlocked': serializer.toJson<bool>(isBlocked),
      'lastSeenAt': serializer.toJson<int?>(lastSeenAt),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  PeerRow copyWith({
    String? id,
    String? peerId,
    String? displayName,
    Value<String?> deviceLabel = const Value.absent(),
    Value<String?> fingerprint = const Value.absent(),
    String? relationshipState,
    bool? isBlocked,
    Value<int?> lastSeenAt = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => PeerRow(
    id: id ?? this.id,
    peerId: peerId ?? this.peerId,
    displayName: displayName ?? this.displayName,
    deviceLabel: deviceLabel.present ? deviceLabel.value : this.deviceLabel,
    fingerprint: fingerprint.present ? fingerprint.value : this.fingerprint,
    relationshipState: relationshipState ?? this.relationshipState,
    isBlocked: isBlocked ?? this.isBlocked,
    lastSeenAt: lastSeenAt.present ? lastSeenAt.value : this.lastSeenAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PeerRow copyWithCompanion(PeersTableCompanion data) {
    return PeerRow(
      id: data.id.present ? data.id.value : this.id,
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      deviceLabel: data.deviceLabel.present
          ? data.deviceLabel.value
          : this.deviceLabel,
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
      relationshipState: data.relationshipState.present
          ? data.relationshipState.value
          : this.relationshipState,
      isBlocked: data.isBlocked.present ? data.isBlocked.value : this.isBlocked,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PeerRow(')
          ..write('id: $id, ')
          ..write('peerId: $peerId, ')
          ..write('displayName: $displayName, ')
          ..write('deviceLabel: $deviceLabel, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('relationshipState: $relationshipState, ')
          ..write('isBlocked: $isBlocked, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    peerId,
    displayName,
    deviceLabel,
    fingerprint,
    relationshipState,
    isBlocked,
    lastSeenAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeerRow &&
          other.id == this.id &&
          other.peerId == this.peerId &&
          other.displayName == this.displayName &&
          other.deviceLabel == this.deviceLabel &&
          other.fingerprint == this.fingerprint &&
          other.relationshipState == this.relationshipState &&
          other.isBlocked == this.isBlocked &&
          other.lastSeenAt == this.lastSeenAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PeersTableCompanion extends UpdateCompanion<PeerRow> {
  final Value<String> id;
  final Value<String> peerId;
  final Value<String> displayName;
  final Value<String?> deviceLabel;
  final Value<String?> fingerprint;
  final Value<String> relationshipState;
  final Value<bool> isBlocked;
  final Value<int?> lastSeenAt;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const PeersTableCompanion({
    this.id = const Value.absent(),
    this.peerId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.deviceLabel = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.relationshipState = const Value.absent(),
    this.isBlocked = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PeersTableCompanion.insert({
    required String id,
    required String peerId,
    required String displayName,
    this.deviceLabel = const Value.absent(),
    this.fingerprint = const Value.absent(),
    required String relationshipState,
    this.isBlocked = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       peerId = Value(peerId),
       displayName = Value(displayName),
       relationshipState = Value(relationshipState),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PeerRow> custom({
    Expression<String>? id,
    Expression<String>? peerId,
    Expression<String>? displayName,
    Expression<String>? deviceLabel,
    Expression<String>? fingerprint,
    Expression<String>? relationshipState,
    Expression<bool>? isBlocked,
    Expression<int>? lastSeenAt,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (peerId != null) 'peer_id': peerId,
      if (displayName != null) 'display_name': displayName,
      if (deviceLabel != null) 'device_label': deviceLabel,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (relationshipState != null) 'relationship_state': relationshipState,
      if (isBlocked != null) 'is_blocked': isBlocked,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PeersTableCompanion copyWith({
    Value<String>? id,
    Value<String>? peerId,
    Value<String>? displayName,
    Value<String?>? deviceLabel,
    Value<String?>? fingerprint,
    Value<String>? relationshipState,
    Value<bool>? isBlocked,
    Value<int?>? lastSeenAt,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return PeersTableCompanion(
      id: id ?? this.id,
      peerId: peerId ?? this.peerId,
      displayName: displayName ?? this.displayName,
      deviceLabel: deviceLabel ?? this.deviceLabel,
      fingerprint: fingerprint ?? this.fingerprint,
      relationshipState: relationshipState ?? this.relationshipState,
      isBlocked: isBlocked ?? this.isBlocked,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
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
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (deviceLabel.present) {
      map['device_label'] = Variable<String>(deviceLabel.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (relationshipState.present) {
      map['relationship_state'] = Variable<String>(relationshipState.value);
    }
    if (isBlocked.present) {
      map['is_blocked'] = Variable<bool>(isBlocked.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<int>(lastSeenAt.value);
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
    return (StringBuffer('PeersTableCompanion(')
          ..write('id: $id, ')
          ..write('peerId: $peerId, ')
          ..write('displayName: $displayName, ')
          ..write('deviceLabel: $deviceLabel, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('relationshipState: $relationshipState, ')
          ..write('isBlocked: $isBlocked, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PresenceTableTable extends PresenceTable
    with TableInfo<$PresenceTableTable, PresenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PresenceTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _peerIdMeta = const VerificationMeta('peerId');
  @override
  late final GeneratedColumn<String> peerId = GeneratedColumn<String>(
    'peer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transportTypeMeta = const VerificationMeta(
    'transportType',
  );
  @override
  late final GeneratedColumn<String> transportType = GeneratedColumn<String>(
    'transport_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hostMeta = const VerificationMeta('host');
  @override
  late final GeneratedColumn<String> host = GeneratedColumn<String>(
    'host',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _portMeta = const VerificationMeta('port');
  @override
  late final GeneratedColumn<int> port = GeneratedColumn<int>(
    'port',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastHeartbeatAtMeta = const VerificationMeta(
    'lastHeartbeatAt',
  );
  @override
  late final GeneratedColumn<int> lastHeartbeatAt = GeneratedColumn<int>(
    'last_heartbeat_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastProbeAtMeta = const VerificationMeta(
    'lastProbeAt',
  );
  @override
  late final GeneratedColumn<int> lastProbeAt = GeneratedColumn<int>(
    'last_probe_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isReachableMeta = const VerificationMeta(
    'isReachable',
  );
  @override
  late final GeneratedColumn<bool> isReachable = GeneratedColumn<bool>(
    'is_reachable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_reachable" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    peerId,
    status,
    transportType,
    host,
    port,
    lastHeartbeatAt,
    lastProbeAt,
    isReachable,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'presence_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<PresenceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('peer_id')) {
      context.handle(
        _peerIdMeta,
        peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_peerIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('transport_type')) {
      context.handle(
        _transportTypeMeta,
        transportType.isAcceptableOrUnknown(
          data['transport_type']!,
          _transportTypeMeta,
        ),
      );
    }
    if (data.containsKey('host')) {
      context.handle(
        _hostMeta,
        host.isAcceptableOrUnknown(data['host']!, _hostMeta),
      );
    }
    if (data.containsKey('port')) {
      context.handle(
        _portMeta,
        port.isAcceptableOrUnknown(data['port']!, _portMeta),
      );
    }
    if (data.containsKey('last_heartbeat_at')) {
      context.handle(
        _lastHeartbeatAtMeta,
        lastHeartbeatAt.isAcceptableOrUnknown(
          data['last_heartbeat_at']!,
          _lastHeartbeatAtMeta,
        ),
      );
    }
    if (data.containsKey('last_probe_at')) {
      context.handle(
        _lastProbeAtMeta,
        lastProbeAt.isAcceptableOrUnknown(
          data['last_probe_at']!,
          _lastProbeAtMeta,
        ),
      );
    }
    if (data.containsKey('is_reachable')) {
      context.handle(
        _isReachableMeta,
        isReachable.isAcceptableOrUnknown(
          data['is_reachable']!,
          _isReachableMeta,
        ),
      );
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
  PresenceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PresenceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      peerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      transportType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transport_type'],
      ),
      host: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host'],
      ),
      port: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}port'],
      ),
      lastHeartbeatAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_heartbeat_at'],
      ),
      lastProbeAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_probe_at'],
      ),
      isReachable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_reachable'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PresenceTableTable createAlias(String alias) {
    return $PresenceTableTable(attachedDatabase, alias);
  }
}

class PresenceRow extends DataClass implements Insertable<PresenceRow> {
  final String id;
  final String peerId;
  final String status;
  final String? transportType;
  final String? host;
  final int? port;
  final int? lastHeartbeatAt;
  final int? lastProbeAt;
  final bool isReachable;
  final int updatedAt;
  const PresenceRow({
    required this.id,
    required this.peerId,
    required this.status,
    this.transportType,
    this.host,
    this.port,
    this.lastHeartbeatAt,
    this.lastProbeAt,
    required this.isReachable,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['peer_id'] = Variable<String>(peerId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || transportType != null) {
      map['transport_type'] = Variable<String>(transportType);
    }
    if (!nullToAbsent || host != null) {
      map['host'] = Variable<String>(host);
    }
    if (!nullToAbsent || port != null) {
      map['port'] = Variable<int>(port);
    }
    if (!nullToAbsent || lastHeartbeatAt != null) {
      map['last_heartbeat_at'] = Variable<int>(lastHeartbeatAt);
    }
    if (!nullToAbsent || lastProbeAt != null) {
      map['last_probe_at'] = Variable<int>(lastProbeAt);
    }
    map['is_reachable'] = Variable<bool>(isReachable);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  PresenceTableCompanion toCompanion(bool nullToAbsent) {
    return PresenceTableCompanion(
      id: Value(id),
      peerId: Value(peerId),
      status: Value(status),
      transportType: transportType == null && nullToAbsent
          ? const Value.absent()
          : Value(transportType),
      host: host == null && nullToAbsent ? const Value.absent() : Value(host),
      port: port == null && nullToAbsent ? const Value.absent() : Value(port),
      lastHeartbeatAt: lastHeartbeatAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastHeartbeatAt),
      lastProbeAt: lastProbeAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastProbeAt),
      isReachable: Value(isReachable),
      updatedAt: Value(updatedAt),
    );
  }

  factory PresenceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PresenceRow(
      id: serializer.fromJson<String>(json['id']),
      peerId: serializer.fromJson<String>(json['peerId']),
      status: serializer.fromJson<String>(json['status']),
      transportType: serializer.fromJson<String?>(json['transportType']),
      host: serializer.fromJson<String?>(json['host']),
      port: serializer.fromJson<int?>(json['port']),
      lastHeartbeatAt: serializer.fromJson<int?>(json['lastHeartbeatAt']),
      lastProbeAt: serializer.fromJson<int?>(json['lastProbeAt']),
      isReachable: serializer.fromJson<bool>(json['isReachable']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'peerId': serializer.toJson<String>(peerId),
      'status': serializer.toJson<String>(status),
      'transportType': serializer.toJson<String?>(transportType),
      'host': serializer.toJson<String?>(host),
      'port': serializer.toJson<int?>(port),
      'lastHeartbeatAt': serializer.toJson<int?>(lastHeartbeatAt),
      'lastProbeAt': serializer.toJson<int?>(lastProbeAt),
      'isReachable': serializer.toJson<bool>(isReachable),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  PresenceRow copyWith({
    String? id,
    String? peerId,
    String? status,
    Value<String?> transportType = const Value.absent(),
    Value<String?> host = const Value.absent(),
    Value<int?> port = const Value.absent(),
    Value<int?> lastHeartbeatAt = const Value.absent(),
    Value<int?> lastProbeAt = const Value.absent(),
    bool? isReachable,
    int? updatedAt,
  }) => PresenceRow(
    id: id ?? this.id,
    peerId: peerId ?? this.peerId,
    status: status ?? this.status,
    transportType: transportType.present
        ? transportType.value
        : this.transportType,
    host: host.present ? host.value : this.host,
    port: port.present ? port.value : this.port,
    lastHeartbeatAt: lastHeartbeatAt.present
        ? lastHeartbeatAt.value
        : this.lastHeartbeatAt,
    lastProbeAt: lastProbeAt.present ? lastProbeAt.value : this.lastProbeAt,
    isReachable: isReachable ?? this.isReachable,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PresenceRow copyWithCompanion(PresenceTableCompanion data) {
    return PresenceRow(
      id: data.id.present ? data.id.value : this.id,
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      status: data.status.present ? data.status.value : this.status,
      transportType: data.transportType.present
          ? data.transportType.value
          : this.transportType,
      host: data.host.present ? data.host.value : this.host,
      port: data.port.present ? data.port.value : this.port,
      lastHeartbeatAt: data.lastHeartbeatAt.present
          ? data.lastHeartbeatAt.value
          : this.lastHeartbeatAt,
      lastProbeAt: data.lastProbeAt.present
          ? data.lastProbeAt.value
          : this.lastProbeAt,
      isReachable: data.isReachable.present
          ? data.isReachable.value
          : this.isReachable,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PresenceRow(')
          ..write('id: $id, ')
          ..write('peerId: $peerId, ')
          ..write('status: $status, ')
          ..write('transportType: $transportType, ')
          ..write('host: $host, ')
          ..write('port: $port, ')
          ..write('lastHeartbeatAt: $lastHeartbeatAt, ')
          ..write('lastProbeAt: $lastProbeAt, ')
          ..write('isReachable: $isReachable, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    peerId,
    status,
    transportType,
    host,
    port,
    lastHeartbeatAt,
    lastProbeAt,
    isReachable,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PresenceRow &&
          other.id == this.id &&
          other.peerId == this.peerId &&
          other.status == this.status &&
          other.transportType == this.transportType &&
          other.host == this.host &&
          other.port == this.port &&
          other.lastHeartbeatAt == this.lastHeartbeatAt &&
          other.lastProbeAt == this.lastProbeAt &&
          other.isReachable == this.isReachable &&
          other.updatedAt == this.updatedAt);
}

class PresenceTableCompanion extends UpdateCompanion<PresenceRow> {
  final Value<String> id;
  final Value<String> peerId;
  final Value<String> status;
  final Value<String?> transportType;
  final Value<String?> host;
  final Value<int?> port;
  final Value<int?> lastHeartbeatAt;
  final Value<int?> lastProbeAt;
  final Value<bool> isReachable;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const PresenceTableCompanion({
    this.id = const Value.absent(),
    this.peerId = const Value.absent(),
    this.status = const Value.absent(),
    this.transportType = const Value.absent(),
    this.host = const Value.absent(),
    this.port = const Value.absent(),
    this.lastHeartbeatAt = const Value.absent(),
    this.lastProbeAt = const Value.absent(),
    this.isReachable = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PresenceTableCompanion.insert({
    required String id,
    required String peerId,
    required String status,
    this.transportType = const Value.absent(),
    this.host = const Value.absent(),
    this.port = const Value.absent(),
    this.lastHeartbeatAt = const Value.absent(),
    this.lastProbeAt = const Value.absent(),
    this.isReachable = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       peerId = Value(peerId),
       status = Value(status),
       updatedAt = Value(updatedAt);
  static Insertable<PresenceRow> custom({
    Expression<String>? id,
    Expression<String>? peerId,
    Expression<String>? status,
    Expression<String>? transportType,
    Expression<String>? host,
    Expression<int>? port,
    Expression<int>? lastHeartbeatAt,
    Expression<int>? lastProbeAt,
    Expression<bool>? isReachable,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (peerId != null) 'peer_id': peerId,
      if (status != null) 'status': status,
      if (transportType != null) 'transport_type': transportType,
      if (host != null) 'host': host,
      if (port != null) 'port': port,
      if (lastHeartbeatAt != null) 'last_heartbeat_at': lastHeartbeatAt,
      if (lastProbeAt != null) 'last_probe_at': lastProbeAt,
      if (isReachable != null) 'is_reachable': isReachable,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PresenceTableCompanion copyWith({
    Value<String>? id,
    Value<String>? peerId,
    Value<String>? status,
    Value<String?>? transportType,
    Value<String?>? host,
    Value<int?>? port,
    Value<int?>? lastHeartbeatAt,
    Value<int?>? lastProbeAt,
    Value<bool>? isReachable,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return PresenceTableCompanion(
      id: id ?? this.id,
      peerId: peerId ?? this.peerId,
      status: status ?? this.status,
      transportType: transportType ?? this.transportType,
      host: host ?? this.host,
      port: port ?? this.port,
      lastHeartbeatAt: lastHeartbeatAt ?? this.lastHeartbeatAt,
      lastProbeAt: lastProbeAt ?? this.lastProbeAt,
      isReachable: isReachable ?? this.isReachable,
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
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (transportType.present) {
      map['transport_type'] = Variable<String>(transportType.value);
    }
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    if (port.present) {
      map['port'] = Variable<int>(port.value);
    }
    if (lastHeartbeatAt.present) {
      map['last_heartbeat_at'] = Variable<int>(lastHeartbeatAt.value);
    }
    if (lastProbeAt.present) {
      map['last_probe_at'] = Variable<int>(lastProbeAt.value);
    }
    if (isReachable.present) {
      map['is_reachable'] = Variable<bool>(isReachable.value);
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
    return (StringBuffer('PresenceTableCompanion(')
          ..write('id: $id, ')
          ..write('peerId: $peerId, ')
          ..write('status: $status, ')
          ..write('transportType: $transportType, ')
          ..write('host: $host, ')
          ..write('port: $port, ')
          ..write('lastHeartbeatAt: $lastHeartbeatAt, ')
          ..write('lastProbeAt: $lastProbeAt, ')
          ..write('isReachable: $isReachable, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContactRequestsTableTable extends ContactRequestsTable
    with TableInfo<$ContactRequestsTableTable, ContactRequestRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContactRequestsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _peerIdMeta = const VerificationMeta('peerId');
  @override
  late final GeneratedColumn<String> peerId = GeneratedColumn<String>(
    'peer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
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
  static const VerificationMeta _respondedAtMeta = const VerificationMeta(
    'respondedAt',
  );
  @override
  late final GeneratedColumn<int> respondedAt = GeneratedColumn<int>(
    'responded_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
    peerId,
    direction,
    status,
    message,
    createdAt,
    respondedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contact_requests_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContactRequestRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('peer_id')) {
      context.handle(
        _peerIdMeta,
        peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_peerIdMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
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
    if (data.containsKey('responded_at')) {
      context.handle(
        _respondedAtMeta,
        respondedAt.isAcceptableOrUnknown(
          data['responded_at']!,
          _respondedAtMeta,
        ),
      );
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
  ContactRequestRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContactRequestRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      peerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_id'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      respondedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}responded_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ContactRequestsTableTable createAlias(String alias) {
    return $ContactRequestsTableTable(attachedDatabase, alias);
  }
}

class ContactRequestRow extends DataClass
    implements Insertable<ContactRequestRow> {
  final String id;
  final String peerId;
  final String direction;
  final String status;
  final String? message;
  final int createdAt;
  final int? respondedAt;
  final int updatedAt;
  const ContactRequestRow({
    required this.id,
    required this.peerId,
    required this.direction,
    required this.status,
    this.message,
    required this.createdAt,
    this.respondedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['peer_id'] = Variable<String>(peerId);
    map['direction'] = Variable<String>(direction);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || message != null) {
      map['message'] = Variable<String>(message);
    }
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || respondedAt != null) {
      map['responded_at'] = Variable<int>(respondedAt);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ContactRequestsTableCompanion toCompanion(bool nullToAbsent) {
    return ContactRequestsTableCompanion(
      id: Value(id),
      peerId: Value(peerId),
      direction: Value(direction),
      status: Value(status),
      message: message == null && nullToAbsent
          ? const Value.absent()
          : Value(message),
      createdAt: Value(createdAt),
      respondedAt: respondedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(respondedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ContactRequestRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContactRequestRow(
      id: serializer.fromJson<String>(json['id']),
      peerId: serializer.fromJson<String>(json['peerId']),
      direction: serializer.fromJson<String>(json['direction']),
      status: serializer.fromJson<String>(json['status']),
      message: serializer.fromJson<String?>(json['message']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      respondedAt: serializer.fromJson<int?>(json['respondedAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'peerId': serializer.toJson<String>(peerId),
      'direction': serializer.toJson<String>(direction),
      'status': serializer.toJson<String>(status),
      'message': serializer.toJson<String?>(message),
      'createdAt': serializer.toJson<int>(createdAt),
      'respondedAt': serializer.toJson<int?>(respondedAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ContactRequestRow copyWith({
    String? id,
    String? peerId,
    String? direction,
    String? status,
    Value<String?> message = const Value.absent(),
    int? createdAt,
    Value<int?> respondedAt = const Value.absent(),
    int? updatedAt,
  }) => ContactRequestRow(
    id: id ?? this.id,
    peerId: peerId ?? this.peerId,
    direction: direction ?? this.direction,
    status: status ?? this.status,
    message: message.present ? message.value : this.message,
    createdAt: createdAt ?? this.createdAt,
    respondedAt: respondedAt.present ? respondedAt.value : this.respondedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ContactRequestRow copyWithCompanion(ContactRequestsTableCompanion data) {
    return ContactRequestRow(
      id: data.id.present ? data.id.value : this.id,
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      direction: data.direction.present ? data.direction.value : this.direction,
      status: data.status.present ? data.status.value : this.status,
      message: data.message.present ? data.message.value : this.message,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      respondedAt: data.respondedAt.present
          ? data.respondedAt.value
          : this.respondedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContactRequestRow(')
          ..write('id: $id, ')
          ..write('peerId: $peerId, ')
          ..write('direction: $direction, ')
          ..write('status: $status, ')
          ..write('message: $message, ')
          ..write('createdAt: $createdAt, ')
          ..write('respondedAt: $respondedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    peerId,
    direction,
    status,
    message,
    createdAt,
    respondedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContactRequestRow &&
          other.id == this.id &&
          other.peerId == this.peerId &&
          other.direction == this.direction &&
          other.status == this.status &&
          other.message == this.message &&
          other.createdAt == this.createdAt &&
          other.respondedAt == this.respondedAt &&
          other.updatedAt == this.updatedAt);
}

class ContactRequestsTableCompanion extends UpdateCompanion<ContactRequestRow> {
  final Value<String> id;
  final Value<String> peerId;
  final Value<String> direction;
  final Value<String> status;
  final Value<String?> message;
  final Value<int> createdAt;
  final Value<int?> respondedAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ContactRequestsTableCompanion({
    this.id = const Value.absent(),
    this.peerId = const Value.absent(),
    this.direction = const Value.absent(),
    this.status = const Value.absent(),
    this.message = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.respondedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContactRequestsTableCompanion.insert({
    required String id,
    required String peerId,
    required String direction,
    required String status,
    this.message = const Value.absent(),
    required int createdAt,
    this.respondedAt = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       peerId = Value(peerId),
       direction = Value(direction),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ContactRequestRow> custom({
    Expression<String>? id,
    Expression<String>? peerId,
    Expression<String>? direction,
    Expression<String>? status,
    Expression<String>? message,
    Expression<int>? createdAt,
    Expression<int>? respondedAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (peerId != null) 'peer_id': peerId,
      if (direction != null) 'direction': direction,
      if (status != null) 'status': status,
      if (message != null) 'message': message,
      if (createdAt != null) 'created_at': createdAt,
      if (respondedAt != null) 'responded_at': respondedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContactRequestsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? peerId,
    Value<String>? direction,
    Value<String>? status,
    Value<String?>? message,
    Value<int>? createdAt,
    Value<int?>? respondedAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ContactRequestsTableCompanion(
      id: id ?? this.id,
      peerId: peerId ?? this.peerId,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
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
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (respondedAt.present) {
      map['responded_at'] = Variable<int>(respondedAt.value);
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
    return (StringBuffer('ContactRequestsTableCompanion(')
          ..write('id: $id, ')
          ..write('peerId: $peerId, ')
          ..write('direction: $direction, ')
          ..write('status: $status, ')
          ..write('message: $message, ')
          ..write('createdAt: $createdAt, ')
          ..write('respondedAt: $respondedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationsTableTable extends ConversationsTable
    with TableInfo<$ConversationsTableTable, ConversationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pinnedMessageIdMeta = const VerificationMeta(
    'pinnedMessageId',
  );
  @override
  late final GeneratedColumn<String> pinnedMessageId = GeneratedColumn<String>(
    'pinned_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastMessagePreviewMeta =
      const VerificationMeta('lastMessagePreview');
  @override
  late final GeneratedColumn<String> lastMessagePreview =
      GeneratedColumn<String>(
        'last_message_preview',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastMessageAtMeta = const VerificationMeta(
    'lastMessageAt',
  );
  @override
  late final GeneratedColumn<int> lastMessageAt = GeneratedColumn<int>(
    'last_message_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unreadCountMeta = const VerificationMeta(
    'unreadCount',
  );
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
    'unread_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isMutedMeta = const VerificationMeta(
    'isMuted',
  );
  @override
  late final GeneratedColumn<bool> isMuted = GeneratedColumn<bool>(
    'is_muted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_muted" IN (0, 1))',
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
    type,
    title,
    pinnedMessageId,
    lastMessagePreview,
    lastMessageAt,
    unreadCount,
    isArchived,
    isMuted,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('pinned_message_id')) {
      context.handle(
        _pinnedMessageIdMeta,
        pinnedMessageId.isAcceptableOrUnknown(
          data['pinned_message_id']!,
          _pinnedMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('last_message_preview')) {
      context.handle(
        _lastMessagePreviewMeta,
        lastMessagePreview.isAcceptableOrUnknown(
          data['last_message_preview']!,
          _lastMessagePreviewMeta,
        ),
      );
    }
    if (data.containsKey('last_message_at')) {
      context.handle(
        _lastMessageAtMeta,
        lastMessageAt.isAcceptableOrUnknown(
          data['last_message_at']!,
          _lastMessageAtMeta,
        ),
      );
    }
    if (data.containsKey('unread_count')) {
      context.handle(
        _unreadCountMeta,
        unreadCount.isAcceptableOrUnknown(
          data['unread_count']!,
          _unreadCountMeta,
        ),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('is_muted')) {
      context.handle(
        _isMutedMeta,
        isMuted.isAcceptableOrUnknown(data['is_muted']!, _isMutedMeta),
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
  ConversationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      pinnedMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pinned_message_id'],
      ),
      lastMessagePreview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message_preview'],
      ),
      lastMessageAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_message_at'],
      ),
      unreadCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unread_count'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      isMuted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_muted'],
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
  $ConversationsTableTable createAlias(String alias) {
    return $ConversationsTableTable(attachedDatabase, alias);
  }
}

class ConversationRow extends DataClass implements Insertable<ConversationRow> {
  final String id;
  final String type;
  final String? title;
  final String? pinnedMessageId;
  final String? lastMessagePreview;
  final int? lastMessageAt;
  final int unreadCount;
  final bool isArchived;
  final bool isMuted;
  final int createdAt;
  final int updatedAt;
  const ConversationRow({
    required this.id,
    required this.type,
    this.title,
    this.pinnedMessageId,
    this.lastMessagePreview,
    this.lastMessageAt,
    required this.unreadCount,
    required this.isArchived,
    required this.isMuted,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || pinnedMessageId != null) {
      map['pinned_message_id'] = Variable<String>(pinnedMessageId);
    }
    if (!nullToAbsent || lastMessagePreview != null) {
      map['last_message_preview'] = Variable<String>(lastMessagePreview);
    }
    if (!nullToAbsent || lastMessageAt != null) {
      map['last_message_at'] = Variable<int>(lastMessageAt);
    }
    map['unread_count'] = Variable<int>(unreadCount);
    map['is_archived'] = Variable<bool>(isArchived);
    map['is_muted'] = Variable<bool>(isMuted);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ConversationsTableCompanion toCompanion(bool nullToAbsent) {
    return ConversationsTableCompanion(
      id: Value(id),
      type: Value(type),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      pinnedMessageId: pinnedMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(pinnedMessageId),
      lastMessagePreview: lastMessagePreview == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessagePreview),
      lastMessageAt: lastMessageAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageAt),
      unreadCount: Value(unreadCount),
      isArchived: Value(isArchived),
      isMuted: Value(isMuted),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ConversationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationRow(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String?>(json['title']),
      pinnedMessageId: serializer.fromJson<String?>(json['pinnedMessageId']),
      lastMessagePreview: serializer.fromJson<String?>(
        json['lastMessagePreview'],
      ),
      lastMessageAt: serializer.fromJson<int?>(json['lastMessageAt']),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      isMuted: serializer.fromJson<bool>(json['isMuted']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String?>(title),
      'pinnedMessageId': serializer.toJson<String?>(pinnedMessageId),
      'lastMessagePreview': serializer.toJson<String?>(lastMessagePreview),
      'lastMessageAt': serializer.toJson<int?>(lastMessageAt),
      'unreadCount': serializer.toJson<int>(unreadCount),
      'isArchived': serializer.toJson<bool>(isArchived),
      'isMuted': serializer.toJson<bool>(isMuted),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ConversationRow copyWith({
    String? id,
    String? type,
    Value<String?> title = const Value.absent(),
    Value<String?> pinnedMessageId = const Value.absent(),
    Value<String?> lastMessagePreview = const Value.absent(),
    Value<int?> lastMessageAt = const Value.absent(),
    int? unreadCount,
    bool? isArchived,
    bool? isMuted,
    int? createdAt,
    int? updatedAt,
  }) => ConversationRow(
    id: id ?? this.id,
    type: type ?? this.type,
    title: title.present ? title.value : this.title,
    pinnedMessageId: pinnedMessageId.present
        ? pinnedMessageId.value
        : this.pinnedMessageId,
    lastMessagePreview: lastMessagePreview.present
        ? lastMessagePreview.value
        : this.lastMessagePreview,
    lastMessageAt: lastMessageAt.present
        ? lastMessageAt.value
        : this.lastMessageAt,
    unreadCount: unreadCount ?? this.unreadCount,
    isArchived: isArchived ?? this.isArchived,
    isMuted: isMuted ?? this.isMuted,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ConversationRow copyWithCompanion(ConversationsTableCompanion data) {
    return ConversationRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      pinnedMessageId: data.pinnedMessageId.present
          ? data.pinnedMessageId.value
          : this.pinnedMessageId,
      lastMessagePreview: data.lastMessagePreview.present
          ? data.lastMessagePreview.value
          : this.lastMessagePreview,
      lastMessageAt: data.lastMessageAt.present
          ? data.lastMessageAt.value
          : this.lastMessageAt,
      unreadCount: data.unreadCount.present
          ? data.unreadCount.value
          : this.unreadCount,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      isMuted: data.isMuted.present ? data.isMuted.value : this.isMuted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('pinnedMessageId: $pinnedMessageId, ')
          ..write('lastMessagePreview: $lastMessagePreview, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('isArchived: $isArchived, ')
          ..write('isMuted: $isMuted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    title,
    pinnedMessageId,
    lastMessagePreview,
    lastMessageAt,
    unreadCount,
    isArchived,
    isMuted,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.title == this.title &&
          other.pinnedMessageId == this.pinnedMessageId &&
          other.lastMessagePreview == this.lastMessagePreview &&
          other.lastMessageAt == this.lastMessageAt &&
          other.unreadCount == this.unreadCount &&
          other.isArchived == this.isArchived &&
          other.isMuted == this.isMuted &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ConversationsTableCompanion extends UpdateCompanion<ConversationRow> {
  final Value<String> id;
  final Value<String> type;
  final Value<String?> title;
  final Value<String?> pinnedMessageId;
  final Value<String?> lastMessagePreview;
  final Value<int?> lastMessageAt;
  final Value<int> unreadCount;
  final Value<bool> isArchived;
  final Value<bool> isMuted;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ConversationsTableCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.pinnedMessageId = const Value.absent(),
    this.lastMessagePreview = const Value.absent(),
    this.lastMessageAt = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.isMuted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationsTableCompanion.insert({
    required String id,
    required String type,
    this.title = const Value.absent(),
    this.pinnedMessageId = const Value.absent(),
    this.lastMessagePreview = const Value.absent(),
    this.lastMessageAt = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.isMuted = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ConversationRow> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? pinnedMessageId,
    Expression<String>? lastMessagePreview,
    Expression<int>? lastMessageAt,
    Expression<int>? unreadCount,
    Expression<bool>? isArchived,
    Expression<bool>? isMuted,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (pinnedMessageId != null) 'pinned_message_id': pinnedMessageId,
      if (lastMessagePreview != null)
        'last_message_preview': lastMessagePreview,
      if (lastMessageAt != null) 'last_message_at': lastMessageAt,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (isArchived != null) 'is_archived': isArchived,
      if (isMuted != null) 'is_muted': isMuted,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String?>? title,
    Value<String?>? pinnedMessageId,
    Value<String?>? lastMessagePreview,
    Value<int?>? lastMessageAt,
    Value<int>? unreadCount,
    Value<bool>? isArchived,
    Value<bool>? isMuted,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ConversationsTableCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      pinnedMessageId: pinnedMessageId ?? this.pinnedMessageId,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isArchived: isArchived ?? this.isArchived,
      isMuted: isMuted ?? this.isMuted,
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
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (pinnedMessageId.present) {
      map['pinned_message_id'] = Variable<String>(pinnedMessageId.value);
    }
    if (lastMessagePreview.present) {
      map['last_message_preview'] = Variable<String>(lastMessagePreview.value);
    }
    if (lastMessageAt.present) {
      map['last_message_at'] = Variable<int>(lastMessageAt.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (isMuted.present) {
      map['is_muted'] = Variable<bool>(isMuted.value);
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
    return (StringBuffer('ConversationsTableCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('pinnedMessageId: $pinnedMessageId, ')
          ..write('lastMessagePreview: $lastMessagePreview, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('isArchived: $isArchived, ')
          ..write('isMuted: $isMuted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationMembersTableTable extends ConversationMembersTable
    with TableInfo<$ConversationMembersTableTable, ConversationMemberRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationMembersTableTable(this.attachedDatabase, [this._alias]);
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
  );
  static const VerificationMeta _peerIdMeta = const VerificationMeta('peerId');
  @override
  late final GeneratedColumn<String> peerId = GeneratedColumn<String>(
    'peer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _joinedAtMeta = const VerificationMeta(
    'joinedAt',
  );
  @override
  late final GeneratedColumn<int> joinedAt = GeneratedColumn<int>(
    'joined_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    peerId,
    role,
    joinedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation_members_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationMemberRow> instance, {
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
    if (data.containsKey('peer_id')) {
      context.handle(
        _peerIdMeta,
        peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_peerIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('joined_at')) {
      context.handle(
        _joinedAtMeta,
        joinedAt.isAcceptableOrUnknown(data['joined_at']!, _joinedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_joinedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {conversationId, peerId},
  ];
  @override
  ConversationMemberRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationMemberRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      peerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      joinedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}joined_at'],
      )!,
    );
  }

  @override
  $ConversationMembersTableTable createAlias(String alias) {
    return $ConversationMembersTableTable(attachedDatabase, alias);
  }
}

class ConversationMemberRow extends DataClass
    implements Insertable<ConversationMemberRow> {
  final String id;
  final String conversationId;
  final String peerId;
  final String role;
  final int joinedAt;
  const ConversationMemberRow({
    required this.id,
    required this.conversationId,
    required this.peerId,
    required this.role,
    required this.joinedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['peer_id'] = Variable<String>(peerId);
    map['role'] = Variable<String>(role);
    map['joined_at'] = Variable<int>(joinedAt);
    return map;
  }

  ConversationMembersTableCompanion toCompanion(bool nullToAbsent) {
    return ConversationMembersTableCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      peerId: Value(peerId),
      role: Value(role),
      joinedAt: Value(joinedAt),
    );
  }

  factory ConversationMemberRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationMemberRow(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      peerId: serializer.fromJson<String>(json['peerId']),
      role: serializer.fromJson<String>(json['role']),
      joinedAt: serializer.fromJson<int>(json['joinedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'peerId': serializer.toJson<String>(peerId),
      'role': serializer.toJson<String>(role),
      'joinedAt': serializer.toJson<int>(joinedAt),
    };
  }

  ConversationMemberRow copyWith({
    String? id,
    String? conversationId,
    String? peerId,
    String? role,
    int? joinedAt,
  }) => ConversationMemberRow(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    peerId: peerId ?? this.peerId,
    role: role ?? this.role,
    joinedAt: joinedAt ?? this.joinedAt,
  );
  ConversationMemberRow copyWithCompanion(
    ConversationMembersTableCompanion data,
  ) {
    return ConversationMemberRow(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      role: data.role.present ? data.role.value : this.role,
      joinedAt: data.joinedAt.present ? data.joinedAt.value : this.joinedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationMemberRow(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('peerId: $peerId, ')
          ..write('role: $role, ')
          ..write('joinedAt: $joinedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, conversationId, peerId, role, joinedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationMemberRow &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.peerId == this.peerId &&
          other.role == this.role &&
          other.joinedAt == this.joinedAt);
}

class ConversationMembersTableCompanion
    extends UpdateCompanion<ConversationMemberRow> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> peerId;
  final Value<String> role;
  final Value<int> joinedAt;
  final Value<int> rowid;
  const ConversationMembersTableCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.peerId = const Value.absent(),
    this.role = const Value.absent(),
    this.joinedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationMembersTableCompanion.insert({
    required String id,
    required String conversationId,
    required String peerId,
    required String role,
    required int joinedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       peerId = Value(peerId),
       role = Value(role),
       joinedAt = Value(joinedAt);
  static Insertable<ConversationMemberRow> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? peerId,
    Expression<String>? role,
    Expression<int>? joinedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (peerId != null) 'peer_id': peerId,
      if (role != null) 'role': role,
      if (joinedAt != null) 'joined_at': joinedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationMembersTableCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String>? peerId,
    Value<String>? role,
    Value<int>? joinedAt,
    Value<int>? rowid,
  }) {
    return ConversationMembersTableCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      peerId: peerId ?? this.peerId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
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
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (joinedAt.present) {
      map['joined_at'] = Variable<int>(joinedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationMembersTableCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('peerId: $peerId, ')
          ..write('role: $role, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTableTable extends MessagesTable
    with TableInfo<$MessagesTableTable, MessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTableTable(this.attachedDatabase, [this._alias]);
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
  );
  static const VerificationMeta _senderPeerIdMeta = const VerificationMeta(
    'senderPeerId',
  );
  @override
  late final GeneratedColumn<String> senderPeerId = GeneratedColumn<String>(
    'sender_peer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientGeneratedIdMeta = const VerificationMeta(
    'clientGeneratedId',
  );
  @override
  late final GeneratedColumn<String> clientGeneratedId =
      GeneratedColumn<String>(
        'client_generated_id',
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
  static const VerificationMeta _textBodyMeta = const VerificationMeta(
    'textBody',
  );
  @override
  late final GeneratedColumn<String> textBody = GeneratedColumn<String>(
    'text_body',
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _replyToMessageIdMeta = const VerificationMeta(
    'replyToMessageId',
  );
  @override
  late final GeneratedColumn<String> replyToMessageId = GeneratedColumn<String>(
    'reply_to_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sentAtMeta = const VerificationMeta('sentAt');
  @override
  late final GeneratedColumn<int> sentAt = GeneratedColumn<int>(
    'sent_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receivedAtMeta = const VerificationMeta(
    'receivedAt',
  );
  @override
  late final GeneratedColumn<int> receivedAt = GeneratedColumn<int>(
    'received_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<int> readAt = GeneratedColumn<int>(
    'read_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdLocallyAtMeta = const VerificationMeta(
    'createdLocallyAt',
  );
  @override
  late final GeneratedColumn<int> createdLocallyAt = GeneratedColumn<int>(
    'created_locally_at',
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
    conversationId,
    senderPeerId,
    clientGeneratedId,
    type,
    textBody,
    status,
    replyToMessageId,
    metadataJson,
    sentAt,
    receivedAt,
    readAt,
    createdLocallyAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageRow> instance, {
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
    if (data.containsKey('sender_peer_id')) {
      context.handle(
        _senderPeerIdMeta,
        senderPeerId.isAcceptableOrUnknown(
          data['sender_peer_id']!,
          _senderPeerIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_senderPeerIdMeta);
    }
    if (data.containsKey('client_generated_id')) {
      context.handle(
        _clientGeneratedIdMeta,
        clientGeneratedId.isAcceptableOrUnknown(
          data['client_generated_id']!,
          _clientGeneratedIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientGeneratedIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('text_body')) {
      context.handle(
        _textBodyMeta,
        textBody.isAcceptableOrUnknown(data['text_body']!, _textBodyMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('reply_to_message_id')) {
      context.handle(
        _replyToMessageIdMeta,
        replyToMessageId.isAcceptableOrUnknown(
          data['reply_to_message_id']!,
          _replyToMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('sent_at')) {
      context.handle(
        _sentAtMeta,
        sentAt.isAcceptableOrUnknown(data['sent_at']!, _sentAtMeta),
      );
    }
    if (data.containsKey('received_at')) {
      context.handle(
        _receivedAtMeta,
        receivedAt.isAcceptableOrUnknown(data['received_at']!, _receivedAtMeta),
      );
    }
    if (data.containsKey('read_at')) {
      context.handle(
        _readAtMeta,
        readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta),
      );
    }
    if (data.containsKey('created_locally_at')) {
      context.handle(
        _createdLocallyAtMeta,
        createdLocallyAt.isAcceptableOrUnknown(
          data['created_locally_at']!,
          _createdLocallyAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdLocallyAtMeta);
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
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {clientGeneratedId},
  ];
  @override
  MessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      senderPeerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_peer_id'],
      )!,
      clientGeneratedId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_generated_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      textBody: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_body'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      replyToMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_to_message_id'],
      ),
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      ),
      sentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sent_at'],
      ),
      receivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}received_at'],
      ),
      readAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}read_at'],
      ),
      createdLocallyAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_locally_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MessagesTableTable createAlias(String alias) {
    return $MessagesTableTable(attachedDatabase, alias);
  }
}

class MessageRow extends DataClass implements Insertable<MessageRow> {
  final String id;
  final String conversationId;
  final String senderPeerId;
  final String clientGeneratedId;
  final String type;
  final String? textBody;
  final String status;
  final String? replyToMessageId;
  final String? metadataJson;
  final int? sentAt;
  final int? receivedAt;
  final int? readAt;
  final int createdLocallyAt;
  final int updatedAt;
  const MessageRow({
    required this.id,
    required this.conversationId,
    required this.senderPeerId,
    required this.clientGeneratedId,
    required this.type,
    this.textBody,
    required this.status,
    this.replyToMessageId,
    this.metadataJson,
    this.sentAt,
    this.receivedAt,
    this.readAt,
    required this.createdLocallyAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['sender_peer_id'] = Variable<String>(senderPeerId);
    map['client_generated_id'] = Variable<String>(clientGeneratedId);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || textBody != null) {
      map['text_body'] = Variable<String>(textBody);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || replyToMessageId != null) {
      map['reply_to_message_id'] = Variable<String>(replyToMessageId);
    }
    if (!nullToAbsent || metadataJson != null) {
      map['metadata_json'] = Variable<String>(metadataJson);
    }
    if (!nullToAbsent || sentAt != null) {
      map['sent_at'] = Variable<int>(sentAt);
    }
    if (!nullToAbsent || receivedAt != null) {
      map['received_at'] = Variable<int>(receivedAt);
    }
    if (!nullToAbsent || readAt != null) {
      map['read_at'] = Variable<int>(readAt);
    }
    map['created_locally_at'] = Variable<int>(createdLocallyAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  MessagesTableCompanion toCompanion(bool nullToAbsent) {
    return MessagesTableCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      senderPeerId: Value(senderPeerId),
      clientGeneratedId: Value(clientGeneratedId),
      type: Value(type),
      textBody: textBody == null && nullToAbsent
          ? const Value.absent()
          : Value(textBody),
      status: Value(status),
      replyToMessageId: replyToMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToMessageId),
      metadataJson: metadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(metadataJson),
      sentAt: sentAt == null && nullToAbsent
          ? const Value.absent()
          : Value(sentAt),
      receivedAt: receivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(receivedAt),
      readAt: readAt == null && nullToAbsent
          ? const Value.absent()
          : Value(readAt),
      createdLocallyAt: Value(createdLocallyAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageRow(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      senderPeerId: serializer.fromJson<String>(json['senderPeerId']),
      clientGeneratedId: serializer.fromJson<String>(json['clientGeneratedId']),
      type: serializer.fromJson<String>(json['type']),
      textBody: serializer.fromJson<String?>(json['textBody']),
      status: serializer.fromJson<String>(json['status']),
      replyToMessageId: serializer.fromJson<String?>(json['replyToMessageId']),
      metadataJson: serializer.fromJson<String?>(json['metadataJson']),
      sentAt: serializer.fromJson<int?>(json['sentAt']),
      receivedAt: serializer.fromJson<int?>(json['receivedAt']),
      readAt: serializer.fromJson<int?>(json['readAt']),
      createdLocallyAt: serializer.fromJson<int>(json['createdLocallyAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'senderPeerId': serializer.toJson<String>(senderPeerId),
      'clientGeneratedId': serializer.toJson<String>(clientGeneratedId),
      'type': serializer.toJson<String>(type),
      'textBody': serializer.toJson<String?>(textBody),
      'status': serializer.toJson<String>(status),
      'replyToMessageId': serializer.toJson<String?>(replyToMessageId),
      'metadataJson': serializer.toJson<String?>(metadataJson),
      'sentAt': serializer.toJson<int?>(sentAt),
      'receivedAt': serializer.toJson<int?>(receivedAt),
      'readAt': serializer.toJson<int?>(readAt),
      'createdLocallyAt': serializer.toJson<int>(createdLocallyAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  MessageRow copyWith({
    String? id,
    String? conversationId,
    String? senderPeerId,
    String? clientGeneratedId,
    String? type,
    Value<String?> textBody = const Value.absent(),
    String? status,
    Value<String?> replyToMessageId = const Value.absent(),
    Value<String?> metadataJson = const Value.absent(),
    Value<int?> sentAt = const Value.absent(),
    Value<int?> receivedAt = const Value.absent(),
    Value<int?> readAt = const Value.absent(),
    int? createdLocallyAt,
    int? updatedAt,
  }) => MessageRow(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    senderPeerId: senderPeerId ?? this.senderPeerId,
    clientGeneratedId: clientGeneratedId ?? this.clientGeneratedId,
    type: type ?? this.type,
    textBody: textBody.present ? textBody.value : this.textBody,
    status: status ?? this.status,
    replyToMessageId: replyToMessageId.present
        ? replyToMessageId.value
        : this.replyToMessageId,
    metadataJson: metadataJson.present ? metadataJson.value : this.metadataJson,
    sentAt: sentAt.present ? sentAt.value : this.sentAt,
    receivedAt: receivedAt.present ? receivedAt.value : this.receivedAt,
    readAt: readAt.present ? readAt.value : this.readAt,
    createdLocallyAt: createdLocallyAt ?? this.createdLocallyAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MessageRow copyWithCompanion(MessagesTableCompanion data) {
    return MessageRow(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      senderPeerId: data.senderPeerId.present
          ? data.senderPeerId.value
          : this.senderPeerId,
      clientGeneratedId: data.clientGeneratedId.present
          ? data.clientGeneratedId.value
          : this.clientGeneratedId,
      type: data.type.present ? data.type.value : this.type,
      textBody: data.textBody.present ? data.textBody.value : this.textBody,
      status: data.status.present ? data.status.value : this.status,
      replyToMessageId: data.replyToMessageId.present
          ? data.replyToMessageId.value
          : this.replyToMessageId,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
      receivedAt: data.receivedAt.present
          ? data.receivedAt.value
          : this.receivedAt,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
      createdLocallyAt: data.createdLocallyAt.present
          ? data.createdLocallyAt.value
          : this.createdLocallyAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageRow(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderPeerId: $senderPeerId, ')
          ..write('clientGeneratedId: $clientGeneratedId, ')
          ..write('type: $type, ')
          ..write('textBody: $textBody, ')
          ..write('status: $status, ')
          ..write('replyToMessageId: $replyToMessageId, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('sentAt: $sentAt, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('readAt: $readAt, ')
          ..write('createdLocallyAt: $createdLocallyAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    senderPeerId,
    clientGeneratedId,
    type,
    textBody,
    status,
    replyToMessageId,
    metadataJson,
    sentAt,
    receivedAt,
    readAt,
    createdLocallyAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageRow &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.senderPeerId == this.senderPeerId &&
          other.clientGeneratedId == this.clientGeneratedId &&
          other.type == this.type &&
          other.textBody == this.textBody &&
          other.status == this.status &&
          other.replyToMessageId == this.replyToMessageId &&
          other.metadataJson == this.metadataJson &&
          other.sentAt == this.sentAt &&
          other.receivedAt == this.receivedAt &&
          other.readAt == this.readAt &&
          other.createdLocallyAt == this.createdLocallyAt &&
          other.updatedAt == this.updatedAt);
}

class MessagesTableCompanion extends UpdateCompanion<MessageRow> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> senderPeerId;
  final Value<String> clientGeneratedId;
  final Value<String> type;
  final Value<String?> textBody;
  final Value<String> status;
  final Value<String?> replyToMessageId;
  final Value<String?> metadataJson;
  final Value<int?> sentAt;
  final Value<int?> receivedAt;
  final Value<int?> readAt;
  final Value<int> createdLocallyAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const MessagesTableCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.senderPeerId = const Value.absent(),
    this.clientGeneratedId = const Value.absent(),
    this.type = const Value.absent(),
    this.textBody = const Value.absent(),
    this.status = const Value.absent(),
    this.replyToMessageId = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.readAt = const Value.absent(),
    this.createdLocallyAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesTableCompanion.insert({
    required String id,
    required String conversationId,
    required String senderPeerId,
    required String clientGeneratedId,
    required String type,
    this.textBody = const Value.absent(),
    required String status,
    this.replyToMessageId = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.readAt = const Value.absent(),
    required int createdLocallyAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       senderPeerId = Value(senderPeerId),
       clientGeneratedId = Value(clientGeneratedId),
       type = Value(type),
       status = Value(status),
       createdLocallyAt = Value(createdLocallyAt),
       updatedAt = Value(updatedAt);
  static Insertable<MessageRow> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? senderPeerId,
    Expression<String>? clientGeneratedId,
    Expression<String>? type,
    Expression<String>? textBody,
    Expression<String>? status,
    Expression<String>? replyToMessageId,
    Expression<String>? metadataJson,
    Expression<int>? sentAt,
    Expression<int>? receivedAt,
    Expression<int>? readAt,
    Expression<int>? createdLocallyAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (senderPeerId != null) 'sender_peer_id': senderPeerId,
      if (clientGeneratedId != null) 'client_generated_id': clientGeneratedId,
      if (type != null) 'type': type,
      if (textBody != null) 'text_body': textBody,
      if (status != null) 'status': status,
      if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (sentAt != null) 'sent_at': sentAt,
      if (receivedAt != null) 'received_at': receivedAt,
      if (readAt != null) 'read_at': readAt,
      if (createdLocallyAt != null) 'created_locally_at': createdLocallyAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String>? senderPeerId,
    Value<String>? clientGeneratedId,
    Value<String>? type,
    Value<String?>? textBody,
    Value<String>? status,
    Value<String?>? replyToMessageId,
    Value<String?>? metadataJson,
    Value<int?>? sentAt,
    Value<int?>? receivedAt,
    Value<int?>? readAt,
    Value<int>? createdLocallyAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return MessagesTableCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderPeerId: senderPeerId ?? this.senderPeerId,
      clientGeneratedId: clientGeneratedId ?? this.clientGeneratedId,
      type: type ?? this.type,
      textBody: textBody ?? this.textBody,
      status: status ?? this.status,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      metadataJson: metadataJson ?? this.metadataJson,
      sentAt: sentAt ?? this.sentAt,
      receivedAt: receivedAt ?? this.receivedAt,
      readAt: readAt ?? this.readAt,
      createdLocallyAt: createdLocallyAt ?? this.createdLocallyAt,
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
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (senderPeerId.present) {
      map['sender_peer_id'] = Variable<String>(senderPeerId.value);
    }
    if (clientGeneratedId.present) {
      map['client_generated_id'] = Variable<String>(clientGeneratedId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (textBody.present) {
      map['text_body'] = Variable<String>(textBody.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (replyToMessageId.present) {
      map['reply_to_message_id'] = Variable<String>(replyToMessageId.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<int>(sentAt.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<int>(receivedAt.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<int>(readAt.value);
    }
    if (createdLocallyAt.present) {
      map['created_locally_at'] = Variable<int>(createdLocallyAt.value);
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
    return (StringBuffer('MessagesTableCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderPeerId: $senderPeerId, ')
          ..write('clientGeneratedId: $clientGeneratedId, ')
          ..write('type: $type, ')
          ..write('textBody: $textBody, ')
          ..write('status: $status, ')
          ..write('replyToMessageId: $replyToMessageId, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('sentAt: $sentAt, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('readAt: $readAt, ')
          ..write('createdLocallyAt: $createdLocallyAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTableTable extends AttachmentsTable
    with TableInfo<$AttachmentsTableTable, AttachmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transferStateMeta = const VerificationMeta(
    'transferState',
  );
  @override
  late final GeneratedColumn<String> transferState = GeneratedColumn<String>(
    'transfer_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
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
    messageId,
    kind,
    fileName,
    mimeType,
    fileSize,
    localPath,
    transferState,
    checksum,
    width,
    height,
    durationMs,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttachmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_fileSizeMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('transfer_state')) {
      context.handle(
        _transferStateMeta,
        transferState.isAcceptableOrUnknown(
          data['transfer_state']!,
          _transferStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transferStateMeta);
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
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
  AttachmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttachmentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      ),
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      transferState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transfer_state'],
      )!,
      checksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum'],
      ),
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
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
  $AttachmentsTableTable createAlias(String alias) {
    return $AttachmentsTableTable(attachedDatabase, alias);
  }
}

class AttachmentRow extends DataClass implements Insertable<AttachmentRow> {
  final String id;
  final String messageId;
  final String kind;
  final String fileName;
  final String? mimeType;
  final int fileSize;
  final String? localPath;
  final String transferState;
  final String? checksum;
  final int? width;
  final int? height;
  final int? durationMs;
  final int createdAt;
  final int updatedAt;
  const AttachmentRow({
    required this.id,
    required this.messageId,
    required this.kind,
    required this.fileName,
    this.mimeType,
    required this.fileSize,
    this.localPath,
    required this.transferState,
    this.checksum,
    this.width,
    this.height,
    this.durationMs,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['message_id'] = Variable<String>(messageId);
    map['kind'] = Variable<String>(kind);
    map['file_name'] = Variable<String>(fileName);
    if (!nullToAbsent || mimeType != null) {
      map['mime_type'] = Variable<String>(mimeType);
    }
    map['file_size'] = Variable<int>(fileSize);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    map['transfer_state'] = Variable<String>(transferState);
    if (!nullToAbsent || checksum != null) {
      map['checksum'] = Variable<String>(checksum);
    }
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  AttachmentsTableCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsTableCompanion(
      id: Value(id),
      messageId: Value(messageId),
      kind: Value(kind),
      fileName: Value(fileName),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      fileSize: Value(fileSize),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      transferState: Value(transferState),
      checksum: checksum == null && nullToAbsent
          ? const Value.absent()
          : Value(checksum),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AttachmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttachmentRow(
      id: serializer.fromJson<String>(json['id']),
      messageId: serializer.fromJson<String>(json['messageId']),
      kind: serializer.fromJson<String>(json['kind']),
      fileName: serializer.fromJson<String>(json['fileName']),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      fileSize: serializer.fromJson<int>(json['fileSize']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      transferState: serializer.fromJson<String>(json['transferState']),
      checksum: serializer.fromJson<String?>(json['checksum']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'messageId': serializer.toJson<String>(messageId),
      'kind': serializer.toJson<String>(kind),
      'fileName': serializer.toJson<String>(fileName),
      'mimeType': serializer.toJson<String?>(mimeType),
      'fileSize': serializer.toJson<int>(fileSize),
      'localPath': serializer.toJson<String?>(localPath),
      'transferState': serializer.toJson<String>(transferState),
      'checksum': serializer.toJson<String?>(checksum),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'durationMs': serializer.toJson<int?>(durationMs),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  AttachmentRow copyWith({
    String? id,
    String? messageId,
    String? kind,
    String? fileName,
    Value<String?> mimeType = const Value.absent(),
    int? fileSize,
    Value<String?> localPath = const Value.absent(),
    String? transferState,
    Value<String?> checksum = const Value.absent(),
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => AttachmentRow(
    id: id ?? this.id,
    messageId: messageId ?? this.messageId,
    kind: kind ?? this.kind,
    fileName: fileName ?? this.fileName,
    mimeType: mimeType.present ? mimeType.value : this.mimeType,
    fileSize: fileSize ?? this.fileSize,
    localPath: localPath.present ? localPath.value : this.localPath,
    transferState: transferState ?? this.transferState,
    checksum: checksum.present ? checksum.value : this.checksum,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AttachmentRow copyWithCompanion(AttachmentsTableCompanion data) {
    return AttachmentRow(
      id: data.id.present ? data.id.value : this.id,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      kind: data.kind.present ? data.kind.value : this.kind,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      transferState: data.transferState.present
          ? data.transferState.value
          : this.transferState,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentRow(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('kind: $kind, ')
          ..write('fileName: $fileName, ')
          ..write('mimeType: $mimeType, ')
          ..write('fileSize: $fileSize, ')
          ..write('localPath: $localPath, ')
          ..write('transferState: $transferState, ')
          ..write('checksum: $checksum, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('durationMs: $durationMs, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    messageId,
    kind,
    fileName,
    mimeType,
    fileSize,
    localPath,
    transferState,
    checksum,
    width,
    height,
    durationMs,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttachmentRow &&
          other.id == this.id &&
          other.messageId == this.messageId &&
          other.kind == this.kind &&
          other.fileName == this.fileName &&
          other.mimeType == this.mimeType &&
          other.fileSize == this.fileSize &&
          other.localPath == this.localPath &&
          other.transferState == this.transferState &&
          other.checksum == this.checksum &&
          other.width == this.width &&
          other.height == this.height &&
          other.durationMs == this.durationMs &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AttachmentsTableCompanion extends UpdateCompanion<AttachmentRow> {
  final Value<String> id;
  final Value<String> messageId;
  final Value<String> kind;
  final Value<String> fileName;
  final Value<String?> mimeType;
  final Value<int> fileSize;
  final Value<String?> localPath;
  final Value<String> transferState;
  final Value<String?> checksum;
  final Value<int?> width;
  final Value<int?> height;
  final Value<int?> durationMs;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const AttachmentsTableCompanion({
    this.id = const Value.absent(),
    this.messageId = const Value.absent(),
    this.kind = const Value.absent(),
    this.fileName = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.localPath = const Value.absent(),
    this.transferState = const Value.absent(),
    this.checksum = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentsTableCompanion.insert({
    required String id,
    required String messageId,
    required String kind,
    required String fileName,
    this.mimeType = const Value.absent(),
    required int fileSize,
    this.localPath = const Value.absent(),
    required String transferState,
    this.checksum = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.durationMs = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       messageId = Value(messageId),
       kind = Value(kind),
       fileName = Value(fileName),
       fileSize = Value(fileSize),
       transferState = Value(transferState),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<AttachmentRow> custom({
    Expression<String>? id,
    Expression<String>? messageId,
    Expression<String>? kind,
    Expression<String>? fileName,
    Expression<String>? mimeType,
    Expression<int>? fileSize,
    Expression<String>? localPath,
    Expression<String>? transferState,
    Expression<String>? checksum,
    Expression<int>? width,
    Expression<int>? height,
    Expression<int>? durationMs,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (messageId != null) 'message_id': messageId,
      if (kind != null) 'kind': kind,
      if (fileName != null) 'file_name': fileName,
      if (mimeType != null) 'mime_type': mimeType,
      if (fileSize != null) 'file_size': fileSize,
      if (localPath != null) 'local_path': localPath,
      if (transferState != null) 'transfer_state': transferState,
      if (checksum != null) 'checksum': checksum,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (durationMs != null) 'duration_ms': durationMs,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttachmentsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? messageId,
    Value<String>? kind,
    Value<String>? fileName,
    Value<String?>? mimeType,
    Value<int>? fileSize,
    Value<String?>? localPath,
    Value<String>? transferState,
    Value<String?>? checksum,
    Value<int?>? width,
    Value<int?>? height,
    Value<int?>? durationMs,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return AttachmentsTableCompanion(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      kind: kind ?? this.kind,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      localPath: localPath ?? this.localPath,
      transferState: transferState ?? this.transferState,
      checksum: checksum ?? this.checksum,
      width: width ?? this.width,
      height: height ?? this.height,
      durationMs: durationMs ?? this.durationMs,
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
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (transferState.present) {
      map['transfer_state'] = Variable<String>(transferState.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
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
    return (StringBuffer('AttachmentsTableCompanion(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('kind: $kind, ')
          ..write('fileName: $fileName, ')
          ..write('mimeType: $mimeType, ')
          ..write('fileSize: $fileSize, ')
          ..write('localPath: $localPath, ')
          ..write('transferState: $transferState, ')
          ..write('checksum: $checksum, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('durationMs: $durationMs, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTableTable extends OutboxTable
    with TableInfo<$OutboxTableTable, OutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _peerIdMeta = const VerificationMeta('peerId');
  @override
  late final GeneratedColumn<String> peerId = GeneratedColumn<String>(
    'peer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextRetryAtMeta = const VerificationMeta(
    'nextRetryAt',
  );
  @override
  late final GeneratedColumn<int> nextRetryAt = GeneratedColumn<int>(
    'next_retry_at',
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
    messageId,
    peerId,
    attemptCount,
    nextRetryAt,
    lastError,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('peer_id')) {
      context.handle(
        _peerIdMeta,
        peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_peerIdMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
        _nextRetryAtMeta,
        nextRetryAt.isAcceptableOrUnknown(
          data['next_retry_at']!,
          _nextRetryAtMeta,
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
  OutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      peerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_id'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      nextRetryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_retry_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
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
  $OutboxTableTable createAlias(String alias) {
    return $OutboxTableTable(attachedDatabase, alias);
  }
}

class OutboxRow extends DataClass implements Insertable<OutboxRow> {
  final String id;
  final String messageId;
  final String peerId;
  final int attemptCount;
  final int? nextRetryAt;
  final String? lastError;
  final int createdAt;
  final int updatedAt;
  const OutboxRow({
    required this.id,
    required this.messageId,
    required this.peerId,
    required this.attemptCount,
    this.nextRetryAt,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['message_id'] = Variable<String>(messageId);
    map['peer_id'] = Variable<String>(peerId);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<int>(nextRetryAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  OutboxTableCompanion toCompanion(bool nullToAbsent) {
    return OutboxTableCompanion(
      id: Value(id),
      messageId: Value(messageId),
      peerId: Value(peerId),
      attemptCount: Value(attemptCount),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory OutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRow(
      id: serializer.fromJson<String>(json['id']),
      messageId: serializer.fromJson<String>(json['messageId']),
      peerId: serializer.fromJson<String>(json['peerId']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      nextRetryAt: serializer.fromJson<int?>(json['nextRetryAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'messageId': serializer.toJson<String>(messageId),
      'peerId': serializer.toJson<String>(peerId),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'nextRetryAt': serializer.toJson<int?>(nextRetryAt),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  OutboxRow copyWith({
    String? id,
    String? messageId,
    String? peerId,
    int? attemptCount,
    Value<int?> nextRetryAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => OutboxRow(
    id: id ?? this.id,
    messageId: messageId ?? this.messageId,
    peerId: peerId ?? this.peerId,
    attemptCount: attemptCount ?? this.attemptCount,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  OutboxRow copyWithCompanion(OutboxTableCompanion data) {
    return OutboxRow(
      id: data.id.present ? data.id.value : this.id,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      nextRetryAt: data.nextRetryAt.present
          ? data.nextRetryAt.value
          : this.nextRetryAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRow(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('peerId: $peerId, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    messageId,
    peerId,
    attemptCount,
    nextRetryAt,
    lastError,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRow &&
          other.id == this.id &&
          other.messageId == this.messageId &&
          other.peerId == this.peerId &&
          other.attemptCount == this.attemptCount &&
          other.nextRetryAt == this.nextRetryAt &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class OutboxTableCompanion extends UpdateCompanion<OutboxRow> {
  final Value<String> id;
  final Value<String> messageId;
  final Value<String> peerId;
  final Value<int> attemptCount;
  final Value<int?> nextRetryAt;
  final Value<String?> lastError;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const OutboxTableCompanion({
    this.id = const Value.absent(),
    this.messageId = const Value.absent(),
    this.peerId = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxTableCompanion.insert({
    required String id,
    required String messageId,
    required String peerId,
    this.attemptCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastError = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       messageId = Value(messageId),
       peerId = Value(peerId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<OutboxRow> custom({
    Expression<String>? id,
    Expression<String>? messageId,
    Expression<String>? peerId,
    Expression<int>? attemptCount,
    Expression<int>? nextRetryAt,
    Expression<String>? lastError,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (messageId != null) 'message_id': messageId,
      if (peerId != null) 'peer_id': peerId,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxTableCompanion copyWith({
    Value<String>? id,
    Value<String>? messageId,
    Value<String>? peerId,
    Value<int>? attemptCount,
    Value<int?>? nextRetryAt,
    Value<String?>? lastError,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return OutboxTableCompanion(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      peerId: peerId ?? this.peerId,
      attemptCount: attemptCount ?? this.attemptCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      lastError: lastError ?? this.lastError,
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
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<int>(nextRetryAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
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
    return (StringBuffer('OutboxTableCompanion(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('peerId: $peerId, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalIdentityTableTable localIdentityTable =
      $LocalIdentityTableTable(this);
  late final $PeersTableTable peersTable = $PeersTableTable(this);
  late final $PresenceTableTable presenceTable = $PresenceTableTable(this);
  late final $ContactRequestsTableTable contactRequestsTable =
      $ContactRequestsTableTable(this);
  late final $ConversationsTableTable conversationsTable =
      $ConversationsTableTable(this);
  late final $ConversationMembersTableTable conversationMembersTable =
      $ConversationMembersTableTable(this);
  late final $MessagesTableTable messagesTable = $MessagesTableTable(this);
  late final $AttachmentsTableTable attachmentsTable = $AttachmentsTableTable(
    this,
  );
  late final $OutboxTableTable outboxTable = $OutboxTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localIdentityTable,
    peersTable,
    presenceTable,
    contactRequestsTable,
    conversationsTable,
    conversationMembersTable,
    messagesTable,
    attachmentsTable,
    outboxTable,
  ];
}

typedef $$LocalIdentityTableTableCreateCompanionBuilder =
    LocalIdentityTableCompanion Function({
      required String id,
      required String peerId,
      required String displayName,
      Value<String?> deviceLabel,
      required String fingerprint,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$LocalIdentityTableTableUpdateCompanionBuilder =
    LocalIdentityTableCompanion Function({
      Value<String> id,
      Value<String> peerId,
      Value<String> displayName,
      Value<String?> deviceLabel,
      Value<String> fingerprint,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$LocalIdentityTableTableFilterComposer
    extends Composer<_$AppDatabase, $LocalIdentityTableTable> {
  $$LocalIdentityTableTableFilterComposer({
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

  ColumnFilters<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceLabel => $composableBuilder(
    column: $table.deviceLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
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
}

class $$LocalIdentityTableTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalIdentityTableTable> {
  $$LocalIdentityTableTableOrderingComposer({
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

  ColumnOrderings<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceLabel => $composableBuilder(
    column: $table.deviceLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
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
}

class $$LocalIdentityTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalIdentityTableTable> {
  $$LocalIdentityTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get peerId =>
      $composableBuilder(column: $table.peerId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceLabel => $composableBuilder(
    column: $table.deviceLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalIdentityTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalIdentityTableTable,
          LocalIdentityRow,
          $$LocalIdentityTableTableFilterComposer,
          $$LocalIdentityTableTableOrderingComposer,
          $$LocalIdentityTableTableAnnotationComposer,
          $$LocalIdentityTableTableCreateCompanionBuilder,
          $$LocalIdentityTableTableUpdateCompanionBuilder,
          (
            LocalIdentityRow,
            BaseReferences<
              _$AppDatabase,
              $LocalIdentityTableTable,
              LocalIdentityRow
            >,
          ),
          LocalIdentityRow,
          PrefetchHooks Function()
        > {
  $$LocalIdentityTableTableTableManager(
    _$AppDatabase db,
    $LocalIdentityTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalIdentityTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalIdentityTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalIdentityTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> peerId = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> deviceLabel = const Value.absent(),
                Value<String> fingerprint = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalIdentityTableCompanion(
                id: id,
                peerId: peerId,
                displayName: displayName,
                deviceLabel: deviceLabel,
                fingerprint: fingerprint,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String peerId,
                required String displayName,
                Value<String?> deviceLabel = const Value.absent(),
                required String fingerprint,
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalIdentityTableCompanion.insert(
                id: id,
                peerId: peerId,
                displayName: displayName,
                deviceLabel: deviceLabel,
                fingerprint: fingerprint,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalIdentityTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalIdentityTableTable,
      LocalIdentityRow,
      $$LocalIdentityTableTableFilterComposer,
      $$LocalIdentityTableTableOrderingComposer,
      $$LocalIdentityTableTableAnnotationComposer,
      $$LocalIdentityTableTableCreateCompanionBuilder,
      $$LocalIdentityTableTableUpdateCompanionBuilder,
      (
        LocalIdentityRow,
        BaseReferences<
          _$AppDatabase,
          $LocalIdentityTableTable,
          LocalIdentityRow
        >,
      ),
      LocalIdentityRow,
      PrefetchHooks Function()
    >;
typedef $$PeersTableTableCreateCompanionBuilder =
    PeersTableCompanion Function({
      required String id,
      required String peerId,
      required String displayName,
      Value<String?> deviceLabel,
      Value<String?> fingerprint,
      required String relationshipState,
      Value<bool> isBlocked,
      Value<int?> lastSeenAt,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$PeersTableTableUpdateCompanionBuilder =
    PeersTableCompanion Function({
      Value<String> id,
      Value<String> peerId,
      Value<String> displayName,
      Value<String?> deviceLabel,
      Value<String?> fingerprint,
      Value<String> relationshipState,
      Value<bool> isBlocked,
      Value<int?> lastSeenAt,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$PeersTableTableFilterComposer
    extends Composer<_$AppDatabase, $PeersTableTable> {
  $$PeersTableTableFilterComposer({
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

  ColumnFilters<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceLabel => $composableBuilder(
    column: $table.deviceLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relationshipState => $composableBuilder(
    column: $table.relationshipState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBlocked => $composableBuilder(
    column: $table.isBlocked,
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

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PeersTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PeersTableTable> {
  $$PeersTableTableOrderingComposer({
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

  ColumnOrderings<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceLabel => $composableBuilder(
    column: $table.deviceLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relationshipState => $composableBuilder(
    column: $table.relationshipState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBlocked => $composableBuilder(
    column: $table.isBlocked,
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

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeersTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PeersTableTable> {
  $$PeersTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get peerId =>
      $composableBuilder(column: $table.peerId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceLabel => $composableBuilder(
    column: $table.deviceLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get relationshipState => $composableBuilder(
    column: $table.relationshipState,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isBlocked =>
      $composableBuilder(column: $table.isBlocked, builder: (column) => column);

  GeneratedColumn<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PeersTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PeersTableTable,
          PeerRow,
          $$PeersTableTableFilterComposer,
          $$PeersTableTableOrderingComposer,
          $$PeersTableTableAnnotationComposer,
          $$PeersTableTableCreateCompanionBuilder,
          $$PeersTableTableUpdateCompanionBuilder,
          (PeerRow, BaseReferences<_$AppDatabase, $PeersTableTable, PeerRow>),
          PeerRow,
          PrefetchHooks Function()
        > {
  $$PeersTableTableTableManager(_$AppDatabase db, $PeersTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeersTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeersTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PeersTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> peerId = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> deviceLabel = const Value.absent(),
                Value<String?> fingerprint = const Value.absent(),
                Value<String> relationshipState = const Value.absent(),
                Value<bool> isBlocked = const Value.absent(),
                Value<int?> lastSeenAt = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeersTableCompanion(
                id: id,
                peerId: peerId,
                displayName: displayName,
                deviceLabel: deviceLabel,
                fingerprint: fingerprint,
                relationshipState: relationshipState,
                isBlocked: isBlocked,
                lastSeenAt: lastSeenAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String peerId,
                required String displayName,
                Value<String?> deviceLabel = const Value.absent(),
                Value<String?> fingerprint = const Value.absent(),
                required String relationshipState,
                Value<bool> isBlocked = const Value.absent(),
                Value<int?> lastSeenAt = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PeersTableCompanion.insert(
                id: id,
                peerId: peerId,
                displayName: displayName,
                deviceLabel: deviceLabel,
                fingerprint: fingerprint,
                relationshipState: relationshipState,
                isBlocked: isBlocked,
                lastSeenAt: lastSeenAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PeersTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PeersTableTable,
      PeerRow,
      $$PeersTableTableFilterComposer,
      $$PeersTableTableOrderingComposer,
      $$PeersTableTableAnnotationComposer,
      $$PeersTableTableCreateCompanionBuilder,
      $$PeersTableTableUpdateCompanionBuilder,
      (PeerRow, BaseReferences<_$AppDatabase, $PeersTableTable, PeerRow>),
      PeerRow,
      PrefetchHooks Function()
    >;
typedef $$PresenceTableTableCreateCompanionBuilder =
    PresenceTableCompanion Function({
      required String id,
      required String peerId,
      required String status,
      Value<String?> transportType,
      Value<String?> host,
      Value<int?> port,
      Value<int?> lastHeartbeatAt,
      Value<int?> lastProbeAt,
      Value<bool> isReachable,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$PresenceTableTableUpdateCompanionBuilder =
    PresenceTableCompanion Function({
      Value<String> id,
      Value<String> peerId,
      Value<String> status,
      Value<String?> transportType,
      Value<String?> host,
      Value<int?> port,
      Value<int?> lastHeartbeatAt,
      Value<int?> lastProbeAt,
      Value<bool> isReachable,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$PresenceTableTableFilterComposer
    extends Composer<_$AppDatabase, $PresenceTableTable> {
  $$PresenceTableTableFilterComposer({
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

  ColumnFilters<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transportType => $composableBuilder(
    column: $table.transportType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastHeartbeatAt => $composableBuilder(
    column: $table.lastHeartbeatAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastProbeAt => $composableBuilder(
    column: $table.lastProbeAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isReachable => $composableBuilder(
    column: $table.isReachable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PresenceTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PresenceTableTable> {
  $$PresenceTableTableOrderingComposer({
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

  ColumnOrderings<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transportType => $composableBuilder(
    column: $table.transportType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastHeartbeatAt => $composableBuilder(
    column: $table.lastHeartbeatAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastProbeAt => $composableBuilder(
    column: $table.lastProbeAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isReachable => $composableBuilder(
    column: $table.isReachable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PresenceTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PresenceTableTable> {
  $$PresenceTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get peerId =>
      $composableBuilder(column: $table.peerId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get transportType => $composableBuilder(
    column: $table.transportType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => column);

  GeneratedColumn<int> get port =>
      $composableBuilder(column: $table.port, builder: (column) => column);

  GeneratedColumn<int> get lastHeartbeatAt => $composableBuilder(
    column: $table.lastHeartbeatAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastProbeAt => $composableBuilder(
    column: $table.lastProbeAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isReachable => $composableBuilder(
    column: $table.isReachable,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PresenceTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PresenceTableTable,
          PresenceRow,
          $$PresenceTableTableFilterComposer,
          $$PresenceTableTableOrderingComposer,
          $$PresenceTableTableAnnotationComposer,
          $$PresenceTableTableCreateCompanionBuilder,
          $$PresenceTableTableUpdateCompanionBuilder,
          (
            PresenceRow,
            BaseReferences<_$AppDatabase, $PresenceTableTable, PresenceRow>,
          ),
          PresenceRow,
          PrefetchHooks Function()
        > {
  $$PresenceTableTableTableManager(_$AppDatabase db, $PresenceTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PresenceTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PresenceTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PresenceTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> peerId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> transportType = const Value.absent(),
                Value<String?> host = const Value.absent(),
                Value<int?> port = const Value.absent(),
                Value<int?> lastHeartbeatAt = const Value.absent(),
                Value<int?> lastProbeAt = const Value.absent(),
                Value<bool> isReachable = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PresenceTableCompanion(
                id: id,
                peerId: peerId,
                status: status,
                transportType: transportType,
                host: host,
                port: port,
                lastHeartbeatAt: lastHeartbeatAt,
                lastProbeAt: lastProbeAt,
                isReachable: isReachable,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String peerId,
                required String status,
                Value<String?> transportType = const Value.absent(),
                Value<String?> host = const Value.absent(),
                Value<int?> port = const Value.absent(),
                Value<int?> lastHeartbeatAt = const Value.absent(),
                Value<int?> lastProbeAt = const Value.absent(),
                Value<bool> isReachable = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PresenceTableCompanion.insert(
                id: id,
                peerId: peerId,
                status: status,
                transportType: transportType,
                host: host,
                port: port,
                lastHeartbeatAt: lastHeartbeatAt,
                lastProbeAt: lastProbeAt,
                isReachable: isReachable,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PresenceTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PresenceTableTable,
      PresenceRow,
      $$PresenceTableTableFilterComposer,
      $$PresenceTableTableOrderingComposer,
      $$PresenceTableTableAnnotationComposer,
      $$PresenceTableTableCreateCompanionBuilder,
      $$PresenceTableTableUpdateCompanionBuilder,
      (
        PresenceRow,
        BaseReferences<_$AppDatabase, $PresenceTableTable, PresenceRow>,
      ),
      PresenceRow,
      PrefetchHooks Function()
    >;
typedef $$ContactRequestsTableTableCreateCompanionBuilder =
    ContactRequestsTableCompanion Function({
      required String id,
      required String peerId,
      required String direction,
      required String status,
      Value<String?> message,
      required int createdAt,
      Value<int?> respondedAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$ContactRequestsTableTableUpdateCompanionBuilder =
    ContactRequestsTableCompanion Function({
      Value<String> id,
      Value<String> peerId,
      Value<String> direction,
      Value<String> status,
      Value<String?> message,
      Value<int> createdAt,
      Value<int?> respondedAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$ContactRequestsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ContactRequestsTableTable> {
  $$ContactRequestsTableTableFilterComposer({
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

  ColumnFilters<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get respondedAt => $composableBuilder(
    column: $table.respondedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContactRequestsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ContactRequestsTableTable> {
  $$ContactRequestsTableTableOrderingComposer({
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

  ColumnOrderings<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get respondedAt => $composableBuilder(
    column: $table.respondedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContactRequestsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContactRequestsTableTable> {
  $$ContactRequestsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get peerId =>
      $composableBuilder(column: $table.peerId, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get respondedAt => $composableBuilder(
    column: $table.respondedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ContactRequestsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContactRequestsTableTable,
          ContactRequestRow,
          $$ContactRequestsTableTableFilterComposer,
          $$ContactRequestsTableTableOrderingComposer,
          $$ContactRequestsTableTableAnnotationComposer,
          $$ContactRequestsTableTableCreateCompanionBuilder,
          $$ContactRequestsTableTableUpdateCompanionBuilder,
          (
            ContactRequestRow,
            BaseReferences<
              _$AppDatabase,
              $ContactRequestsTableTable,
              ContactRequestRow
            >,
          ),
          ContactRequestRow,
          PrefetchHooks Function()
        > {
  $$ContactRequestsTableTableTableManager(
    _$AppDatabase db,
    $ContactRequestsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContactRequestsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContactRequestsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ContactRequestsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> peerId = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> message = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> respondedAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactRequestsTableCompanion(
                id: id,
                peerId: peerId,
                direction: direction,
                status: status,
                message: message,
                createdAt: createdAt,
                respondedAt: respondedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String peerId,
                required String direction,
                required String status,
                Value<String?> message = const Value.absent(),
                required int createdAt,
                Value<int?> respondedAt = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ContactRequestsTableCompanion.insert(
                id: id,
                peerId: peerId,
                direction: direction,
                status: status,
                message: message,
                createdAt: createdAt,
                respondedAt: respondedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContactRequestsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContactRequestsTableTable,
      ContactRequestRow,
      $$ContactRequestsTableTableFilterComposer,
      $$ContactRequestsTableTableOrderingComposer,
      $$ContactRequestsTableTableAnnotationComposer,
      $$ContactRequestsTableTableCreateCompanionBuilder,
      $$ContactRequestsTableTableUpdateCompanionBuilder,
      (
        ContactRequestRow,
        BaseReferences<
          _$AppDatabase,
          $ContactRequestsTableTable,
          ContactRequestRow
        >,
      ),
      ContactRequestRow,
      PrefetchHooks Function()
    >;
typedef $$ConversationsTableTableCreateCompanionBuilder =
    ConversationsTableCompanion Function({
      required String id,
      required String type,
      Value<String?> title,
      Value<String?> pinnedMessageId,
      Value<String?> lastMessagePreview,
      Value<int?> lastMessageAt,
      Value<int> unreadCount,
      Value<bool> isArchived,
      Value<bool> isMuted,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$ConversationsTableTableUpdateCompanionBuilder =
    ConversationsTableCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String?> title,
      Value<String?> pinnedMessageId,
      Value<String?> lastMessagePreview,
      Value<int?> lastMessageAt,
      Value<int> unreadCount,
      Value<bool> isArchived,
      Value<bool> isMuted,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$ConversationsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationsTableTable> {
  $$ConversationsTableTableFilterComposer({
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

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinnedMessageId => $composableBuilder(
    column: $table.pinnedMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessagePreview => $composableBuilder(
    column: $table.lastMessagePreview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMuted => $composableBuilder(
    column: $table.isMuted,
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
}

class $$ConversationsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationsTableTable> {
  $$ConversationsTableTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinnedMessageId => $composableBuilder(
    column: $table.pinnedMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessagePreview => $composableBuilder(
    column: $table.lastMessagePreview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMuted => $composableBuilder(
    column: $table.isMuted,
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
}

class $$ConversationsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationsTableTable> {
  $$ConversationsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get pinnedMessageId => $composableBuilder(
    column: $table.pinnedMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastMessagePreview => $composableBuilder(
    column: $table.lastMessagePreview,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isMuted =>
      $composableBuilder(column: $table.isMuted, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ConversationsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversationsTableTable,
          ConversationRow,
          $$ConversationsTableTableFilterComposer,
          $$ConversationsTableTableOrderingComposer,
          $$ConversationsTableTableAnnotationComposer,
          $$ConversationsTableTableCreateCompanionBuilder,
          $$ConversationsTableTableUpdateCompanionBuilder,
          (
            ConversationRow,
            BaseReferences<
              _$AppDatabase,
              $ConversationsTableTable,
              ConversationRow
            >,
          ),
          ConversationRow,
          PrefetchHooks Function()
        > {
  $$ConversationsTableTableTableManager(
    _$AppDatabase db,
    $ConversationsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> pinnedMessageId = const Value.absent(),
                Value<String?> lastMessagePreview = const Value.absent(),
                Value<int?> lastMessageAt = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<bool> isMuted = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsTableCompanion(
                id: id,
                type: type,
                title: title,
                pinnedMessageId: pinnedMessageId,
                lastMessagePreview: lastMessagePreview,
                lastMessageAt: lastMessageAt,
                unreadCount: unreadCount,
                isArchived: isArchived,
                isMuted: isMuted,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                Value<String?> title = const Value.absent(),
                Value<String?> pinnedMessageId = const Value.absent(),
                Value<String?> lastMessagePreview = const Value.absent(),
                Value<int?> lastMessageAt = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<bool> isMuted = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ConversationsTableCompanion.insert(
                id: id,
                type: type,
                title: title,
                pinnedMessageId: pinnedMessageId,
                lastMessagePreview: lastMessagePreview,
                lastMessageAt: lastMessageAt,
                unreadCount: unreadCount,
                isArchived: isArchived,
                isMuted: isMuted,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConversationsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversationsTableTable,
      ConversationRow,
      $$ConversationsTableTableFilterComposer,
      $$ConversationsTableTableOrderingComposer,
      $$ConversationsTableTableAnnotationComposer,
      $$ConversationsTableTableCreateCompanionBuilder,
      $$ConversationsTableTableUpdateCompanionBuilder,
      (
        ConversationRow,
        BaseReferences<
          _$AppDatabase,
          $ConversationsTableTable,
          ConversationRow
        >,
      ),
      ConversationRow,
      PrefetchHooks Function()
    >;
typedef $$ConversationMembersTableTableCreateCompanionBuilder =
    ConversationMembersTableCompanion Function({
      required String id,
      required String conversationId,
      required String peerId,
      required String role,
      required int joinedAt,
      Value<int> rowid,
    });
typedef $$ConversationMembersTableTableUpdateCompanionBuilder =
    ConversationMembersTableCompanion Function({
      Value<String> id,
      Value<String> conversationId,
      Value<String> peerId,
      Value<String> role,
      Value<int> joinedAt,
      Value<int> rowid,
    });

class $$ConversationMembersTableTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationMembersTableTable> {
  $$ConversationMembersTableTableFilterComposer({
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

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConversationMembersTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationMembersTableTable> {
  $$ConversationMembersTableTableOrderingComposer({
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

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationMembersTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationMembersTableTable> {
  $$ConversationMembersTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get peerId =>
      $composableBuilder(column: $table.peerId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<int> get joinedAt =>
      $composableBuilder(column: $table.joinedAt, builder: (column) => column);
}

class $$ConversationMembersTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversationMembersTableTable,
          ConversationMemberRow,
          $$ConversationMembersTableTableFilterComposer,
          $$ConversationMembersTableTableOrderingComposer,
          $$ConversationMembersTableTableAnnotationComposer,
          $$ConversationMembersTableTableCreateCompanionBuilder,
          $$ConversationMembersTableTableUpdateCompanionBuilder,
          (
            ConversationMemberRow,
            BaseReferences<
              _$AppDatabase,
              $ConversationMembersTableTable,
              ConversationMemberRow
            >,
          ),
          ConversationMemberRow,
          PrefetchHooks Function()
        > {
  $$ConversationMembersTableTableTableManager(
    _$AppDatabase db,
    $ConversationMembersTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationMembersTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ConversationMembersTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ConversationMembersTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> peerId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<int> joinedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationMembersTableCompanion(
                id: id,
                conversationId: conversationId,
                peerId: peerId,
                role: role,
                joinedAt: joinedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                required String peerId,
                required String role,
                required int joinedAt,
                Value<int> rowid = const Value.absent(),
              }) => ConversationMembersTableCompanion.insert(
                id: id,
                conversationId: conversationId,
                peerId: peerId,
                role: role,
                joinedAt: joinedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConversationMembersTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversationMembersTableTable,
      ConversationMemberRow,
      $$ConversationMembersTableTableFilterComposer,
      $$ConversationMembersTableTableOrderingComposer,
      $$ConversationMembersTableTableAnnotationComposer,
      $$ConversationMembersTableTableCreateCompanionBuilder,
      $$ConversationMembersTableTableUpdateCompanionBuilder,
      (
        ConversationMemberRow,
        BaseReferences<
          _$AppDatabase,
          $ConversationMembersTableTable,
          ConversationMemberRow
        >,
      ),
      ConversationMemberRow,
      PrefetchHooks Function()
    >;
typedef $$MessagesTableTableCreateCompanionBuilder =
    MessagesTableCompanion Function({
      required String id,
      required String conversationId,
      required String senderPeerId,
      required String clientGeneratedId,
      required String type,
      Value<String?> textBody,
      required String status,
      Value<String?> replyToMessageId,
      Value<String?> metadataJson,
      Value<int?> sentAt,
      Value<int?> receivedAt,
      Value<int?> readAt,
      required int createdLocallyAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$MessagesTableTableUpdateCompanionBuilder =
    MessagesTableCompanion Function({
      Value<String> id,
      Value<String> conversationId,
      Value<String> senderPeerId,
      Value<String> clientGeneratedId,
      Value<String> type,
      Value<String?> textBody,
      Value<String> status,
      Value<String?> replyToMessageId,
      Value<String?> metadataJson,
      Value<int?> sentAt,
      Value<int?> receivedAt,
      Value<int?> readAt,
      Value<int> createdLocallyAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$MessagesTableTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTableTable> {
  $$MessagesTableTableFilterComposer({
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

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderPeerId => $composableBuilder(
    column: $table.senderPeerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientGeneratedId => $composableBuilder(
    column: $table.clientGeneratedId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textBody => $composableBuilder(
    column: $table.textBody,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyToMessageId => $composableBuilder(
    column: $table.replyToMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdLocallyAt => $composableBuilder(
    column: $table.createdLocallyAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessagesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTableTable> {
  $$MessagesTableTableOrderingComposer({
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

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderPeerId => $composableBuilder(
    column: $table.senderPeerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientGeneratedId => $composableBuilder(
    column: $table.clientGeneratedId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textBody => $composableBuilder(
    column: $table.textBody,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyToMessageId => $composableBuilder(
    column: $table.replyToMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdLocallyAt => $composableBuilder(
    column: $table.createdLocallyAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessagesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTableTable> {
  $$MessagesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get senderPeerId => $composableBuilder(
    column: $table.senderPeerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get clientGeneratedId => $composableBuilder(
    column: $table.clientGeneratedId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get textBody =>
      $composableBuilder(column: $table.textBody, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get replyToMessageId => $composableBuilder(
    column: $table.replyToMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);

  GeneratedColumn<int> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);

  GeneratedColumn<int> get createdLocallyAt => $composableBuilder(
    column: $table.createdLocallyAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MessagesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessagesTableTable,
          MessageRow,
          $$MessagesTableTableFilterComposer,
          $$MessagesTableTableOrderingComposer,
          $$MessagesTableTableAnnotationComposer,
          $$MessagesTableTableCreateCompanionBuilder,
          $$MessagesTableTableUpdateCompanionBuilder,
          (
            MessageRow,
            BaseReferences<_$AppDatabase, $MessagesTableTable, MessageRow>,
          ),
          MessageRow,
          PrefetchHooks Function()
        > {
  $$MessagesTableTableTableManager(_$AppDatabase db, $MessagesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> senderPeerId = const Value.absent(),
                Value<String> clientGeneratedId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> textBody = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> replyToMessageId = const Value.absent(),
                Value<String?> metadataJson = const Value.absent(),
                Value<int?> sentAt = const Value.absent(),
                Value<int?> receivedAt = const Value.absent(),
                Value<int?> readAt = const Value.absent(),
                Value<int> createdLocallyAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesTableCompanion(
                id: id,
                conversationId: conversationId,
                senderPeerId: senderPeerId,
                clientGeneratedId: clientGeneratedId,
                type: type,
                textBody: textBody,
                status: status,
                replyToMessageId: replyToMessageId,
                metadataJson: metadataJson,
                sentAt: sentAt,
                receivedAt: receivedAt,
                readAt: readAt,
                createdLocallyAt: createdLocallyAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                required String senderPeerId,
                required String clientGeneratedId,
                required String type,
                Value<String?> textBody = const Value.absent(),
                required String status,
                Value<String?> replyToMessageId = const Value.absent(),
                Value<String?> metadataJson = const Value.absent(),
                Value<int?> sentAt = const Value.absent(),
                Value<int?> receivedAt = const Value.absent(),
                Value<int?> readAt = const Value.absent(),
                required int createdLocallyAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MessagesTableCompanion.insert(
                id: id,
                conversationId: conversationId,
                senderPeerId: senderPeerId,
                clientGeneratedId: clientGeneratedId,
                type: type,
                textBody: textBody,
                status: status,
                replyToMessageId: replyToMessageId,
                metadataJson: metadataJson,
                sentAt: sentAt,
                receivedAt: receivedAt,
                readAt: readAt,
                createdLocallyAt: createdLocallyAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessagesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessagesTableTable,
      MessageRow,
      $$MessagesTableTableFilterComposer,
      $$MessagesTableTableOrderingComposer,
      $$MessagesTableTableAnnotationComposer,
      $$MessagesTableTableCreateCompanionBuilder,
      $$MessagesTableTableUpdateCompanionBuilder,
      (
        MessageRow,
        BaseReferences<_$AppDatabase, $MessagesTableTable, MessageRow>,
      ),
      MessageRow,
      PrefetchHooks Function()
    >;
typedef $$AttachmentsTableTableCreateCompanionBuilder =
    AttachmentsTableCompanion Function({
      required String id,
      required String messageId,
      required String kind,
      required String fileName,
      Value<String?> mimeType,
      required int fileSize,
      Value<String?> localPath,
      required String transferState,
      Value<String?> checksum,
      Value<int?> width,
      Value<int?> height,
      Value<int?> durationMs,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$AttachmentsTableTableUpdateCompanionBuilder =
    AttachmentsTableCompanion Function({
      Value<String> id,
      Value<String> messageId,
      Value<String> kind,
      Value<String> fileName,
      Value<String?> mimeType,
      Value<int> fileSize,
      Value<String?> localPath,
      Value<String> transferState,
      Value<String?> checksum,
      Value<int?> width,
      Value<int?> height,
      Value<int?> durationMs,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$AttachmentsTableTableFilterComposer
    extends Composer<_$AppDatabase, $AttachmentsTableTable> {
  $$AttachmentsTableTableFilterComposer({
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

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transferState => $composableBuilder(
    column: $table.transferState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
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
}

class $$AttachmentsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AttachmentsTableTable> {
  $$AttachmentsTableTableOrderingComposer({
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

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transferState => $composableBuilder(
    column: $table.transferState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
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
}

class $$AttachmentsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttachmentsTableTable> {
  $$AttachmentsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get transferState => $composableBuilder(
    column: $table.transferState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AttachmentsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttachmentsTableTable,
          AttachmentRow,
          $$AttachmentsTableTableFilterComposer,
          $$AttachmentsTableTableOrderingComposer,
          $$AttachmentsTableTableAnnotationComposer,
          $$AttachmentsTableTableCreateCompanionBuilder,
          $$AttachmentsTableTableUpdateCompanionBuilder,
          (
            AttachmentRow,
            BaseReferences<
              _$AppDatabase,
              $AttachmentsTableTable,
              AttachmentRow
            >,
          ),
          AttachmentRow,
          PrefetchHooks Function()
        > {
  $$AttachmentsTableTableTableManager(
    _$AppDatabase db,
    $AttachmentsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String> transferState = const Value.absent(),
                Value<String?> checksum = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsTableCompanion(
                id: id,
                messageId: messageId,
                kind: kind,
                fileName: fileName,
                mimeType: mimeType,
                fileSize: fileSize,
                localPath: localPath,
                transferState: transferState,
                checksum: checksum,
                width: width,
                height: height,
                durationMs: durationMs,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String messageId,
                required String kind,
                required String fileName,
                Value<String?> mimeType = const Value.absent(),
                required int fileSize,
                Value<String?> localPath = const Value.absent(),
                required String transferState,
                Value<String?> checksum = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsTableCompanion.insert(
                id: id,
                messageId: messageId,
                kind: kind,
                fileName: fileName,
                mimeType: mimeType,
                fileSize: fileSize,
                localPath: localPath,
                transferState: transferState,
                checksum: checksum,
                width: width,
                height: height,
                durationMs: durationMs,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AttachmentsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttachmentsTableTable,
      AttachmentRow,
      $$AttachmentsTableTableFilterComposer,
      $$AttachmentsTableTableOrderingComposer,
      $$AttachmentsTableTableAnnotationComposer,
      $$AttachmentsTableTableCreateCompanionBuilder,
      $$AttachmentsTableTableUpdateCompanionBuilder,
      (
        AttachmentRow,
        BaseReferences<_$AppDatabase, $AttachmentsTableTable, AttachmentRow>,
      ),
      AttachmentRow,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableTableCreateCompanionBuilder =
    OutboxTableCompanion Function({
      required String id,
      required String messageId,
      required String peerId,
      Value<int> attemptCount,
      Value<int?> nextRetryAt,
      Value<String?> lastError,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$OutboxTableTableUpdateCompanionBuilder =
    OutboxTableCompanion Function({
      Value<String> id,
      Value<String> messageId,
      Value<String> peerId,
      Value<int> attemptCount,
      Value<int?> nextRetryAt,
      Value<String?> lastError,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$OutboxTableTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTableTable> {
  $$OutboxTableTableFilterComposer({
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

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
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

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTableTable> {
  $$OutboxTableTableOrderingComposer({
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

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
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

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTableTable> {
  $$OutboxTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get peerId =>
      $composableBuilder(column: $table.peerId, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$OutboxTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTableTable,
          OutboxRow,
          $$OutboxTableTableFilterComposer,
          $$OutboxTableTableOrderingComposer,
          $$OutboxTableTableAnnotationComposer,
          $$OutboxTableTableCreateCompanionBuilder,
          $$OutboxTableTableUpdateCompanionBuilder,
          (
            OutboxRow,
            BaseReferences<_$AppDatabase, $OutboxTableTable, OutboxRow>,
          ),
          OutboxRow,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableTableManager(_$AppDatabase db, $OutboxTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> peerId = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<int?> nextRetryAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxTableCompanion(
                id: id,
                messageId: messageId,
                peerId: peerId,
                attemptCount: attemptCount,
                nextRetryAt: nextRetryAt,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String messageId,
                required String peerId,
                Value<int> attemptCount = const Value.absent(),
                Value<int?> nextRetryAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => OutboxTableCompanion.insert(
                id: id,
                messageId: messageId,
                peerId: peerId,
                attemptCount: attemptCount,
                nextRetryAt: nextRetryAt,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTableTable,
      OutboxRow,
      $$OutboxTableTableFilterComposer,
      $$OutboxTableTableOrderingComposer,
      $$OutboxTableTableAnnotationComposer,
      $$OutboxTableTableCreateCompanionBuilder,
      $$OutboxTableTableUpdateCompanionBuilder,
      (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTableTable, OutboxRow>),
      OutboxRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalIdentityTableTableTableManager get localIdentityTable =>
      $$LocalIdentityTableTableTableManager(_db, _db.localIdentityTable);
  $$PeersTableTableTableManager get peersTable =>
      $$PeersTableTableTableManager(_db, _db.peersTable);
  $$PresenceTableTableTableManager get presenceTable =>
      $$PresenceTableTableTableManager(_db, _db.presenceTable);
  $$ContactRequestsTableTableTableManager get contactRequestsTable =>
      $$ContactRequestsTableTableTableManager(_db, _db.contactRequestsTable);
  $$ConversationsTableTableTableManager get conversationsTable =>
      $$ConversationsTableTableTableManager(_db, _db.conversationsTable);
  $$ConversationMembersTableTableTableManager get conversationMembersTable =>
      $$ConversationMembersTableTableTableManager(
        _db,
        _db.conversationMembersTable,
      );
  $$MessagesTableTableTableManager get messagesTable =>
      $$MessagesTableTableTableManager(_db, _db.messagesTable);
  $$AttachmentsTableTableTableManager get attachmentsTable =>
      $$AttachmentsTableTableTableManager(_db, _db.attachmentsTable);
  $$OutboxTableTableTableManager get outboxTable =>
      $$OutboxTableTableTableManager(_db, _db.outboxTable);
}
