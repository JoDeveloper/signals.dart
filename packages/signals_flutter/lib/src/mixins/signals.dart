import 'dart:async';
import 'dart:collection';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:signals_core/signals_core.dart' as core;

import '../../signals_core.dart';

typedef _SignalMetadata = ({
  bool? local,
  core.ReadonlySignal<dynamic> target,
  ({Function cb, core.EffectCleanup cleanup})? listener,
});

/// Signals mixin that will automatically rebuild the widget tree when any of
/// the signals change and dispose of any signals and effects created locally.
///
/// ```dart
/// class MyWidget extends StatefulWidget {
///  ...
/// }
///
/// class _MyWidget extends State<MyWidget> with SignalsMixin {
///   late var _signal = this.createSignal(0);
///   late var _computed = this.createComputed(() => _signal() * 2);
///
///   @override
///   void initState() {
///     super.initState();
///     this.createEffect(() {
///       print('count: $_signal, double: $_computed');
///     });
///   }
///   ...
/// }
/// ```
mixin SignalsMixin<T extends StatefulWidget> on State<T> {
  final _signals = HashMap.of(<int, _SignalMetadata>{});
  core.EffectCleanup? _cleanup;
  final _effects = <core.EffectCleanup>[];

  /// Dispose and remove signal
  void disposeSignal(int id) {
    final s = _signals.remove(id);
    if (s == null) return;
    s.target.dispose();
    s.listener?.cleanup();
  }

  Future<void> _rebuild() async {
    if (!mounted) return;

    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted) return;
    }

    setState(() {});
    return;
  }

  void _setup() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cb = core.effect(() {
        for (final s in _signals.values.where((e) => e.local != null)) {
          s.target.value;
        }
        _rebuild();
      });
      _cleanup?.call();
      _cleanup = cb;
    });
  }

  void _watch(core.ReadonlySignal<dynamic> target, bool local) {
    if (_signals[target.globalId]?.local != null) {
      return;
    }
    final listener = _signals[target.globalId]?.listener;
    _signals[target.globalId] = (
      local: local,
      target: target,
      listener: listener,
    );
    _setup();
  }

  void _unwatch(core.ReadonlySignal<dynamic> target) {
    if (!_signals.containsKey(target.globalId)) return;
    final listener = _signals[target.globalId]?.listener;
    _signals[target.globalId] = (
      local: null,
      target: target,
      listener: listener,
    );
    _setup();
  }

  /// Create a signal<T> and watch for changes
  Signal<V> createSignal<V>(
    V val, {
    String? debugLabel,
    bool autoDispose = true,
  }) {
    final s = signal<V>(
      val,
      debugLabel: debugLabel,
      autoDispose: autoDispose,
    );
    _watch(s, true);
    return s;
  }

  /// Create a [ListSignal]<T> and watch for changes
  core.ListSignal<V> createListSignal<V>(
    List<V> list, {
    String? debugLabel,
    bool autoDispose = true,
  }) {
    final s = core.ListSignal<V>(
      list,
      debugLabel: debugLabel,
      autoDispose: autoDispose,
    );
    _watch(s, true);
    return s;
  }

  /// Create a [SetSignal]<T> and watch for changes
  core.SetSignal<V> createSetSignal<V>(
    Set<V> set, {
    String? debugLabel,
    bool autoDispose = true,
  }) {
    final s = core.SetSignal<V>(
      set,
      debugLabel: debugLabel,
      autoDispose: autoDispose,
    );
    _watch(s, true);
    return s;
  }

  /// Create a [QueueSignal]<T> and watch for changes
  core.QueueSignal<V> createQueueSignal<V>(
    Queue<V> queue, {
    String? debugLabel,
    bool autoDispose = true,
  }) {
    final s = core.QueueSignal<V>(
      queue,
      debugLabel: debugLabel,
      autoDispose: autoDispose,
    );
    _watch(s, true);
    return s;
  }

  /// Create a [MapSignal]<T> and watch for changes
  core.MapSignal<K, V> createMapSignal<K, V>(
    Map<K, V> value, {
    String? debugLabel,
    bool autoDispose = true,
  }) {
    final s = core.MapSignal<K, V>(
      value,
      debugLabel: debugLabel,
      autoDispose: autoDispose,
    );
    _watch(s, true);
    return s;
  }

  /// Create a computed<T> and watch for changes
  Computed<V> createComputed<V>(
    V Function() cb, {
    String? debugLabel,
    bool autoDispose = true,
  }) {
    final s = computed<V>(
      cb,
      debugLabel: debugLabel,
      autoDispose: autoDispose,
    );
    _watch(s, true);
    return s;
  }

  /// Bind an existing signal<T> and watch for changes
  S bindSignal<V, S extends core.ReadonlySignal<V>>(S val) {
    _watch(val, false);
    return val;
  }

  /// Unbind an existing signal<T> changes
  S unbindSignal<V, S extends core.ReadonlySignal<V>>(S val) {
    _unwatch(val);
    return val;
  }

  /// Watch signal value
  V watchSignal<V, S extends core.ReadonlySignal<V>>(S val) {
    return bindSignal(val).value;
  }

  /// Unwatch an existing signal<T> value changes
  V unwatchSignal<V, S extends core.ReadonlySignal<V>>(S val) {
    return unbindSignal(val).value;
  }

  /// Watch signal value
  void listenSignal(
    core.ReadonlySignal<dynamic> target,
    void Function() callback, {
    String? debugLabel,
  }) {
    final current = _signals[target.globalId];
    if (current?.listener?.cb.hashCode == callback.hashCode) return;
    current?.listener?.cleanup();
    final cb = createEffect(
      callback,
      debugLabel: debugLabel,
    );
    _signals[target.globalId] = (
      local: current?.local,
      target: target,
      listener: (cb: callback, cleanup: cb),
    );
  }

  /// Stop listening to a signal value
  void unlistenSignal(
    core.ReadonlySignal<dynamic> target,
    void Function() callback,
  ) {
    final current = _signals[target.globalId];
    if (current != null) {
      current.listener?.cleanup();
      _signals[target.globalId] = (
        local: current.local,
        target: target,
        listener: null,
      );
    }
  }

  /// Create a effect.
  ///
  /// Do not call inside the build method.
  ///
  /// Calling this method in build() will create a new
  /// effect every render.
  core.EffectCleanup createEffect(
    dynamic Function() cb, {
    String? debugLabel,
    dynamic Function()? onDispose,
  }) {
    final s = core.effect(
      cb,
      debugLabel: debugLabel,
      onDispose: onDispose,
    );
    _effects.add(s);
    return () {
      _effects.remove(s);
      s();
    };
  }

  /// Reset all stored signals and effects
  void clearSignalsAndEffects() {
    _cleanup?.call();
    _cleanup = null;
    final local = _signals //
        .values
        .where((e) => e.local == true)
        .map((e) => e.target);
    for (final s in local) {
      s.dispose();
    }
    for (final cb in _effects) {
      cb();
    }
    _effects.clear();
    _signals.clear();
  }

  @override
  void dispose() {
    clearSignalsAndEffects();
    super.dispose();
  }
}
