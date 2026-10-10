import 'package:benkyo/core/db/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True while the welcome tour should show: first launch, or "Show
/// Welcome Tour Again" in Settings.
final onboardingProvider = AsyncNotifierProvider<Onboarding, bool>(
  Onboarding.new,
);

class Onboarding extends AsyncNotifier<bool> {
  static const _key = 'onboarding.done';

  @override
  Future<bool> build() async {
    final prefs = await ref.read(appDatabaseProvider).prefsWithPrefix(_key);
    return prefs[_key] != 'true';
  }

  Future<void> finish() async {
    state = const AsyncData(false);
    await ref.read(appDatabaseProvider).setPref(_key, 'true');
  }

  void replay() => state = const AsyncData(true);
}
