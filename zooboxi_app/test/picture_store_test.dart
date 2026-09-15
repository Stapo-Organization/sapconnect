import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/core/widgets/picture_store.dart';

/// The picture path end to end against a server of our own: bytes come
/// back, a status that is not 200 is a failure and not a picture, two asks
/// for one URL are one fetch, and a server that never answers is a timeout
/// rather than a placeholder forever.
///
/// The test binding swaps `HttpClient` for one that answers 400 to
/// everything; this is the one test that needs the real one, so the body
/// runs under an override that hands back the genuine client. The binding
/// is still initialised, so `getTemporaryDirectory` fails fast (no plugin)
/// and the store runs without its disk — which is exactly what it must
/// tolerate.
class _RealHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpServer server;
  var hits = 0;

  Future<Uint8List> fetch(String url) => HttpOverrides.runWithHttpOverrides(
        () => PictureStore.instance.bytes(url),
        _RealHttp(),
      );

  setUp(() async {
    hits = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      hits++;
      switch (request.uri.path) {
        case '/ok.png':
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType('image', 'png')
            ..add(List<int>.generate(2048, (i) => i % 251));
          await request.response.close();
        case '/missing.png':
          request.response.statusCode = 404;
          await request.response.close();
        case '/silent.png':
          // Never answers. The client must give up, not wait.
          break;
        default:
          request.response.statusCode = 500;
          await request.response.close();
      }
    });
  });

  tearDown(() => server.close(force: true));

  String url(String path) => 'http://${server.address.host}:${server.port}$path';

  test('bytes arrive whole', () async {
    final data = await fetch(url('/ok.png'));
    expect(data, isA<Uint8List>());
    expect(data.length, 2048);
    expect(data[1000], 1000 % 251);
  });

  test('a status other than 200 is an error, never an empty picture', () async {
    await expectLater(
      fetch(url('/missing.png')),
      throwsA(isA<HttpException>()),
    );
  });

  test('two asks for one URL are one fetch', () async {
    final a = fetch(url('/ok.png?shared'));
    final b = fetch(url('/ok.png?shared'));
    expect(identical(a, b), isTrue);
    await Future.wait([a, b]);
    expect(hits, 1);
  });

  test(
    'a server that never answers is a timeout, retried once on a fresh client',
    () async {
      PictureStore.instance.headersTimeout = const Duration(milliseconds: 400);
      addTearDown(() => PictureStore.instance.headersTimeout = const Duration(seconds: 15));
      await expectLater(
        fetch(url('/silent.png')),
        throwsA(isA<TimeoutException>()),
      );
      // The retry after the first timeout is the second hit.
      expect(hits, 2);
    },
  );
}
