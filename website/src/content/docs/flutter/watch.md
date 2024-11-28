---
title: Watch
description: Watch a signal for changes in Flutter
sidebar:
  order: 3
  badge:
    text: Updated
    variant: note
---

## Watch

To watch a signal for changes in Flutter, use the `Watch` widget. This will only rebuild this widget method and not the entire widget tree.

```dart
final signal = signal(10);
...
@override
Widget build(BuildContext context) {
  return Watch((context) => Text('$signal'));
}
```

This will also automatically unsubscribe when the widget is disposed.

Any inherited widgets referenced to inside the Watch scope will be subscribed to for updates ([MediaQuery](https://api.flutter.dev/flutter/widgets/MediaQuery-class.html), [Theme](https://api.flutter.dev/flutter/material/Theme-class.html), etc.) and retrigger the builder method.

There is also a drop in replacement for builder:

```diff
final signal = signal(10);
...
@override
Widget build(BuildContext context) {
-  return Builder(
+  return Watch.builder(
    builder: (context) => Text('$signal'),
  );
}
```

## WatchBuilder

If you need to pass an optional child widget, use the `WatchBuilder` widget.

```dart
final signal = signal(10);
...
@override
Widget build(BuildContext context) {
  return WatchBuilder(
    builder: (context, child) {
      return InkWell(
        onTap: () => signal.value++,
        child: Row(
          children: [
            Text('$signal: '),
            child!,
          ],
        ),
      );
    },
    child: const Icon(Icons.add),
  );
}
```

## .watch(context)

If you need to map to a widget property use the `watch` extension method. This will infer the type and subscribe to the signal.

```dart
final fontSize = signal(10);
...
@override
Widget build(BuildContext context) {
  return Text('Hello World',
    style: TextStyle(fontSize:fontSize.watch(context)),
  );
}
```

It is recommended to use `Watch` instead of `.watch(context)` as it will automatically unsubscribe when the widget is disposed instead of waiting on the garbage collector via [WeakReferences](https://api.flutter.dev/flutter/dart-core/WeakReference-class.html).

### Rebuilds

To protect against unnecessary rebuilds, the `watch` extension will only subscribe once to the nearest element and mark the widget as dirty.

This means that if you have multiple widgets that are watching the same signal, only the first one will be subscribed to the signal and multiple updates will be batched together.

It is also possible to isolate the rebuilds with the `Builder` widget, however it is recommended to use `Watch` or `SignalWidget` instead.

```dart
final signal = signal(10);
...
@override
Widget build(BuildContext context) {
  // Called once
  return Column(
    children: [
      Builder(
        builder: (context) {
          // Called every time the signal changes
          final count = signal.watch(context);
          return Text('$count');
        },
      ),
      Text('Not rebuilt'),
    ],
  );
}
```

## Selectors

With signals instead of using `select` you instead create a new `computed` signal that is derived from the original signal.

```dart
final signal = signal((a: 1, b: 2));
final computed = computed(() => signal.value.a);
...
@override
Widget build(BuildContext context) {
  return Watch((_) => Text('$computed'));
}
```

It is also possible to select from the signal directly:

```dart
final signal = signal((a: 1, b: 2));
final computed = signal.select((s) => s.value.a);
...
@override
Widget build(BuildContext context) {
  return Watch((_) => Text('$computed'));
}
```
