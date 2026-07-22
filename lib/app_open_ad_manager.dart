import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';

/// Carrega e exibe o anúncio de Abertura de App (App Open Ad) do AdMob,
/// mostrado quando o usuário retorna ao app a partir do background.
class AppOpenAdManager {
  AppOpenAdManager._();
  static final AppOpenAdManager instance = AppOpenAdManager._();

  static const Duration _maxCacheDuration = Duration(hours: 4);

  AppOpenAd? _appOpenAd;
  bool _isLoadingAd = false;
  bool _isShowingAd = false;
  DateTime? _loadTime;

  bool get _isAdAvailable =>
      _appOpenAd != null &&
      _loadTime != null &&
      DateTime.now().difference(_loadTime!) < _maxCacheDuration;

  void loadAd() {
    if (_isLoadingAd || _isAdAvailable) return;
    _isLoadingAd = true;
    AppOpenAd.load(
      adUnitId: AdUnitIds.appOpen,
      request: const AdRequest(nonPersonalizedAds: true),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoadingAd = false;
          _appOpenAd = ad;
          _loadTime = DateTime.now();
        },
        onAdFailedToLoad: (error) {
          _isLoadingAd = false;
          _appOpenAd = null;
        },
      ),
    );
  }

  void showAdIfAvailable() {
    if (_isShowingAd) return;
    if (!_isAdAvailable) {
      loadAd();
      return;
    }
    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => _isShowingAd = true,
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAd();
      },
    );
    _appOpenAd!.show();
  }
}
