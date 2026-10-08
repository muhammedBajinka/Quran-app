import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran_app/models/audio/media_item.dart';
import 'package:quran_app/state/audio/media_audio_controller.dart';

class DelayedAudioPlayer extends Fake implements AudioPlayer {
  final loaded = <String>[];
  final played = <String?>[];
  String? source;
  Completer<Duration?>? nextLoad;
  Completer<void>? nextStop;
  Completer<void>? nextPause;
  Completer<void>? nextSeek;
  bool failNextLoad = false;
  bool failNextPlay = false;
  bool disposed = false;
  ProcessingState state = ProcessingState.ready;

  @override
  ProcessingState get processingState => state;

  @override
  Future<Duration?> setUrl(String url, {
    Map<String, String>? headers,
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) async {
    loaded.add(url);
    final pending = nextLoad;
    nextLoad = null;
    if (pending != null) await pending.future;
    if (failNextLoad) {
      failNextLoad = false;
      throw StateError('source failed');
    }
    source = url;
    return const Duration(seconds: 10);
  }

  @override
  Future<void> stop() async {
    final pending = nextStop;
    nextStop = null;
    if (pending != null) await pending.future;
  }

  @override
  Future<void> pause() async {
    final pending = nextPause;
    nextPause = null;
    if (pending != null) await pending.future;
  }

  @override
  Future<void> play() async {
    if (failNextPlay) {
      failNextPlay = false;
      throw StateError('play failed');
    }
    played.add(source);
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    final pending = nextSeek;
    nextSeek = null;
    if (pending != null) await pending.future;
    state = ProcessingState.ready;
  }

  @override
  Future<void> dispose() async { disposed = true; }
}

MediaItem clip(String id) => MediaItem(
  id: id, type: MediaItemType.dua, title: id,
  audioUrl: 'https://example.com/$id.mp3',
);

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DelayedAudioPlayer player;
  late MediaAudioController controller;
  setUp(() {
    player = DelayedAudioPlayer();
    controller = MediaAudioController(player: player);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
  });
  tearDown(() => controller.dispose());

  test('a delayed old source cannot play over the newly selected clip', () async {
    final load = Completer<Duration?>();
    player.nextLoad = load;
    final first = controller.playItem(clip('first'));
    await flush();
    final second = controller.playItem(clip('second'));
    expect(player.loaded, ['https://example.com/first.mp3']);
    load.complete(null);
    await Future.wait([first, second]);
    expect(player.played, ['https://example.com/second.mp3']);
    expect(controller.currentItem?.id, 'second');
  });

  test('pause during a load prevents late automatic playback', () async {
    final load = Completer<Duration?>();
    player.nextLoad = load;
    final operation = controller.playItem(clip('first'));
    await flush();
    await controller.pause();
    load.complete(null);
    await operation;
    expect(player.played, isEmpty);
  });

  test('background load waits for foreground and resumes the latest clip', () async {
    final load = Completer<Duration?>();
    player.nextLoad = load;
    final operation = controller.playItem(clip('first'));
    await flush();
    controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
    controller.didChangeAppLifecycleState(AppLifecycleState.hidden);
    load.complete(null);
    await operation;
    await controller.playItem(clip('second'));
    expect(player.played, isEmpty);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await flush();
    expect(player.played, ['https://example.com/second.mp3']);
  });

  test('manual pause remains paused after background and foreground', () async {
    await controller.playItem(clip('first'));
    await controller.pause();
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await flush();
    expect(player.played, hasLength(1));
  });

  test('a new source waits for a delayed native pause acknowledgement', () async {
    await controller.playItem(clip('first'));
    final pending = Completer<void>();
    player.nextPause = pending;
    final pause = controller.pause();
    final next = controller.playItem(clip('second'));
    await flush();
    expect(player.played, hasLength(1));
    pending.complete();
    await Future.wait([pause, next]);
    expect(player.played.last, 'https://example.com/second.mp3');
  });

  test('a late close cannot erase or stop a newly selected source', () async {
    await controller.playItem(clip('first'));
    final pending = Completer<void>();
    player.nextStop = pending;
    final close = controller.close();
    await flush();
    final next = controller.playItem(clip('second'));
    await flush();
    expect(player.played, hasLength(1));
    pending.complete();
    await Future.wait([close, next]);
    expect(controller.currentItem?.id, 'second');
    expect(player.played.last, 'https://example.com/second.mp3');
  });

  test('pause during replay seeking does not restart completed audio', () async {
    await controller.playItem(clip('first'));
    player.state = ProcessingState.completed;
    final pending = Completer<void>();
    player.nextSeek = pending;
    final replay = controller.play();
    await flush();
    await controller.pause();
    pending.complete();
    await replay;
    expect(player.played, hasLength(1));
  });

  test('failed loads do not prevent the next clip from playing', () async {
    player.failNextLoad = true;
    await expectLater(controller.playItem(clip('first')), throwsStateError);
    await controller.playItem(clip('second'));
    expect(player.played, ['https://example.com/second.mp3']);
  });

  test('play future failures are handled without poisoning the queue', () async {
    player.failNextPlay = true;
    await controller.playItem(clip('first'));
    await flush();
    await controller.playItem(clip('second'));
    expect(player.played, ['https://example.com/second.mp3']);
  });

  test('disposing during a load never notifies or plays afterward', () async {
    final pending = Completer<Duration?>();
    player.nextLoad = pending;
    var notifications = 0;
    controller.addListener(() => notifications++);
    final operation = controller.playItem(clip('first'));
    await flush();
    controller.dispose();
    final before = notifications;
    pending.complete(null);
    await operation;
    expect(notifications, before);
    expect(player.played, isEmpty);
    expect(player.disposed, isTrue);
  });
}
