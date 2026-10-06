/// Single source of truth for every user visible string in TSHK Compass.
///
/// The whole app is shown in one language at a time, chosen with the language
/// button in the header (and in the settings card on the Guide tab): English,
/// isiZulu, Português, Chichewa or iciBemba. English and isiZulu are
/// authored here; Portuguese, Chichewa and Bemba come from
/// `assets/translations.json` through the [Bi.key] of each string (see
/// [L10n.resolve] for the fallback order: chosen language → English).
///
/// Rules:
/// * Never put user visible literals in widgets: add a [Bi] here.
/// * Every [Bi] has a unique-meaning `key`, and that key exists in every
///   table of `translations.json` (enforced by `test/core/l10n_test.dart`).
/// * Parameterised strings use `{name}` placeholders in the file and pass the
///   values through `args`. An arg that is itself a [Bi] (e.g. "left") is
///   resolved in the same language.
library;

import 'app_language.dart';

export 'app_language.dart' show AppLanguage, L10n;

/// A localised string: English and isiZulu authored in code, the other
/// languages looked up by [key].
class Bi {
  const Bi(this.en, this.zu, {this.key, this.args});

  /// English text (also the fallback for missing translations).
  final String en;

  /// isiZulu text, authored in code.
  final String zu;

  /// Key into `translations.json` for Portuguese, Chichewa and Bemba.
  final String? key;

  /// Optional `{placeholder}` values for parameterised strings. Values may
  /// be plain strings or other [Bi]s (resolved in the same language).
  final Map<String, Object>? args;

  /// The text in the currently selected language.
  ///
  /// Widgets reading this in `build` must depend on `LanguageScope` (or use
  /// `LocalizedText`) so they rebuild when the language changes.
  String get text => textIn(L10n.language);

  /// The text in a specific language (for tests and previews).
  String textIn(AppLanguage language) => L10n.resolve(
    en: en,
    zu: zu,
    key: key,
    args: _argsIn(language),
    language: language,
  );

  Map<String, String>? _argsIn(AppLanguage language) {
    final Map<String, Object>? values = args;
    if (values == null || values.isEmpty) {
      return null;
    }
    return values.map(
      (String name, Object value) => MapEntry<String, String>(
        name,
        value is Bi ? value.textIn(language) : '$value',
      ),
    );
  }

  @override
  String toString() => text;
}

/// All app strings.
abstract final class S {
  // ---------------------------------------------------------------- branding

  /// Large serif title shown in the header of every screen (a name: never
  /// translated).
  static const String appTitle = 'TSHK Compass';

  /// Small letter-spaced eyebrow shown above the title (rendered uppercase).
  static const Bi eyebrow = Bi(
    'Ekuphumuleni · Spiritual capital',
    'Ekuphumuleni · Inhlokodolobha yomoya',
    key: 'eyebrow',
  );

  /// Footer caption under the crest on the Guide screen (proper names: never
  /// translated).
  static const String crestCaption =
      'The Revelation Spiritual Home · The Spiritual Home Kingdom';

  /// Spoken label of the crest image.
  static const Bi crestLabel = Bi(
    'The Revelation Spiritual Home crest',
    'Uphawu lwe-The Revelation Spiritual Home',
    key: 'crest_label',
  );

  // -------------------------------------------------------------------- tabs

  static const Bi tabCompass = Bi('Compass', 'Ikhompasi', key: 'tab_compass');
  static const Bi tabMsamo = Bi('Msamo', 'Umsamo', key: 'tab_msamo');
  static const Bi tabLocation = Bi('Location', 'Indawo', key: 'tab_location');
  static const Bi tabCentres = Bi('Centres', 'Izikhungo', key: 'tab_centres');
  static const Bi tabGuide = Bi('Guide', 'Umhlahlandlela', key: 'tab_guide');

  // ----------------------------------------------------------------- compass

  static const Bi startCompass = Bi(
    'Start compass',
    'Qala ikhompasi',
    key: 'btn_start',
  );
  static const Bi startToBegin = Bi(
    'Start the compass to begin',
    'Qala ikhompasi ukuze uqale',
    key: 'state_start',
  );
  static const Bi locationNotSet = Bi(
    'Location: not set',
    'Indawo: ayikabekwa',
    key: 'loc_unset',
  );
  static const Bi compassOff = Bi(
    'Compass: off',
    'Ikhompasi: ivaliwe',
    key: 'cmp_off',
  );
  static const Bi compassOn = Bi(
    'Compass: on',
    'Ikhompasi: ivuliwe',
    key: 'compass_on',
  );

  /// "Location: 26.2041° S, 28.0473° E" on the status line.
  static Bi locationValue(String point) => Bi(
    'Location: $point',
    'Indawo: $point',
    key: 'loc_value',
    args: <String, Object>{'p': point},
  );

  /// "Compass: 318° true" on the status line.
  static Bi compassTrue(String bearing) => Bi(
    'Compass: $bearing true',
    'Ikhompasi: $bearing iqiniso',
    key: 'compass_true',
    args: <String, Object>{'n': bearing},
  );

  /// "Compass: 298° magnetic" on the status line.
  static Bi compassMagnetic(String bearing) => Bi(
    'Compass: $bearing magnetic',
    'Ikhompasi: $bearing kazibuthe',
    key: 'compass_magnetic',
    args: <String, Object>{'n': bearing},
  );

  static const Bi compassHelp = Bi(
    'The arrow points to Ekuphumuleni. When it sits under the marker at the '
        'top, you are facing the spiritual capital. Hold the phone flat and '
        'away from metal.',
    'Umcibisholo ukhomba e-Ekuphumuleni. Uma ungaphansi kophawu oluphezulu, '
        'ubheke enhlokodolobha yomoya. Bamba ifoni ithe bha, kude nensimbi.',
    key: 'compass_help',
  );

  /// "Bearing 318° NW" under the dial.
  static Bi bearingValue(String bearing) => Bi(
    'Bearing $bearing',
    'Ukubheka $bearing',
    key: 'bearing_value',
    args: <String, Object>{'b': bearing},
  );

  /// Spoken description of the compass dial.
  static Bi dialLabel(int bearingDeg) => Bi(
    'Compass dial. Bearing to Ekuphumuleni $bearingDeg degrees.',
    'Ikhompasi. Ukubheka e-Ekuphumuleni ngamadigri angu-$bearingDeg.',
    key: 'dial_label',
    args: <String, Object>{'n': '$bearingDeg'},
  );
  static const Bi dialTurnHint = Bi(
    'Turn to bring the needle to the marker.',
    'Phenduka kuze umcibisholo ufike ophawini.',
    key: 'dial_turn_hint',
  );

  // Readout labels.
  static const Bi sunHeight = Bi(
    'Sun height · above horizon',
    'Ukuphakama kwelanga · ngaphezu komkhathizwe',
    key: 'sun_height',
  );
  static const Bi facingSun = Bi(
    'Facing the sun',
    'Ubheke ilanga',
    key: 'sun_facing',
  );
  static const Bi stickShadow = Bi(
    "Using a stick's shadow",
    'Ukusebenzisa isithunzi sentonga',
    key: 'sun_shadow',
  );
  static const Bi bearingTrue = Bi(
    'Bearing (true)',
    'Ukubheka',
    key: 'ro_bearing',
  );
  static const Bi distance = Bi('Distance', 'Ibanga', key: 'ro_dist');

