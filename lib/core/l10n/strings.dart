/// Single source of truth for every user visible string in TSHK Compass.
///
/// The app is bilingual by design: every label shows English as the main text
/// and a secondary line underneath it. The secondary line is isiZulu by
/// default (authored here, next to the English) and can be switched to
/// Portuguese, Chichewa or Bemba; those come from `assets/translations.json`
/// through the [Bi.key] of each string (see [L10n.secondary] for the fallback
/// order: chosen language → isiZulu → English).
///
/// Never put user visible literals in widgets: add a [Bi] here.
library;

import 'app_language.dart';

export 'app_language.dart' show AppLanguage;

/// A bilingual string value: English plus a secondary line.
class Bi {
  const Bi(this.en, this.zu, {this.key, this.args});

  /// English (primary) text.
  final String en;

  /// isiZulu text: the authored default for the secondary line.
  final String zu;

  /// Optional key into `translations.json` for the other languages.
  final String? key;

  /// Optional `{placeholder}` values for parameterised strings.
  final Map<String, String>? args;

  /// The secondary line in the currently selected language.
  String get secondary =>
      L10n.secondary(en: en, zu: zu, key: key, args: args);

  /// The secondary line in a specific language (for tests and previews).
  String secondaryIn(AppLanguage language) =>
      L10n.secondary(en: en, zu: zu, key: key, args: args, language: language);

  /// "English · secondary" on one line.
  String get inline => '$en · $secondary';

  /// Copy with placeholder values filled in.
  Bi withArgs(Map<String, String> values) => Bi(
        _fill(en, values),
        _fill(zu, values),
        key: key,
        args: <String, String>{...?args, ...values},
      );

  static String _fill(String template, Map<String, String> values) {
    String out = template;
    values.forEach((String name, String value) {
      out = out.replaceAll('{$name}', value);
    });
    return out;
  }

  @override
  String toString() => en;
}

/// All app strings.
abstract final class S {
  // ---------------------------------------------------------------- branding

  /// Large serif title shown in the header of every screen.
  static const String appTitle = 'TSHK Compass';

  /// Small uppercase letter-spaced eyebrow shown above the title.
  static const String eyebrow = 'EKUPHUMULENI · SPIRITUAL CAPITAL';

  /// Footer caption under the crest on the Guide screen.
  static const String crestCaption =
      'The Revelation Spiritual Home · The Spiritual Home Kingdom';

  // -------------------------------------------------------------------- tabs

  static const Bi tabCompass = Bi('Compass', 'Ikhompasi', key: 'tab_compass');
  static const Bi tabMsamo = Bi('Msamo', 'Umsamo', key: 'tab_msamo');
  static const Bi tabLocation = Bi('Location', 'Indawo', key: 'tab_location');
  static const Bi tabCentres = Bi('Centres', 'Izikhungo', key: 'tab_centres');
  static const Bi tabGuide = Bi('Guide', 'Umhlahlandlela', key: 'tab_guide');

  // ----------------------------------------------------------------- compass

  static const Bi startCompass = Bi('Start compass', 'Qala ikhompasi', key: 'btn_start');
  static const Bi startToBegin =
      Bi('Start the compass to begin', 'Qala ikhompasi ukuze uqale', key: 'state_start');
  static const Bi locationNotSet = Bi('Location: not set', 'Indawo: ayikabekwa', key: 'loc_unset');
  static const Bi compassOff = Bi('Compass: off', 'Ikhompasi: ivaliwe', key: 'cmp_off');
  static const Bi compassOn = Bi('Compass: on', 'Ikhompasi: ivuliwe');

  static const Bi compassHelp = Bi(
    'The arrow points to Ekuphumuleni. When it sits under the marker at the '
        'top, you are facing the spiritual capital. Hold the phone flat and '
        'away from metal.',
    'Umcibisholo ukhomba e-Ekuphumuleni. Uma ungaphansi kophawu oluphezulu, '
        'ubheke enhlokodolobha yomoya. Bamba ifoni ithe bha, kude nensimbi.', key: 'note_arrow');

