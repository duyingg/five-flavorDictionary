import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/data/preference_transactions.dart';
import 'providers.dart';

/// Keeps provider state fresh when another Flutter engine changes shared data.
class PreferenceSyncRegion extends ConsumerStatefulWidget {
  const PreferenceSyncRegion({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<PreferenceSyncRegion> createState() =>
      _PreferenceSyncRegionState();
}

class _PreferenceSyncRegionState extends ConsumerState<PreferenceSyncRegion>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _changes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _changes = PreferenceTransactions.changes.listen(_refresh);
  }

  void _refresh(String group) {
    if (!mounted) return;
    final operation = group == 'favorites'
        ? ref.read(favoritesControllerProvider.notifier).refreshFromStorage()
        : ref
            .read(searchHistoryControllerProvider.notifier)
            .refreshFromStorage();
    unawaited(operation.catchError((Object _) {}));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh('favorites');
      _refresh('history');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _changes?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
