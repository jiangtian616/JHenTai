// Copyright (c) 2016, Agilord. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
import 'dart:async';
import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:executor/executor.dart';
import 'package:jhentai/src/utils/log.dart';

import '../exception/cancel_exception.dart';

/// copied from [package:executor/executor.dart] and
/// 1. replace [_waiting] ListQueue by PriorityQueue
/// 2. add [cancelTask]
abstract class EHExecutor {
  /// The maximum number of tasks running concurrently.
  int concurrency = 1;

  /// The maximum rate of how frequently tasks can be started.
  Rate? rate;

  /// Async task executor.
  factory EHExecutor({
    int concurrency = 1,
    Rate? rate,
  }) =>
      _EHExecutor(concurrency, rate);

  /// The number of tasks that are currently running.
  int get runningCount;

  /// The number of tasks that are currently waiting to be started.
  int get waitingCount;

  /// The total number of tasks scheduled ([runningCount] + [waitingCount]).
  int get scheduledCount;

  /// Schedules an async task and returns with a future that completes when the
  /// task is finished. Task may not get executed immediately.
  Future<R> scheduleTask<R>(int priority, AsyncTask<R> task);

  /// Schedules an async task and returns its stream. The task is considered
  /// running until the stream is closed.
  Stream<R> scheduleStream<R>(int priority, StreamTask<R> task);

  /// Returns a [Future] that completes when all currently running tasks
  /// complete.
  ///
  /// If [withWaiting] is set, it will include the waiting tasks too.
  Future join({bool withWaiting = false});

  /// If task is in waiting queue, remove it
  void cancelTask(AsyncTask task);

  /// Notifies the listeners about a state change in [Executor], for example:
  /// - one or more tasks have started
  /// - one or more tasks have completed
  ///
  /// Clients can use this to monitor [scheduledCount] and queue more tasks to
  /// ensure [Executor] is running on full capacity.
  Stream get onChange;

  /// Closes the executor and reject tasks.
  Future close();
}

class _EHExecutor implements EHExecutor {
  int _concurrency;
  Rate? _rate;
  final Map<AsyncTask, _PriorityItem> task2WaitingItem = {};
  final PriorityQueue<_PriorityItem> _waiting = PriorityQueue<_PriorityItem>((a, b) => a.priority - b.priority);
  final ListQueue<_PriorityItem> _running = ListQueue<_PriorityItem>();
  final ListQueue<DateTime> _started = ListQueue<DateTime>();
  final StreamController _onChangeController = StreamController.broadcast();
  bool _closing = false;
  Timer? _triggerTimer;

  _EHExecutor(this._concurrency, this._rate) {
    assert(_concurrency > 0);
  }

  @override
  int get runningCount => _running.length;

  @override
  int get waitingCount => _waiting.length;

  @override
  int get scheduledCount => runningCount + waitingCount;

  bool get isClosing => _closing;

  @override
  int get concurrency => _concurrency;

  @override
  set concurrency(int value) {
    if (_concurrency == value) return;
    assert(value > 0);
    _concurrency = value;
    _trigger();
  }

  @override
  Rate? get rate => _rate;

  @override
  set rate(Rate? value) {
    if (_rate == value) return;
    _rate = value;
    _trigger();
  }

  @override
  Future<R> scheduleTask<R>(int priority, AsyncTask<R> task) async {
    if (isClosing) throw Exception('Executor doesn\'t accept tasks.');
    final item = _PriorityItem<R>(priority);
    _waiting.add(item);
    task2WaitingItem[task] = item;
    _trigger();
    try {
      await item.trigger.future;
    } catch (e) {
      item.result.completeError(e);
      return item.result.future;
    } finally {
      task2WaitingItem.remove(task);
    }
    if (isClosing) {
      item.result.completeError(TimeoutException('Executor is closing'));
    } else {
      try {
        final r = await task();
        item.result.complete(r);
      } catch (e) {
        item.result.completeError(e);
      }
    }
    _running.remove(item);
    _trigger();
    item.done.complete();
    return item.result.future;
  }

  @override
  Stream<R> scheduleStream<R>(int priority, StreamTask<R> task) {
    final streamController = StreamController<R>();
    StreamSubscription<R>? streamSubscription;
    final resourceCompleter = Completer();
    complete() {
      if (streamSubscription != null) {
        streamSubscription?.cancel();
        streamSubscription = null;
      }
      if (!resourceCompleter.isCompleted) {
        resourceCompleter.complete();
      }
      if (!streamController.isClosed) {
        streamController.close();
      }
    }
    completeWithError(e, st) {
      if (!streamController.isClosed) {
        streamController.addError(e as Object, st as StackTrace);
      }
      complete();
    }
    streamController
      ..onCancel = complete
      ..onPause = (() => streamSubscription?.pause())
      ..onResume = () => streamSubscription?.resume();
    scheduleTask(priority, () {
      if (resourceCompleter.isCompleted) return null;
      try {
        final stream = task();
        if (stream == null) {
          complete();
          return null;
        }
        streamSubscription = stream.listen(streamController.add, onError: streamController.addError, onDone: complete, cancelOnError: true);
      } catch (e, st) {
        completeWithError(e, st);
      }
      return resourceCompleter.future;
    }).catchError(completeWithError);
    return streamController.stream;
  }

  @override
  Future join({bool withWaiting = false}) {
    final futures = <Future>[];
    for (final item in _running) {
      futures.add(item.result.future.catchError((_) async => null));
    }
    if (withWaiting) {
      for (final item in _waiting.unorderedElements) {
        futures.add(item.result.future.catchError((_) async => null));
      }
    }
    if (futures.isEmpty) return Future.value();
    return Future.wait(futures);
  }

  @override
  void cancelTask(AsyncTask task) {
    if (!task2WaitingItem.containsKey(task)) {
      return;
    }

    _PriorityItem item = task2WaitingItem[task]!;
    _waiting.remove(item);

    if (item.trigger.isCompleted) {
      return;
    }

    try {
      item.trigger.completeError(CancelException());
    } on StateError catch (e) {
      if (e.message.contains('Future already completed')) {
        Log.warning('_EHExecutor.cancelTask: Future already completed');
      } else {
        rethrow;
      }
    }
  }

  @override
  Stream get onChange => _onChangeController.stream;

  @override
  Future close() async {
    _closing = true;
    _trigger();
    await join(withWaiting: true);
    _triggerTimer?.cancel();
    await _onChangeController.close();
  }

  void _trigger() {
    _triggerTimer?.cancel();
    _triggerTimer = null;

    while (_running.length < _concurrency && _waiting.isNotEmpty) {
      final rate = _rate;
      if (rate != null) {
        final now = DateTime.now();
        final limitStart = now.subtract(rate.period);
        while (_started.isNotEmpty && _started.first.isBefore(limitStart)) {
          _started.removeFirst();
        }
        if (_started.isNotEmpty) {
          final gap = rate.period ~/ rate.maximum;
          final last = now.difference(_started.last);
          if (gap > last) {
            final diff = gap - last;
            _triggerTimer ??= Timer(diff, _trigger);
            return;
          }
        }
        _started.add(now);
      }

      final item = _waiting.removeFirst();
      _running.add(item);
      item.done.future.whenComplete(() {
        _trigger();
        if (!_closing && _onChangeController.hasListener && !_onChangeController.isClosed) {
          _onChangeController.add(null);
        }
      });
      item.trigger.complete();
    }
  }
}

class _PriorityItem<R> {
  final int priority;
  final trigger = Completer();
  final result = Completer<R>();
  final done = Completer();

  _PriorityItem(this.priority);
}
