import 'dart:async';

import 'package:benkyo/app/theme/tokens.dart';
import 'package:benkyo/core/native/native_api.g.dart';
import 'package:benkyo/core/widgets/glass_panel.dart';
import 'package:benkyo/core/widgets/platform_menu.dart';
import 'package:benkyo/features/music/domain/spotify_link.dart';
import 'package:benkyo/features/music/presentation/music_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Spotify controls at the bottom of the Focus screen.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  static const height = 72.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final music = ref.watch(musicProvider);
    if (music == null) return const SizedBox.shrink();
    final s = music.spotify;
    final c = ref.read(musicProvider.notifier);

    final Widget body;
    if (!s.installed) {
      body = _Message(
        title: 'Spotify isn’t installed',
        subtitle: 'Benkyo plays music through the Spotify app.',
        action: ('Get Spotify', c.launch),
      );
    } else if (!s.running) {
      body = _Message(
        title: 'Spotify',
        subtitle: 'Pick a playlist, or open Spotify.',
        action: ('Open Spotify', c.launch),
        menu: true,
      );
    } else if (music.error == 'not-allowed' ||
        s.access == SpotifyAccess.denied) {
      body = _Message(
        title: 'Benkyo can’t control Spotify',
        subtitle: 'Allow it in System Settings → Automation.',
        action: ('Open Settings', c.openAutomationSettings),
      );
    } else if (s.title == null) {
      body = _Message(
        title: 'Spotify is open',
        subtitle: music.error ?? 'Press play or pick a playlist.',
        play: true,
        menu: true,
      );
    } else {
      body = _NowPlaying(music);
    }

    return SizedBox(
      width: 640,
      height: height,
      child: GlassPanel(
        radius: 18,
        opacity: 0.6,
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        child: body,
      ),
    );
  }
}

class _Art extends StatelessWidget {
  const _Art(this.url);

  final String? url;

  @override
  Widget build(BuildContext context) {
    const placeholder = ColoredBox(
      color: Color(0xFF6C5B7B),
      child: Center(child: Icon(Icons.music_note, size: 22)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.square(
        dimension: 48,
        child: url == null || url!.isEmpty
            ? placeholder
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

class _Message extends ConsumerWidget {
  const _Message({
    required this.title,
    required this.subtitle,
    this.action,
    this.play = false,
    this.menu = false,
  });

  final String title;
  final String subtitle;
  final (String, Future<void> Function())? action;
  final bool play;
  final bool menu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final c = ref.read(musicProvider.notifier);
    return Row(
      children: [
        const _Art(null),
        const SizedBox(width: Tokens.s12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall,
              ),
            ],
          ),
        ),
        if (play) _PlayButton(playing: false, onPressed: c.playPause),
        if (action case (final label, final onPressed))
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
            onPressed: onPressed,
            child: Text(label),
          ),
        if (menu) const _PlaylistButton(),
      ],
    );
  }
}

class _NowPlaying extends ConsumerStatefulWidget {
  const _NowPlaying(this.music);

  final MusicState music;

  @override
  ConsumerState<_NowPlaying> createState() => _NowPlayingState();
}

class _NowPlayingState extends ConsumerState<_NowPlaying> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Repaints the progress bar; position itself comes from Spotify.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.music.spotify.playing) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final s = widget.music.spotify;
    final c = ref.read(musicProvider.notifier);
    final text = Theme.of(context).textTheme;
    final total = Duration(milliseconds: s.durationMs ?? 0);
    final pos = widget.music.positionAt(DateTime.now());
    final progress = total.inMilliseconds == 0
        ? 0.0
        : pos.inMilliseconds / total.inMilliseconds;

    return Row(
      children: [
        _Art(s.artworkUrl),
        const SizedBox(width: Tokens.s12),
        SizedBox(
          width: 170,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                s.artist ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Previous track',
          icon: const Icon(Icons.skip_previous),
          onPressed: c.previous,
        ),
        _PlayButton(playing: s.playing, onPressed: c.playPause),
        IconButton(
          tooltip: 'Next track',
          icon: const Icon(Icons.skip_next),
          onPressed: c.next,
        ),
        const SizedBox(width: Tokens.s8),
        Text(_clock(pos), style: text.bodySmall),
        const SizedBox(width: Tokens.s8),
        Expanded(
          child: Semantics(
            label: 'Track progress',
            value: '${_clock(pos)} of ${_clock(total)}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 4,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
        ),
        const SizedBox(width: Tokens.s8),
        Text(_clock(total), style: text.bodySmall),
        const SizedBox(width: Tokens.s4),
        const _PlaylistButton(),
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onPressed});

  final bool playing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: playing ? 'Pause music' : 'Play music',
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: Tokens.inkOnAccent,
      fixedSize: const Size(40, 40),
    ),
    icon: Icon(playing ? Icons.pause : Icons.play_arrow, size: 20),
  );
}

/// Focus playlists and "Paste Spotify Link…" in a native menu.
class _PlaylistButton extends ConsumerWidget {
  const _PlaylistButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Builder(
    builder: (button) => IconButton(
      tooltip: 'Choose playlist',
      icon: const Icon(Icons.queue_music, size: 20),
      style: IconButton.styleFrom(backgroundColor: Colors.white12),
      onPressed: () async {
        final box = button.findRenderObject()! as RenderBox;
        // Opens upward: the player sits at the bottom of the window.
        final id = await showPlatformMenu(
          context,
          box.localToGlobal(box.size.topLeft(Offset.zero)),
          [
            for (final p in presets) MenuEntry(p.name, id: p.uri),
            const MenuEntry.separator(),
            const MenuEntry('Paste Spotify Link…', id: 'paste'),
          ],
        );
        if (id == null || !context.mounted) return;
        final uri = id == 'paste' ? await _askForLink(context) : id;
        if (uri != null) await ref.read(musicProvider.notifier).play(uri);
      },
    ),
  );
}

/// Asks for a Spotify link, pre-filled from the clipboard when it has one.
Future<String?> _askForLink(BuildContext context) async {
  final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
  if (!context.mounted) return null;
  return await showDialog<String>(
    context: context,
    builder: (_) =>
        _LinkDialog(initial: parseSpotifyLink(clip) == null ? '' : clip),
  );
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({required this.initial});

  final String initial;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final uri = parseSpotifyLink(_controller.text);
    if (uri == null) {
      setState(
        () => _error = 'That isn’t a Spotify playlist, album or track link.',
      );
      return;
    }
    Navigator.of(context).pop(uri);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Tokens.glass,
    title: const Text('Play a Spotify link'),
    content: SizedBox(
      width: 420,
      child: TextField(
        controller: _controller,
        autofocus: true,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: 'https://open.spotify.com/playlist/…',
          errorText: _error,
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Play')),
    ],
  );
}