  // Readout labels.
  static const Bi sunHeight =
      Bi('Sun height · above horizon', 'Ukuphakama kwelanga · ngaphezu komkhathizwe');
  static const Bi facingSun = Bi('Facing the sun', 'Ubheke ilanga', key: 'sun_facing');
  static const Bi stickShadow =
      Bi("Using a stick's shadow", 'Ukusebenzisa isithunzi sentonga', key: 'sun_shadow');
  static const Bi bearingTrue = Bi('Bearing (true)', 'Ukubheka', key: 'ro_bearing');
  static const Bi distance = Bi('Distance', 'Ibanga', key: 'ro_dist');
  static const Bi magneticBearing =
      Bi('Magnetic bearing · hand compass', 'Ukubheka kazibuthe · ikhompasi yesandla');
  static const Bi declination = Bi('Declination · WMM 2025', 'Ukuchezuka · WMM 2025');
  static const Bi yourLocation = Bi('Your location', 'Indawo yakho', key: 'ro_loc');

  static const Bi notSetHint = Bi(
    'Not set · Tap Start, or set it under Location',
    'Ayikabekwa · Cindezela u-Qala, noma uyibeke ngaphansi kwe-Indawo',
  );

  // Readout values.
  static const Bi belowHorizon = Bi('Below horizon', 'Ngaphansi komkhathizwe');
  static const Bi aboveHorizon = Bi('above horizon', 'ngaphezu komkhathizwe');
  static const Bi yesFacingSun = Bi('Yes, you are facing the sun', 'Yebo, ubheke ilanga');
  static const Bi noFacingSun = Bi('No, the sun is not ahead', 'Cha, ilanga alikho phambili');
  static const Bi sunBehind = Bi('The sun is behind you', 'Ilanga lingemuva kwakho');
  static const Bi sunUnknown =
      Bi('Start the compass to know', 'Qala ikhompasi ukuze wazi');
  static const Bi shadowHint =
      Bi('Shadow points this way', 'Isithunzi sikhomba ngalapha');
  static const Bi noSensorValue =
      Bi('No sensor — use the bearings below', 'Ayikho inzwa — sebenzisa izinombolo');

  // States and warnings.
  static const Bi calibrateHint =
      Bi('Calibrate: move the phone in a figure-8',
          'Linganisa: zungezisa ifoni njengo-8', key: 'calib');
  static const Bi noSensor = Bi(
    'This device has no compass sensor. The true bearing, magnetic bearing '
        'and distance to Ekuphumuleni are still shown — use a hand compass or '
        'the bearings below to face the spiritual capital.',
    'Le foni ayinayo inzwa yekhompasi. Ukubheka okuqondile, ukubheka '
        'kazibuthe nebanga lokuya e-Ekuphumuleni kusabonisiwe — sebenzisa '
        'ikhompasi yesandla noma lezi zinombolo ukuze ubheke enhlokodolobha '
        'yomoya.',
  );
  static const Bi sensorUnavailable =
      Bi('Compass sensor unavailable', 'Inzwa yekhompasi ayitholakali');
  static const Bi waitingForHeading =
      Bi('Waiting for a heading…', 'Kulinde isiqondiso…', key: 'turn_wait');
  static const Bi aligned =
      Bi('Facing Ekuphumuleni', 'Ubheke e-Ekuphumuleni', key: 'facing');
  static const Bi notAvailable = Bi('Not available', 'Ayitholakali');

  // ------------------------------------------------------------------- msamo

  static const Bi msamoIntro = Bi(
    'A msamo (umsamo) is placed so that it faces Ekuphumuleni. Stand where the '
        'msamo will stand, hold the phone flat, and turn until the needle sits '
        'on the marker.',
    'Umsamo ubekwa ubheke e-Ekuphumuleni. Yima lapho kuzoba khona umsamo, '
        'bamba ifoni ithe bha, uphenduke kuze kufike umcibisholo ophawini.',
  );
  static const Bi msamoRequired =
      Bi('Required direction', 'Isiqondiso esidingekayo');
  static const Bi msamoAligned =
      Bi('Your msamo is facing Ekuphumuleni',
          'Umsamo wakho ubheke e-Ekuphumuleni', key: 'msamo_aligned');
  static const Bi msamoNotAligned =
      Bi('Keep turning until the needle is centred',
          'Qhubeka uphenduka kuze kube semaphakathi');
  static const Bi lockDirection =
      Bi('Lock this direction', 'Khiya lesi siqondiso');
  static const Bi unlockDirection = Bi('Unlock', 'Vula');
  static const Bi lockedNote = Bi(
    'Direction locked. The reading is frozen so you can mark the position.',
    'Isiqondiso sikhiyiwe. Ukufunda kumisiwe ukuze ukwazi ukumaka indawo.',
  );
  static const Bi msamoWaiting = Bi(
    'Start the compass to see the turn instruction',
    'Qala ikhompasi ukuze ubone isiqondiso sokuphenduka',
  );

