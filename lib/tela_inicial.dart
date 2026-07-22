import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';
import 'main.dart';

class TelaInicial extends StatefulWidget {
  const TelaInicial({super.key});

  @override
  State<TelaInicial> createState() => _TelaInicialState();
}

class _TelaInicialState extends State<TelaInicial>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final Animation<double> _floatAnim;
  late final AnimationController _glowController;
  late final AnimationController _shineController;

  ui.Image? _logoImage;

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: -9, end: 9).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _carregarLogo();
    _carregarBanner();
    _carregarInterstitial();
  }

  Future<void> _carregarLogo() async {
    try {
      // ==== NOME DA IMAGEM CORRIGIDO AQUI ====
      final data = await rootBundle.load('assets/images/logoflutuante.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (mounted) setState(() => _logoImage = frame.image);
    } catch (e) {
      debugPrint("Erro ao carregar a imagem logoflutuante.png: $e");
    }
  }

  void _carregarBanner() {
    _bannerAd = BannerAd(
      adUnitId: AdUnitIds.banner,
      size: AdSize.banner,
      request: const AdRequest(nonPersonalizedAds: true),
      listener: BannerAdListener(
        onAdLoaded: (_) => mounted ? setState(() {}) : null,
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _bannerAd = null);
        },
      ),
    )..load();
  }

  void _carregarInterstitial() {
    InterstitialAd.load(
      adUnitId: AdUnitIds.interstitial,
      request: const AdRequest(nonPersonalizedAds: true),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  void _entrar() {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _navegar();
        },
        onAdFailedToShowFullScreenContent: (ad, _) {
          ad.dispose();
          _navegar();
        },
      );
      _interstitialAd!.show();
      _interstitialAd = null;
    } else {
      _navegar();
    }
  }

  void _navegar() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SnakeGame()),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    _glowController.dispose();
    _shineController.dispose();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannerH = _bannerAd != null ? 50.0 : 0.0;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final w = constraints.maxWidth;

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/capa.png',
                fit: BoxFit.fill,
                width: w,
                height: h,
                errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF0D1B2A)),
              ),

              Positioned(
                top: h * -0.11,
                left: w * 0.00,
                right: w * 0.00,
                height: h * 0.60,
                child: AnimatedBuilder(
                  animation: _floatAnim,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, _floatAnim.value),
                    child: child,
                  ),
                  child: _logoPremium(),
                ),
              ),

              Positioned(
                top: h * 0.73,
                left: 0,
                right: 0,
                child: Center(child: _botaoEntrar()),
              ),

              Positioned(
                bottom: bannerH + 6,
                left: 0,
                right: 0,
                child: const Center(
                  child: Text(
                    '© Ez Corp - Todos os direitos reservados',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              if (_bannerAd != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: bannerH,
                  child: AdWidget(ad: _bannerAd!),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _logoPremium() {
    if (_logoImage == null) return const SizedBox();

    return AnimatedBuilder(
      animation: _shineController,
      builder: (_, __) {
        final shimmerPos = (_shineController.value * 2.8) - 1.4;
        const double width = 800;

        return SizedBox(
          width: width,
          child: AspectRatio(
            aspectRatio: 1.35,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow por trás do logo
                Container(
                  width: width * 0.82,
                  height: width * 0.32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x55FF5ACD),
                        blurRadius: 30,
                        spreadRadius: 6,
                      ),
                      BoxShadow(
                        color: Color(0x44FFC857),
                        blurRadius: 45,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                ),
                
                // CustomPainter com saveLayer, srcATop, Shimmer e Verniz
                CustomPaint(
                  size: Size(width, width / 1.35),
                  painter: _LogoPainter(
                    image: _logoImage!,
                    shimmerPosition: shimmerPos,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _botaoEntrar() {
    return GestureDetector(
      onTap: _entrar,
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (_, __) {
          return Container(
            width: 230,
            height: 66,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FF88).withOpacity(0.55),
                  blurRadius: 22,
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: const Color(0xFF00AAFF).withOpacity(0.35),
                  blurRadius: 36,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: _glowController.value * 2 * math.pi,
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: const BoxDecoration(
                        gradient: SweepGradient(
                          colors: [
                            Color(0xFF00FF88),
                            Color(0xFF00CCFF),
                            Color(0xFF00FF88),
                            Color(0xFF003322),
                            Color(0xFF003322),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 220,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B6B2A),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'ENTRAR',
                      style: TextStyle(
                        fontSize: 26,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final ui.Image image;
  final double shimmerPosition;

  _LogoPainter({required this.image, required this.shimmerPosition});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // saveLayer cria uma camada isolada de composição.
    canvas.saveLayer(rect, Paint());

    // 1. Desenha o logo
    paintImage(
      canvas: canvas,
      rect: rect,
      image: image,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
    );

    // 2. Shimmer deslizante com os stops exatos
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.srcATop
        ..shader = LinearGradient(
          begin: Alignment(shimmerPosition - 0.6, -1.0),
          end: Alignment(shimmerPosition + 0.6, 1.0),
          colors: const [
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
            Color(0x40FFFFFF),
            Color(0x99FFFFFF),
            Color(0x40FFFFFF),
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: const [0.0, 0.28, 0.42, 0.50, 0.58, 0.72, 1.0],
        ).createShader(rect),
    );

    // 3. Verniz fixo no topo com os stops exatos
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.srcATop
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.24),
            Colors.white.withOpacity(0.06),
            Colors.transparent,
          ],
          stops: const [0.0, 0.18, 0.40],
        ).createShader(rect),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.shimmerPosition != shimmerPosition;
}