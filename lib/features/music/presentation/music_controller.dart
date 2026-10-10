import 'dart:async';

import 'package:benkyo/core/native/native_api.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<SpotifyApi> spotifyApiProvider = Provider((_) => SpotifyApi());

@immutable
class MusicState {
  const MusicState(this.spotify, this.receivedAt, {this.error});

  final SpotifyState spotify;

  /// When [spotify] was read; playback position advances from here.
  final DateTime receivedAt;

  /// Last failed action, shown inline. Cleared by the next update.
  final String? error;

  /// Position now, extrapolated while playing.
  Duration positionAt(DateTime now) {
    final base = Duration(milliseconds: spotify.positionMs ?? 0);
    final pos = spotify.playing ? base + now.difference(receivedAt) : base;
    final total = Duration(milliseconds: spotify.durationMs ?? 0);
    return pos > total ? total : pos;
  }
}

final musicProvider = NotifierProvider<MusicController, MusicState?>(
  MusicController.new,
);

class MusicController extends Notifier<MusicState?> implements SpotifyEvents {
  SpotifyApi get _api => ref.read(spotifyApiProvider);

  @override
  MusicState? build() {
    SpotifyEvents.setUp(this);
    ref.onDispose(() => SpotifyEvents.setUp(null));
    unawaited(refresh());
    return null;
  }

  @override
  void changed(SpotifyState state) =>
      this.state = MusicState(state, DateTime.now());

  Future<void> refresh() async {
    try {
      changed(await _api.state());
    } on PlatformException {
      // Not on macOS / no bridge: the player just stays hidden.
    }
  }

  Future<void> playPause() => _run(_api.playPause);
  Future<void> next() => _run(_api.next);
  Future<void> previous() => _run(_api.previous);

  Future<void> launch() async {
    if (!await _api.launch()) await _api.openDownloadPage();
  }

  /// Plays [uri], opening Spotify first if needed (it takes a moment to be
  /// ready for commands, so retry briefly).
  Future<void> play(String uri) async {
    if (!(state?.spotify.running ?? false)) {
      if (!await _api.launch()) {
        await _api.openDownloadPage();
        return;
      }
    }
    for (var attempt = 0; ; attempt++) {
      try {
        await _api.play(uri);
        break;
      } on PlatformException catch (e) {
        if (e.code == 'not-allowed' || attempt >= 15) {
          await _fail(e);
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
    }
    await refresh();
  }

  Future<void> openAutomationSettings() => _api.openAutomationSettings();

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on PlatformException catch (e) {
      await _fail(e);
      return;
    }
    await refresh(); // first use: picks up the newly granted permission
  }

  Future<void> _fail(PlatformException e) async {
    await refresh();
    final s = state;
    if (s == null) return;
    state = MusicState(
      s.spotify,
      s.receivedAt,
      error: switch (e.code) {
        'not-allowed' => 'not-allowed',
        'not-running' => 'Spotify isn’t open',
        _ => 'Spotify didn’t respond',
      },
    );
  }
}