  /// "Distance: 412 km".
  static Bi distanceValue(String distance) => Bi(
    'Distance: $distance',
    'Ibanga: $distance',
    key: 'distance_value',
    args: <String, Object>{'d': distance},
  );
  static const Bi magneticBearing = Bi(
    'Magnetic bearing · hand compass',
    'Ukubheka kazibuthe · ikhompasi yesandla',
    key: 'magnetic_bearing',
  );
  static const Bi declination = Bi(
    'Declination · WMM 2025',
    'Ukuchezuka · WMM 2025',
    key: 'declination',
  );
  static const Bi declinationWest = Bi(
    'Magnetic north is west of true north',
    'Inyakatho kazibuthe ingasentshonalanga yenyakatho yangempela',
    key: 'decl_west',
  );
  static const Bi declinationEast = Bi(
    'Magnetic north is east of true north',
    'Inyakatho kazibuthe ingasempumalanga yenyakatho yangempela',
    key: 'decl_east',
  );
  static const Bi yourLocation = Bi(
    'Your location',
    'Indawo yakho',
    key: 'ro_loc',
  );

  static const Bi notSetHint = Bi(
    'Not set · Tap Start, or set it under Location',
    'Ayikabekwa · Cindezela u-Qala, noma uyibeke ngaphansi kwe-Indawo',
    key: 'not_set_hint',
  );

  // Readout values.
  static const Bi yes = Bi('Yes', 'Yebo', key: 'yes');
  static const Bi no = Bi('No', 'Cha', key: 'no');
  static const Bi belowHorizon = Bi(
    'Below horizon',
    'Ngaphansi komkhathizwe',
    key: 'below_horizon',
  );
  static const Bi aboveHorizon = Bi(
    'above horizon',
    'ngaphezu komkhathizwe',
    key: 'above_horizon',
  );
  static const Bi yesFacingSun = Bi(
    'Yes, you are facing the sun',
    'Yebo, ubheke ilanga',
    key: 'yes_facing_sun',
  );
  static const Bi noFacingSun = Bi(
    'No, the sun is not ahead',
    'Cha, ilanga alikho phambili',
    key: 'no_facing_sun',
  );

  /// "Not ahead · 32° to your right" (caption of the facing-the-sun card).
  static Bi sunOffBy(int deg, {required bool toRight}) {
    final Bi dir = toRight ? right : left;
    return Bi(
      'Not ahead · $deg° to your ${dir.en}',
      'Alikho phambili · $deg° ${dir.zu}',
      key: 'sun_off_by',
      args: <String, Object>{'n': '$deg', 'dir': dir},
    );
  }

  static const Bi sunBehind = Bi(
    'The sun is behind you',
    'Ilanga lingemuva kwakho',
    key: 'sun_behind',
  );
  static const Bi sunUnknown = Bi(
    'Start the compass to know',
    'Qala ikhompasi ukuze wazi',
    key: 'sun_unknown',
  );
  static const Bi shadowHint = Bi(
    'Shadow points this way',
    'Isithunzi sikhomba ngalapha',
    key: 'shadow_hint',
  );
  static const Bi noSensorValue = Bi(
    'No sensor — use the bearings below',
    'Ayikho inzwa — sebenzisa izinombolo',
    key: 'no_sensor_value',
  );

  // States and warnings.
  static const Bi calibrateHint = Bi(
    'Calibrate: move the phone in a figure-8',
    'Linganisa: zungezisa ifoni njengo-8',
    key: 'calib',
  );
  static const Bi noSensor = Bi(
    'This device has no compass sensor. The true bearing, magnetic bearing '
        'and distance to Ekuphumuleni are still shown — use a hand compass or '
        'the bearings below to face the spiritual capital.',
    'Le foni ayinayo inzwa yekhompasi. Ukubheka okuqondile, ukubheka '
        'kazibuthe nebanga lokuya e-Ekuphumuleni kusabonisiwe — sebenzisa '
        'ikhompasi yesandla noma lezi zinombolo ukuze ubheke enhlokodolobha '
        'yomoya.',
    key: 'no_sensor',
  );
  static const Bi sensorUnavailable = Bi(
    'Compass sensor unavailable',
    'Inzwa yekhompasi ayitholakali',
    key: 'sensor_unavailable',
  );
  static const Bi waitingForHeading = Bi(
    'Waiting for a heading…',
    'Kulinde isiqondiso…',
    key: 'turn_wait',
  );
  static const Bi aligned = Bi(
    'Facing Ekuphumuleni',
    'Ubheke e-Ekuphumuleni',
    key: 'facing',
  );
  static const Bi notAvailable = Bi(
    'Not available',
    'Ayitholakali',
    key: 'not_available',
  );
  static const Bi compassErrorBody = Bi(
    'The compass sensor stopped with an error. Tap Retry sensors, or stop the '
        'compass and start it again.',
    'Inzwa yekhompasi imile ngenxa yephutha. Cindezela u-Zama izinzwa futhi, '
        'noma umise ikhompasi bese uyiqala futhi.',
    key: 'compass_error_body',
  );

  // ------------------------------------------------------------------- msamo

  static const Bi msamoIntro = Bi(
    'A msamo (umsamo) is placed so that it faces Ekuphumuleni. Stand where the '
        'msamo will stand, hold the phone flat, and turn until the needle sits '
        'on the marker.',
    'Umsamo ubekwa ubheke e-Ekuphumuleni. Yima lapho kuzoba khona umsamo, '
        'bamba ifoni ithe bha, uphenduke kuze kufike umcibisholo ophawini.',
    key: 'msamo_intro',
  );
  static const Bi msamoRequired = Bi(
    'Required direction',
    'Isiqondiso esidingekayo',
    key: 'msamo_required',
  );
  static const Bi msamoAligned = Bi(
    'Your msamo is facing Ekuphumuleni',
    'Umsamo wakho ubheke e-Ekuphumuleni',
    key: 'msamo_aligned',
  );
  static const Bi msamoNotAligned = Bi(
    'Keep turning until the needle is centred',
    'Qhubeka uphenduka kuze kube semaphakathi',
    key: 'msamo_not_aligned',
  );
  static const Bi lockDirection = Bi(
    'Lock this direction',
    'Khiya lesi siqondiso',
    key: 'lock_direction',
  );
  static const Bi unlockDirection = Bi('Unlock', 'Vula', key: 'unlock');
  static const Bi lockedNote = Bi(
    'Direction locked. The reading is frozen so you can mark the position.',
    'Isiqondiso sikhiyiwe. Ukufunda kumisiwe ukuze ukwazi ukumaka indawo.',
    key: 'locked_note',
  );
  static const Bi msamoWaiting = Bi(
    'Start the compass to see the turn instruction',
    'Qala ikhompasi ukuze ubone isiqondiso sokuphenduka',
    key: 'msamo_waiting',
  );

  /// "left" / "right", as words, for the turn instructions.
  static const Bi left = Bi('left', 'kwesokunxele', key: 'left');
  static const Bi right = Bi('right', 'kwesokudla', key: 'right');

  /// "Turn 32° to your right".
  static Bi turnBy(int deg, {required bool toRight}) {
    final Bi dir = toRight ? right : left;
    return Bi(
      'Turn $deg° to your ${dir.en}',
      'Phendukela ${dir.zu} ngo-$deg°',
      key: 'turn_state',
      args: <String, Object>{'n': '$deg', 'dir': dir},
    );
  }

  /// "Turn around 175°".
  static Bi turnAround(int deg) => Bi(
    'Turn around $deg°',
    'Phenduka ngo-$deg°',
    key: 'turn_around',
    args: <String, Object>{'n': '$deg'},
  );

  // ---------------------------------------------------------------- location