  /// "left" / "right", as words, for the turn instructions.
  static const Bi left = Bi('left', 'kwesokunxele', key: 'left');
  static const Bi right = Bi('right', 'kwesokudla', key: 'right');

  /// "Turn 32° to your right" / "Phendukela kwesokudla ngo-32°".
  static Bi turnBy(int deg, {required bool toRight}) {
    final Bi dir = toRight ? right : left;
    return Bi(
      'Turn $deg° to your ${dir.en}',
      'Phendukela ${dir.zu} ngo-$deg°',
      key: 'turn_state',
      args: <String, String>{'n': '$deg', 'dir': dir.secondary},
    );
  }

  /// "Turn around 175°".
  static Bi turnAround(int deg) => Bi(
        'Turn around $deg°',
        'Phenduka ngo-$deg°',
      );

  // Kept for callers that still want the plain strings.
  static String turnRightEn(int deg) => turnBy(deg, toRight: true).en;
  static String turnRightZu(int deg) => turnBy(deg, toRight: true).zu;
  static String turnLeftEn(int deg) => turnBy(deg, toRight: false).en;
  static String turnLeftZu(int deg) => turnBy(deg, toRight: false).zu;
  static String turnAroundEn(int deg) => turnAround(deg).en;
  static String turnAroundZu(int deg) => turnAround(deg).zu;

  // ---------------------------------------------------------------- location

  static const Bi useMyLocation =
      Bi('Use my location', 'Sebenzisa indawo yami', key: 'btn_gps');
  static const Bi enterManually =
      Bi('Enter coordinates manually', 'Faka izixhumanisi ngesandla', key: 'coords_title');
  static const Bi pickFromCentres =
      Bi('Pick from centres', 'Khetha esikhungweni');
  static const Bi returnToGps =
      Bi('Return to live GPS', 'Buyela ku-GPS ebukhoma');
  static const Bi latitude = Bi('Latitude', 'I-latitude');
  static const Bi longitude = Bi('Longitude', 'I-longitude');
  static const Bi accuracy = Bi('Accuracy', 'Ukunemba');
  static const Bi altitude = Bi('Altitude', 'Ukuphakama');
  static const Bi updated = Bi('Updated', 'Kubuyekezwe');
  static const Bi sourceGps = Bi('Live GPS', 'I-GPS ebukhoma');
  static const Bi sourceManual = Bi('Saved location', 'Indawo egciniwe');
  static const Bi currentPosition =
      Bi('Current position', 'Indawo yamanje');
  static const Bi manualInUse = Bi(
    'A saved location is being used for all bearings and distances.',
    'Indawo egciniwe isetshenziselwa zonke iziqondiso namabanga.',
  );
  static const Bi openSettings = Bi('Open settings', 'Vula izilungiselelo');
  static const Bi locationServicesOff = Bi(
    'Location services are switched off. Turn them on to use the compass.',
    'Izinsiza zendawo zivaliwe. Zivule ukuze usebenzise ikhompasi.',
  );
  static const Bi permissionNeeded = Bi(
    'Location permission is needed to work out the direction of Ekuphumuleni.',
    'Imvume yendawo iyadingeka ukuthola isiqondiso sase-Ekuphumuleni.',
  );
  static const Bi permissionDenied = Bi(
    'Location permission was denied. You can still enter your coordinates by '
        'hand, or allow access in Settings.',
    'Imvume yendawo yenqatshiwe. Usengafaka izixhumanisi ngesandla, noma '
        'uvumele ukufinyelela kuzilungiselelo.',
  );
  static const Bi permissionDeniedForever = Bi(
    'Location permission is permanently denied. Open Settings to allow it, or '
        'enter your coordinates by hand.',
    'Imvume yendawo yenqatshiwe unomphela. Vula izilungiselelo ukuze uyivumele, '
        'noma ufake izixhumanisi ngesandla.',
  );
  static const Bi invalidLatitude =
      Bi('Enter a latitude between -90 and 90', 'Faka i-latitude phakathi -90 no-90');
  static const Bi invalidLongitude = Bi(
      'Enter a longitude between -180 and 180',
      'Faka i-longitude phakathi -180 no-180');
  static const Bi saved = Bi('Location saved', 'Indawo igciniwe');
  static const Bi save = Bi('Save', 'Gcina');
  static const Bi cancel = Bi('Cancel', 'Khansela');
  static const Bi locate = Bi('Locating…', 'Kuthungathwa…');

