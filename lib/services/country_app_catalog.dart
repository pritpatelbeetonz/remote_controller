import 'package:remote_controller/models/tv_app.dart';

/// Service responsible for supplying and filtering the curated TV application catalog
/// based on country-level restrictions.
class CountryAppCatalog {
  static final CountryAppCatalog _instance = CountryAppCatalog._internal();

  factory CountryAppCatalog() => _instance;

  CountryAppCatalog._internal();

  /// Central repository of curated apps.
  /// This list can later be fetched/updated from Remote Config or Firestore databases.
  final List<TVApp> _catalog = const [
    // ==========================================
    // GLOBAL APPS
    // ==========================================
    TVApp(
      id: 'com.google.android.youtube.tv',
      name: 'YouTube',
      category: 'Entertainment',
      iconAsset: 'assets/channel/YouTube.png',
      supportedCountries: [],
      isGlobal: true,
    ),
    TVApp(
      id: 'com.google.android.youtube.tvmusic',
      name: 'YouTube Music',
      category: 'Music',
      iconAsset: 'assets/channel/YouTube Music.png',
      supportedCountries: [],
      isGlobal: true,
    ),
    TVApp(
      id: 'com.netflix.ninja',
      name: 'Netflix',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Netflix.png',
      supportedCountries: [],
      isGlobal: true,
    ),
    TVApp(
      id: 'com.amazon.amazonvideo.livingroom',
      name: 'Amazon Prime Video',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Amazon Prime Video.png',
      supportedCountries: [],
      isGlobal: true,
    ),
    TVApp(
      id: 'com.disney.disneyplus',
      name: 'Disney+',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Disney+.png',
      supportedCountries: [],
      isGlobal: true,
    ),
    TVApp(
      id: 'com.apple.atve.androidtv.appletv',
      name: 'Apple TV',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Apple TV.png',
      supportedCountries: [],
      isGlobal: true,
    ),
    TVApp(
      id: 'com.spotify.tv.android',
      name: 'Spotify',
      category: 'Music',
      iconAsset: 'assets/channel/Spotify.png',
      supportedCountries: [],
      isGlobal: true,
    ),
    TVApp(
      id: 'com.plexapp.android',
      name: 'Plex',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Plex.png',
      supportedCountries: [],
      isGlobal: true,
    ),
    TVApp(
      id: 'org.xbmc.kodi',
      name: 'Kodi',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Kodi.png',
      supportedCountries: [],
      isGlobal: true,
    ),
    TVApp(
      id: 'org.videolan.vlc',
      name: 'VLC',
      category: 'Entertainment',
      iconAsset: 'assets/channel/VLC.png',
      supportedCountries: [],
      isGlobal: true,
    ),
    TVApp(
      id: 'com.google.android.videos',
      name: 'Google TV',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Google TV.png',
      supportedCountries: [],
      isGlobal: true,
    ),
    TVApp(
      id: 'com.android.vending',
      name: 'Google Play Store',
      category: 'System',
      iconAsset: 'assets/channel/Google Play Store.png',
      supportedCountries: [],
      isGlobal: true,
    ),
    TVApp(
      id: 'tv.twitch.android.app',
      name: 'Twitch',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Twitch.png',
      supportedCountries: [],
      isGlobal: true,
    ),
    TVApp(
      id: 'com.crunchyroll.crunchyroid',
      name: 'Crunchyroll',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Crunchyroll.png',
      supportedCountries: [],
      isGlobal: true,
    ),
    TVApp(
      id: 'com.valvesoftware.steamlink',
      name: 'Steam Link',
      category: 'Gaming',
      iconAsset: 'assets/channel/Steam Link.png',
      supportedCountries: [],
      isGlobal: true,
    ),

    // ==========================================
    // INDIA (IN)
    // ==========================================
    TVApp(
      id: 'com.sonyliv',
      name: 'Sony LIV',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Sony LIV.png',
      supportedCountries: ['IN'],
      isGlobal: false,
    ),
    TVApp(
      id: 'com.graymatrix.did',
      name: 'ZEE5',
      category: 'Entertainment',
      iconAsset: 'assets/channel/ZEE5.png',
      supportedCountries: ['IN'],
      isGlobal: false,
    ),
    TVApp(
      id: 'in.startv.hotstar',
      name: 'JioHotstar',
      category: 'Entertainment',
      iconAsset: 'assets/channel/JioHotstar.png',
      supportedCountries: ['IN'],
      isGlobal: false,
    ),
    TVApp(
      id: 'com.suntv.sunnxt',
      name: 'Sun NXT',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Sun NXT.png',
      supportedCountries: ['IN'],
      isGlobal: false,
    ),
    TVApp(
      id: 'com.aha.android.tv',
      name: 'Aha',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Aha.png',
      supportedCountries: ['IN'],
      isGlobal: false,
    ),
    TVApp(
      id: 'com.mxtech.videoplayer.ad',
      name: 'MX Player TV',
      category: 'Entertainment',
      iconAsset: 'assets/channel/MX Player TV.png',
      supportedCountries: ['IN'],
      isGlobal: false,
    ),
    TVApp(
      id: 'com.erosnow',
      name: 'Eros Now',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Eros Now.png',
      supportedCountries: ['IN'],
      isGlobal: false,
    ),

    // ==========================================
    // UNITED STATES (US)
    // ==========================================
    TVApp(
      id: 'com.hulu.livingroomplus',
      name: 'Hulu',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Hulu.png',
      supportedCountries: ['US'],
      isGlobal: false,
    ),
    TVApp(
      id: 'com.wbd.stream',
      name: 'Max',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Max.png',
      supportedCountries: ['US'],
      isGlobal: false,
    ),
    TVApp(
      id: 'com.peacocktv.peacockandroid',
      name: 'Peacock',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Peacock.png',
      supportedCountries: ['US'],
      isGlobal: false,
    ),
    TVApp(
      id: 'com.cbs.ca',
      name: 'Paramount+',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Paramount+.png',
      supportedCountries: ['US'],
      isGlobal: false,
    ),
    TVApp(
      id: 'com.tubitv',
      name: 'Tubi',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Tubi.png',
      supportedCountries: ['US'],
      isGlobal: false,
    ),
    TVApp(
      id: 'tv.pluto.android',
      name: 'Pluto TV',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Pluto TV.png',
      supportedCountries: ['US'],
      isGlobal: false,
    ),

    // ==========================================
    // UNITED KINGDOM (GB)
    // ==========================================
    TVApp(
      id: 'uk.co.bbc.iplayer',
      name: 'BBC iPlayer',
      category: 'Entertainment',
      iconAsset: 'assets/channel/BBC iPlayer.png',
      supportedCountries: ['GB'],
      isGlobal: false,
    ),
    TVApp(
      id: 'air.ITVMobilePlayer',
      name: 'ITVX',
      category: 'Entertainment',
      iconAsset: 'assets/channel/ITVX.png',
      supportedCountries: ['GB'],
      isGlobal: false,
    ),
    TVApp(
      id: 'com.channel4.ondemand',
      name: 'Channel 4',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Channel 4.png',
      supportedCountries: ['GB'],
      isGlobal: false,
    ),
    TVApp(
      id: 'com.bskyb.nowtv.beta',
      name: 'NOW',
      category: 'Entertainment',
      iconAsset: 'assets/channel/NOW.png',
      supportedCountries: ['GB'],
      isGlobal: false,
    ),
    TVApp(
      id: 'com.mobileiq.demand5',
      name: 'My5',
      category: 'Entertainment',
      iconAsset: 'assets/channel/My5.png',
      supportedCountries: ['GB'],
      isGlobal: false,
    ),

    // ==========================================
    // CANADA (CA)
    // ==========================================
    TVApp(
      id: 'ca.cbc.android.cbctv',
      name: 'CBC Gem',
      category: 'Entertainment',
      iconAsset: 'assets/channel/CBC Gem.png',
      supportedCountries: ['CA'],
      isGlobal: false,
    ),
    TVApp(
      id: 'ca.bellmedia.cravetv',
      name: 'Crave',
      category: 'Entertainment',
      iconAsset: 'assets/channel/crave.png',
      supportedCountries: ['CA'],
      isGlobal: false,
    ),

    // ==========================================
    // AUSTRALIA (AU)
    // ==========================================
    TVApp(
      id: 'au.com.stan.and',
      name: 'Stan',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Stan.png',
      supportedCountries: ['AU'],
      isGlobal: false,
    ),
    TVApp(
      id: 'au.net.abc.iview',
      name: 'ABC iview',
      category: 'Entertainment',
      iconAsset: 'assets/channel/ABC iview.png',
      supportedCountries: ['AU'],
      isGlobal: false,
    ),
    TVApp(
      id: 'au.com.nine.now',
      name: '9Now',
      category: 'Entertainment',
      iconAsset: 'assets/channel/9Now.png',
      supportedCountries: ['AU'],
      isGlobal: false,
    ),
    TVApp(
      id: 'com.yahoo.mobile.client.android.plus7',
      name: '7plus',
      category: 'Entertainment',
      iconAsset: 'assets/channel/7plus.png',
      supportedCountries: ['AU'],
      isGlobal: false,
    ),

    // ==========================================
    // JAPAN (JP)
    // ==========================================
    TVApp(
      id: 'tv.abema',
      name: 'ABEMA',
      category: 'Entertainment',
      iconAsset: 'assets/channel/abema.png',
      supportedCountries: ['JP'],
      isGlobal: false,
    ),
    TVApp(
      id: 'jp.co.tver.tver',
      name: 'TVer',
      category: 'Entertainment',
      iconAsset: 'assets/channel/TVer.png',
      supportedCountries: ['JP'],
      isGlobal: false,
    ),
    TVApp(
      id: 'jp.unext.tv',
      name: 'U-NEXT',
      category: 'Entertainment',
      iconAsset: 'assets/channel/U-NEXT.png',
      supportedCountries: ['JP'],
      isGlobal: false,
    ),
    TVApp(
      id: 'jp.happyon.android',
      name: 'Hulu Japan',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Hulu Japan.png',
      supportedCountries: ['JP'],
      isGlobal: false,
    ),

    // ==========================================
    // SOUTH KOREA (KR)
    // ==========================================
    TVApp(
      id: 'net.cj.cjhv.gs.tving',
      name: 'TVING',
      category: 'Entertainment',
      iconAsset: 'assets/channel/TVING.png',
      supportedCountries: ['KR'],
      isGlobal: false,
    ),
    TVApp(
      id: 'kr.co.wavve.player',
      name: 'Wavve',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Wavve.png',
      supportedCountries: ['KR'],
      isGlobal: false,
    ),
    TVApp(
      id: 'com.coupang.mobile.play',
      name: 'Coupang Play',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Coupang Play.png',
      supportedCountries: ['KR'],
      isGlobal: false,
    ),

    // ==========================================
    // GERMANY (DE)
    // ==========================================
    TVApp(
      id: 'de.prosiebensat1digital.seventv',
      name: 'Joyn',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Joyn.png',
      supportedCountries: ['DE'],
      isGlobal: false,
    ),
    TVApp(
      id: 'de.zdf.android.mediathek',
      name: 'ZDFmediathek',
      category: 'Entertainment',
      iconAsset: 'assets/channel/ZDFmediathek.png',
      supportedCountries: ['DE'],
      isGlobal: false,
    ),
    TVApp(
      id: 'de.swr.avp.ard',
      name: 'ARD Mediathek',
      category: 'Entertainment',
      iconAsset: 'assets/channel/ARD Mediathek.png',
      supportedCountries: ['DE'],
      isGlobal: false,
    ),

    // ==========================================
    // FRANCE (FR)
    // ==========================================
    TVApp(
      id: 'tv.molotov.app',
      name: 'Molotov',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Molotov.png',
      supportedCountries: ['FR'],
      isGlobal: false,
    ),
    TVApp(
      id: 'fr.francetv.pluzz',
      name: 'France.tv',
      category: 'Entertainment',
      iconAsset: 'assets/channel/France.tv.png',
      supportedCountries: ['FR'],
      isGlobal: false,
    ),
    TVApp(
      id: 'com.canal.android.canal',
      name: 'Canal+',
      category: 'Entertainment',
      iconAsset: 'assets/channel/Canal.png',
      supportedCountries: ['FR'],
      isGlobal: false,
    ),
  ];

  /// Filters and returns a sorted, immutable list of curated apps for the given [countryCode].
  ///
  /// The returned list:
  /// 1. Always includes all Global Apps.
  /// 2. Includes country-specific apps matching the [countryCode] (case-insensitive).
  /// 3. Filters out any duplicate package names.
  /// 4. Is sorted alphabetically by app name.
  /// 5. Is returned as an immutable, unmodifiable list.
  List<TVApp> getAppsForCountry(String countryCode) {
    final normalizedCode = countryCode.trim().toUpperCase();
    final Map<String, TVApp> uniqueApps = {};

    for (final app in _catalog) {
      if (app.isGlobal || app.supportedCountries.contains(normalizedCode)) {
        uniqueApps[app.id] = app;
      }
    }

    final filteredList = uniqueApps.values.toList();

    // Sort alphabetically by name (case-insensitive)
    filteredList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return List<TVApp>.unmodifiable(filteredList);
  }
}
