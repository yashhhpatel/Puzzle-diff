import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent player progress and settings.
class Progress extends ChangeNotifier {
  static final Progress I = Progress._();
  Progress._();
  SharedPreferences? _p;

  int level = 1;
  int coins = 500;
  bool sound = true, vibration = true, music = true;
  Map<String, int> boosters = {'wand': 2, 'broom': 2, 'magnet': 2};
  bool onboarded = false;
  bool adsFree = false;

  /// Number of cold starts, including this one (1 on the first launch).
  int launchCount = 0;

  /// Best star rating per completed level.
  Map<int, int> stars = {};

  /// Date key (yyyymmdd) of the last completed Daily Challenge.
  int dailyDone = 0;

  /// Purchase IDs already granted, so a re-delivered purchase is not paid out twice.
  List<String> grantedPurchases = [];

  int get totalStars => stars.values.fold(0, (a, b) => a + b);

  Future<void> load() async {
    try {
      _p = await SharedPreferences.getInstance();
      level = _p!.getInt('level') ?? 1;
      coins = _p!.getInt('coins') ?? 500;
      sound = _p!.getBool('sound') ?? true;
      vibration = _p!.getBool('vibration') ?? true;
      music = _p!.getBool('music') ?? true;
      for (final k in boosters.keys.toList()) {
        boosters[k] = _p!.getInt('b_$k') ?? 2;
      }
      onboarded = _p!.getBool('onboarded') ?? false;
      adsFree = _p!.getBool('adsFree') ?? false;
      dailyDone = _p!.getInt('dailyDone') ?? 0;
      stars = {
        for (final e in _p!.getStringList('stars') ?? const <String>[])
          if (e.contains(':')) int.parse(e.split(':')[0]): int.parse(e.split(':')[1]),
      };
      grantedPurchases = _p!.getStringList('granted') ?? [];
      launchCount = (_p!.getInt('launchCount') ?? 0) + 1;
      _p!.setInt('launchCount', launchCount);
    } catch (_) {}
  }

  void save() {
    final p = _p;
    if (p != null) {
      p.setInt('level', level);
      p.setInt('coins', coins);
      p.setBool('sound', sound);
      p.setBool('vibration', vibration);
      p.setBool('music', music);
      boosters.forEach((k, v) => p.setInt('b_$k', v));
      p.setBool('onboarded', onboarded);
      p.setBool('adsFree', adsFree);
      p.setInt('dailyDone', dailyDone);
      p.setStringList('stars', [for (final e in stars.entries) '${e.key}:${e.value}']);
      p.setStringList('granted', grantedPurchases);
    }
    notifyListeners();
  }

  void addCoins(int n) {
    coins += n;
    save();
  }

  void recordStars(int level, int n) {
    if ((stars[level] ?? 0) < n) stars[level] = n;
    save();
  }

  static int dateKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
  bool get dailyDoneToday => dailyDone == dateKey(DateTime.now());
}

/// Version of the installed app, read at runtime from the platform (it comes
/// from `version:` in pubspec.yaml, e.g. 1.2.0+15 -> "1.2.0" build "15").
class AppInfo {
  static String version = '';
  static String build = '';

  static Future<void> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
      build = info.buildNumber;
    } catch (e) {
      debugPrint('package info failed: $e');
    }
  }

  /// "v1.2.0 (15)", or "" if unknown.
  static String get label => version.isEmpty ? '' : (build.isEmpty ? 'v$version' : 'v$version ($build)');
}

/// Sound effects, music and haptics, honouring the settings toggles.
class Sfx {
  static final Sfx I = Sfx._();
  Sfx._();
  final Map<String, List<AudioPlayer>> _pools = {};
  final Map<String, int> _next = {};
  AudioPlayer? _music;

  static const _names = ['pick', 'drop', 'shelf', 'sparkle', 'complete', 'coin', 'click', 'error', 'whoosh'];

  // Every audioplayers player requests full audio focus by default, so each
  // sound effect used to take focus from the music, which then stopped for
  // good. Effects now mix in without touching focus; only the music holds it.
  static final _sfxContext = AudioContext(
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none,
      usageType: AndroidUsageType.game,
      contentType: AndroidContentType.sonification,
    ),
    // Ambient already mixes with other audio on iOS.
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );
  static final _musicContext = AudioContext(
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.gain,
      usageType: AndroidUsageType.game,
      contentType: AndroidContentType.music,
    ),
    // Ambient already mixes with other audio on iOS.
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  Future<void> init() async {
    // Music first, so it starts as soon as the game opens.
    try {
      final m = AudioPlayer();
      await m.setAudioContext(_musicContext);
      await m.setReleaseMode(ReleaseMode.loop);
      await m.setVolume(0.35);
      await m.setSource(AssetSource('sfx/music.wav'));
      _music = m;
      updateMusic();
    } catch (e) {
      debugPrint('music init failed: $e');
    }
    for (final n in _names) {
      try {
        // Android caps AudioTracks per app, so keep the pools small.
        final count = (n == 'drop' || n == 'coin') ? 2 : 1;
        final list = <AudioPlayer>[];
        for (var i = 0; i < count; i++) {
          final p = AudioPlayer();
          await p.setAudioContext(_sfxContext);
          await p.setPlayerMode(PlayerMode.lowLatency);
          await p.setReleaseMode(ReleaseMode.stop);
          await p.setSource(AssetSource('sfx/$n.wav'));
          list.add(p);
        }
        _pools[n] = list;
        _next[n] = 0;
      } catch (e) {
        debugPrint('sfx $n init failed: $e');
      }
    }
  }

  /// True while the background music is actually playing (for diagnostics).
  bool get musicPlaying => _music?.state == PlayerState.playing;

  void play(String name) {
    if (!Progress.I.sound) return;
    final pool = _pools[name];
    if (pool == null || pool.isEmpty) return;
    final i = _next[name]!;
    _next[name] = (i + 1) % pool.length;
    final p = pool[i];
    p.stop().then((_) => p.resume()).catchError((_) {});
  }

  void haptic() {
    if (Progress.I.vibration) HapticFeedback.lightImpact();
  }

  void updateMusic() {
    final m = _music;
    if (m == null) return;
    if (Progress.I.music) {
      m.resume().catchError((Object e) => debugPrint('music resume failed: $e'));
    } else {
      m.pause().catchError((_) {});
    }
  }

  void pauseMusic() => _music?.pause().catchError((_) {});
}
