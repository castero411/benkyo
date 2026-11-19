/// A focus playlist offered in the music menu.
typedef Preset = ({String name, String uri});

/// Spotify's own editorial playlists (IDs checked against Spotify).
const presets = <Preset>[
  (name: 'lofi beats', uri: 'spotify:playlist:37i9dQZF1DWWQRwui0ExPn'),
  (name: 'Deep Focus', uri: 'spotify:playlist:37i9dQZF1DWZeKCadgRdKQ'),
  (name: 'Peaceful Piano', uri: 'spotify:playlist:37i9dQZF1DX4sWSpwq3LiO'),
  (
    name: 'Jazz in the Background',
    uri: 'spotify:playlist:37i9dQZF1DWV7EzJMK2FUI',
  ),
  (name: 'Brain Food', uri: 'spotify:playlist:37i9dQZF1DWXLeA8Omikj7'),
];

/// A share link or URI → `spotify:<kind>:<id>`, or null if it isn't one.
///
/// Accepts `https://open.spotify.com/[intl-xx/]playlist/ID?si=…`,
/// album/track/artist links, and `spotify:playlist:ID` URIs.
String? parseSpotifyLink(String input) {
  final match = RegExp(
    r'^(?:https?://open\.spotify\.com/(?:intl-[a-z]{2}(?:-[a-z]{2})?/)?'
    '|spotify:)(playlist|album|track|artist)[/:]([A-Za-z0-9]{10,})'
    r'(?:[?#/].*)?$',
    caseSensitive: false,
  ).firstMatch(input.trim());
  if (match == null) return null;
  return 'spotify:${match.group(1)!.toLowerCase()}:${match.group(2)}';
}