  static const Bi useMyLocation = Bi(
    'Use my location',
    'Sebenzisa indawo yami',
    key: 'btn_gps',
  );
  static const Bi enterManually = Bi(
    'Enter coordinates manually',
    'Faka izixhumanisi ngesandla',
    key: 'coords_title',
  );
  static const Bi pickFromCentres = Bi(
    'Pick from centres',
    'Khetha esikhungweni',
    key: 'pick_centre',
  );
  static const Bi returnToGps = Bi(
    'Return to live GPS',
    'Buyela ku-GPS ebukhoma',
    key: 'return_gps',
  );
  static const Bi latitude = Bi('Latitude', 'I-latitude', key: 'latitude');
  static const Bi longitude = Bi('Longitude', 'I-longitude', key: 'longitude');
  static const Bi accuracy = Bi('Accuracy', 'Ukunemba', key: 'guide_acc');
  static const Bi altitude = Bi('Altitude', 'Ukuphakama', key: 'altitude');
  static const Bi updated = Bi('Updated', 'Kubuyekezwe', key: 'updated');
  static const Bi source = Bi('Source', 'Umthombo', key: 'source');
  static const Bi place = Bi('Place', 'Indawo', key: 'place');
  static const Bi sourceGps = Bi(
    'Live GPS',
    'I-GPS ebukhoma',
    key: 'src_live_gps',
  );
  static const Bi sourceManual = Bi(
    'Saved location',
    'Indawo egciniwe',
    key: 'src_saved',
  );

  /// Label stored with coordinates typed in by hand.
  static const Bi manualEntry = Bi(
    'Manual entry',
    'Ifakwe ngesandla',
    key: 'manual_entry',
  );
  static const Bi currentPosition = Bi(
    'Current position',
    'Indawo yamanje',
    key: 'current_position',
  );
  static const Bi manualInUse = Bi(
    'A saved location is being used for all bearings and distances.',
    'Indawo egciniwe isetshenziselwa zonke iziqondiso namabanga.',
    key: 'manual_in_use',
  );
  static const Bi openSettings = Bi(
    'Open settings',
    'Vula izilungiselelo',
    key: 'open_settings',
  );
  static const Bi locationServicesOff = Bi(
    'Location services are switched off. Turn them on to use the compass.',
    'Izinsiza zendawo zivaliwe. Zivule ukuze usebenzise ikhompasi.',
    key: 'loc_services_off',
  );
  static const Bi permissionNeeded = Bi(
    'Location permission is needed to work out the direction of Ekuphumuleni.',
    'Imvume yendawo iyadingeka ukuthola isiqondiso sase-Ekuphumuleni.',
    key: 'perm_needed',
  );
  static const Bi permissionDenied = Bi(
    'Location permission was denied. You can still enter your coordinates by '
        'hand, or allow access in Settings.',
    'Imvume yendawo yenqatshiwe. Usengafaka izixhumanisi ngesandla, noma '
        'uvumele ukufinyelela kuzilungiselelo.',
    key: 'perm_denied',
  );
  static const Bi permissionDeniedForever = Bi(
    'Location permission is permanently denied. Open Settings to allow it, or '
        'enter your coordinates by hand.',
    'Imvume yendawo yenqatshiwe unomphela. Vula izilungiselelo ukuze uyivumele, '
        'noma ufake izixhumanisi ngesandla.',
    key: 'perm_denied_forever',
  );
  static const Bi locationError = Bi(
    'Your location could not be read. Check that location is switched on and '
        'try again.',
    'Indawo yakho ayikwazanga ukutholakala. Qinisekisa ukuthi indawo ivuliwe '
        'bese uzama futhi.',
    key: 'loc_error',
  );
  static const Bi invalidLatitude = Bi(
    'Enter a latitude between -90 and 90',
    'Faka i-latitude phakathi -90 no-90',
    key: 'invalid_lat',
  );
  static const Bi invalidLongitude = Bi(
    'Enter a longitude between -180 and 180',
    'Faka i-longitude phakathi -180 no-180',
    key: 'invalid_lng',
  );
  static const Bi saved = Bi('Location saved', 'Indawo igciniwe', key: 'saved');

  /// "Location saved · Soweto".
  static Bi savedNamed(String name) => Bi(
    'Location saved · $name',
    'Indawo igciniwe · $name',
    key: 'saved_named',
    args: <String, Object>{'name': name},
  );
  static const Bi save = Bi('Save', 'Gcina', key: 'save');
  static const Bi cancel = Bi('Cancel', 'Khansela', key: 'cancel');
  static const Bi locate = Bi('Locating…', 'Kuthungathwa…', key: 'gps_finding');

  // ----------------------------------------------------------------- centres

  static const Bi searchCentre = Bi(
    'Search a centre or town',
    'Sesha isikhungo',
    key: 'search_ph',
  );
  static const Bi nearest = Bi('Nearest', 'Eseduze', key: 'btn_near');
  static const Bi allCentres = Bi(
    'All centres, grouped by region',
    'Zonke izikhungo ngezifunda',
    key: 'c_status_all',
  );
  static const Bi mapCaption = Bi(
    'Pins mark the suburb or town of each centre; tap a pin, then Directions, '
        'to be guided to the exact address. The gold pin is Ekuphumuleni.',
    'Isikhonkwane sikhomba indawo yesikhungo; cindezela isikhonkwane bese '
        'ucindezela u-Izikhombisi-ndlela ukuze uyiswe ekhelini eliqondile. '
        'Isikhonkwane segolide yi-Ekuphumuleni.',
    key: 'map_caption',
  );
  static const Bi mapButton = Bi('Map', 'Imephu', key: 'map');
  static const Bi callButton = Bi('Call', 'Shayela', key: 'call');
  static const Bi directionsButton = Bi(
    'Directions',
    'Izikhombisi-ndlela',
    key: 'directions',
  );
  static const Bi noResults = Bi(
    'No centre matches your search',
    'Asikho isikhungo esitholakalayo',
    key: 'no_match',
  );
  static const Bi noPhone = Bi(
    'No phone number on file',
    'Ayikho inombolo yocingo',
    key: 'no_phone',
  );
  static const Bi noAddress = Bi(
    'Address to be added',
    'Ikheli lizokwengezwa',
    key: 'no_address',
  );
  static const Bi offlineMap = Bi(
    'The map needs an internet connection. The list of centres below still '
        'works offline.',
    'Imephu idinga uxhumano lwe-inthanethi. Uhlu lwezikhungo olungezansi '
        'lusasebenza ngaphandle kwe-inthanethi.',
    key: 'offline_map',
  );
  static const Bi mapUnavailable = Bi(
    'Map unavailable offline',
    'Imephu ayitholakali ngaphandle kwe-inthanethi',
    key: 'map_unavailable',
  );
  static const Bi retry = Bi('Retry', 'Zama futhi', key: 'retry');
  static const Bi zoomIn = Bi('Zoom in', 'Sondeza', key: 'zoom_in');
  static const Bi zoomOut = Bi('Zoom out', 'Hlehlisa', key: 'zoom_out');
  static const Bi nearestFound = Bi(
    'Nearest centre',
    'Isikhungo esiseduze',
    key: 'nearest_centre',
  );

  /// "Nearest centre: Soweto · 12 km".
  static Bi nearestCentreValue(String centre, String distance) => Bi(
    'Nearest centre: $centre · $distance',
    'Isikhungo esiseduze: $centre · $distance',
    key: 'nearest_centre_value',
    args: <String, Object>{'c': centre, 'd': distance},
  );
  static const Bi loadingCentres = Bi(
    'Loading centres…',
    'Kulayishwa izikhungo…',
    key: 'c_loading',
  );
  static const Bi centresFailed = Bi(
    'The centres file could not be read.',
    'Ifayela lezikhungo alikwazanga ukufundwa.',
    key: 'centres_failed',
  );
  static const Bi attribution = Bi(
    'Map data © OpenStreetMap contributors',
    'Idatha yemephu © abanikeli be-OpenStreetMap',
    key: 'attribution',
  );