  // ----------------------------------------------------------------- centres

  static const Bi searchCentre =
      Bi('Search a centre or town', 'Sesha isikhungo', key: 'search_ph');
  static const Bi nearest = Bi('Nearest', 'Eseduze', key: 'btn_near');
  static const Bi allCentres =
      Bi('All centres, grouped by region', 'Zonke izikhungo ngezifunda', key: 'c_status_all');
  static const Bi mapCaption = Bi(
    'Pins mark the suburb or town of each centre; tap a pin, then Directions, '
        'to be guided to the exact address. The gold pin is Ekuphumuleni.',
    'Isikhonkwane sikhomba indawo yesikhungo; cindezela "Directions" ukuze '
        'uyiswe ekhelini eliqondile. Isikhonkwane segolide yi-Ekuphumuleni.', key: 'map_note');
  static const Bi mapButton = Bi('Map', 'Imephu');
  static const Bi callButton = Bi('Call', 'Shayela');
  static const Bi directionsButton = Bi('Directions', 'Izikhombisi-ndlela');
  static const Bi noResults =
      Bi('No centre matches your search', 'Asikho isikhungo esitholakalayo', key: 'no_match');
  static const Bi noPhone =
      Bi('No phone number on file', 'Ayikho inombolo yocingo');
  static const Bi noAddress =
      Bi('Address to be added', 'Ikheli lizokwengezwa');
  static const Bi offlineMap = Bi(
    'The map needs an internet connection. The list of centres below still '
        'works offline.',
    'Imephu idinga uxhumano lwe-inthanethi. Uhlu lwezikhungo olungezansi '
        'lusasebenza ngaphandle kwe-inthanethi.',
  );
  static const Bi retry = Bi('Retry', 'Zama futhi', key: 'retry');
  static const Bi zoomIn = Bi('Zoom in', 'Sondeza');
  static const Bi zoomOut = Bi('Zoom out', 'Hlehlisa');
  static const Bi nearestFound =
      Bi('Nearest centre', 'Isikhungo esiseduze', key: 'nearest_you');
  static const Bi loadingCentres =
      Bi('Loading centres…', 'Kulayishwa izikhungo…', key: 'c_loading');
  static const Bi centresFailed = Bi(
    'The centres file could not be read.',
    'Ifayela lezikhungo alikwazanga ukufundwa.',
  );
  static const Bi attribution = Bi(
    'Map data © OpenStreetMap contributors',
    'Idatha yemephu © abanikeli be-OpenStreetMap',
  );

  // ------------------------------------------------------------------- guide

  static const Bi coordinates = Bi('Coordinates', 'Izixhumanisi');
  static const Bi dmsLabel = Bi('DMS', 'DMS');
  static const Bi decimalLabel = Bi('Decimal', 'Amadesimali');
  static const Bi howToUse = Bi('How to use it', 'Indlela yokuyisebenzisa', key: 'guide_how');
  static const Bi accuracyHeading = Bi('Accuracy', 'Ukunemba', key: 'guide_acc');
  static const Bi aboutHeading = Bi('About this app', 'Mayelana nalolu hlelo');
  static const Bi purposeHeading = Bi('Purpose', 'Inhloso');

  static const Bi purposeBody = Bi(
    'TSHK Compass is for Abantwana Bobukhosi Bukamoya (amasosha), the spiritual '
        'nation of The Revelation Spiritual Home and The Spiritual Home Kingdom '
        'under HSRM Imboni Dr uZwi-Lezwe Radebe.',
    'I-TSHK Compass ingeyabantwana boBukhosi bukaMoya (amasosha), isizwe '
        'sikamoya se-The Revelation Spiritual Home ne-The Spiritual Home '
        'Kingdom ngaphansi kuka-HSRM Imboni Dr uZwi-Lezwe Radebe.',
  );

