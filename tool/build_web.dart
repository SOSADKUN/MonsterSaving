// Builds the Flutter Web release and caches its complete local asset set.
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

Future<void> main() async {
  final build = await Process.start(
    'flutter',
    ['build', 'web', '--release', '--no-web-resources-cdn'],
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  final result = await build.exitCode;
  if (result != 0) {
    exit(result);
  }
  await prepareOfflineBundle();
}

Future<void> prepareOfflineBundle() async {
  final root = Directory('build/web').absolute;
  // Remove the replaced font from incremental bundles before offline caching.
  final legacyFont = File('${root.path}/assets/assets/fonts/NotoSansTC.ttf');
  if (!File('assets/fonts/NotoSansTC.ttf').existsSync() &&
      await legacyFont.exists()) {
    await legacyFont.delete();
  }
  final files = await root
      .list(recursive: true)
      .where((e) => e is File)
      .cast<File>()
      .toList();
  files.sort((a, b) => a.path.compareTo(b.path));
  final resources = <String>[];
  final hashes = <String>[];
  for (final file in files) {
    final relative = file.path
        .substring(root.path.length + 1)
        .replaceAll(Platform.pathSeparator, '/');
    if (relative == 'saving_monster_sw.js' ||
        relative == 'flutter_service_worker.js' ||
        relative == '_headers' ||
        relative.startsWith('.')) {
      continue;
    }
    resources.add(Uri(path: relative).toString());
    hashes.add('$relative:${sha256.convert(await file.readAsBytes())}');
  }
  final version = sha256
      .convert(utf8.encode(hashes.join('\n')))
      .toString()
      .substring(0, 20);
  final worker =
      '''
'use strict';
const CACHE = 'saving-monster-$version';
const RESOURCES = ${jsonEncode(resources)};
self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    await cache.addAll(RESOURCES);
    await self.skipWaiting();
  })());
});
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      if (key.startsWith('saving-monster-') && key !== CACHE) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});
self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET' || new URL(event.request.url).origin !== self.location.origin) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const cached = await cache.match(event.request, {ignoreSearch: true});
    if (cached) {
      // Cached MP4 playback must support the byte ranges used by mobile browsers.
      const range = event.request.headers.get('range');
      if (range && new URL(event.request.url).pathname.endsWith('.mp4')) {
        const data = await cached.arrayBuffer();
        const match = range.match(/^bytes=([0-9]*)-([0-9]*)/);
        if (!match || match[0] !== range || (!match[1] && !match[2])) return new Response(null, {status: 416, headers: {'Content-Range': 'bytes */' + data.byteLength}});
        const suffix = !match[1];
        const start = suffix ? Math.max(0, data.byteLength - Number(match[2])) : Number(match[1]);
        const end = suffix || !match[2] ? data.byteLength - 1 : Math.min(Number(match[2]), data.byteLength - 1);
        if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start < 0 || start > end || start >= data.byteLength) return new Response(null, {status: 416, headers: {'Content-Range': 'bytes */' + data.byteLength}});
        const headers = new Headers(cached.headers);
        headers.set('Content-Type', 'video/mp4');
        headers.set('Content-Length', String(end - start + 1));
        headers.set('Content-Range', 'bytes ' + start + '-' + end + '/' + data.byteLength);
        headers.set('Accept-Ranges', 'bytes');
        headers.delete('Content-Encoding');
        return new Response(data.slice(start, end + 1), {status: 206, headers});
      }
      return cached;
    }
    try { return await fetch(event.request); }
    catch (error) {
      if (event.request.mode === 'navigate') {
        const index = await cache.match(new URL('index.html', self.registration.scope));
        if (index) return index;
      }
      throw error;
    }
  })());
});
''';
  await File('${root.path}/saving_monster_sw.js').writeAsString(worker);
  stdout.writeln(
    'Offline worker prepared: ${resources.length} bundled resources, version $version.',
  );
}