  // ------------------------------------------------------------------- guide

  static const Bi coordinates = Bi(
    'Coordinates',
    'Izixhumanisi',
    key: 'coordinates',
  );

  /// Degrees / minutes / seconds.
  static const Bi dmsLabel = Bi('DMS', 'DMS', key: 'dms');
  static const Bi decimalLabel = Bi('Decimal', 'Amadesimali', key: 'decimal');
  static const Bi howToUse = Bi(
    'How to use it',
    'Indlela yokuyisebenzisa',
    key: 'guide_how',
  );
  static const Bi accuracyHeading = Bi(
    'Accuracy',
    'Ukunemba',
    key: 'guide_acc',
  );
  static const Bi aboutHeading = Bi(
    'About this app',
    'Mayelana nalolu hlelo',
    key: 'about_heading',
  );
  static const Bi purposeHeading = Bi(
    'Purpose',
    'Inhloso',
    key: 'purpose_heading',
  );

  /// One line describing what Ekuphumuleni is.
  static const Bi ekuphumuleniDescription = Bi(
    'Ekuphumuleni is the designated spiritual capital for AIS spiritual '
        'mountain, temple and palace.',
    'Ekuphumuleni yinhlokodolobha yomoya eqokiwe yentaba yomoya ye-AIS, '
        'ithempeli nesigodlo.',
    key: 'ekuphumuleni_desc',
  );

  static const Bi purposeBody = Bi(
    'TSHK Compass is for Abantwana Bobukhosi Bukamoya (amasosha), the spiritual '
        'nation of The Revelation Spiritual Home and The Spiritual Home Kingdom '
        'under HSRM Imboni Dr uZwi-Lezwe Radebe.',
    'I-TSHK Compass ingeyabantwana boBukhosi bukaMoya (amasosha), isizwe '
        'sikamoya se-The Revelation Spiritual Home ne-The Spiritual Home '
        'Kingdom ngaphansi kuka-HSRM Imboni Dr uZwi-Lezwe Radebe.',
    key: 'purpose_body',
  );

  static const Bi purposeBody2 = Bi(
    'Wherever you are in the world, it shows the direction of Ekuphumuleni, the '
        'spiritual capital, so that prayer can face it and a msamo (umsamo) can '
        'be positioned toward it.',
    'Noma ngabe ukuphi emhlabeni, ikhombisa isiqondiso sase-Ekuphumuleni, '
        'inhlokodolobha yomoya, ukuze umkhuleko ubheke ngakhona futhi umsamo '
        'ubekwe ubheke ngakhona.',
    key: 'purpose_body2',
  );

  static const Bi step1 = Bi(
    'Tap Start compass and allow location and motion access.',
    'Cindezela "Qala ikhompasi" bese uvumela i-GPS nezinzwa zefoni.',
    key: 'guide_s1',
  );
  static const Bi step2 = Bi(
    'Hold the phone flat and turn until the arrow reaches the marker at the '
        'top.',
    'Bamba ifoni ithe bha, uphenduke kuze kufike umcibisholo ophawini '
        'oluphezulu.',
    key: 'guide_s2',
  );
  static const Bi step3 = Bi(
    'For a msamo, open the Msamo tab and follow the turn instruction.',
    'Ngomsamo, vula ithebhu ethi Msamo ulandele isiqondiso.',
    key: 'guide_s3',
  );

  static const Bi accuracyBody = Bi(
    'Phones read magnetic north, not true north. Across Southern Africa '
        'magnetic north lies roughly 17° to 28° west of true north — about 20° '
        'at Johannesburg and about 27° at Durban — and it drifts a little every '
        'year. TSHK Compass corrects for this with the World Magnetic Model '
        '(WMM 2025), using your position, altitude and the date, so the bearing '
        'shown is a true bearing. If the arrow drifts, move the phone in a '
        'figure-8 to calibrate the sensor, and keep it away from metal, magnets '
        'and speakers. Bearings are great-circle (initial) bearings and '
        'distances are given in kilometres.',
    'Omakhalekhukhwini bafunda inyakatho kazibuthe, hhayi inyakatho yangempela. '
        'ENingizimu ye-Afrika inyakatho kazibuthe ingaba ngu-17° kuya ku-28° '
        'entshonalanga yenyakatho yangempela — cishe u-20° eGoli kanye no-27° '
        'eThekwini — futhi iyashintsha kancane unyaka nonyaka. I-TSHK Compass '
        'iyakulungisa lokhu nge-World Magnetic Model (WMM 2025), isebenzisa '
        'indawo yakho, ukuphakama nosuku, ngakho isiqondiso esibonisiwe '
        'siyiqiniso. Uma umcibisholo unganembile, zungezisa ifoni njengo-8 '
        'ukuyilinganisa, futhi uyigcine kude nensimbi, ozibuthe nezipikha. '
        'Iziqondiso ziyiziqondiso ezinkulu (great-circle) futhi amabanga '
        'avezwa ngamakhilomitha.',
    key: 'accuracy_body',
  );

  static const Bi permissionsNote = Bi(
    'On iPhone, the first time you tap Start compass the system asks for '
        'location access and for motion and orientation access. Location is '
        'used only while the app is open, and only to work out the bearing and '
        'distance to Ekuphumuleni. On Android, location and the motion sensors '
        'are requested in the same way; nothing is stored or sent anywhere.',
    'Ku-iPhone, uma ucindezela u-Qala ikhompasi okokuqala, uhlelo lucela '
        'imvume yendawo kanye neyokunyakaza. Indawo isetshenziswa kuphela '
        'uma uhlelo luvuliwe, futhi kuphela ukuthola isiqondiso nebanga '
        'lokuya e-Ekuphumuleni. Ku-Android, indawo nezinzwa zokunyakaza '
        'kucelwa ngendlela efanayo; akukho okugcinwa noma okuthunyelwayo.',
    key: 'permissions_note',
  );

  static const Bi aboutBody = Bi(
    'TSHK Compass is the native iOS and Android app of the Ekuphumuleni '
        'compass. It works offline: the compass, the sun position and this '
        'guide need no internet connection. Only the map on the Centres tab '
        'needs to download map tiles.',
    'I-TSHK Compass iwuhlelo lwangempela lwe-iOS ne-Android lwekhompasi '
        'yase-Ekuphumuleni. Isebenza ngaphandle kwe-inthanethi: ikhompasi, '
        'isikhundla selanga nalomhlahlandlela akudingi uxhumano. Imephu '
        'esethebhu ye-Izikhungo kuphela edinga ukulanda amathayela emephu.',
    key: 'about_body',
  );

  // ---------------------------------------------------------- shared widgets

  static const Bi close = Bi('Close', 'Vala', key: 'close');
  static const Bi ekuphumuleni = Bi(
    'Ekuphumuleni',
    'Ekuphumuleni',
    key: 'ekuphumuleni',
  );
  static const Bi spiritualCapital = Bi(
    'Spiritual capital',
    'Inhlokodolobha yomoya',
    key: 'spiritual_capital',
  );

  // ------------------------------------------------------- compass engine

  /// Status chip: which rung of the ladder is driving the dial.
  static const Bi srcFused = Bi(
    'Compass sensor',
    'Inzwa yekhompasi',
    key: 'src_fused',
  );
  static const Bi srcRaw = Bi(
    'Raw sensors',
    'Izinzwa eziluhlaza',
    key: 'src_raw',
  );
  static const Bi srcRelative = Bi(
    'Turn sensor + calibration',
    'Inzwa yokuphenduka + ukulungiswa',
    key: 'src_relative',
  );
  static const Bi srcGps = Bi(
    'GPS (walking)',
    'I-GPS (uhamba)',
    key: 'src_gps',
  );
  static const Bi srcSun = Bi(
    'Sun guidance',
    'Isiqondiso selanga',
    key: 'src_sun',
  );