  static const Bi purposeBody2 = Bi(
    'Wherever you are in the world, it shows the direction of Ekuphumuleni, the '
        'spiritual capital, so that prayer can face it and a msamo (umsamo) can '
        'be positioned toward it.',
    'Noma ngabe ukuphi emhlabeni, ikhombisa isiqondiso sase-Ekuphumuleni, '
        'inhlokodolobha yomoya, ukuze umkhuleko ubheke ngakhona futhi umsamo '
        'ubekwe ubheke ngakhona.',
  );

  static const Bi step1 = Bi(
    'Tap Start compass and allow location and motion access.',
    'Cindezela "Qala ikhompasi" bese uvumela i-GPS nezinzwa zefoni.', key: 'guide_s1');
  static const Bi step2 = Bi(
    'Hold the phone flat and turn until the arrow reaches the marker at the '
        'top.',
    'Bamba ifoni ithe bha, uphenduke kuze kufike umcibisholo ophawini '
        'oluphezulu.', key: 'guide_s2');
  static const Bi step3 = Bi(
    'For a msamo, open the Msamo tab and follow the turn instruction.',
    'Ngomsamo, vula ithebhu ethi Msamo ulandele isiqondiso.', key: 'guide_s3');

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
        'entshonalanga yenykatho yangempela — cishe u-20° eGoli kanye no-27° '
        'eThekwini — futhi iyashintsha kancane unyaka nonyaka. I-TSHK Compass '
        'iyakulungisa lokhu nge-World Magnetic Model (WMM 2025), isebenzisa '
        'indawo yakho, ukuphakama nosuku, ngakho isiqondiso esibonisiwe '
        'siyiqiniso. Uma umcibisholo unganembile, zungezisa ifoni njengo-8 '
        'ukuyilinganisa, futhi uyigcine kude nensimbi, ozibuthe nezipikha. '
        'Iziqondiso ziyiziqondiso ezinkulu (great-circle) futhi amabanga '
        'avezwa ngamakhilomitha.',
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
  );

  // ---------------------------------------------------------- shared widgets

  static const Bi close = Bi('Close', 'Vala', key: 'close');
  static const Bi ekuphumuleni = Bi('Ekuphumuleni', 'Ekuphumuleni');
  static const Bi spiritualCapital =
      Bi('Spiritual capital', 'Inhlokodolobha yomoya');

  /// "412 km" — the unit itself is the same in both languages.
  static const String unitKm = 'km';
  static const String unitM = 'm';

  // ------------------------------------------------------- compass engine

  /// Status chip: which rung of the ladder is driving the dial.
  static const Bi srcFused = Bi('Compass sensor', 'Inzwa yekhompasi');
  static const Bi srcRaw = Bi('Raw sensors', 'Izinzwa eziluhlaza');
  static const Bi srcRelative =
      Bi('Turn sensor + calibration', 'Inzwa yokuphenduka + ukulungiswa');
  static const Bi srcGps = Bi('GPS (walking)', 'I-GPS (uhamba)');
  static const Bi srcSun = Bi('Sun guidance', 'Isiqondiso selanga');

  static const Bi compassOnShort = Bi('Compass: on', 'Ikhompasi: iyasebenza');
  static const Bi compassWaiting =
      Bi('Compass: waiting for sensor…', 'Ikhompasi: ilinde inzwa');
  static const Bi compassNeedsCal =
      Bi('Compass: needs calibration', 'Ikhompasi: idinga ukulungiswa');
  static const Bi compassNone =
      Bi('Compass: not available', 'Ikhompasi: ayitholakali');
  static const Bi compassDenied =
      Bi('Compass: permission refused', 'Ikhompasi: ayivunyelwanga');
  static const Bi compassPaused = Bi(
    'Move the phone to wake the compass',
    'Nyakazisa ifoni',
    key: 'cmp_paused',
  );
  static const Bi walkForDirection = Bi(
    'Walk a few steps to get direction',
    'Hamba izinyathelo ezimbalwa',
  );
  static const Bi stopCompass = Bi('Stop compass', 'Misa ikhompasi');
  static const Bi retryCompass = Bi('Retry sensors', 'Zama izinzwa futhi', key: 'retry');

  // One-tap calibration.
  static const Bi calibrationTitle =
      Bi('Set the direction once', 'Beka isiqondiso kanye');
  static const Bi calibrationBody = Bi(
    'This phone can feel how far it turns but not where north is. Point the '
        'top of the phone at the sun and tap Set, or point it at north with a '
        'hand compass and tap Set.',
    'Le foni izwa ukuthi iphenduke kangakanani kodwa ayazi ukuthi inyakatho '
        'ikuphi. Khomba ilanga ngengxenye engenhla yefoni ucindezele u-Set, '
        'noma ukhombe enyakatho ngekhompasi yesandla ucindezele u-Set.',
    key: 'sunwhy_rel',
  );
  static const Bi setToSun =
      Bi('Set: phone points at the sun', 'Beka: ifoni ibheke ilanga', key: 'btn_suncal');
  static const Bi setToNorth = Bi(
    'Set: phone points north (hand compass)',
    'Beka: ifoni ibheke enyakatho',
    key: 'btn_northcal',
  );
  static const Bi calibratedToSun =
      Bi('Calibrated to the sun', 'Kulungiswe ngelanga');
  static const Bi calibratedToNorth =
      Bi('Calibrated to magnetic north', 'Kulungiswe ngenyakatho kazibuthe');
  static const Bi recalibrate = Bi('Set again', 'Beka futhi');
  static const Bi sunBelowHorizonShort =
      Bi('Sun below the horizon', 'Ilanga selishonile', key: 'sun_night');

  // Sun-only guidance.
  static const Bi sunGuidanceTitle = Bi('Use the sun', 'Sebenzisa ilanga', key: 'sun_title');
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
      args: <String, String>{'n': '$deg', 'dir': dir.secondary},
    );
  }

  /// "Turn until the sun is on your left."
  static Bi sunOnSide({required bool onRight}) {
    final Bi dir = onRight ? right : left;
    return Bi(
      'Turn until the sun is on your ${dir.en}.',
      'Phenduka kuze kuthi ilanga libe ${dir.zu}.',
    );
  }

  /// "A stick's shadow points to 312° (NW). Stand facing along the shadow,
  /// then turn 40° to the right."
  static Bi stickShadowGuide(String shadowBearing, int deg,
      {required bool toRight}) {
    final Bi dir = toRight ? right : left;
    return Bi(
      "A stick's shadow points to $shadowBearing. Stand facing along the "
          'shadow, then turn $deg° to the ${dir.en}.',
      'Isithunzi sentonga sikhomba ku-$shadowBearing. Yima ubheke '
          'ngasesithunzini, bese uphendukela ${dir.zu} ngo-$deg°.',
    );
  }

  static const Bi sunNightLong = Bi(
    'The sun is below the horizon now. Use a hand compass with the magnetic '
        'bearing, or try again in daylight.',
    'Ilanga selishonile. Sebenzisa ikhompasi yesandla nokubheka kazibuthe, '
        'noma uzame futhi emini.',
    key: 'sun_night',
  );

  /// "Use a hand compass: 312° magnetic".
  static Bi handCompass(int magneticDeg) => Bi(
        'Use a hand compass: $magneticDeg° magnetic',
        'Sebenzisa ikhompasi yesandla: $magneticDeg° magnetic',
        key: 'hand_compass',
        args: <String, String>{'n': '$magneticDeg'},
      );

  // Level bubble.
  static const Bi flat = Bi('Flat', 'Ithe bha', key: 'flat');
  static const Bi tilted = Bi('Tilted', 'Itshekile', key: 'tilted');
  static const Bi keepFlat =
      Bi('Keep the phone flat', 'Gcina ifoni ithe bha', key: 'level_s');

  // Permissions (motion sensors).
  static const Bi motionDenied = Bi(
    'Motion access was refused. Allow Motion & Fitness in Settings so the '
        'compass can follow the phone; the bearings below still work.',
    'Imvume yokunyakaza yenqatshiwe. Vumela i-Motion & Fitness '
        'kuzilungiselelo; izinombolo ezingezansi zisasebenza.',
  );

  // ---------------------------------------------------------------- towns

  static const Bi pickTown = Bi('Pick a town', 'Khetha idolobha', key: 'town_title');
  static const Bi useThisTown =
      Bi('Use this town', 'Sebenzisa leli dolobha', key: 'btn_town');
  static const Bi searchTown = Bi('Search a town', 'Sesha idolobha');
  static const Bi manualNote = Bi(
    'Use this when GPS is unavailable — for example indoors or when the phone '
        'has no signal.',
    'Sebenzisa lokhu uma i-GPS ingatholakali — isibonelo ngaphakathi endlini '
        'noma uma ifoni ingenalo isignali.',
  );
  static const Bi noTownMatch = Bi('No town matches', 'Alikho idolobha elitholakele', key: 'no_match');
  static const Bi townNote = Bi(
    'Town centre coordinates: accurate to a few kilometres, which changes the '
        'bearing by well under a degree.',
    'Izixhumanisi zenkaba yedolobha: zinemba kumakhilomitha ambalwa, okushintsha '
        'ukubheka ngaphansi kwedigri eyodwa.',
  );

  // ------------------------------------------------------------ settings

  static const Bi settingsHeading = Bi('Settings', 'Izilungiselelo');
  static const Bi secondaryLanguage =
      Bi('Second language', 'Ulimi lwesibili');
  static const Bi secondaryLanguageNote = Bi(
    'English always stays on top. Choose the language shown underneath.',
    'IsiNgisi sihlala phezulu. Khetha ulimi olubonisiwe ngezansi.',
  );
  static const Bi batterySaver = Bi('Battery saver · Simple mode', 'Ukonga ibhethri · Imodi elula');
  static const Bi batterySaverNote = Bi(
    'Fewer animations, no shadows, a lighter map. Switched on automatically '
        'on phones with little memory.',
    'Ukunyakaza okuncane, azikho izithunzi, imephu elula. Kuvulwa ngokuzenzakalela '
        'kumafoni anememori encane.',
  );
  static const Bi simpleModeAuto = Bi('On (this phone)', 'Kuvuliwe (le foni)');
  static const Bi on = Bi('On', 'Kuvuliwe');
  static const Bi off = Bi('Off', 'Kuvaliwe');

  // ---------------------------------------------------------- membership

  static const Bi account = Bi('Account', 'I-akhawunti', key: 'account');
  static const Bi authTitle = Bi('Sign in to continue', 'Ngena ukuze uqhubeke', key: 'auth_title');
  static const Bi authEmail = Bi('Your e-mail address', 'Ikheli lakho le-imeyili', key: 'auth_email');
  static const Bi authSend = Bi('Send code', 'Thumela ikhodi', key: 'auth_send');
  static const Bi authCheck = Bi('Check your e-mail', 'Bheka i-imeyili yakho', key: 'auth_check');
  static Bi authCode(String email) => Bi(
        'Enter the code sent to $email',
        'Faka ikhodi ethunyelwe ku-$email',
        key: 'auth_code',
        args: <String, String>{'e': email},
      );
  static const Bi authCodeLabel = Bi('6-digit code', 'Ikhodi yezinombolo ezi-6', key: 'auth_code_l');
  static const Bi authVerify = Bi('Sign in', 'Ngena', key: 'auth_verify');
  static const Bi authChange = Bi('Use another e-mail', 'Sebenzisa enye i-imeyili', key: 'auth_change');
  static const Bi authBadEmail = Bi('Please enter a valid e-mail address.', 'Sicela ufake ikheli le-imeyili elifanele.', key: 'auth_bad_email');
  static const Bi authSendFail = Bi('The code could not be sent. Please try again.', 'Asikwazanga ukuthumela ikhodi. Sicela uzame futhi.', key: 'auth_send_fail');
  static const Bi authBadCode = Bi('Enter the code from the e-mail.', 'Faka ikhodi esuka ku-imeyili.', key: 'auth_bad_code');
  static const Bi authWrongCode = Bi('That code did not work. Check it or request a new one.', 'Leyo khodi ayisebenzanga. Yihlole noma ucele entsha.', key: 'auth_wrong_code');
  static const Bi signOut = Bi('Sign out', 'Phuma', key: 'pay_signout');

  static const Bi payChecking = Bi('Checking your membership…', 'Sihlola ubulungu bakho…', key: 'pay_checking');
  static const Bi payConfirming = Bi('Confirming your payment…', 'Siqinisekisa inkokhelo yakho…', key: 'pay_confirming');
  static const Bi payWait = Bi('This usually takes a few seconds.', 'Lokhu kuvame ukuthatha imizuzwana embalwa.', key: 'pay_wait');
  static const Bi payOffline = Bi('Connect to the internet to check your membership', 'Xhuma ku-inthanethi ukuze sihlole ubulungu bakho', key: 'pay_offline');
  static const Bi payPastDue = Bi("We have not received this month's payment yet", 'Asikakutholi ukukhokha kwale nyanga', key: 'pay_pastdue');
  static const Bi payExpired = Bi('Your membership has ended', 'Ubulungu bakho buphelile', key: 'pay_expired');
  static const Bi trialEnded = Bi('Your free trial has ended', 'Isikhathi sakho sokuzama mahhala siphelile', key: 'trial_ended');
  static const Bi payStore = Bi('A membership is required. Please sign in with a member account.', 'Kudingeka ubulungu. Sicela ungene nge-akhawunti yelungu.', key: 'pay_store');
  static Bi payOffer(String price) => Bi(
        'Continue with a monthly membership of $price. Cancel any time.',
        'Qhubeka ngobulungu banyanga zonke obungu-$price. Ungakhansela noma nini.',
        key: 'pay_offer',
        args: <String, String>{'p': price},
      );
  static Bi trialOffer(int days, String price) => Bi(
        'Free for $days days, then $price per month.',
        'Mahhala izinsuku ezingu-$days, bese kuba ngu-$price ngenyanga.',
        key: 'trial_offer',
        args: <String, String>{'n': '$days', 'p': price},
      );
  static Bi payButton(String price) => Bi(
        'Subscribe · $price per month',
        'Bhalisa · $price ngenyanga',
        key: 'pay_btn',
        args: <String, String>{'p': price},
      );
  static const Bi payCancel = Bi('Cancel subscription', 'Khansela ukubhalisa', key: 'pay_cancel');
  static const Bi payCancelConfirm = Bi('Tap again to confirm the cancellation', 'Cindezela futhi ukuze uqinisekise ukukhansela', key: 'pay_cancel_confirm');
  static const Bi payCancelDone = Bi('Your subscription has been cancelled. No further payments will be taken.', 'Ukubhalisa kwakho kukhanseliwe. Ayikho enye inkokhelo ezothathwa.', key: 'pay_cancel_done');
  static const Bi payCancelFail = Bi('We could not cancel right now. Please try again later.', 'Asikwazanga ukukhansela manje. Sicela uzame emuva kwesikhathi.', key: 'pay_cancel_fail');
  static const Bi payOpenFail = Bi('PayFast could not be opened. Please try again.', 'Asikwazanga ukuvula i-PayFast. Sicela uzame futhi.', key: 'pay_open_fail');
  static const Bi paySlow = Bi('Your payment is still being confirmed. If PayFast showed success, wait a minute and tap Retry.', 'Inkokhelo yakho isaqinisekiswa. Uma i-PayFast ibonise impumelelo, linda umzuzu bese ucindezela u-Zama futhi.', key: 'pay_slow');
  static const Bi payCancelledNote = Bi('The payment was cancelled. You can try again.', 'Inkokhelo ikhanseliwe. Ungazama futhi.', key: 'pay_cancelled_note');
  static const Bi payActive = Bi('Membership active, renews monthly', 'Ubulungu busebenza, buvuselelwa njalo ngenyanga', key: 'pay_active');
  static Bi payCancelledUntil(String date) => Bi(
        'Cancelled. Access until $date',
        'Kukhanseliwe. Ungasebenzisa kuze kube ngu-$date',
        key: 'pay_cancelled_until',
        args: <String, String>{'d': date},
      );
  static const Bi payNone = Bi('No active membership', 'Abukho ubulungu obusebenzayo', key: 'pay_none');
  static Bi trialLeft(int days) => Bi(
        'Free trial: $days days left',
        'Isikhathi sokuzama mahhala: kusele izinsuku ezingu-$days',
        key: 'trial_left',
        args: <String, String>{'n': '$days'},
      );
  static const Bi membershipTitle = Bi('Membership', 'Ubulungu');
  static const Bi membershipCachedNote = Bi(
    'Showing the last confirmed status (offline).',
    'Kuboniswa isimo sokugcina esiqinisekisiwe (ngaphandle kwe-inthanethi).',
  );
}
