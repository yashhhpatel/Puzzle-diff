/// Support address used by the Contact Us page.
const kSupportEmail = 'anjalisasani10@gmail.com';

/// Public privacy policy page (also enter it in Play Console > App content).
const kPrivacyPolicyUrl = 'https://api.buildprivacypolicy.com/policy/56b2f7da-e487-4bf6-8ab5-ac6d8e3ca0ce';

/// Coins paid for finishing a level / the Daily Challenge.
const kLevelReward = 10;
const kDailyReward = 50;

/// Store and ad identifiers. Replace the placeholders with the real values
/// from Google Play Console and AdMob before publishing.
class StoreConfig {
  // Consumable coin packs (Play Console > Monetize > In-app products).
  static const coins550 = 'coins_550';
  static const coins2750 = 'coins_2750';
  static const coins5500 = 'coins_5500';
  static const coins15000 = 'coins_15000';
  static const coins27000 = 'coins_27000';
  static const coins55000 = 'coins_55000';

  /// Consumable bundle: 900 coins + 2 of each booster.
  static const boosterBundle = 'bundle_boosters';

  /// Non-consumable: disables interstitial ads.
  static const removeAds = 'remove_ads';

  static const consumables = {
    coins550: 550,
    coins2750: 2750,
    coins5500: 5500,
    coins15000: 15000,
    coins27000: 27000,
    coins55000: 55000,
    boosterBundle: 900,
  };

  static Set<String> get allIds => {...consumables.keys, removeAds};
}

class AdConfig {
  // Google's official test IDs. Also replace the APPLICATION_ID meta-data in
  // android/app/src/main/AndroidManifest.xml when switching to real IDs.
  static const androidInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const androidBanner = 'ca-app-pub-3940256099942544/9214589741'; // adaptive banner
  static const androidAppOpen = 'ca-app-pub-3940256099942544/9257395921';
  static const androidRewarded = 'ca-app-pub-3940256099942544/5224354917';

  /// App Open ads expire after this long (Google's guidance: 4 hours).
  static const appOpenMaxAge = Duration(hours: 4);

  /// An interstitial follows every Nth completed level.
  static const levelsPerInterstitial = 2;
}
