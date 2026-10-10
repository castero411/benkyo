import 'dart:async';

import 'package:benkyo/core/native/native_api.g.dart';
import 'package:benkyo/features/calendar/domain/calendar_event.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<CalendarApi> calendarApiProvider = Provider(
  (_) => CalendarApi(),
);

/// Calendar access. Asked for only when the user turns it on or schedules.
class CalendarAccess extends AsyncNotifier<AccessStatus> {
  @override
  Future<AccessStatus> build() async {
    try {
      return await ref.read(calendarApiProvider).status();
    } on PlatformException {
      return AccessStatus.denied; // no bridge (tests, other platforms)
    }
  }

  /// True when access is (now) granted.
  Future<bool> ensure() async {
    final api = ref.read(calendarApiProvider);
    if (state.value == AccessStatus.granted) return true;
    final granted = await api.requestAccess();
    state = AsyncData(await api.status());
    return granted;
  }

  Future<void> openSettings() =>
      ref.read(calendarApiProvider).openPrivacySettings();
}

final calendarAccessProvider =
    AsyncNotifierProvider<CalendarAccess, AccessStatus>(CalendarAccess.new);

/// Session-only: "Show your calendar" was dismissed.
final calendarCardDismissedProvider =
    NotifierProvider<CalendarCardDismissed, bool>(CalendarCardDismissed.new);

class CalendarCardDismissed extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

/// Events today and tomorrow (tomorrow feeds the schedule suggestions),
/// refreshed whenever the calendar changes anywhere.
final StreamProvider<List<CalEvent>> upcomingEventsProvider = StreamProvider((
  ref,
) {
  final granted =
      ref.watch(calendarAccessProvider).value == AccessStatus.granted;
  if (!granted) return Stream.value(const []);

  final api = ref.read(calendarApiProvider);
  final changes = StreamController<void>();
  CalendarEvents.setUp(_OnChange(() => changes.add(null)));
  ref.onDispose(() {
    CalendarEvents.setUp(null);
    unawaited(changes.close());
  });

  Future<List<CalEvent>> fetch() async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to = DateTime(now.year, now.month, now.day + 2);
    final dtos = await api.events(
      from.millisecondsSinceEpoch,
      to.millisecondsSinceEpoch,
    );
    return dtos.map(CalEvent.fromDto).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  return (() async* {
    yield await fetch();
    await for (final _ in changes.stream) {
      yield await fetch();
    }
  })();
});

class _OnChange implements CalendarEvents {
  _OnChange(this.onChange);

  final void Function() onChange;

  @override
  void changed() => onChange();
}
