import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where every picture in the app comes from — the store's photos, the
/// cut-outs, the hero art, the brand marks.
///
/// This replaces `cached_network_image` + `flutter_cache_manager`, and the
/// reason is a phone, not a preference. On the owner's iPhone every picture
/// sat on its placeholder for good: no bytes, no error, while the very same
/// build drew everything on the simulator and the store answered the app's
/// other requests without a hitch. A probe planted in the tiles then fetched
/// each of those URLs with a bare `HttpClient` and decoded it in a second
/// or two. Whatever had seized — the package's SQLite ledger, or a
/// connection its `package:http` client kept trusting — sat between the URL
/// and the bytes, and it was not ours to debug on a beta OS.
///
/// So the path is now short enough to see all of: a URL, a `HttpClient` with
/// timeouts on every step, and a file on disk named by the URL's hash. No
/// database, no third-party client. A request that fails once is retried
/// once on a brand-new client, so a stale socket costs a second, not a
/// picture.
class PictureStore {
  PictureStore._();

  static final PictureStore instance = PictureStore._();

  /// How long a picture on disk is trusted before it is fetched again.
  static const Duration keep = Duration(days: 30);

  /// Files past this count trigger a sweep of the oldest.
  static const int cap = 1200;

  /// How long each step may take: the connection, the headers, the body.
  /// Fields, not constants, so a test can make a silent server give up in
  /// under a second.
  @visibleForTesting
  Duration connectTimeout = const Duration(seconds: 10);
  @visibleForTesting
  Duration headersTimeout = const Duration(seconds: 15);
  @visibleForTesting
  Duration bodyTimeout = const Duration(seconds: 30);

  HttpClient _newClient() => HttpClient()
    ..connectionTimeout = connectTimeout
    // Short: a connection that sat idle across a lock-and-unlock is the one
    // most likely to be dead without saying so.
    ..idleTimeout = const Duration(seconds: 5);

  late HttpClient _client = _newClient();
  Future<Directory?>? _root;
  final Map<String, Future<Uint8List>> _inFlight = {};

  /// The bytes for [url] — off disk when they are there, else fetched and
  /// kept. Concurrent asks for one URL share one fetch.
  Future<Uint8List> bytes(String url) => _inFlight.putIfAbsent(
        url,
        // A block, not an arrow: `remove` hands back the very future being
        // built, and `whenComplete` would wait on it — forever.
        () => _load(url).whenComplete(() {
          _inFlight.remove(url);
        }),
      );

  Future<Uint8List> _load(String url) async {
    final file = await _fileFor(url);
    if (file != null) {
      try {
        final stat = await file.stat();
        if (stat.type == FileSystemEntityType.file &&
            DateTime.now().difference(stat.modified) < keep) {
          final data = await file.readAsBytes();
          if (data.isNotEmpty) return data;
        }
      } catch (_) {
        // Unreadable is the same as absent.
      }
    }
    final data = await _fetch(url);
    if (file != null) unawaited(_keep(file, data));
    return data;
  }

  Future<Uint8List> _fetch(String url) async {
    final uri = Uri.parse(url);
    try {
      return await _get(_client, uri);
    } on TimeoutException {
      // The client, not the server, is the likelier culprit: start over.
      _client.close(force: true);
      _client = _newClient();
      return _get(_client, uri);
    }
  }

  Future<Uint8List> _get(HttpClient client, Uri uri) async {
    final request = await client.getUrl(uri).timeout(connectTimeout);
    final response = await request.close().timeout(headersTimeout);
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>().catchError((_) {});
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }
    final data = await consolidateHttpClientResponseBytes(response).timeout(bodyTimeout);
    if (data.isEmpty) throw HttpException('empty body', uri: uri);
    return data;
  }

  /// Write beside, then rename: a reader never sees half a file.
  Future<void> _keep(File file, Uint8List data) async {
    try {
      final tmp = File('${file.path}.part');
      await tmp.writeAsBytes(data, flush: true);
      await tmp.rename(file.path);
    } catch (_) {
      // Disk full, sandbox gone — the picture still showed.
    }
  }

  Future<File?> _fileFor(String url) async {
    final root = await (_root ??= _open());
    if (root == null) return null;
    final name = crypto.sha1.convert(utf8.encode(url)).toString();
    return File(p.join(root.path, name));
  }

  Future<Directory?> _open() async {
    try {
      final dir = Directory(
        p.join((await getTemporaryDirectory()).path, 'zooboxi-pictures'),
      );
      await dir.create(recursive: true);
      unawaited(_sweep(dir));
      return dir;
    } catch (_) {
      // No plugin (tests), no sandbox: pictures still load, just not from disk.
      return null;
    }
  }

  /// Drop what is stale, and the oldest beyond [cap]. Once per launch, off
  /// the first picture, never in the way of it.
  Future<void> _sweep(Directory dir) async {
    try {
      final now = DateTime.now();
      final files = <(File, DateTime)>[];
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final stat = await entity.stat();
        if (entity.path.endsWith('.part') || now.difference(stat.modified) > keep) {
          await entity.delete();
        } else {
          files.add((entity, stat.modified));
        }
      }
      if (files.length > cap) {
        files.sort((a, b) => a.$2.compareTo(b.$2));
        for (final (file, _) in files.take(files.length - cap)) {
          await file.delete();
        }
      }
    } catch (_) {}
  }

  /// Forget everything on disk. The customer's «مسح الصور المؤقتة», and the
  /// tests'.
  Future<void> clear() async {
    final root = await (_root ??= _open());
    if (root == null) return;
    try {
      await root.delete(recursive: true);
      await root.create(recursive: true);
    } catch (_) {}
  }
}

/// An [ImageProvider] over [PictureStore]. Equal by URL, so Flutter's own
/// in-memory image cache does its usual work on top.
class ZbPicture extends ImageProvider<ZbPicture> {
  const ZbPicture(this.url, {this.scale = 1.0});

  final String url;
  final double scale;

  @override
  Future<ZbPicture> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<ZbPicture>(this);

  @override
  ImageStreamCompleter loadImage(ZbPicture key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _codec(key, decode),
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: () => [
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<ZbPicture>('Image key', key),
      ],
    );
  }

  Future<ui.Codec> _codec(ZbPicture key, ImageDecoderCallback decode) async {
    final bytes = await PictureStore.instance.bytes(key.url);
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is ZbPicture && other.url == url && other.scale == scale;

  @override
  int get hashCode => Object.hash(url, scale);

  @override
  String toString() => 'ZbPicture("$url", scale: $scale)';
}
