import 'dart:io' show Platform;

/// IDs de unidade de anúncio do AdMob, por plataforma.
class AdUnitIds {
  static String get banner => Platform.isIOS
      ? 'ca-app-pub-1403007154605909/7997212967'
      : 'ca-app-pub-1403007154605909/3576807563';

  static String get interstitial => Platform.isIOS
      ? 'ca-app-pub-1403007154605909/4941739981'
      : 'ca-app-pub-1403007154605909/4203373384';

  static String get rewarded => Platform.isIOS
      ? 'ca-app-pub-1403007154605909/9479750792'
      : 'ca-app-pub-1403007154605909/5562621312';

  static String get appOpen => Platform.isIOS
      ? 'ca-app-pub-1403007154605909/2315576647'
      : 'ca-app-pub-1403007154605909/4277459802';
}
