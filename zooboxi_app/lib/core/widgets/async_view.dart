import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'error_state.dart';

/// The standard [AsyncValue] renderer: skeleton while loading, retryable
/// error, builder on data.
///
/// Data wins over a concurrent refresh, so a pull-to-refresh never blanks a
/// screen the customer is already reading.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.builder,
    this.skeleton,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Widget? skeleton;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) return builder(value.requireValue);
    if (value.hasError) return ErrorState(error: value.error, onRetry: onRetry);
    return skeleton ?? const Center(child: CircularProgressIndicator());
  }
}

/// Sliver flavour, for screens built out of a `CustomScrollView`.
class SliverAsyncView<T> extends StatelessWidget {
  const SliverAsyncView({
    super.key,
    required this.value,
    required this.builder,
    this.skeleton,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Widget? skeleton;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) return SliverToBoxAdapter(child: builder(value.requireValue));
    if (value.hasError) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorState(error: value.error, onRetry: onRetry),
      );
    }
    return SliverToBoxAdapter(
      child: skeleton ??
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ),
    );
  }
}
