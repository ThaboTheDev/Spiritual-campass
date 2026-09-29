/// Single source of truth for every user visible string in TSHK Compass.
///
/// The app is bilingual by design: every label shows English as the main text
/// and isiZulu as a smaller secondary line underneath it, so there is no
/// language switch. Every string therefore lives here as a [Bi] value
/// (English + isiZulu) or as a plain `String` when both languages are the same
/// (e.g. "WMM 2025").
///
/// isiZulu spellings should be confirmed by a fluent speaker before release;
/// they are kept in one file so that a single review pass covers them all.
library;

/// A bilingual (English + isiZulu) string value.
class Bi {
  const Bi(this.en, this.zu);

  /// English (primary) text.
  final String en;

  /// isiZulu (secondary) text.
  final String zu;

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

  static const Bi tabCompass = Bi('Compass', 'Ikhompasi');
  static const Bi tabMsamo = Bi('Msamo', 'Umsamo');
  static const Bi tabLocation = Bi('Location', 'Indawo');
  static const Bi tabCentres = Bi('Centres', 'Izikhungo');
  static const Bi tabGuide = Bi('Guide', 'Umhlahlandlela');

  // ----------------------------------------------------------------- compass

  static const Bi startCompass = Bi('Start compass', 'Qala ikhompasi');
  static const Bi startToBegin =
      Bi('Start the compass to begin', 'Qala ikhompasi ukuze uqale');
  static const Bi locationNotSet = Bi('Location: not set', 'Indawo: ayikabekwa');
  static const Bi compassOff = Bi('Compass: off', 'Ikhompasi: ivaliwe');
  static const Bi compassOn = Bi('Compass: on', 'Ikhompasi: ivuliwe');

  static const Bi compassHelp = Bi(
    'The arrow points to Ekuphumuleni. When it sits under the marker at the '
        'top, you are facing the spiritual capital. Hold the phone flat and '
        'away from metal.',
    'Umcibisholo ukhomba e-Ekuphumuleni. Uma ungaphansi kophawu oluphezulu, '
        'ubheke enhlokodolobha yomoya. Bamba ifoni ithe bha, kude nensimbi.',
  );

  // Readout labels.
  static const Bi sunHeight =
      Bi('Sun height · above horizon', 'Ukuphakama kwelanga · ngaphezu komkhathizwe');
  static const Bi facingSun = Bi('Facing the sun', 'Ubheke ilanga');
  static const Bi stickShadow =
      Bi("Using a stick's shadow", 'Ukusebenzisa isithunzi sentonga');
  static const Bi bearingTrue = Bi('Bearing (true)', 'Ukubheka');
  static const Bi distance = Bi('Distance', 'Ibanga');
  static const Bi magneticBearing =
      Bi('Magnetic bearing · hand compass', 'Ukubheka kazibuthe · ikhompasi yesandla');
  static const Bi declination = Bi('Declination · WMM 2025', 'Ukuchezuka · WMM 2025');
  static const Bi yourLocation = Bi('Your location', 'Indawo yakho');

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
          'Linganisa: zungezisa ifoni njengo-8');
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
      Bi('Waiting for a heading…', 'Kulinde isiqondiso…');
  static const Bi aligned =
      Bi('Facing Ekuphumuleni', 'Ubheke e-Ekuphumuleni');
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
          'Umsamo wakho ubheke e-Ekuphumuleni');
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

  /// "Turn 32° to your right" — English, parameterised by degrees.
  static String turnRightEn(int deg) => 'Turn $deg° to your right';

  /// "Phendukela ngakwesokudla ngo-32°" — isiZulu, parameterised by degrees.
  static String turnRightZu(int deg) => 'Phendukela ngakwesokudla ngo-$deg°';

  /// "Turn 32° to your left".
  static String turnLeftEn(int deg) => 'Turn $deg° to your left';

  /// "Phendukela ngakwesokunxele ngo-32°".
  static String turnLeftZu(int deg) => 'Phendukela ngakwesokunxele ngo-$deg°';

  /// "Turn around 175°".
  static String turnAroundEn(int deg) => 'Turn around $deg°';
  static String turnAroundZu(int deg) => 'Phenduka ngo-$deg°';

  // ---------------------------------------------------------------- location

  static const Bi useMyLocation =
      Bi('Use my location', 'Sebenzisa indawo yami');
  static const Bi enterManually =
      Bi('Enter coordinates manually', 'Faka izixhumanisi ngesandla');
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
      Bi('Search a centre or town', 'Sesha isikhungo');
  static const Bi nearest = Bi('Nearest', 'Eseduze');
  static const Bi allCentres =
      Bi('All centres, grouped by region', 'Zonke izikhungo ngezifunda');
  static const Bi mapCaption = Bi(
    'Pins mark the suburb or town of each centre; tap a pin, then Directions, '
        'to be guided to the exact address. The gold pin is Ekuphumuleni.',
    'Isikhonkwane sikhomba indawo yesikhungo; cindezela "Directions" ukuze '
        'uyiswe ekhelini eliqondile. Isikhonkwane segolide yi-Ekuphumuleni.',
  );
  static const Bi mapButton = Bi('Map', 'Imephu');
  static const Bi callButton = Bi('Call', 'Shayela');
  static const Bi directionsButton = Bi('Directions', 'Izikhombisi-ndlela');
  static const Bi noResults =
      Bi('No centre matches your search', 'Asikho isikhungo esitholakalayo');
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
  static const Bi retry = Bi('Retry', 'Zama futhi');
  static const Bi zoomIn = Bi('Zoom in', 'Sondeza');
  static const Bi zoomOut = Bi('Zoom out', 'Hlehlisa');
  static const Bi nearestFound =
      Bi('Nearest centre', 'Isikhungo esiseduze');
  static const Bi loadingCentres =
      Bi('Loading centres…', 'Kulayishwa izikhungo…');
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
  static const Bi howToUse = Bi('How to use it', 'Indlela yokuyisebenzisa');
  static const Bi accuracyHeading = Bi('Accuracy', 'Ukunemba');
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
    'Cindezela "Qala ikhompasi" bese uvumela i-GPS nezinzwa zefoni.',
  );
  static const Bi step2 = Bi(
    'Hold the phone flat and turn until the arrow reaches the marker at the '
        'top.',
    'Bamba ifoni ithe bha, uphenduke kuze kufike umcibisholo ophawini '
        'oluphezulu.',
  );
  static const Bi step3 = Bi(
    'For a msamo, open the Msamo tab and follow the turn instruction.',
    'Ngomsamo, vula ithebhu ethi Msamo ulandele isiqondiso.',
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

  static const Bi close = Bi('Close', 'Vala');
  static const Bi ekuphumuleni = Bi('Ekuphumuleni', 'Ekuphumuleni');
  static const Bi spiritualCapital =
      Bi('Spiritual capital', 'Inhlokodolobha yomoya');

  /// "412 km" — the unit itself is the same in both languages.
  static const String unitKm = 'km';
  static const String unitM = 'm';
}