  static const Bi compassOnShort = Bi(
    'Compass: on',
    'Ikhompasi: iyasebenza',
    key: 'compass_on',
  );
  static const Bi compassWaiting = Bi(
    'Compass: waiting for sensor…',
    'Ikhompasi: ilinde inzwa',
    key: 'compass_waiting',
  );
  static const Bi compassNeedsCal = Bi(
    'Compass: needs calibration',
    'Ikhompasi: idinga ukulungiswa',
    key: 'compass_needs_cal',
  );
  static const Bi compassNone = Bi(
    'Compass: not available',
    'Ikhompasi: ayitholakali',
    key: 'compass_none',
  );
  static const Bi compassDenied = Bi(
    'Compass: permission refused',
    'Ikhompasi: ayivunyelwanga',
    key: 'compass_denied',
  );
  static const Bi compassNeedsLocation = Bi(
    'Compass: needs location',
    'Ikhompasi: idinga indawo',
    key: 'compass_needs_loc',
  );
  static const Bi compassError = Bi(
    'Compass: error',
    'Ikhompasi: iphutha',
    key: 'compass_error',
  );
  static const Bi compassPaused = Bi(
    'Move the phone to wake the compass',
    'Nyakazisa ifoni ukuze uvuse ikhompasi',
    key: 'compass_paused',
  );
  static const Bi walkForDirection = Bi(
    'Walk a few steps to get direction',
    'Hamba izinyathelo ezimbalwa',
    key: 'walk_for_direction',
  );
  static const Bi stopCompass = Bi(
    'Stop compass',
    'Misa ikhompasi',
    key: 'stop_compass',
  );
  static const Bi retryCompass = Bi(
    'Retry sensors',
    'Zama izinzwa futhi',
    key: 'retry_sensors',
  );

  // One-tap calibration.
  static const Bi calibrationTitle = Bi(
    'Set the direction once',
    'Beka isiqondiso kanye',
    key: 'calibration_title',
  );
  static const Bi calibrationBody = Bi(
    'This phone can feel how far it turns but not where north is. Point the '
        'top of the phone at the sun and tap Set, or point it at north with a '
        'hand compass and tap Set.',
    'Le foni izwa ukuthi iphenduke kangakanani kodwa ayazi ukuthi inyakatho '
        'ikuphi. Khomba ilanga ngengxenye engenhla yefoni ucindezele u-Beka, '
        'noma ukhombe enyakatho ngekhompasi yesandla ucindezele u-Beka.',
    key: 'calibration_body',
  );
  static const Bi setToSun = Bi(
    'Set: phone points at the sun',
    'Beka: ifoni ibheke ilanga',
    key: 'set_to_sun',
  );
  static const Bi setToNorth = Bi(
    'Set: phone points north (hand compass)',
    'Beka: ifoni ibheke enyakatho',
    key: 'set_to_north',
  );
  static const Bi calibratedToSun = Bi(
    'Calibrated to the sun',
    'Kulungiswe ngelanga',
    key: 'calibrated_sun',
  );
  static const Bi calibratedToNorth = Bi(
    'Calibrated to magnetic north',
    'Kulungiswe ngenyakatho kazibuthe',
    key: 'calibrated_north',
  );
  static const Bi recalibrate = Bi(
    'Set again',
    'Beka futhi',
    key: 'recalibrate',
  );
  static const Bi sunBelowHorizonShort = Bi(
    'Sun below the horizon',
    'Ilanga selishonile',
    key: 'sun_night',
  );

  // Sun-only guidance.
  static const Bi sunGuidanceTitle = Bi(
    'Use the sun',
    'Sebenzisa ilanga',
    key: 'sun_title',
  );
  static const Bi sunNow = Bi('Sun now', 'Ilanga manje', key: 'sun_now');
  static const Bi sunWhyNone = Bi(
    'This phone has no working compass; use the sun and the bearings below.',
    'Le foni ayinayo ikhompasi; sebenzisa ilanga.',
    key: 'sunwhy_none',
  );
  static const Bi sunAhead = Bi(
    'Face the sun: Ekuphumuleni is straight ahead.',
    'Bheka ilanga, Ekuphumuleni iphambi kwakho.',
    key: 'sun_ahead',
  );

  /// "Face the sun, then turn 32° to the right."
  static Bi sunTurn(int deg, {required bool toRight}) {
    final Bi dir = toRight ? right : left;
    return Bi(
      'Face the sun, then turn $deg° to the ${dir.en}.',
      'Bheka ilanga, bese uphendukela ${dir.zu} ngo-$deg°.',
      key: 'sun_turn',
      args: <String, Object>{'n': '$deg', 'dir': dir},
    );
  }

  /// "Turn until the sun is on your left."
  static Bi sunOnSide({required bool onRight}) {
    final Bi dir = onRight ? right : left;
    return Bi(
      'Turn until the sun is on your ${dir.en}.',
      'Phenduka kuze kuthi ilanga libe ${dir.zu}.',
      key: 'sun_on_side',
      args: <String, Object>{'dir': dir},
    );
  }

  /// "A stick's shadow points to 312° NW. Stand facing along the shadow,
  /// then turn 40° to the right."
  static Bi stickShadowGuide(
    String shadowBearing,
    int deg, {
    required bool toRight,
  }) {
    final Bi dir = toRight ? right : left;
    return Bi(
      "A stick's shadow points to $shadowBearing. Stand facing along the "
          'shadow, then turn $deg° to the ${dir.en}.',
      'Isithunzi sentonga sikhomba ku-$shadowBearing. Yima ubheke '
          'ngasesithunzini, bese uphendukela ${dir.zu} ngo-$deg°.',
      key: 'stick_shadow_guide',
      args: <String, Object>{'b': shadowBearing, 'n': '$deg', 'dir': dir},
    );
  }

  static const Bi sunNightLong = Bi(
    'The sun is below the horizon now. Use a hand compass with the magnetic '
        'bearing, or try again in daylight.',
    'Ilanga selishonile. Sebenzisa ikhompasi yesandla nokubheka kazibuthe, '
        'noma uzame futhi emini.',
    key: 'sun_night_long',
  );

  /// "Use a hand compass: 312° magnetic".
  static Bi handCompass(int magneticDeg) => Bi(
    'Use a hand compass: $magneticDeg° magnetic',
    'Sebenzisa ikhompasi yesandla: $magneticDeg° kazibuthe',
    key: 'hand_compass',
    args: <String, Object>{'n': '$magneticDeg'},
  );

  // Level bubble.
  static const Bi flat = Bi('Flat', 'Ithe bha', key: 'flat');
  static const Bi tilted = Bi('Tilted', 'Itshekile', key: 'tilted');
  static const Bi keepFlat = Bi(
    'Keep the phone flat',
    'Gcina ifoni ithe bha',
    key: 'level_s',
  );

  // Permissions (motion sensors).
  static const Bi motionDenied = Bi(
    'Motion access was refused. Allow Motion & Fitness in Settings so the '
        'compass can follow the phone; the bearings below still work.',
    'Imvume yokunyakaza yenqatshiwe. Vumela i-Motion & Fitness '
        'kuzilungiselelo; izinombolo ezingezansi zisasebenza.',
    key: 'motion_denied',
  );

  // ---------------------------------------------------------------- towns

