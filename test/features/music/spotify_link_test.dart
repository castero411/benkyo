import 'package:benkyo/features/music/domain/spotify_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('share links and URIs become spotify: URIs', () {
    const id = '37i9dQZF1DWWQRwui0ExPn';
    for (final link in [
      'https://open.spotify.com/playlist/$id',
      'https://open.spotify.com/playlist/$id?si=abc123',
      'https://open.spotify.com/intl-de/playlist/$id',
      '  spotify:playlist:$id  ',
    ]) {
      expect(parseSpotifyLink(link), 'spotify:playlist:$id', reason: link);
    }
    expect(
      parseSpotifyLink('https://open.spotify.com/album/1ATL5GLyefJaxhQzSPVrLX'),
      'spotify:album:1ATL5GLyefJaxhQzSPVrLX',
    );
  });

  test('anything else is rejected', () {
    for (final bad in [
      '',
      'lofi beats',
      'https://example.com/playlist/37i9dQZF1DWWQRwui0ExPn',
      'https://open.spotify.com/user/someone',
      'spotify:playlist:x" & do shell script "rm',
    ]) {
      expect(parseSpotifyLink(bad), isNull, reason: bad);
    }
  });

  test('every preset is a valid playlist URI', () {
    for (final p in presets) {
      expect(parseSpotifyLink(p.uri), p.uri);
    }
  });
}
