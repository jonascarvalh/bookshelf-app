import 'dart:async';

import 'package:book_app/core/covers/cover_cache.dart';
import 'package:book_app/core/database/app_database.dart';
import 'package:book_app/core/network/connectivity_service.dart';
import 'package:book_app/core/notifications/reminder_scheduler.dart';
import 'package:book_app/features/books/domain/entities/book.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Banco SQLite em memória, isolado por teste.
AppDatabase memoryDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

class FakeConnectivity implements ConnectivityService {
  FakeConnectivity({this._online = true});

  bool _online;
  final _controller = StreamController<bool>.broadcast();

  set online(bool value) {
    _online = value;
    _controller.add(value);
  }

  @override
  Future<bool> get isOnline async => _online;

  @override
  Stream<bool> get onStatusChange => _controller.stream;
}

/// Sem capas nos testes: o app mostra a capa gerada.
class FakeCoverCache implements CoverCache {
  FakeCoverCache([this.covers = const {}]);

  final Map<int, Uint8List> covers;

  @override
  Future<Uint8List?> load(int coverId, {CoverSize size = CoverSize.medium}) async =>
      covers[coverId];
}

class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({this.isSupported = true, this.grantPermission = true});

  @override
  final bool isSupported;
  final bool grantPermission;
  final calls = <String>[];

  @override
  Future<bool> requestPermission() async {
    calls.add('permission');
    return grantPermission;
  }

  @override
  Future<void> scheduleDaily({required int hour, required int minute}) async =>
      calls.add('schedule $hour:$minute');

  @override
  Future<void> cancel() async => calls.add('cancel');
}

const domCasmurro = Book(
  id: 'OL1003040W',
  title: 'Dom Casmurro',
  authors: ['Machado de Assis'],
  coverId: 647501,
  firstPublishYear: 1900,
  pageCount: 268,
  isbns: ['9788500507007'],
);

const alienista = Book(
  id: 'OL1003134W',
  title: 'O Alienista',
  authors: ['Machado de Assis'],
  pageCount: 100,
);