  static const Bi pickTown = Bi(
    'Pick a town',
    'Khetha idolobha',
    key: 'town_title',
  );
  static const Bi useThisTown = Bi(
    'Use this town',
    'Sebenzisa leli dolobha',
    key: 'btn_town',
  );
  static const Bi searchTown = Bi(
    'Search a town',
    'Sesha idolobha',
    key: 'search_town',
  );
  static const Bi manualNote = Bi(
    'Use this when GPS is unavailable — for example indoors or when the phone '
        'has no signal.',
    'Sebenzisa lokhu uma i-GPS ingatholakali — isibonelo ngaphakathi endlini '
        'noma uma ifoni ingenalo isignali.',
    key: 'manual_note',
  );
  static const Bi noTownMatch = Bi(
    'No town matches',
    'Alikho idolobha elitholakele',
    key: 'no_town_match',
  );
  static const Bi townNote = Bi(
    'Town centre coordinates: accurate to a few kilometres, which changes the '
        'bearing by well under a degree.',
    'Izixhumanisi zenkaba yedolobha: zinemba kumakhilomitha ambalwa, okushintsha '
        'ukubheka ngaphansi kwedigri eyodwa.',
    key: 'town_note',
  );

  // ------------------------------------------------------------ settings

  static const Bi settingsHeading = Bi(
    'Settings',
    'Izilungiselelo',
    key: 'settings',
  );
  static const Bi language = Bi('Language', 'Ulimi', key: 'language');
  static const Bi languageNote = Bi(
    'Choose the language for all text in the app.',
    'Khetha ulimi lwawo wonke umbhalo osohlelweni.',
    key: 'language_note',
  );
  static const Bi batterySaver = Bi(
    'Battery saver · Simple mode',
    'Ukonga ibhethri · Imodi elula',
    key: 'battery_saver',
  );
  static const Bi batterySaverNote = Bi(
    'Fewer animations, no shadows, a lighter map. Switched on automatically '
        'on phones with little memory.',
    'Ukunyakaza okuncane, azikho izithunzi, imephu elula. Kuvulwa ngokuzenzakalela '
        'kumafoni anememori encane.',
    key: 'battery_saver_note',
  );
  static const Bi simpleModeAuto = Bi(
    'On (this phone)',
    'Kuvuliwe (le foni)',
    key: 'simple_auto',
  );
  static const Bi on = Bi('On', 'Kuvuliwe', key: 'on');
  static const Bi off = Bi('Off', 'Kuvaliwe', key: 'off');

  // ---------------------------------------------------------- membership

  static const Bi membershipTitle = Bi(
    'Membership',
    'Ubulungu',
    key: 'membership',
  );
  static const Bi account = Bi('Account', 'I-akhawunti', key: 'account');
  static const Bi logOut = Bi('Log out', 'Phuma', key: 'pay_signout');

  // ------------------------------------------------- log in / create account

  static const Bi authTitle = Bi(
    'Sign in to continue',
    'Ngena ukuze uqhubeke',
    key: 'auth_title',
  );
  static const Bi authLogIn = Bi('Log in', 'Ngena', key: 'auth_verify');
  static const Bi authCreate = Bi(
    'Create account',
    'Vula i-akhawunti',
    key: 'auth_create',
  );
  static const Bi authCreateIntro = Bi(
    'Create an account to start your free trial.',
    'Vula i-akhawunti ukuze uqale ukuzama mahhala.',
    key: 'auth_create_intro',
  );
  static const Bi authEmail = Bi(
    'Your e-mail address',
    'Ikheli lakho le-imeyili',
    key: 'auth_email',
  );
  static const Bi authPassword = Bi(
    'Password',
    'Iphasiwedi',
    key: 'auth_password',
  );
  static const Bi authShowPassword = Bi(
    'Show password',
    'Bonisa iphasiwedi',
    key: 'auth_pw_show',
  );
  static const Bi authHidePassword = Bi(
    'Hide password',
    'Fihla iphasiwedi',
    key: 'auth_pw_hide',
  );

  /// There is no self-service password recovery: an administrator generates a
  /// new password instead (Admin tools ▸ auto-generate a password).
  static const Bi authContactAdmin = Bi(
    'Forgot your password? An administrator can issue you a new one.',
    'Ukhohlwe iphasiwedi yakho? Umphathi angakunika entsha.',
    key: 'auth_contact_admin',
  );
  static const Bi authBadEmail = Bi(
    'Please enter a valid e-mail address.',
    'Sicela ufake ikheli le-imeyili elifanele.',
    key: 'auth_bad_email',
  );
  static const Bi authNoPassword = Bi(
    'Enter your password.',
    'Faka iphasiwedi yakho.',
    key: 'auth_no_password',
  );
  static const Bi authShortPassword = Bi(
    'Use at least 8 characters.',
    'Sebenzisa okungenani izinhlamvu ezingu-8.',
    key: 'auth_short_pw',
  );
  static const Bi authInvalid = Bi(
    'That e-mail and password do not match. Please try again.',
    'Leyo imeyili nephasiwedi azihambisani. Sicela uzame futhi.',
    key: 'auth_invalid',
  );
  static const Bi authAlready = Bi(
    'That address already has an account. Log in instead.',
    'Lelo kheli selinayo i-akhawunti. Ngena kunalokho.',
    key: 'auth_already',
  );
  static const Bi authWeak = Bi(
    'That password is too weak. Use a longer one.',
    'Leyo phasiwedi ibuthakathaka. Sebenzisa ende kakhulu.',
    key: 'auth_weak',
  );
  static const Bi authRateLimited = Bi(
    'Too many attempts. Please wait a few minutes and try again.',
    'Imizamo eminingi kakhulu. Sicela ulinde imizuzu embalwa uzame futhi.',
    key: 'auth_rate',
  );
  static const Bi authFailed = Bi(
    'That did not work. Please try again.',
    'Lokho akusebenzanga. Sicela uzame futhi.',
    key: 'auth_failed',
  );

  // ------------------------------------------------------- password change

  static const Bi pwTitle = Bi(
    'Set your own password',
    'Beka eyakho iphasiwedi',
    key: 'pw_title',
  );
  static const Bi pwBody = Bi(
    'An administrator gave you a temporary password. Choose your own before '
        'you carry on.',
    'Umphathi ukunike iphasiwedi yesikhashana. Khetha eyakho ngaphambi kokuba '
        'uqhubeke.',
    key: 'pw_body',
  );
  static const Bi pwNew = Bi(
    'New password',
    'Iphasiwedi entsha',
    key: 'pw_new',
  );
  static const Bi pwConfirm = Bi(
    'Confirm new password',
    'Qinisekisa iphasiwedi entsha',
    key: 'pw_confirm',
  );
  static const Bi pwMismatch = Bi(
    'The two passwords do not match.',
    'Amaphasiwedi amabili awafani.',
    key: 'pw_mismatch',
  );
  static const Bi pwSave = Bi(
    'Save password',
    'Gcina iphasiwedi',
    key: 'pw_save',
  );
  static const Bi pwChanged = Bi(
    'Your password has been changed.',
    'Iphasiwedi yakho ishintshiwe.',
    key: 'pw_changed',
  );
  static const Bi pwFailed = Bi(
    'The password could not be changed. Please try again.',
    'Iphasiwedi ayikwazanga ukushintshwa. Sicela uzame futhi.',
    key: 'pw_failed',
  );
  static const Bi pwChange = Bi(
    'Change password',
    'Shintsha iphasiwedi',
    key: 'pw_change',
  );
  static const Bi pwOffline = Bi(
    'You must be online to set a new password.',
    'Kumele uxhume ku-inthanethi ukuze ubeke iphasiwedi entsha.',
    key: 'pw_offline',
  );

