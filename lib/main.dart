import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

import 'ad_ids.dart';
import 'app_open_ad_manager.dart';
import 'tela_inicial.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  MobileAds.instance.initialize();
  AppOpenAdManager.instance.loadAd();
  runApp(const EzCobrinhaApp());
}

class EzCobrinhaApp extends StatefulWidget {
  const EzCobrinhaApp({super.key});

  @override
  State<EzCobrinhaApp> createState() => _EzCobrinhaAppState();
}

class _EzCobrinhaAppState extends State<EzCobrinhaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Mostra o anúncio de abertura ao retornar do background (não no cold start).
    if (state == AppLifecycleState.resumed) {
      AppOpenAdManager.instance.showAdIfAvailable();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Classic Snake - Ez Cobrinha',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TelaInicial()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Image.asset(
          'assets/images/splash.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

const int rowCount = 28;
const int colCount = 14;
const int totalCells = rowCount * colCount;

enum Direction { up, down, left, right }

final List<Color> levelColors = [
  const Color(0xFF00E5FF),
  const Color(0xFF00FF85),
  const Color(0xFFFFEA00),
  const Color(0xFFFF9100),
  const Color(0xFFFF3D71),
  const Color(0xFFFF1744),
  const Color(0xFF9D00FF),
  const Color(0xFF2979FF),
  const Color(0xFF00BFA5),
  const Color(0xFF76FF03),
];

final List<Color> _boardThemes = [
  const Color(0xFFE8F5E9),
  const Color(0xFFA5D6A7),
  const Color(0xFFFCE4EC),
  const Color(0xFFFFF9C4),
  const Color(0xFFE1F5FE),
  const Color(0xFF0F172A),
];

class SnakeGame extends StatefulWidget {
  const SnakeGame({super.key});

  @override
  State<SnakeGame> createState() => _SnakeGameState();
}

class _SnakeGameState extends State<SnakeGame> with WidgetsBindingObserver {
  List<int> snake = [];
  int foodIndex = 0;
  Direction currentDir = Direction.up;
  Direction nextDir = Direction.up;
  Color snakeColor = Colors.white;
  Color foodColor = Colors.white;
  Color nextFoodColor = Colors.white;

  int difficulty = 0;
  final Random random = Random();

  Timer? _gameTimer;
  Timer? _gameClockTimer;
  Timer? _countdownTimer;
  Timer? _longPressTimer;
  Timer? _bannerRetryTimer;

  // ── Cabeça ────────────────────────────────────────────────────────────────
  // 'closed' | 'half' | 'open'  — nunca pisca, só anima quando necessário
  String _headImageState = 'closed';
  Timer? _mouthAnimTimer;
  Timer? _randomHalfTimer;
  bool _isMouthAnimating = false;
  int _mouthAnimStep = 0;
  // Flag para evitar que o Future.delayed dispare depois de cancelado
  int _randomHalfGeneration = 0;
  static const int _mouthOpenDistance = 3;

  // ── Rabo ──────────────────────────────────────────────────────────────────
  bool _tailFlipped = false;
  Timer? _tailWagTimer;

  int score = 0;
  int recordScore = 0;
  int currentLevel = 1;
  int secondsPlayed = 0;

  bool isFastDropping = false;
  int vidas = 3;
  DateTime? exhaustedTime;
  Duration remainingWait = Duration.zero;

  bool isPaused = false;
  bool isGameOver = false;
  bool isLifeLostOverlay = false;
  DateTime? _pauseStartTime;

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  final AudioPlayer _musicPlayer = AudioPlayer();
  AudioPool? _dropPool;
  AudioPool? _deathPool;
  AudioPool? _movePool;
  int _lastMoveSound = 0;

  bool _isMusicMenuOpen = false;
  bool _isThemeMenuOpen = false;
  int _currentTrackIndex = 0;
  int _currentThemeIndex = 0;
  bool _isMusicMuted = false;
  bool _areEffectsMuted = false;

  final List<String> _tracks = [
    'ambiente.mp3',
    'bombinsound.mp3',
    'luxury.mp3',
    'morning.mp3',
    'mountain.mp3',
    'relax.mp3',
  ];

  final List<int> _levelSpeeds = [
    500, 450, 400, 350, 300, 260, 220, 190, 160, 140, 120, 100, 90, 80, 70,
  ];

  // ── LIFECYCLE ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startRandomHalfTimer();
    _startTailWagTimer();
    unawaited(_configureAudio());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadAds());
    });
    _initializeGame();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (!isGameOver && !isLifeLostOverlay && !isPaused) {
        _togglePause(forcePause: true);
      }
      _musicPlayer.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (!_isMusicMuted) _musicPlayer.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Invalida geração do timer aleatório para bloquear Future.delayed pendentes
    _randomHalfGeneration++;
    _gameTimer?.cancel();
    _gameClockTimer?.cancel();
    _countdownTimer?.cancel();
    _longPressTimer?.cancel();
    _bannerRetryTimer?.cancel();
    _mouthAnimTimer?.cancel();
    _randomHalfTimer?.cancel();
    _tailWagTimer?.cancel();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _musicPlayer.dispose();
    if (_dropPool != null) unawaited(_dropPool!.dispose());
    if (_deathPool != null) unawaited(_deathPool!.dispose());
    if (_movePool != null) unawaited(_movePool!.dispose());
    super.dispose();
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  /// Chama setState somente se o widget ainda está montado.
  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  // ── ÁUDIO ─────────────────────────────────────────────────────────────────

  Future<void> _configureAudio() async {
    if (!mounted) return;
    final musicCtx = AudioContext(
      android: const AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: false,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.none,
      ),
    );
    final fxCtx = AudioContext(
      android: const AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: false,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.game,
        audioFocus: AndroidAudioFocus.none,
      ),
    );
    await _musicPlayer.setAudioContext(musicCtx);
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    _dropPool = await AudioPool.create(
      source: AssetSource('sounds/bloco.wav'),
      maxPlayers: 4, minPlayers: 1,
      playerMode: PlayerMode.mediaPlayer, audioContext: fxCtx,
    );
    _deathPool = await AudioPool.create(
      source: AssetSource('sounds/arroto.mp3'),
      maxPlayers: 2, minPlayers: 1,
      playerMode: PlayerMode.mediaPlayer, audioContext: fxCtx,
    );
    _movePool = await AudioPool.create(
      source: AssetSource('sounds/gluup.mp3'),
      maxPlayers: 3, minPlayers: 1,
      playerMode: PlayerMode.mediaPlayer, audioContext: fxCtx,
    );
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) await _playMusic(0);
  }

  Future<void> _playMusic(int index) async {
    if (!mounted) return;
    _safeSetState(() { _currentTrackIndex = index; _isMusicMenuOpen = false; });
    await _musicPlayer.stop();
    await _musicPlayer.setVolume(0.4);
    await _musicPlayer.play(AssetSource('sounds/${_tracks[index]}'));
    if (_isMusicMuted) await _musicPlayer.pause();
  }

  void _playInteractionSound() {
    if (_areEffectsMuted) return;
    HapticFeedback.selectionClick();
    _dropPool?.start(volume: 1.0);
  }

  void _playDeathSound() {
    if (_areEffectsMuted) return;
    HapticFeedback.heavyImpact();
    _deathPool?.start(volume: 1.0);
  }

  void _playMoveSound() {
    if (_areEffectsMuted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastMoveSound < 80) return;
    _lastMoveSound = now;
    _movePool?.start(volume: 0.4);
  }

  void _toggleMusicMute() {
    _safeSetState(() => _isMusicMuted = !_isMusicMuted);
    if (_isMusicMuted) { _musicPlayer.pause(); } else { _musicPlayer.resume(); }
  }

  void _toggleEffectsMute() {
    _safeSetState(() => _areEffectsMuted = !_areEffectsMuted);
  }

  // ── PERSISTÊNCIA ──────────────────────────────────────────────────────────

  Future<void> _initializeGame() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _safeSetState(() {
      recordScore = prefs.getInt('snakeRecordScore') ?? 0;
      vidas = prefs.getInt('snakeVidas') ?? 3;
      difficulty = prefs.getInt('snakeDiffLevel') ?? 0;
      _currentThemeIndex = prefs.getInt('snakeTheme') ?? 5;
      final savedTime = prefs.getString('snakeExhaustedTime');
      if (savedTime != null) exhaustedTime = DateTime.parse(savedTime);
    });
    if (vidas <= 0) {
      isGameOver = true;
      _startCountdown();
    } else {
      _startGame(isNewGame: false);
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('snakeRecordScore', recordScore);
    await prefs.setInt('snakeVidas', vidas);
    await prefs.setInt('snakeDiffLevel', difficulty);
    await prefs.setInt('snakeTheme', _currentThemeIndex);
    if (exhaustedTime != null) {
      await prefs.setString('snakeExhaustedTime', exhaustedTime!.toIso8601String());
    } else {
      await prefs.remove('snakeExhaustedTime');
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (exhaustedTime == null) { t.cancel(); return; }
      final passed = DateTime.now().difference(exhaustedTime!);
      const totalWait = Duration(minutes: 120);
      if (passed >= totalWait) {
        _safeSetState(() { vidas = 3; exhaustedTime = null; remainingWait = Duration.zero; });
        _saveData();
        t.cancel();
      } else {
        _safeSetState(() => remainingWait = totalWait - passed);
      }
    });
  }

  // ── ADS ───────────────────────────────────────────────────────────────────

  Future<void> _loadAds() async {
    if (!mounted) return;
    _bannerRetryTimer?.cancel();
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerLoaded = false;
    final mq = MediaQuery.maybeOf(context);
    final screenWidth = mq == null ? 320 : mq.size.width.truncate();
    final adaptiveSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(screenWidth);
    if (!mounted) return;
    final banner = BannerAd(
      adUnitId: AdUnitIds.banner,
      size: adaptiveSize ?? AdSize.banner,
      request: const AdRequest(nonPersonalizedAds: true),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) { ad.dispose(); return; }
          _safeSetState(() { _bannerAd = ad as BannerAd; _isBannerLoaded = true; });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          _safeSetState(() { _bannerAd = null; _isBannerLoaded = false; });
          _bannerRetryTimer = Timer(const Duration(seconds: 12), () {
            if (mounted) unawaited(_loadAds());
          });
        },
      ),
    );
    _bannerAd = banner;
    banner.load();
    _loadInterstitialAd();
    _loadRewardedAd();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: AdUnitIds.interstitial,
      request: const AdRequest(nonPersonalizedAds: true),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) { if (mounted) _interstitialAd = ad; else ad.dispose(); },
        onAdFailedToLoad: (_) { if (mounted) _interstitialAd = null; },
      ),
    );
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: AdUnitIds.rewarded,
      request: const AdRequest(nonPersonalizedAds: true),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) { if (mounted) _rewardedAd = ad; else ad.dispose(); },
        onAdFailedToLoad: (_) { if (mounted) _rewardedAd = null; },
      ),
    );
  }

  void _showRewardedAd() {
    if (_rewardedAd == null || !mounted) return;
    bool rewardEarned = false;
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewardedAd();
        if (!mounted) return;
        if (rewardEarned) _processReward();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadRewardedAd();
      },
    );
    _rewardedAd!.show(onUserEarnedReward: (_, __) => rewardEarned = true);
    _rewardedAd = null;
  }

  void _processReward() {
    if (!mounted) return;
    _countdownTimer?.cancel();
    _safeSetState(() {
      vidas = 2;
      exhaustedTime = null;
      isGameOver = false;
      remainingWait = Duration.zero;
    });
    _saveData();
    _startGame(isNewGame: true);
  }

  // ── LÓGICA DO JOGO ────────────────────────────────────────────────────────

  void _startGameClock() {
    _gameClockTimer?.cancel();
    _gameClockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (!isPaused && !isGameOver && !isLifeLostOverlay) {
        _safeSetState(() => secondsPlayed++);
      }
    });
  }

  String _formatPlayTime() {
    final m = (secondsPlayed ~/ 60).toString().padLeft(2, '0');
    final s = (secondsPlayed % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  void _checkLevelUp() {
    final calcLevel = (score ~/ 100) + 1;
    if (calcLevel != currentLevel) {
      _safeSetState(() => currentLevel = calcLevel);
      _resumeTimer();
    }
  }

  int _getSpeedForCurrentLevel() {
    if (difficulty == 0) return _levelSpeeds[0];
    int idx = (currentLevel - 1).clamp(0, _levelSpeeds.length - 1);
    return _levelSpeeds[idx];
  }

  void _startGame({bool isNewGame = true}) {
    // Cancela todos os timers de animação antes de resetar estado
    _mouthAnimTimer?.cancel();
    _randomHalfGeneration++;          // invalida Future.delayed pendentes
    _isMouthAnimating = false;

    _safeSetState(() {
      if (isNewGame) { score = 0; secondsPlayed = 0; currentLevel = 1; }
      isFastDropping = false;
      isGameOver = false;
      isLifeLostOverlay = false;
      isPaused = false;
      _pauseStartTime = null;
      _headImageState = 'closed';
      _tailFlipped = false;
      final startRow = rowCount ~/ 2;
      final startCol = colCount ~/ 2;
      snake = [
        startRow * colCount + startCol,
        (startRow + 1) * colCount + startCol,
        (startRow + 2) * colCount + startCol,
      ];
      currentDir = Direction.up;
      nextDir = Direction.up;
      snakeColor = _getRandomColor();
      foodColor = _getRandomColor();
      nextFoodColor = _getRandomColor();
    });

    if (isNewGame) _saveData();
    _spawnFood();
    _startRandomHalfTimer();
    _startTailWagTimer();
    _startGameClock();
    _resumeTimer();
  }

  void _resumeTimer() {
    _gameTimer?.cancel();
    if (isGameOver || isPaused || isLifeLostOverlay) return;
    final speed = isFastDropping ? 40 : _getSpeedForCurrentLevel();
    _gameTimer = Timer.periodic(Duration(milliseconds: speed), (_) => _moveSnake());
  }

  Color _getRandomColor() {
    final maxColors = min(currentLevel + 2, levelColors.length);
    return levelColors[random.nextInt(maxColors)];
  }

  void _spawnFood() {
    final empty = <int>[];
    for (int i = 0; i < totalCells; i++) {
      if (!snake.contains(i)) empty.add(i);
    }
    if (empty.isNotEmpty) foodIndex = empty[random.nextInt(empty.length)];
  }

  /// Movimenta a cobra — todo setState é separado, sem aninhamento.
  void _moveSnake() {
    if (!mounted || isPaused || isGameOver || isLifeLostOverlay) return;

    currentDir = nextDir;
    int head = snake.first;
    int r = head ~/ colCount;
    int c = head % colCount;

    if (currentDir == Direction.up)    r--;
    else if (currentDir == Direction.down)  r++;
    else if (currentDir == Direction.left)  c--;
    else if (currentDir == Direction.right) c++;

    if (difficulty == 2) {
      if (r < 0 || r >= rowCount || c < 0 || c >= colCount) {
        _handleCollisionDeath();
        return;
      }
    } else {
      if (r < 0) r = rowCount - 1;
      if (r >= rowCount) r = 0;
      if (c < 0) c = colCount - 1;
      if (c >= colCount) c = 0;
    }

    final newHead = r * colCount + c;
    if (snake.contains(newHead)) {
      _handleCollisionDeath();
      return;
    }

    final ateFood = newHead == foodIndex;

    // setState único, sem chamadas externas dentro dele
    _safeSetState(() {
      snake.insert(0, newHead);
      if (!ateFood) snake.removeLast();
    });

    _playMoveSound();
    _checkMouthAnimation();

    if (ateFood) {
      _playInteractionSound();
      _mouthAnimTimer?.cancel();
      _isMouthAnimating = false;
      _safeSetState(() {
        _headImageState = 'closed';
        snakeColor = foodColor;
        foodColor = nextFoodColor;
        nextFoodColor = _getRandomColor();
        score += 10;
        if (score > recordScore) recordScore = score;
      });
      _saveData();
      _checkLevelUp();
      _spawnFood();
    }
  }

  void _onDirectionDown(Direction dir) {
    if (isGameOver || isLifeLostOverlay || isPaused) return;
    bool changed = false;
    if (dir == Direction.up && currentDir != Direction.down)    { nextDir = Direction.up;    changed = true; }
    else if (dir == Direction.down && currentDir != Direction.up)   { nextDir = Direction.down;  changed = true; }
    else if (dir == Direction.left && currentDir != Direction.right) { nextDir = Direction.left;  changed = true; }
    else if (dir == Direction.right && currentDir != Direction.left) { nextDir = Direction.right; changed = true; }
    if (changed) { _moveSnake(); _resumeTimer(); }
    _longPressTimer?.cancel();
    _longPressTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _safeSetState(() => isFastDropping = true);
      _resumeTimer();
    });
  }

  void _onDirectionUp() {
    _longPressTimer?.cancel();
    if (isFastDropping) {
      _safeSetState(() => isFastDropping = false);
      _resumeTimer();
    }
  }

  void _handleCollisionDeath() {
    _gameTimer?.cancel();
    _mouthAnimTimer?.cancel();
    _isMouthAnimating = false;
    _playDeathSound();
    if (vidas > 1) {
      _safeSetState(() { vidas--; isLifeLostOverlay = true; isFastDropping = false; });
      _saveData();
    } else {
      _safeSetState(() {
        vidas = 0; isGameOver = true;
        isFastDropping = false;
        exhaustedTime = DateTime.now();
      });
      _saveData();
      _startCountdown();
    }
  }

  void _resumeFromLifeLost() {
    if (!mounted) return;
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose(); _loadInterstitialAd();
          if (!mounted) return;
          _finishResumeFromLifeLost();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose(); _loadInterstitialAd();
          if (!mounted) return;
          _finishResumeFromLifeLost();
        },
      );
      _interstitialAd!.show();
      _interstitialAd = null;
    } else {
      _finishResumeFromLifeLost();
    }
  }

  void _finishResumeFromLifeLost() {
    if (!mounted) return;
    _safeSetState(() => isLifeLostOverlay = false);
    _startGame(isNewGame: false);
  }

  void _togglePause({bool forcePause = false}) {
    if (!mounted || isGameOver || isLifeLostOverlay) return;
    if (isPaused && !forcePause) {
      final pausedLong = _pauseStartTime != null &&
          DateTime.now().difference(_pauseStartTime!).inSeconds >= 10;
      if (pausedLong && _interstitialAd != null) {
        _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose(); _loadInterstitialAd();
            if (!mounted) return;
            _safeSetState(() { isPaused = false; _pauseStartTime = null; });
            _resumeTimer();
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            ad.dispose(); _loadInterstitialAd();
            if (!mounted) return;
            _safeSetState(() { isPaused = false; _pauseStartTime = null; });
            _resumeTimer();
          },
        );
        _interstitialAd!.show();
        _interstitialAd = null;
        return;
      }
      _safeSetState(() { isPaused = false; _pauseStartTime = null; });
      _resumeTimer();
    } else if (!isPaused) {
      _safeSetState(() {
        isPaused = true; isFastDropping = false;
        _pauseStartTime = DateTime.now();
      });
      _gameTimer?.cancel();
    }
  }

  void _triggerReset() {
    if (!mounted) return;
    if (vidas <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sem vidas! Assista ao vídeo.'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }
    _togglePause(forcePause: true);
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose(); _loadInterstitialAd();
          if (!mounted) return;
          _startGame(isNewGame: true);
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose(); _loadInterstitialAd();
          if (!mounted) return;
          _startGame(isNewGame: true);
        },
      );
      _interstitialAd!.show();
      _interstitialAd = null;
    } else {
      _startGame(isNewGame: true);
    }
  }

  String _formatWaitTime() {
    final h = remainingWait.inHours.toString().padLeft(2, '0');
    final m = (remainingWait.inMinutes % 60).toString().padLeft(2, '0');
    final s = (remainingWait.inSeconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  bool isPlaying() => !isPaused && !isGameOver && !isLifeLostOverlay && score > 0;

  // ── ANIMAÇÃO DA CABEÇA ────────────────────────────────────────────────────

  /// Efeito aleatório de língua/vida — usa geração para cancelar Future.delayed antigos.
  void _startRandomHalfTimer() {
    _randomHalfTimer?.cancel();
    final myGen = ++_randomHalfGeneration;
    final interval = 2000 + random.nextInt(3000);
    _randomHalfTimer = Timer(Duration(milliseconds: interval), () {
      // Se a geração mudou, este disparo é obsoleto — ignora
      if (!mounted || myGen != _randomHalfGeneration) return;
      if (_isMouthAnimating || isPaused || isGameOver) {
        _startRandomHalfTimer();
        return;
      }
      _safeSetState(() => _headImageState = 'half');
      final capturedGen = _randomHalfGeneration;
      Future.delayed(const Duration(milliseconds: 180), () {
        if (!mounted || capturedGen != _randomHalfGeneration) return;
        if (!_isMouthAnimating) _safeSetState(() => _headImageState = 'closed');
        _startRandomHalfTimer();
      });
    });
  }

  int _distanceToFood() {
    if (snake.isEmpty) return 999;
    final head = snake.first;
    final hr = head ~/ colCount; final hc = head % colCount;
    final fr = foodIndex ~/ colCount; final fc = foodIndex % colCount;
    return (hr - fr).abs() + (hc - fc).abs();
  }

  void _checkMouthAnimation() {
    if (_distanceToFood() <= _mouthOpenDistance && !_isMouthAnimating) {
      _startMouthOpenAnimation();
    }
  }

  void _startMouthOpenAnimation() {
    if (_isMouthAnimating) return;
    _isMouthAnimating = true;
    _mouthAnimStep = 0;
    _runMouthStep();
  }

  void _runMouthStep() {
    if (!mounted) { _isMouthAnimating = false; return; }
    if (_distanceToFood() > _mouthOpenDistance + 1) {
      _isMouthAnimating = false;
      _safeSetState(() => _headImageState = 'closed');
      return;
    }
    const frames = ['half', 'open', 'half', 'closed'];
    _safeSetState(() => _headImageState = frames[_mouthAnimStep % frames.length]);
    _mouthAnimStep++;
    _mouthAnimTimer?.cancel();
    _mouthAnimTimer = Timer(const Duration(milliseconds: 130), _runMouthStep);
  }

  // ── ANIMAÇÃO DO RABO ──────────────────────────────────────────────────────

  void _startTailWagTimer() {
    _tailWagTimer?.cancel();
    final interval = 300 + random.nextInt(300);
    _tailWagTimer = Timer(Duration(milliseconds: interval), () {
      if (!mounted) return;
      if (!isPaused && !isGameOver && snake.length >= 2) {
        _safeSetState(() => _tailFlipped = !_tailFlipped);
      }
      _startTailWagTimer();
    });
  }

  // ── WIDGETS ───────────────────────────────────────────────────────────────

  /// Cabeça: 10% maior que a célula, rotacionada conforme direção.
  Widget _buildHeadImage(double cellSize) {
    final headSize = cellSize * 1.10;
    int qTurns;
    switch (currentDir) {
      case Direction.up:    qTurns = 0; break;
      case Direction.right: qTurns = 1; break;
      case Direction.down:  qTurns = 2; break;
      case Direction.left:  qTurns = 3; break;
    }
    return SizedBox(
      width: cellSize, height: cellSize,
      child: OverflowBox(
        maxWidth: headSize, maxHeight: headSize,
        child: RotatedBox(
          quarterTurns: qTurns,
          child: Image.asset(
            'assets/images/head_$_headImageState.png',
            width: headSize, height: headSize, fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  /// Rabo: 70% da célula, rotacionado conforme direção do segmento final.
  /// O balanço respeita o eixo correto conforme orientação (horizontal/vertical).
  Widget _buildTailImage(double cellSize) {
    final tail = snake.last;
    final prev = snake[snake.length - 2];
    final dr = (tail ~/ colCount) - (prev ~/ colCount);
    final dc = (tail % colCount) - (prev % colCount);

    int qTurns;
    if      (dr < 0) qTurns = 0;
    else if (dr > 0) qTurns = 2;
    else if (dc < 0) qTurns = 3;
    else             qTurns = 1;

    // Rabo vertical (dr != 0): balança no eixo X
    // Rabo horizontal (dc != 0): balança no eixo Y
    final scaleX = (dr != 0 && _tailFlipped) ? -1.0 : 1.0;
    final scaleY = (dc != 0 && _tailFlipped) ? -1.0 : 1.0;

    const tailSize = 0.70; // 70% da célula
    return SizedBox(
      width: cellSize, height: cellSize,
      child: Center(
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(scaleX, scaleY, 1.0),
          child: RotatedBox(
            quarterTurns: qTurns,
            child: Image.asset(
              'assets/images/tail.png',
              width: cellSize * tailSize,
              height: cellSize * tailSize,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlNode(Direction dir, IconData icon) {
    return Listener(
      onPointerDown: (_) => _onDirectionDown(dir),
      onPointerUp: (_) => _onDirectionUp(),
      onPointerCancel: (_) => _onDirectionUp(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 85, height: 70, alignment: Alignment.center,
        child: _buildBrickBtn(icon),
      ),
    );
  }

  Widget _sideStatusBlock(String title, String value,
      {bool isHighlight = false, bool isGold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(children: [
        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(
          fontSize: isHighlight ? 18 : 15, fontWeight: FontWeight.bold,
          color: isGold ? Colors.amber : (isHighlight ? Colors.cyanAccent : Colors.white),
        )),
      ]),
    );
  }

  Widget _buildNextPiecePreview() {
    return Container(
      width: 20, height: 20,
      decoration: BoxDecoration(
        color: nextFoodColor, shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: nextFoodColor.withOpacity(0.6), blurRadius: 10, spreadRadius: 2)],
      ),
    );
  }

  Widget _buildBrickBtn(IconData icon) {
    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(color: Colors.amber, shape: BoxShape.circle, boxShadow: [
        BoxShadow(color: Colors.orange[800]!, offset: const Offset(0, 5)),
        const BoxShadow(color: Colors.black54, offset: Offset(0, 8), blurRadius: 4),
      ]),
      child: Center(child: Icon(icon, color: Colors.black87, size: 36)),
    );
  }

  Widget _buildGameOverContent() {
    if (!isGameOver) return const SizedBox.shrink();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text("Score Final: $score", style: const TextStyle(fontSize: 18, color: Colors.white)),
      const SizedBox(height: 15),
      if (vidas <= 0 && exhaustedTime != null) ...[
        Text(_formatWaitTime(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber)),
        const Text("Para ganhar 3 vidas", style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 25),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700], foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          onPressed: _showRewardedAd,
          icon: const Icon(Icons.ondemand_video),
          label: const Text("ASSISTIR VÍDEO (+2 VIDAS)"),
        ),
      ],
    ]);
  }

  Widget _buildOverlay({
    required String title, required Color titleColor,
    required Widget content, required String btnText,
    required Color btnColor, required IconData icon,
    required VoidCallback action, bool hideBtn = false,
  }) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.72),
        child: Center(
          child: Container(
            width: 300,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: titleColor, width: 2),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: TextStyle(color: titleColor, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 18),
              content,
              if (!hideBtn) ...[
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  onPressed: action, icon: Icon(icon), label: Text(btnText),
                  style: ElevatedButton.styleFrom(backgroundColor: btnColor, foregroundColor: Colors.black87),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildMusicMenu() {
    return GestureDetector(
      onTap: () => _safeSetState(() => _isMusicMenuOpen = false),
      child: Container(
        color: Colors.black.withOpacity(0.85),
        child: Center(
          child: Container(
            width: 250, padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.cyanAccent, width: 2),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text("ESCOLHA A FAIXA", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(color: Colors.white24),
              for (int i = 0; i < _tracks.length; i++)
                ListTile(
                  dense: true,
                  title: Text(_tracks[i].replaceAll('.mp3', '').toUpperCase(),
                      style: TextStyle(color: _currentTrackIndex == i ? Colors.cyanAccent : Colors.white)),
                  leading: Icon(_currentTrackIndex == i ? Icons.music_note : Icons.music_off,
                      color: _currentTrackIndex == i ? Colors.cyanAccent : Colors.white54),
                  onTap: () => _playMusic(i),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeMenu() {
    return GestureDetector(
      onTap: () => _safeSetState(() => _isThemeMenuOpen = false),
      child: Container(
        color: Colors.black.withOpacity(0.85),
        child: Center(
          child: Container(
            width: 250, padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.pinkAccent, width: 2),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text("COR DO TABULEIRO", style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(color: Colors.white24),
              Wrap(
                spacing: 15, runSpacing: 15, alignment: WrapAlignment.center,
                children: List.generate(_boardThemes.length, (i) => GestureDetector(
                  onTap: () {
                    _safeSetState(() { _currentThemeIndex = i; _isThemeMenuOpen = false; });
                    _saveData();
                  },
                  child: Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      color: _boardThemes[i], borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _currentThemeIndex == i ? Colors.pinkAccent : Colors.white24,
                        width: _currentThemeIndex == i ? 3 : 1,
                      ),
                    ),
                  ),
                )),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final IconData musicMuteIcon = _isMusicMuted ? Icons.music_off : Icons.music_note;
    final Color musicMuteColor = _isMusicMuted ? Colors.redAccent : Colors.cyanAccent;
    final IconData effectsMuteIcon = _areEffectsMuted ? Icons.volume_off : Icons.graphic_eq;
    final Color effectsMuteColor = _areEffectsMuted ? Colors.redAccent : Colors.orangeAccent;
    final String pauseText = isPaused ? "(Play)" : "(Pause)";
    final IconData pauseIcon = isPaused ? Icons.play_arrow : Icons.pause;

    IconData diffIcon; Color diffColor; String diffText;
    if (difficulty == 0) {
      diffIcon = Icons.health_and_safety; diffColor = Colors.greenAccent; diffText = "NORMAL";
    } else if (difficulty == 1) {
      diffIcon = Icons.warning_amber_rounded; diffColor = Colors.orangeAccent; diffText = "DIFÍCIL";
    } else {
      diffIcon = Icons.local_fire_department; diffColor = Colors.redAccent; diffText = "EXTREMO";
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                if (_isBannerLoaded && _bannerAd != null)
                  SizedBox(
                    height: _bannerAd!.size.height.toDouble(),
                    width: double.infinity,
                    child: AdWidget(ad: _bannerAd!),
                  ),
                Expanded(
                  child: Row(
                    children: [
                      // ── Painel lateral ──────────────────────────────────
                      Container(
                        width: 88,
                        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E293B),
                          border: Border(right: BorderSide(color: Colors.white24, width: 2)),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 10),
                              const Text("NEXT", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              _buildNextPiecePreview(),
                              const SizedBox(height: 10),
                              _sideStatusBlock("LEVEL", "$currentLevel"),
                              Text(_formatPlayTime(), style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              _sideStatusBlock("SCORE", "$score", isHighlight: true),
                              _sideStatusBlock("RECORD", "$recordScore", isGold: true),
                              const Text("VIDAS", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(3, (i) => Icon(
                                  Icons.favorite,
                                  color: i < vidas ? Colors.redAccent : Colors.white24,
                                  size: 15,
                                )),
                              ),
                              const SizedBox(height: 16),
                              GestureDetector(
                                onTap: () {
                                  if (!isPlaying()) {
                                    _safeSetState(() => difficulty = (difficulty + 1) % 3);
                                    _saveData();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                      content: Text('Pausa ou Reset para trocar de modo!'),
                                      duration: Duration(seconds: 1),
                                    ));
                                  }
                                },
                                child: Column(children: [
                                  Icon(diffIcon, color: diffColor, size: 28),
                                  Text(diffText, style: TextStyle(color: diffColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                ]),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => _safeSetState(() => _isThemeMenuOpen = true),
                                child: const Column(children: [
                                  Icon(Icons.palette, color: Colors.pinkAccent, size: 26),
                                  SizedBox(height: 2),
                                  Text("(mudar)", style: TextStyle(color: Colors.white54, fontSize: 10)),
                                ]),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: _togglePause,
                                child: Column(children: [
                                  Icon(pauseIcon, color: Colors.white, size: 28),
                                  const SizedBox(height: 2),
                                  Text(pauseText, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                                ]),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: _triggerReset,
                                child: const Column(children: [
                                  Icon(Icons.replay, color: Colors.redAccent, size: 28),
                                  Text("RESET", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                ]),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // ── Tabuleiro ────────────────────────────────────────
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final cellWidth = constraints.maxWidth / colCount;
                            final cellHeight = constraints.maxHeight / rowCount;
                            final size = cellWidth < cellHeight ? cellWidth : cellHeight;
                            return GestureDetector(
                              onTap: _togglePause,
                              behavior: HitTestBehavior.translucent,
                              child: Stack(
                                children: [
                                  Center(
                                    child: SizedBox(
                                      width: size * colCount, height: size * rowCount,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: difficulty == 2 ? Colors.redAccent : Colors.grey[300]!,
                                            width: difficulty == 2 ? 4 : 2,
                                          ),
                                          color: _boardThemes[_currentThemeIndex],
                                        ),
                                        child: GridView.builder(
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: totalCells,
                                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: colCount,
                                            childAspectRatio: 1.0,
                                          ),
                                          itemBuilder: (context, index) {
                                            final isSnake = snake.contains(index);
                                            final isHead = snake.isNotEmpty && snake.first == index;
                                            final isTail = snake.length >= 3 && snake.last == index && !isHead;
                                            final isFood = index == foodIndex;
                                            final cellColor = isSnake ? snakeColor : (isFood ? foodColor : Colors.transparent);

                                            if (isHead) {
                                              return _buildHeadImage(size);
                                            } else if (isTail) {
                                              return _buildTailImage(size);
                                            } else if (isSnake) {
                                              return Padding(
                                                padding: const EdgeInsets.all(2.2),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: cellColor,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: Colors.black, width: 0.8),
                                                    boxShadow: [BoxShadow(color: cellColor.withOpacity(0.35), blurRadius: 2.5, spreadRadius: 0.3)],
                                                  ),
                                                ),
                                              );
                                            } else if (isFood) {
                                              return Padding(
                                                padding: const EdgeInsets.all(2.2),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: cellColor,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: Colors.black, width: 0.8),
                                                    boxShadow: [
                                                      BoxShadow(color: foodColor.withOpacity(0.7), blurRadius: 6, spreadRadius: 2),
                                                      BoxShadow(color: foodColor.withOpacity(0.3), blurRadius: 12, spreadRadius: 3),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            } else {
                                              final gridLineColor = _currentThemeIndex == 5 ? Colors.white10 : Colors.black12;
                                              return Container(decoration: BoxDecoration(border: Border.all(color: gridLineColor, width: 0.5)));
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Overlay: vida perdida
                                  if (isLifeLostOverlay)
                                    Positioned.fill(
                                      child: Container(
                                        color: Colors.black.withOpacity(0.72),
                                        child: Center(
                                          child: Container(
                                            width: 280, padding: const EdgeInsets.all(24),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF111827),
                                              borderRadius: BorderRadius.circular(18),
                                              border: Border.all(color: Colors.orangeAccent),
                                            ),
                                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                                              const Icon(Icons.favorite_border, color: Colors.orangeAccent, size: 44),
                                              const SizedBox(height: 10),
                                              const Text("VIDA PERDIDA", style: TextStyle(color: Colors.orangeAccent, fontSize: 22, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 12),
                                              Text("Vidas restantes: $vidas", style: const TextStyle(color: Colors.white)),
                                              const SizedBox(height: 20),
                                              ElevatedButton.icon(
                                                onPressed: _resumeFromLifeLost,
                                                icon: const Icon(Icons.play_arrow),
                                                label: const Text("CONTINUAR"),
                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black87),
                                              ),
                                            ]),
                                          ),
                                        ),
                                      ),
                                    ),
                                  // Overlay: pausa / game over
                                  if ((isGameOver || isPaused) && !isLifeLostOverlay)
                                    _buildOverlay(
                                      title: isGameOver ? "GAME OVER" : "PAUSADO",
                                      titleColor: isGameOver ? Colors.redAccent : Colors.cyanAccent,
                                      content: _buildGameOverContent(),
                                      btnText: isGameOver ? "" : "DESPAUSAR",
                                      btnColor: Colors.cyanAccent,
                                      icon: Icons.play_arrow,
                                      action: _togglePause,
                                      hideBtn: isGameOver && vidas <= 0,
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Controles ────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.only(bottom: 8, top: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    border: Border(top: BorderSide(color: Colors.white24, width: 2)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildControlNode(Direction.up, Icons.arrow_drop_up),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            _buildControlNode(Direction.left, Icons.arrow_left),
                            const SizedBox(width: 45),
                            _buildControlNode(Direction.right, Icons.arrow_right),
                          ]),
                          _buildControlNode(Direction.down, Icons.arrow_drop_down),
                          const SizedBox(height: 5),
                          const Text(
                            "© 2026 Ez Corp. Todos os direitos reservados.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white30, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Positioned(
                        left: 30, top: 10,
                        child: Column(children: [
                          GestureDetector(
                            onTap: () => _safeSetState(() => _isMusicMenuOpen = !_isMusicMenuOpen),
                            child: const Column(children: [
                              Icon(Icons.library_music, color: Colors.cyanAccent, size: 28),
                              Text("MUSIC", style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                              SizedBox(height: 2),
                              Text("(mudar)", style: TextStyle(color: Colors.white54, fontSize: 10)),
                            ]),
                          ),
                          const SizedBox(height: 15),
                          GestureDetector(
                            onTap: _toggleMusicMute,
                            child: Column(children: [
                              Icon(musicMuteIcon, color: musicMuteColor, size: 28),
                              const SizedBox(height: 2),
                              const Text("(Tirar som)", style: TextStyle(color: Colors.white54, fontSize: 10)),
                            ]),
                          ),
                          const SizedBox(height: 15),
                          GestureDetector(
                            onTap: _toggleEffectsMute,
                            child: Column(children: [
                              Icon(effectsMuteIcon, color: effectsMuteColor, size: 28),
                              const SizedBox(height: 2),
                              const Text("(Tirar Efeitos)", style: TextStyle(color: Colors.white54, fontSize: 10)),
                            ]),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isMusicMenuOpen) Positioned.fill(child: _buildMusicMenu()),
            if (_isThemeMenuOpen) Positioned.fill(child: _buildThemeMenu()),
          ],
        ),
      ),
    );
  }
}
