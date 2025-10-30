import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;

  // TEST MODE - Set to false for production
  static const bool _testMode = true;

  // ⚠️ SECURITY: Replace with environment variables in production
  // Test Ad Unit IDs (Google's official test IDs)
  static const String _androidRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917'; // Google test ID
  // TODO: Replace with: String.fromEnvironment('ADMOB_ANDROID_REWARDED_ID')
  
  // static const String _iosRewardedAdUnitId =
  //     'ca-app-pub-3940256099942544/1712485313'; // Google test ID
  // TODO: Replace with: String.fromEnvironment('ADMOB_IOS_REWARDED_ID')

  // Initialize Mobile Ads SDK
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  // Load rewarded ad
  Future<void> loadRewardedAd() async {
    await RewardedAd.load(
      adUnitId: _getAdUnitId(),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoaded = true;
          print('Rewarded ad loaded');
        },
        onAdFailedToLoad: (error) {
          print('Failed to load rewarded ad: $error');
          _isAdLoaded = false;
        },
      ),
    );
  }

  // Show rewarded ad
  Future<bool> showRewardedAd() async {
    // In test mode, skip ads and return true immediately
    if (_testMode) {
      print('🧪 TEST MODE: Skipping ad, returning true');
      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Simulate ad delay
      return true;
    }

    if (!_isAdLoaded || _rewardedAd == null) {
      print('Rewarded ad not ready');
      return false;
    }

    bool rewardEarned = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isAdLoaded = false;
        loadRewardedAd(); // Preload next ad
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _isAdLoaded = false;
        loadRewardedAd();
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        rewardEarned = true;
        print('User earned reward: ${reward.amount} ${reward.type}');
      },
    );

    return rewardEarned;
  }

  // Get platform-specific ad unit ID
  String _getAdUnitId() {
    // TODO: Use Platform.isAndroid/isIOS for production
    return _androidRewardedAdUnitId; // Default to Android for testing
  }

  // Dispose
  void dispose() {
    _rewardedAd?.dispose();
  }
}