  // ------------------------------------------------------------ trial page

  static Bi trialTitle(int days) => Bi(
    'Your $days-day free trial has started',
    'Isikhathi sakho sezinsuku ezingu-$days sokuzama mahhala siqalile',
    key: 'trial_title',
    args: <String, Object>{'n': '$days'},
  );
  static const Bi trialWhat = Bi(
    'Everything is included',
    'Konke kufakiwe',
    key: 'trial_what',
  );
  static const Bi featCompass = Bi(
    'Compass to Ekuphumuleni',
    'Ikhompasi eya e-Ekuphumuleni',
    key: 'feat_compass',
  );
  static const Bi featMsamo = Bi(
    'Msamo positioning',
    'Ukubekwa komsamo',
    key: 'feat_msamo',
  );
  static const Bi featSun = Bi(
    'Sun and shadow guidance',
    'Isiqondiso selanga nesithunzi',
    key: 'feat_sun',
  );
  static const Bi featCentres = Bi(
    'Centres directory with directions',
    'Uhlu lwezikhungo nezikhombisi-ndlela',
    key: 'feat_centres',
  );
  static const Bi featLanguages = Bi(
    'English plus four other languages: isiZulu, Português, Chichewa, '
        'iciBemba',
    'IsiNgisi kanye nezinye izilimi ezine: isiZulu, Português, Chichewa, '
        'iciBemba',
    key: 'feat_languages',
  );
  static const Bi trialStart = Bi(
    'Start using the app',
    'Qala ukusebenzisa uhlelo',
    key: 'trial_start',
  );
  static const Bi payNow = Bi('Pay now', 'Khokha manje', key: 'pay_now');
  static const Bi storePlans = Bi(
    'View plans',
    'Buka izinhlelo zobulungu',
    key: 'store_plans',
  );
  static const Bi storeRestore = Bi(
    'Restore purchases',
    'Buyisela okuthengiwe',
    key: 'store_restore',
  );
  static const Bi storeManage = Bi(
    'Manage subscription',
    'Phatha ubulungu',
    key: 'store_manage',
  );
  static Bi trialLeft(int days) => Bi(
    'Free trial: $days days left',
    'Isikhathi sokuzama mahhala: kusele izinsuku ezingu-$days',
    key: 'trial_left',
    args: <String, Object>{'n': '$days'},
  );
  static Bi trialOffer(int days, String price) => Bi(
    'Free for $days days, then $price per month.',
    'Mahhala izinsuku ezingu-$days, bese kuba ngu-$price ngenyanga.',
    key: 'trial_offer',
    args: <String, Object>{'n': '$days', 'p': price},
  );
  static const Bi trialEnded = Bi(
    'Your free trial has ended',
    'Isikhathi sakho sokuzama mahhala siphelile',
    key: 'trial_ended',
  );

  // --------------------------------------------------------------- paywall

  static const Bi paywallTitle = Bi(
    'A membership is needed to carry on',
    'Kudingeka ubulungu ukuze uqhubeke',
    key: 'paywall_title',
  );
  static const Bi payGraceNote = Bi(
    'After a missed payment there are three days of grace; after that the '
        'app waits for PayFast to confirm.',
    'Uma inkokhelo iphuthile kunezinsuku ezintathu zomusa; emva kwalokho '
        'uhlelo lulinda i-PayFast ukuba iqinisekise.',
    key: 'pay_grace',
  );
  static Bi payOffer(String price) => Bi(
    'Continue with a monthly membership of $price. Cancel any time.',
    'Qhubeka ngobulungu banyanga zonke obungu-$price. Ungakhansela noma nini.',
    key: 'pay_offer',
    args: <String, Object>{'p': price},
  );
  static Bi payButton(String price) => Bi(
    'Subscribe · $price per month',
    'Bhalisa · $price ngenyanga',
    key: 'pay_btn',
    args: <String, Object>{'p': price},
  );
  static const Bi payStore = Bi(
    'A membership is required. Please sign in with a member account.',
    'Kudingeka ubulungu. Sicela ungene nge-akhawunti yelungu.',
    key: 'pay_store',
  );

  // --------------------------------------------------------------- offline

  static const Bi offlineTitle = Bi(
    'No connection',
    'Akukho ukuxhumana',
    key: 'offline_title',
  );
  static const Bi payOffline = Bi(
    'Connect to the internet to check your membership',
    'Xhuma ku-inthanethi ukuze sihlole ubulungu bakho',
    key: 'pay_offline',
  );
  static const Bi membershipCachedNote = Bi(
    'Showing the last confirmed status (offline).',
    'Kuboniswa isimo sokugcina esiqinisekisiwe (ngaphandle kwe-inthanethi).',
    key: 'membership_cached',
  );

  // -------------------------------------------------------- account screen

  static const Bi accountOpen = Bi(
    'Account and membership',
    'I-akhawunti nobulungu',
    key: 'acct_open',
  );
  static const Bi accountNote = Bi(
    'Your e-mail, your membership, your password.',
    'I-imeyili yakho, ubulungu bakho, iphasiwedi yakho.',
    key: 'acct_note',
  );
  static const Bi accountSignedInAs = Bi(
    'Signed in as',
    'Ungene njengo-',
    key: 'acct_as',
  );
  static const Bi accountStatusLabel = Bi(
    'Status',
    'Isimo',
    key: 'acct_status',
  );
  static Bi accountUntil(String date) => Bi(
    'Access until $date',
    'Ukufinyelela kuze kube ngu-$date',
    key: 'acct_until',
    args: <String, Object>{'d': date},
  );
  static const Bi payChecking = Bi(
    'Checking your membership…',
    'Sihlola ubulungu bakho…',
    key: 'pay_checking',
  );
  static const Bi payConfirming = Bi(
    'Confirming your payment…',
    'Siqinisekisa inkokhelo yakho…',
    key: 'pay_confirming',
  );
  static const Bi payWait = Bi(
    'This usually takes a few seconds.',
    'Lokhu kuvame ukuthatha imizuzwana embalwa.',
    key: 'pay_wait',
  );
  static const Bi payPastDue = Bi(
    "We have not received this month's payment yet",
    'Asikakutholi ukukhokha kwale nyanga',
    key: 'pay_pastdue',
  );
  static const Bi payExpired = Bi(
    'Your membership has ended',
    'Ubulungu bakho buphelile',
    key: 'pay_expired',
  );
  static const Bi payActive = Bi(
    'Membership active, renews monthly',
    'Ubulungu busebenza, buvuselelwa njalo ngenyanga',
    key: 'pay_active',
  );
  static Bi payCancelledUntil(String date) => Bi(
    'Cancelled. Access until $date',
    'Kukhanseliwe. Ungasebenzisa kuze kube ngu-$date',
    key: 'pay_cancelled_until',
    args: <String, Object>{'d': date},
  );
  static const Bi payNone = Bi(
    'No active membership',
    'Abukho ubulungu obusebenzayo',
    key: 'pay_none',
  );
  static const Bi payCancel = Bi(
    'Cancel subscription',
    'Khansela ukubhalisa',
    key: 'pay_cancel',
  );
  static const Bi payCancelConfirm = Bi(
    'Tap again to confirm the cancellation',
    'Cindezela futhi ukuze uqinisekise ukukhansela',
    key: 'pay_cancel_confirm',
  );
  static const Bi payCancelDone = Bi(
    'Your subscription has been cancelled. No further payments will be taken.',
    'Ukubhalisa kwakho kukhanseliwe. Ayikho enye inkokhelo ezothathwa.',
    key: 'pay_cancel_done',
  );
  static const Bi payCancelFail = Bi(
    'We could not cancel right now. Please try again later.',
    'Asikwazanga ukukhansela manje. Sicela uzame emuva kwesikhathi.',
    key: 'pay_cancel_fail',
  );
  static const Bi payOpenFail = Bi(
    'PayFast could not be opened. Please try again.',
    'Asikwazanga ukuvula i-PayFast. Sicela uzame futhi.',
    key: 'pay_open_fail',
  );
  static const Bi storeBillingFailed = Bi(
    'Store billing is unavailable right now. Check your connection and try again.',
    'Inkokhelo yesitolo ayitholakali manje. Hlola i-inthanethi bese uzama futhi.',
    key: 'store_billing_failed',
  );
  static const Bi paySlow = Bi(
    'Your payment is still being confirmed. Wait a minute, then tap Retry.',
    'Inkokhelo yakho isaqinisekiswa. Linda umzuzu bese ucindezela u-Zama futhi.',
    key: 'pay_slow',
  );
  static const Bi payCancelledNote = Bi(
    'The payment was cancelled. You can try again.',
    'Inkokhelo ikhanseliwe. Ungazama futhi.',
    key: 'pay_cancelled_note',
  );

  // ------------------------------------------------------------ admin area

  static const Bi adminOpen = Bi(
    'Admin tools',
    'Amathuluzi omphathi',
    key: 'admin_open',
  );
  static const Bi adminTitle = Bi(
    'Administration',
    'Ukuphatha',
    key: 'admin_title',
  );
  static const Bi adminNote = Bi(
    'Only administrators see this. The server checks it again.',
    'Abaphathi kuphela ababona lokhu. Iseva iyaphinda ihlole.',
    key: 'admin_note',
  );
  static const Bi adminAddCentre = Bi(
    'Add a centre',
    'Engeza isikhungo',
    key: 'admin_add_centre',
  );
  static const Bi adminGenPassword = Bi(
    'Auto-generate password',
    'Yakha iphasiwedi ngokuzenzakalela',
    key: 'admin_gen_pw',
  );
  static const Bi adminDeleteUser = Bi(
    'Delete a user',
    'Susa umsebenzisi',
    key: 'admin_del_user',
  );
  static const Bi adminRegion = Bi('Region', 'Isifunda', key: 'admin_region');
  static const Bi adminCentreName = Bi(
    'Centre name',
    'Igama lesikhungo',
    key: 'admin_name',
  );
  static const Bi adminAddress = Bi('Address', 'Ikheli', key: 'admin_address');
  static const Bi adminPhone = Bi(
    'Phone number',
    'Inombolo yocingo',
    key: 'admin_phone',
  );
  static const Bi adminRequired = Bi(
    'Required',
    'Kuyadingeka',
    key: 'admin_required',
  );
  static Bi adminCentreAdded(String name) => Bi(
    '$name has been added.',
    'U-$name wengeziwe.',
    key: 'admin_centre_added',
    args: <String, Object>{'n': name},
  );
  static const Bi adminDuplicateCentre = Bi(
    'A centre with that name already exists in that region.',
    'Kukhona kakade isikhungo esinaleli gama kuleso sifunda.',
    key: 'admin_dup_centre',
  );
  static const Bi adminInvalidCentre = Bi(
    'Please check the fields marked below.',
    'Sicela uhlole izinkambu ezimakiwe ngezansi.',
    key: 'admin_bad_centre',
  );
  static const Bi adminSearchUser = Bi(
    'Search by e-mail',
    'Sesha ngemeyili',
    key: 'admin_search_user',
  );
  static const Bi adminSearch = Bi('Search', 'Sesha', key: 'admin_search');
  static const Bi adminNoUsers = Bi(
    'No user matches that search.',
    'Akekho umsebenzisi otholakalayo.',
    key: 'admin_no_users',
  );
  static Bi adminSelected(String email) => Bi(
    'Selected: $email',
    'Okukhethiwe: $email',
    key: 'admin_selected',
    args: <String, Object>{'e': email},
  );
  static Bi adminGenConfirm(String email) => Bi(
    'Generate a new temporary password for $email? Their current password '
        'stops working at once.',
    'Yakha iphasiwedi entsha yesikhashana ka-$email? Iphasiwedi yakhe '
        'yamanje iyeka ukusebenza ngaso leso sikhathi.',
    key: 'admin_gen_confirm',
    args: <String, Object>{'e': email},
  );
  static const Bi adminGenerate = Bi(
    'Generate password',
    'Yakha iphasiwedi',
    key: 'admin_generate',
  );
  static const Bi adminTempTitle = Bi(
    'Temporary password',
    'Iphasiwedi yesikhashana',
    key: 'admin_temp_title',
  );
  static const Bi adminTempWarning = Bi(
    'Shown once. Pass it on securely.',
    'Iboniswa kanye. Yidlulise ngokuphepha.',
    key: 'admin_temp_warn',
  );
  static const Bi adminCopy = Bi('Copy', 'Kopisha', key: 'admin_copy');
  static const Bi adminCopied = Bi(
    'Copied',
    'Kukopishiwe',
    key: 'admin_copied',
  );
  static Bi adminDeleteConfirm(String email) => Bi(
    'Type $email to confirm the deletion.',
    'Thayipha u-$email ukuze uqinisekise ukususa.',
    key: 'admin_del_confirm',
    args: <String, Object>{'e': email},
  );
  static const Bi adminDeleteMismatch = Bi(
    'The e-mail does not match.',
    'I-imeyili ayifani.',
    key: 'admin_del_mismatch',
  );
  static const Bi adminDelete = Bi(
    'Delete user',
    'Susa umsebenzisi',
    key: 'admin_delete',
  );
  static Bi adminDeleted(String email) => Bi(
    '$email has been deleted.',
    'U-$email ususiwe.',
    key: 'admin_deleted',
    args: <String, Object>{'e': email},
  );
  static const Bi adminDeletedCancelled = Bi(
    'Their subscription was cancelled as well.',
    'Ukubhalisa kwakhe nakho kukhanseliwe.',
    key: 'admin_del_cancelled',
  );
  static const Bi adminDeletedNoSub = Bi(
    'They had no active subscription.',
    'Ubengenakho ukubhalisa okusebenzayo.',
    key: 'admin_del_nosub',
  );
  static const Bi adminCannotDeleteSelf = Bi(
    'You cannot delete your own account.',
    'Awukwazi ukususa i-akhawunti yakho.',
    key: 'admin_del_self',
  );
  static const Bi adminPayfastFailed = Bi(
    'PayFast could not cancel the subscription, so nothing was deleted. '
        'Please try again later.',
    'I-PayFast ayikwazanga ukukhansela ukubhalisa, ngakho akukho okususiwe. '
        'Sicela uzame emuva kwesikhathi.',
    key: 'admin_payfast_fail',
  );
  static const Bi adminForbidden = Bi(
    'This account is not an administrator.',
    'Le akhawunti akusiyo eyomphathi.',
    key: 'admin_forbidden',
  );
  static const Bi adminFailed = Bi(
    'That did not work. Please try again.',
    'Lokho akusebenzanga. Sicela uzame futhi.',
    key: 'admin_failed',
  );

  // --------------------------------------------------------- centres state

  static const Bi centresOffline = Bi(
    'Showing the saved list: the centres could not be downloaded.',
    'Kuboniswa uhlu olugciniwe: izikhungo azikwazanga ukulandwa.',
    key: 'centres_offline',
  );
  static const Bi centresEmpty = Bi(
    'The centres will appear once the phone is online.',
    'Izikhungo zizovela uma ifoni ixhunywe ku-inthanethi.',
    key: 'centres_empty',
  );
}
