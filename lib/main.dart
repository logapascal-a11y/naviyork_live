import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<ThemeMode> appThemeNotifier = ValueNotifier(ThemeMode.system);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (context, currentThemeMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'NaviYork',
          themeMode: currentThemeMode,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF2F2F7),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C1C1E),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF000000),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent),
            drawerTheme: const DrawerThemeData(backgroundColor: Colors.transparent, elevation: 0),
          ),
          home: const MapScreen(),
        );
      },
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final MapController _mapController = MapController();
  final LatLng _nycCenter = const LatLng(40.7500, -73.9850);

  bool _showSubwayLines = false;
  bool _showCitiBikes = false;
  bool _showFavoritesLayer = false;
  bool _isSurvivalModeActive = false;
  bool _is3DMode = false;
  bool _isTracking = false;
  bool _showToursList = false;

  bool _isMetric = true;
  String _currentLanguage = 'DE'; 
  int? _currentTempC;
  double _usdToEurRate = 0.92; 
  
  double _dailyBudget = 100.0;
  double _spentToday = 0.0;
  int _omnyRides = 0;
  LatLng? _hotelLocation;

  double _currentZoom = 13.5;
  double _currentRotation = 0.0;

  List<Polyline> _subwayPolylines = [];
  List<Marker> _stationMarkers = [];
  List<Marker> _citiBikeMarkers = [];
  List<Map<String, dynamic>> _allAttractions = [];
  List<Marker> _attractionMarkers = [];
  Map<String, bool> _categoryVisibility = {};
  Set<String> _favorites = {};

  final List<Map<String, dynamic>> _allTours = [
    {
      "id": "classic_manhattan", "title": "The Manhattan Classic", "subtitle": "Wolkenkratzer & Lichter", "duration": "3 Std.", "distance": "4.2 km", "imageBytes": null,
      "points": [
        {"name": "Grand Central Terminal", "lat": 40.7527, "lng": -73.9772, "description": "Starte in der Haupthalle mit der berühmten Sternendecke."},
        {"name": "Chrysler Building", "lat": 40.7516, "lng": -73.9753, "description": "Ein kurzer Blick auf das wohl schönste Art-Déco-Gebäude der Stadt."},
        {"name": "Bryant Park", "lat": 40.7536, "lng": -73.9832, "description": "Hol dir einen Kaffee und genieße diese grüne Oase."},
        {"name": "Times Square", "lat": 40.7580, "lng": -73.9855, "description": "Das leuchtende Herz der Stadt."},
        {"name": "Rockefeller Center", "lat": 40.7587, "lng": -73.9787, "description": "Das Ende der Tour an der berühmten Plaza."}
      ]
    },
    {
      "id": "downtown_brooklyn", "title": "Brooklyn Bridge", "subtitle": "Die beste Skyline", "duration": "2 Std.", "distance": "3.5 km", "imageBytes": null,
      "points": [
        {"name": "City Hall Park", "lat": 40.7128, "lng": -74.0060, "description": "Startpunkt direkt vor dem Eingang zur Brücke."},
        {"name": "Brooklyn Bridge", "lat": 40.7061, "lng": -73.9969, "description": "Ein unglaublicher Spaziergang über das Wahrzeichen."},
        {"name": "Washington St DUMBO", "lat": 40.7032, "lng": -73.9896, "description": "Das berühmte Foto-Motiv mit der Manhattan Bridge im Hintergrund."}
      ]
    },
    {
      "id": "central_park", "title": "Central Park", "subtitle": "Die grüne Lunge", "duration": "4 Std.", "distance": "5.0 km", "imageBytes": null,
      "points": [
        {"name": "The Plaza Hotel", "lat": 40.7644, "lng": -73.9745, "description": "Das ikonische Hotel am südlichen Rand des Parks."},
        {"name": "Bethesda Terrace", "lat": 40.7738, "lng": -73.9708, "description": "Der berühmte Brunnen mit Engel - bekannt aus hunderten Filmen."},
        {"name": "The Metropolitan Museum of Art", "lat": 40.7794, "lng": -73.9632, "description": "Das Ziel unserer Tour an den Treppen des Museum of Art."}
      ]
    },
    {
      "id": "financial_district", "title": "Wall Street & WTC", "subtitle": "Geld & Geschichte", "duration": "2.5 Std.", "distance": "2.8 km", "imageBytes": null,
      "points": [
        {"name": "Charging Bull", "lat": 40.7056, "lng": -74.0134, "description": "Der berühmte Bulle der Wall Street."},
        {"name": "New York Stock Exchange", "lat": 40.7069, "lng": -74.0113, "description": "Das Zentrum der globalen Finanzwelt."},
        {"name": "Trinity Church", "lat": 40.7081, "lng": -74.0122, "description": "Eine historische Kirche mitten zwischen den Wolkenkratzern."},
        {"name": "9/11 Memorial", "lat": 40.7115, "lng": -74.0124, "description": "Die eindrucksvollen Wasserbecken am Ground Zero."},
        {"name": "One World Trade Center", "lat": 40.7130, "lng": -74.0131, "description": "Das höchste Gebäude der USA."}
      ]
    }
  ];
  Map<String, dynamic>? _selectedTour;

  StreamSubscription<Position>? _positionStream;
  LatLng? _currentLocation;
  bool _isSearchActive = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String? _selectedAttractionName;

  late AnimationController _radarController;
  late Animation<double> _radarAnimation;
  late AnimationController _tiltController;
  late Animation<double> _tiltAnimation;
  AnimationController? _mapAnimController;
  OverlayEntry? _toastOverlay;
  late AnimationController _toastController;
  late Animation<double> _toastAnimation;
  Timer? _toastTimer;
  late AnimationController _searchBlurController;
  late Animation<double> _searchBlurAnimation;

  String _nycTimeString = '';
  String _nycDateString = '';
  String _nycWeatherCondition = 'Lädt...';
  String _nycWeatherString = '☀️ --';
  int _currentWeatherCode = 0;
  String? _currentWarningText;
  IconData? _currentWarningIcon;
  Color? _currentWarningColor;
  bool _userDismissedWarning = false;
  Timer? _clockTimer;
  
  DateTime? _sunsetTime;
  String _goldenHourText = '';

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _radarAnimation = CurvedAnimation(parent: _radarController, curve: Curves.easeOut);
    _tiltController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _tiltAnimation = CurvedAnimation(parent: _tiltController, curve: Curves.easeInOutBack);
    _toastController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _toastAnimation = CurvedAnimation(parent: _toastController, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
    _searchBlurController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _searchBlurAnimation = CurvedAnimation(parent: _searchBlurController, curve: Curves.easeInOut);

    _updateNYCTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateNYCTime());

    _loadSettingsAndFavorites();
    _fetchNYCWeather();
    _fetchExchangeRate();
    _loadSubwayData();
    _loadCitiBikes();

    _loadAttractions().then((_) {
      _loadSurvivalData();
      _loadTours();
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _radarController.dispose();
    _tiltController.dispose();
    _mapAnimController?.dispose();
    _toastController.dispose();
    _searchBlurController.dispose();
    _toastTimer?.cancel();
    _clockTimer?.cancel();
    if (_toastOverlay != null) {
      _toastOverlay!.remove();
    }
    super.dispose();
  }

  String t(String key) {
    const texts = {
      'menu': {'DE': 'Menü', 'EN': 'Menu', 'ES': 'Menú'},
      'my_places': {'DE': 'MEINE ORTE', 'EN': 'MY PLACES', 'ES': 'MIS LUGARES'},
      'favorites': {'DE': 'Favoriten', 'EN': 'Favorites', 'ES': 'Favoritos'},
      'my_hotel': {'DE': 'Mein Hotel', 'EN': 'My Hotel', 'ES': 'Mi Hotel'},
      'no_favs': {'DE': 'Noch keine Favoriten.', 'EN': 'No favorites yet.', 'ES': 'No hay favoritos aún.'},
      'directory': {'DE': 'VERZEICHNIS', 'EN': 'DIRECTORY', 'ES': 'DIRECTORIO'},
      'all_cats': {'DE': 'Alle Kategorien', 'EN': 'All Categories', 'ES': 'Todas las categorías'},
      'tools': {'DE': 'SMART TOOLS', 'EN': 'SMART TOOLS', 'ES': 'HERRAMIENTAS'},
      'calc_travel': {'DE': 'Reise-Rechner', 'EN': 'Travel Calculators', 'ES': 'Calculadoras'},
      'currency': {'DE': 'Währungsrechner', 'EN': 'Currency Calc', 'ES': 'Divisas'},
      'tip': {'DE': 'Trinkgeld-Splitter', 'EN': 'Tip Splitter', 'ES': 'Propinas'},
      'budget': {'DE': 'Tages-Budget', 'EN': 'Daily Budget', 'ES': 'Presupuesto diario'},
      'omny': {'DE': 'OMNY Fahrten-Tracker', 'EN': 'OMNY Ride Tracker', 'ES': 'Tracker de OMNY'},
      'maps': {'DE': 'KARTEN & PLÄNE', 'EN': 'MAPS & PLANS', 'ES': 'MAPAS Y PLANOS'},
      'offline_maps': {'DE': 'Offline Karten', 'EN': 'Offline Maps', 'ES': 'Mapas Offline'},
      'subway': {'DE': 'Offizieller U-Bahn Plan', 'EN': 'Official Subway Map', 'ES': 'Mapa del Metro'},
      'guide': {'DE': 'NYC SURVIVAL GUIDE', 'EN': 'NYC SURVIVAL GUIDE', 'ES': 'GUÍA DE SUPERVIVENCIA'},
      'knowledge': {'DE': 'Wissen & Tipps', 'EN': 'Knowledge & Tips', 'ES': 'Conocimiento y Consejos'},
      'system': {'DE': 'SYSTEM', 'EN': 'SYSTEM', 'ES': 'SISTEMA'},
      'settings': {'DE': 'Einstellungen', 'EN': 'Settings', 'ES': 'Ajustes'},
      'dark_mode': {'DE': 'Dunkelmodus', 'EN': 'Dark Mode', 'ES': 'Modo oscuro'},
      'metric': {'DE': 'Metrisches System', 'EN': 'Metric System', 'ES': 'Sistema métrico'},
      'language': {'DE': 'Sprache', 'EN': 'Language', 'ES': 'Idioma'},
      'delete_favs': {'DE': 'Favoriten löschen', 'EN': 'Delete Favorites', 'ES': 'Borrar favoritos'},
      'search': {'DE': 'Suche nach Attraktionen...', 'EN': 'Search attractions...', 'ES': 'Buscar atracciones...'},
      'search_naviyork': {'DE': 'In NaviYork suchen', 'EN': 'Search in NaviYork', 'ES': 'Buscar en NaviYork'},
      'end_tour': {'DE': 'Tour beenden', 'EN': 'End Tour', 'ES': 'Terminar ruta'},
      'tours': {'DE': 'Entdecker-Touren', 'EN': 'Explorer Tours', 'ES': 'Rutas guiadas'},
      'close': {'DE': 'Schließen', 'EN': 'Close', 'ES': 'Cerrar'},
      'understood': {'DE': 'Verstanden', 'EN': 'Got it', 'ES': 'Entendido'},
      'calc_route': {'DE': 'Route berechnen', 'EN': 'Calculate Route', 'ES': 'Calcular ruta'},
      'tickets': {'DE': 'Tickets & Infos ansehen', 'EN': 'View Tickets & Info', 'ES': 'Ver entradas e info'},
      'golden_now': {'DE': 'Golden Hour ist JETZT!', 'EN': 'Golden Hour is NOW!', 'ES': '¡La Hora Dorada es AHORA!'},
      'golden_over': {'DE': 'Golden Hour vorbei', 'EN': 'Golden Hour over', 'ES': 'Hora Dorada terminó'},
      'golden_in': {'DE': 'Golden Hour in', 'EN': 'Golden Hour in', 'ES': 'Hora Dorada en'},
      'cancel': {'DE': 'Abbrechen', 'EN': 'Cancel', 'ES': 'Cancelar'},
      'delete': {'DE': 'Löschen', 'EN': 'Delete', 'ES': 'Eliminar'},
      'route_maps': {'DE': 'In Google Maps öffnen', 'EN': 'Open in Google Maps', 'ES': 'Abrir en Google Maps'},
      'hotel_set': {'DE': 'Hotel gespeichert!', 'EN': 'Hotel saved!', 'ES': '¡Hotel guardado!'},
      'hotel_removed': {'DE': 'Hotel entfernt', 'EN': 'Hotel removed', 'ES': 'Hotel eliminado'},
      'hotel_prompt': {'DE': 'Möchtest du diesen Ort als dein Hotel markieren?', 'EN': 'Set this location as your hotel?', 'ES': '¿Marcar este lugar como tu hotel?'},
      'save': {'DE': 'Speichern', 'EN': 'Save', 'ES': 'Guardar'},
    };
    return texts[key]?[_currentLanguage] ?? key;
  }

  Future<void> _loadSettingsAndFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favorites = (prefs.getStringList('naviyork_favorites') ?? []).toSet();
      _isMetric = prefs.getBool('naviyork_is_metric') ?? true;
      _currentLanguage = prefs.getString('naviyork_lang') ?? 'DE';
      _dailyBudget = prefs.getDouble('naviyork_budget') ?? 100.0;
      _spentToday = prefs.getDouble('naviyork_spent') ?? 0.0;
      _omnyRides = prefs.getInt('naviyork_omny') ?? 0;
      double? hLat = prefs.getDouble('naviyork_hotel_lat');
      double? hLng = prefs.getDouble('naviyork_hotel_lng');
      if (hLat != null && hLng != null) {
        _hotelLocation = LatLng(hLat, hLng);
      }
      _buildAttractionMarkers();
    });
  }

  Future<void> _toggleMetricSystem(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('naviyork_is_metric', value);
    setState(() {
      _isMetric = value;
      _updateWeatherDisplay();
    });
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Link blockiert: $url');
    }
  }

  Future<void> _routeTo(double lat, double lng) async {
    final Uri appleUrl = Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&dirflg=r');
    if (await canLaunchUrl(appleUrl)) {
      await launchUrl(appleUrl);
    } else {
      final googleUrl = Uri.parse('http://googleusercontent.com/maps.google.com/maps?daddr=$lat,$lng&dirflg=w');
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
    }
  }

  void _checkSmartWarnings(DateTime nycTime) {
    String? newWarning;
    IconData? newIcon;
    Color? newColor;
    bool isRain = (_currentWeatherCode >= 51 && _currentWeatherCode <= 67) || (_currentWeatherCode >= 95);

    if (isRain) {
      newWarning = "Regen in NYC: Perfekt für Museen & Indoor-Märkte!";
      newIcon = Icons.water_drop_outlined;
      newColor = Colors.blueAccent;
    } else if (nycTime.weekday <= 5 && ((nycTime.hour == 16 && nycTime.minute >= 30) || nycTime.hour == 17 || (nycTime.hour == 18 && nycTime.minute <= 30))) {
      newWarning = "Rush-Hour: U-Bahnen sind extrem voll. Tipp: CitiBikes!";
      newIcon = Icons.groups_outlined;
      newColor = Colors.orangeAccent;
    } else if (nycTime.hour >= 21 || nycTime.hour < 5) {
      newWarning = "Night Mode: Große Parks nach Einbruch der Dunkelheit meiden.";
      newIcon = Icons.dark_mode_outlined;
      newColor = Colors.indigoAccent;
    }

    if (_currentWarningText != newWarning) {
      setState(() {
        _currentWarningText = newWarning;
        _currentWarningIcon = newIcon;
        _currentWarningColor = newColor;
        _userDismissedWarning = false;
      });
    }
  }

  void _updateNYCTime() {
    DateTime now = DateTime.now().toUtc();
    bool isDST = (now.month > 3 && now.month < 11) || (now.month == 3 && now.day >= 10) || (now.month == 11 && now.day < 3);
    DateTime nycTime = now.subtract(Duration(hours: isDST ? 4 : 5));
    
    int h = nycTime.hour;
    int m = nycTime.minute;
    String minuteStr = m < 10 ? '0$m' : '$m';
    
    List<String> weekdays = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"];
    List<String> months = ["Jan.", "Feb.", "März", "April", "Mai", "Juni", "Juli", "Aug.", "Sept.", "Okt.", "Nov.", "Dez."];
    
    if (mounted) {
      setState(() {
        _nycTimeString = '$h:$minuteStr';
        _nycDateString = '${weekdays[nycTime.weekday - 1]}, ${nycTime.day}. ${months[nycTime.month - 1]}';
        
        if (_sunsetTime != null) {
          DateTime goldenStart = _sunsetTime!.subtract(const Duration(hours: 1));
          if (nycTime.isBefore(goldenStart)) {
            Duration diff = goldenStart.difference(nycTime);
            _goldenHourText = '${t('golden_in')} ${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
          } else if (nycTime.isBefore(_sunsetTime!)) {
            _goldenHourText = t('golden_now');
          } else {
            _goldenHourText = t('golden_over');
          }
        }
      });
      _checkSmartWarnings(nycTime);
    }
  }

  void _updateWeatherDisplay() {
    if (_currentTempC == null) return;
    int tempDisplay = _isMetric ? _currentTempC! : (_currentTempC! * 9 / 5 + 32).round();
    String unit = _isMetric ? '°C' : '°F';
    String emoji = '☀️';
    String cond = 'Sonnig';
    
    if (_currentWeatherCode >= 1 && _currentWeatherCode <= 3) { emoji = '⛅️'; cond = 'Leicht bewölkt'; }
    else if (_currentWeatherCode == 45 || _currentWeatherCode == 48) { emoji = '🌫'; cond = 'Nebel'; }
    else if (_currentWeatherCode >= 51 && _currentWeatherCode <= 67) { emoji = '🌧'; cond = 'Regen'; }
    else if (_currentWeatherCode >= 71 && _currentWeatherCode <= 77) { emoji = '❄️'; cond = 'Schnee'; }
    else if (_currentWeatherCode >= 95) { emoji = '⛈'; cond = 'Gewitter'; }

    setState(() {
      _nycWeatherString = '$emoji $tempDisplay$unit';
      _nycWeatherCondition = cond;
    });
  }

  Future<void> _fetchNYCWeather() async {
    try {
      final req = await HttpClient().getUrl(Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=40.7143&longitude=-74.006&current_weather=true&daily=sunset&timezone=America%2FNew_York'));
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final data = json.decode(body);
        if (data['current_weather'] != null) {
          _currentTempC = (data['current_weather']['temperature'] as num).round();
          _currentWeatherCode = data['current_weather']['weathercode'];
          if (data['daily'] != null && data['daily']['sunset'] != null && (data['daily']['sunset'] as List).isNotEmpty) {
            _sunsetTime = DateTime.tryParse(data['daily']['sunset'][0]);
          }
          if (mounted) {
            _updateWeatherDisplay();
            _updateNYCTime();
          }
        }
      }
    } catch (e) {
      debugPrint("Wetter Fehler: $e");
    }
  }

  Future<void> _fetchExchangeRate() async {
    final prefs = await SharedPreferences.getInstance();
    double savedRate = prefs.getDouble('usd_to_eur_rate') ?? 0.92;
    setState(() { _usdToEurRate = savedRate; });

    try {
      final req = await HttpClient().getUrl(Uri.parse('https://api.frankfurter.app/latest?from=USD&to=EUR'));
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final data = json.decode(body);
        if (data['rates'] != null && data['rates']['EUR'] != null) {
          double liveRate = (data['rates']['EUR'] as num).toDouble();
          setState(() { _usdToEurRate = liveRate; });
          await prefs.setDouble('usd_to_eur_rate', liveRate);
        }
      }
    } catch (e) {
      debugPrint("Währung Fehler: $e");
    }
  }

  Future<void> _loadTours() async {
    try {
      String csvRes = '';
      try {
        csvRes = await rootBundle.loadString('assets/Touren.csv');
      } catch (e) {
        try {
          csvRes = await rootBundle.loadString('assets/Touren .csv');
        } catch (e2) {
          debugPrint("Konnte CSV-Bilder nicht finden: $e2");
          return;
        }
      }

      final lines = csvRes.split('\n');
      for (var line in lines) {
        int firstQuote = line.indexOf('"');
        int lastQuote = line.lastIndexOf('"');
        if (firstQuote != -1 && lastQuote > firstQuote) {
          String tName = line.substring(0, firstQuote).replaceAll(';', '').trim().toLowerCase();
          String b64 = line.substring(firstQuote + 1, lastQuote);
          if (b64.startsWith('data:image')) {
            for (var t in _allTours) {
              String jName = t['title'].toString().toLowerCase();
              if (tName.contains(jName) || jName.contains(tName)) {
                try {
                  final bytes = base64Decode(b64.split(',').last);
                  setState(() {
                    t['imageBytes'] = bytes;
                  });
                } catch (decodeErr) {
                  debugPrint("Base64 Error: $decodeErr");
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Fehler beim Bilder-Matching: $e");
    }
  }

  Future<void> _loadSurvivalData() async {
    try {
      final String response = await rootBundle.loadString('assets/survival.json');
      final data = await json.decode(response);
      if (data['survival_spots'] != null) {
        setState(() {
          for (var spot in data['survival_spots']) {
            _allAttractions.add({
              'name': spot['name'],
              'category': spot['category'],
              'description': spot['description'],
              'lat': spot['lat'],
              'lng': spot['lng'],
              'imageUrl': spot['imageUrl'] ?? '',
              'affiliateUrl': spot['affiliateUrl'] ?? '',
              'price': spot['price'] ?? 'Kostenlos',
              'isSurvival': true,
              'survivalType': spot['type']
            });
            if (!_categoryVisibility.containsKey(spot['category'])) {
              _categoryVisibility[spot['category']] = true;
            }
          }
          _buildAttractionMarkers();
        });
      }
    } catch (e) {
      debugPrint("Fehler Survival: $e");
    }
  }

  Future<void> _loadSubwayData() async {
    try {
      final String linesRes = await rootBundle.loadString('assets/subway.json');
      final linesData = await json.decode(linesRes);
      List<Polyline> loadedLines = [];
      if (linesData['features'] != null) {
        for (var f in linesData['features']) {
          if (f['geometry'] == null || f['geometry']['coordinates'] == null) {
            continue;
          }
          var props = f['properties'] ?? {};
          String lName = props['rt_symbol']?.toString() ?? props['route_id']?.toString() ?? props['name']?.toString() ?? '';
          if (lName.isEmpty) {
            props.forEach((key, value) {
              if (value is String && value.length < 5) {
                lName += " $value";
              }
            });
          }
          Color lColor = _getSubwayColor(lName);
          if (f['geometry']['type'] == 'LineString') {
            List<LatLng> pts = [];
            for (var c in f['geometry']['coordinates']) {
              if (c != null && c.length >= 2) {
                pts.add(LatLng(c[1] as double, c[0] as double));
              }
            }
            loadedLines.add(Polyline(points: pts, color: lColor, strokeWidth: 4.0));
          } else if (f['geometry']['type'] == 'MultiLineString') {
            for (var l in f['geometry']['coordinates']) {
              if (l == null) {
                continue;
              }
              List<LatLng> pts = [];
              for (var c in l) {
                if (c != null && c.length >= 2) {
                  pts.add(LatLng(c[1] as double, c[0] as double));
                }
              }
              loadedLines.add(Polyline(points: pts, color: lColor, strokeWidth: 4.0));
            }
          }
        }
      }
      final String stRes = await rootBundle.loadString('assets/stations.json');
      final stData = await json.decode(stRes);
      List<Marker> loadedSt = [];
      if (stData['features'] != null) {
        for (var f in stData['features']) {
          if (f['geometry'] != null && f['geometry']['type'] == 'Point') {
            double lng = (f['geometry']['coordinates'][0] as num).toDouble();
            double lat = (f['geometry']['coordinates'][1] as num).toDouble();
            var props = f['properties'] ?? {};
            String sName = props['stop_name'] ?? props['station_name'] ?? props['name'] ?? 'Station';
            String lines = props['daytime_routes'] ?? props['trains'] ?? props['line'] ?? '';
            String dName = sName.length > 12 ? "${sName.substring(0, 10)}..." : sName;
            loadedSt.add(
              Marker(
                point: LatLng(lat, lng),
                width: 80,
                height: 30,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _animatedMapMove(LatLng(lat, lng), _mapController.camera.zoom);
                    Future.delayed(const Duration(milliseconds: 900), () {
                      if (!mounted) return;
                      _showSubwayStationDetails(sName, lines, lat, lng);
                    });
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 1.5)
                        )
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300, width: 0.5)
                        ),
                        child: Text(
                          dName,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis
                        )
                      )
                    ]
                  )
                )
              )
            );
          }
        }
      }
      setState(() {
        _subwayPolylines = loadedLines;
        _stationMarkers = loadedSt;
      });
    } catch (e) {
      debugPrint("Subway Fehler: $e");
    }
  }

  Future<void> _loadCitiBikes() async {
    try {
      final infoReq = await HttpClient().getUrl(Uri.parse('https://gbfs.citibikenyc.com/gbfs/en/station_information.json'));
      final infoRes = await infoReq.close();
      final infoData = json.decode(await infoRes.transform(utf8.decoder).join());

      final statusReq = await HttpClient().getUrl(Uri.parse('https://gbfs.citibikenyc.com/gbfs/en/station_status.json'));
      final statusRes = await statusReq.close();
      final statusData = json.decode(await statusRes.transform(utf8.decoder).join());

      Map<String, int> availableBikes = {};
      if (statusData['data'] != null && statusData['data']['stations'] != null) {
        for (var s in statusData['data']['stations']) {
          availableBikes[s['station_id']] = s['num_bikes_available'] ?? 0;
        }
      }

      List<Marker> loadedMarkers = [];
      if (infoData['data'] != null && infoData['data']['stations'] != null) {
        for (var station in infoData['data']['stations']) {
          double lat = (station['lat'] as num).toDouble();
          double lon = (station['lon'] as num).toDouble();
          String name = station['name'] ?? 'Citi Bike Station';
          String stationId = station['station_id'];

          int bikesReady = availableBikes[stationId] ?? 0;

          if (bikesReady > 0) {
            loadedMarkers.add(
              Marker(
                point: LatLng(lat, lon),
                width: 32,
                height: 32,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _animatedMapMove(LatLng(lat, lon), _mapController.camera.zoom);
                    Future.delayed(const Duration(milliseconds: 900), () {
                      if (!mounted) return;
                      _showCitiBikeDetails(name, bikesReady, lat, lon);
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2)
                        )
                      ]
                    ),
                    child: const Icon(Icons.pedal_bike, color: Colors.white, size: 16)
                  )
                )
              )
            );
          }
        }
      }
      setState(() {
        _citiBikeMarkers = loadedMarkers;
      });
    } catch (e) {
      debugPrint("Fehler Live Citi Bikes: $e");
    }
  }

  Future<void> _loadAttractions() async {
    try {
      final String response = await rootBundle.loadString('assets/attractions.csv');
      if (response.isEmpty) return;
      String separator = response.contains(';') ? ';' : ',';
      List<Map<String, dynamic>> loadedData = [];
      Map<String, bool> categories = {};
      List<List<String>> rows = [];
      List<String> currentRow = [];
      StringBuffer currentCell = StringBuffer();
      bool inQuotes = false;

      for (int i = 0; i < response.length; i++) {
        String char = response[i];
        if (char == '"') {
          if (i + 1 < response.length && response[i + 1] == '"') {
            currentCell.write('"');
            i++;
          } else {
            inQuotes = !inQuotes;
          }
        } else if (char == separator && !inQuotes) {
          currentRow.add(currentCell.toString().trim());
          currentCell.clear();
        } else if ((char == '\n' || char == '\r') && !inQuotes) {
          if (char == '\r' && i + 1 < response.length && response[i + 1] == '\n') {
            i++;
          }
          currentRow.add(currentCell.toString().trim());
          currentCell.clear();
          if (currentRow.isNotEmpty && currentRow.length > 3) {
            rows.add(List.from(currentRow));
          }
          currentRow.clear();
        } else {
          currentCell.write(char);
        }
      }
      if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
        currentRow.add(currentCell.toString().trim());
        if (currentRow.length > 3) {
          rows.add(List.from(currentRow));
        }
      }

      for (var row in rows) {
        if (row.length < 7 || row[0].toLowerCase().contains('name') || row[0].toLowerCase().contains('tabelle')) {
          continue;
        }
        String name = row[0];
        String category = row[1].replaceAll('"', '').trim();
        if (category.isEmpty) {
          category = "Sonstiges";
        }
        double lat = double.tryParse(row[3].replaceAll(',', '.')) ?? 0.0;
        double lng = double.tryParse(row[4].replaceAll(',', '.')) ?? 0.0;
        if (lng > 0) {
          lng = -lng;
        }
        String price = "";
        if (row.length >= 8) {
          price = row[7].replaceAll('"', '').trim();
        }
        if (lat != 0.0 && lng != 0.0) {
          categories[category] = true;
          loadedData.add({
            'name': name,
            'category': category,
            'description': row[2],
            'lat': lat,
            'lng': lng,
            'imageUrl': row[5],
            'affiliateUrl': row[6],
            'price': price,
            'isSurvival': false
          });
        }
      }
      setState(() {
        _allAttractions = loadedData;
        _categoryVisibility = categories;
        _buildAttractionMarkers();
      });
    } catch (e) {
      debugPrint("Fehler Attraktionen: $e");
    }
  }

  void _buildAttractionMarkers() {
    List<Marker> markers = [];
    
    if (_hotelLocation != null) {
      markers.add(
        Marker(
          point: _hotelLocation!,
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              _showHotelOptions();
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.indigoAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
                ]
              ),
              child: const Icon(Icons.bed, color: Colors.white, size: 30),
            ),
          ),
        )
      );
    }

    for (var attr in _allAttractions) {
      String cat = attr['category'];
      String name = attr['name'];
      bool isFavorite = _favorites.contains(name);
      bool isSurvivalSpot = attr['isSurvival'] == true;
      String survivalType = attr['survivalType'] ?? '';
      bool isVisible = false;

      if (_isSurvivalModeActive) {
        isVisible = isSurvivalSpot;
      } else {
        bool isCatActive = _categoryVisibility[cat] ?? true;
        bool isFavLayerActive = _showFavoritesLayer;
        isVisible = isCatActive || (isFavorite && isFavLayerActive);
      }
      if (!isVisible) {
        continue;
      }

      bool isSelected = _selectedAttractionName == name;
      bool focusModeActive = _selectedAttractionName != null;
      double markerSize = isSelected ? 55.0 : 45.0;
      double markerOpacity = (focusModeActive && !isSelected) ? 0.4 : 1.0;
      Color markerColor = const Color(0xFF1C1C1E);
      IconData markerIcon = _getCategoryIcon(cat);

      if (isFavorite) {
        markerColor = Colors.amber;
        markerIcon = Icons.star_rounded;
      } else if (_isSurvivalModeActive && isSurvivalSpot) {
        if (survivalType == 'toilet') {
          markerColor = Colors.orangeAccent;
        }
        if (survivalType == 'wifi') {
          markerColor = Colors.greenAccent.shade700;
          markerSize = 50.0;
        }
      }

      markers.add(
        Marker(
          point: LatLng(attr['lat'] as double, attr['lng'] as double),
          width: markerSize,
          height: markerSize,
          child: GestureDetector(
            onTap: () => _navigateToAttraction(attr, fromMenu: false),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: markerOpacity,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: isSelected ? 3.5 : 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isSurvivalModeActive ? markerColor.withValues(alpha: 0.6) : Colors.black26,
                      blurRadius: _isSurvivalModeActive ? 12 : (isSelected ? 8 : 4),
                      offset: Offset(0, isSelected ? 4 : 2),
                    )
                  ]
                ),
                child: Icon(
                  markerIcon,
                  color: Colors.white,
                  size: isSelected ? 28 : 22,
                ),
              ),
            ),
          ),
        )
      );
    }
    setState(() {
      _attractionMarkers = markers;
    });
  }

  IconData _getCategoryIcon(String category) {
    String cat = category.toLowerCase();
    if (cat.contains('toilet') || cat.contains('wc')) return Icons.wc_outlined;
    if (cat.contains('wifi') || cat.contains('wlan')) return Icons.wifi_rounded;
    if (cat.contains('aussicht') || cat.contains('view')) return Icons.visibility_outlined;
    if (cat.contains('museum') || cat.contains('museen') || cat.contains('kunst')) return Icons.account_balance_outlined;
    if (cat.contains('park') || cat.contains('natur')) return Icons.park_outlined;
    if (cat.contains('essen') || cat.contains('food')) return Icons.restaurant_outlined;
    if (cat.contains('shop') || cat.contains('kauf')) return Icons.shopping_bag_outlined;
    if (cat.contains('boot')) return Icons.directions_boat_outlined;
    return Icons.place_outlined;
  }

  Color _getSubwayColor(String name) {
    if (name.isEmpty) return Colors.grey.withValues(alpha: 0.5);
    name = name.toUpperCase();
    if (RegExp(r'\b(7|7X)\b').hasMatch(name)) return const Color(0xFFB933AD);
    if (RegExp(r'\b(1|2|3)\b').hasMatch(name)) return const Color(0xFFEE352E);
    if (RegExp(r'\b(4|5|6|6X)\b').hasMatch(name)) return const Color(0xFF00933C);
    if (RegExp(r'\b(A|C|E)\b').hasMatch(name)) return const Color(0xFF0039A6);
    if (RegExp(r'\b(B|D|F|M)\b').hasMatch(name)) return const Color(0xFFFF6319);
    if (RegExp(r'\b(N|Q|R|W)\b').hasMatch(name)) return const Color(0xFFFCCC0A);
    if (RegExp(r'\b(G)\b').hasMatch(name)) return const Color(0xFF6CBE45);
    if (RegExp(r'\b(J|Z)\b').hasMatch(name)) return const Color(0xFF996633);
    if (RegExp(r'\b(L)\b').hasMatch(name)) return const Color(0xFFA7A9AC);
    if (RegExp(r'\b(S|FS|GS)\b').hasMatch(name)) return const Color(0xFF808183);
    return Colors.grey.withValues(alpha: 0.5);
  }

  Widget _buildTourImage(Map<String, dynamic> tour) {
    if (tour['imageBytes'] != null) {
      return Image.memory(
        tour['imageBytes'] as Uint8List,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (c, e, s) => Container(
          color: Colors.grey.shade800,
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 40),
          ),
        )
      );
    }
    return Container(
      color: Colors.grey.shade800,
      child: const Center(
        child: Icon(Icons.image, color: Colors.white54, size: 40),
      ),
    );
  }

  Widget _buildFilterPill({required String title, required IconData icon, required bool isActive, required VoidCallback onTap, required bool isDark}) {
    Widget child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.blueAccent : (isDark ? Colors.grey.shade900.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? Colors.blueAccent : (isDark ? Colors.white12 : Colors.black12),
          width: 0.5,
        )
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isActive ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.black87),
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.black87),
            )
          )
        ]
      )
    );

    if (!isActive) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: child,
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: child,
        ),
      ),
    );
  }

  Widget _buildDistanceAndTimeChip(bool isDark, double lat, double lng) {
    if (_currentLocation == null) return const SizedBox.shrink();
    final double distMeter = const Distance().distance(_currentLocation!, LatLng(lat, lng));
    
    String distText;
    if (_isMetric) {
      distText = distMeter < 1000 ? '${distMeter.round()} m' : '${(distMeter / 1000).toStringAsFixed(1)} km';
    } else {
      double miles = distMeter / 1609.34;
      distText = miles < 0.2 ? '${(distMeter * 3.28084).round()} ft' : '${miles.toStringAsFixed(1)} mi';
    }

    final walkMinutes = (distMeter / 83.33).ceil();
    final timeText = walkMinutes < 60 ? '$walkMinutes Min.' : '${(walkMinutes / 60).floor()} Std. ${walkMinutes % 60} Min.';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.blueAccent.withValues(alpha: 0.1) : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.blueAccent.withValues(alpha: 0.3),
        )
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.directions_walk, size: 18, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Text(
            '$distText  •  ca. $timeText Fußweg',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.blueAccent.shade100 : Colors.blue.shade800,
            )
          )
        ]
      )
    );
  }

  Widget _buildDescriptionWidget(String text, bool isDark) {
    const String highlight = "Dein NaviYork Insider-Tipp:";
    Color textColor = isDark ? Colors.grey.shade400 : Colors.grey.shade700;
    Color highlightColor = isDark ? Colors.white : Colors.black87;
    
    if (text.contains(highlight)) {
      List<String> parts = text.split(highlight);
      return RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 16,
            color: textColor,
            height: 1.4,
            fontFamily: 'San Francisco'
          ),
          children: [
            if (parts[0].isNotEmpty) TextSpan(text: parts[0]),
            TextSpan(
              text: highlight,
              style: TextStyle(fontWeight: FontWeight.bold, color: highlightColor)
            ),
            if (parts.length > 1 && parts[1].isNotEmpty) TextSpan(text: parts[1])
          ]
        )
      );
    }
    
    return Text(
      text,
      style: TextStyle(fontSize: 16, color: textColor, height: 1.4)
    );
  }

  void _closeSearch() {
    if (_isSearchActive) {
      _searchBlurController.reverse();
      setState(() {
        _isSearchActive = false;
        _searchQuery = '';
        _searchController.clear();
      });
      _searchFocusNode.unfocus();
    }
  }

  void _navigateToAttraction(Map<String, dynamic> attr, {bool fromMenu = false}) {
    if (fromMenu) {
      Navigator.pop(context);
    } else {
      HapticFeedback.mediumImpact();
    }
    _closeSearch();
    if (_isTracking) {
      setState(() {
        _isTracking = false;
      });
    }
    setState(() {
      _selectedAttractionName = attr['name'];
      _categoryVisibility[attr['category']] = true;
      if (_showFavoritesLayer && !_favorites.contains(attr['name'])) {
        _showFavoritesLayer = false;
      }
      if (_isSurvivalModeActive && attr['isSurvival'] != true) {
        _isSurvivalModeActive = false;
        _showToastNotification("SOS Modus deaktiviert", Icons.explore, Colors.blueAccent);
      }
      _buildAttractionMarkers();
    });
    _animatedMapMove(LatLng(attr['lat'] as double, attr['lng'] as double), _mapController.camera.zoom);
    
    Future.delayed(const Duration(milliseconds: 900), () async {
      if (!mounted) return;
      await _showAttractionDetails(attr);
      if (mounted) {
        setState(() {
          _selectedAttractionName = null;
        });
        _buildAttractionMarkers();
      }
    });
  }

  Future<void> _showAttractionDetails(Map<String, dynamic> attr) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      enableDrag: true,
      builder: (BuildContext modalContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            bool isDark = Theme.of(context).brightness == Brightness.dark;
            bool isFav = _favorites.contains(attr['name']);
            bool isSurvival = attr['isSurvival'] == true;
            return SafeArea(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ]
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    children: [
                      CustomScrollView(
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        slivers: [
                          if (attr['imageUrl'].toString().isNotEmpty)
                            SliverAppBar(
                              stretch: true,
                              expandedHeight: 250.0,
                              backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                              automaticallyImplyLeading: false,
                              flexibleSpace: FlexibleSpaceBar(
                                stretchModes: const [
                                  StretchMode.zoomBackground,
                                  StretchMode.blurBackground
                                ],
                                background: Image.network(
                                  attr['imageUrl'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                    height: 250,
                                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.grey.shade500,
                                      size: 40,
                                    ),
                                  )
                                )
                              )
                            )
                          else
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 30),
                            ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(8)
                                        ),
                                        child: Text(
                                          attr['category'].toString().toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : Colors.black87
                                          )
                                        )
                                      ),
                                      if (attr['price'].toString().isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8)
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.sell_outlined, size: 14, color: Colors.green),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${attr['price']} €',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green
                                                )
                                              )
                                            ]
                                          )
                                        )
                                    ]
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          attr['name'],
                                          style: const TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.5
                                          )
                                        )
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          isFav ? Icons.star_rounded : Icons.star_border_rounded,
                                          color: isFav ? Colors.amber : Colors.grey.shade400,
                                          size: 36
                                        ),
                                        onPressed: () {
                                          _toggleFavorite(attr['name']);
                                          setModalState(() {});
                                        }
                                      )
                                    ]
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDescriptionWidget(attr['description'], isDark),
                                  const SizedBox(height: 24),
                                  _buildDistanceAndTimeChip(isDark, attr['lat'] as double, attr['lng'] as double),
                                  if (!isSurvival) ...[
                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: ElevatedButton.icon(
                                        icon: Icon(Icons.local_activity_outlined, color: isDark ? Colors.black : Colors.white),
                                        label: Text(
                                          t('tickets'),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.black : Colors.white
                                          )
                                        ),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _launchUrl(attr['affiliateUrl']);
                                        }
                                      )
                                    ),
                                    const SizedBox(height: 10)
                                  ],
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueAccent,
                                        foregroundColor: Colors.white
                                      ),
                                      icon: const Icon(Icons.directions_outlined),
                                      label: Text(
                                        t('calc_route'),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _routeTo(attr['lat'] as double, attr['lng'] as double);
                                      }
                                    )
                                  )
                                ]
                              )
                            )
                          )
                        ]
                      ),
                      Positioned(
                        top: 12,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                width: 40,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(10)
                                )
                              )
                            )
                          )
                        )
                      )
                    ]
                  )
                )
              )
            );
          }
        );
      }
    );
  }
void _showSetHotelDialog(LatLng point) {
    HapticFeedback.heavyImpact();
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
        title: Text(t('my_hotel'), style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Text(t('hotel_prompt'), style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: Text(t('cancel'), style: const TextStyle(color: Colors.grey))
          ),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble('naviyork_hotel_lat', point.latitude);
              await prefs.setDouble('naviyork_hotel_lng', point.longitude);
              setState(() {
                _hotelLocation = point;
                _buildAttractionMarkers();
              });
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _showToastNotification(t('hotel_set'), Icons.bed, Colors.indigoAccent);
            }, 
            child: Text(t('save'), style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold))
          )
        ]
      )
    );
  }

  void _showHotelOptions() {
    if (_hotelLocation == null) return;
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bed, color: Colors.indigoAccent, size: 40),
              const SizedBox(height: 16),
              Text(t('my_hotel'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, foregroundColor: Colors.white),
                  icon: const Icon(Icons.directions_walk),
                  label: Text(t('calc_route')),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _routeTo(_hotelLocation!.latitude, _hotelLocation!.longitude);
                  }
                )
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 50,
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(t('delete')),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('naviyork_hotel_lat');
                    await prefs.remove('naviyork_hotel_lng');
                    setState(() {
                      _hotelLocation = null;
                      _buildAttractionMarkers();
                    });
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _showToastNotification(t('hotel_removed'), Icons.delete, Colors.redAccent);
                  }
                )
              )
            ]
          )
        )
      )
    );
  }

  void _showCurrencyConverter() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    TextEditingController usdController = TextEditingController();
    double resultEur = 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      enableDrag: true,
      builder: (BuildContext modalContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Container(
                margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, -10),
                    )
                  ]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10)
                        )
                      )
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10)
                          ),
                          child: const Icon(Icons.currency_exchange, color: Colors.green, size: 28)
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            t('currency'),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: -0.5
                            )
                          )
                        )
                      ]
                    ),
                    const SizedBox(height: 24),
                    Text("Betrag in US-Dollar (\$)", style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: usdController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.attach_money, color: Colors.grey),
                        filled: true,
                        fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          String cleanVal = val.replaceAll(',', '.');
                          double? usd = double.tryParse(cleanVal);
                          if (usd != null) {
                            resultEur = usd * _usdToEurRate;
                          } else {
                            resultEur = 0.0;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3))
                      ),
                      child: Column(
                        children: [
                          Text("Entspricht etwa in Euro (€)", style: TextStyle(fontSize: 14, color: isDark ? Colors.blueAccent.shade100 : Colors.blue.shade800, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                            "${resultEur.toStringAsFixed(2)} €",
                            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: isDark ? Colors.blueAccent.shade100 : Colors.blue.shade800)
                          ),
                          const SizedBox(height: 8),
                          Text("Aktueller Kurs: 1\$ = ${_usdToEurRate.toStringAsFixed(3)}€", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                          foregroundColor: isDark ? Colors.white : Colors.black87
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(t('close'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))
                      )
                    )
                  ]
                )
              )
            );
          }
        );
      }
    );
  }

  void _showTipCalculator() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    TextEditingController billController = TextEditingController();
    TextEditingController customTipController = TextEditingController();
    double tipPercent = 20.0;
    int splitCount = 1;
    double totalTip = 0.0;
    double totalBill = 0.0;
    double perPerson = 0.0;

    void calculate(StateSetter setModalState) {
      String cleanVal = billController.text.replaceAll(',', '.');
      double? bill = double.tryParse(cleanVal);
      if (bill != null && bill > 0) {
        setModalState(() {
          totalTip = bill * (tipPercent / 100);
          totalBill = bill + totalTip;
          perPerson = totalBill / splitCount;
        });
      } else {
        setModalState(() {
          totalTip = 0.0;
          totalBill = 0.0;
          perPerson = 0.0;
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      enableDrag: true,
      builder: (BuildContext modalContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Container(
                margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), 
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, -10),
                    )
                  ]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10)
                        )
                      )
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10)
                          ),
                          child: const Icon(Icons.receipt, color: Colors.orangeAccent, size: 28)
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            t('tip'),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: -0.5
                            )
                          )
                        )
                      ]
                    ),
                    const SizedBox(height: 24),
                    
                    Text("Rechnungsbetrag (ohne Tip)", style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: billController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.attach_money, color: Colors.grey),
                        filled: true,
                        fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) => calculate(setModalState),
                    ),
                    const SizedBox(height: 20),

                    Text("Trinkgeld (Tip)", style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [18.0, 20.0, 22.0].map((percent) {
                        bool isActive = tipPercent == percent && customTipController.text.isEmpty;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              customTipController.clear();
                              setModalState(() { tipPercent = percent; });
                              calculate(setModalState);
                            },
                            child: Container(
                              margin: EdgeInsets.only(right: percent == 22.0 ? 0 : 8),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.orangeAccent : (isDark ? Colors.grey.shade900 : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isActive ? Colors.orangeAccent : Colors.transparent)
                              ),
                              child: Center(
                                child: Text("${percent.toInt()}%", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isActive ? Colors.black87 : (isDark ? Colors.white : Colors.black87)))
                              )
                            )
                          )
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: customTipController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.edit, color: Colors.grey, size: 18),
                        suffixText: '%',
                        hintText: "Eigener Prozentsatz (z.B. 15)",
                        filled: true,
                        fillColor: customTipController.text.isNotEmpty ? Colors.orangeAccent.withValues(alpha: 0.2) : (isDark ? Colors.grey.shade900 : Colors.grey.shade100),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) {
                        String cleanVal = val.replaceAll(',', '.');
                        double? customTip = double.tryParse(cleanVal);
                        setModalState(() {
                          if (customTip != null) {
                            tipPercent = customTip;
                          } else {
                            tipPercent = 20.0;
                          }
                        });
                        calculate(setModalState);
                      }
                    ),
                    const SizedBox(height: 20),

                    Text("Aufteilen auf", style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16)
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            color: splitCount > 1 ? Colors.blueAccent : Colors.grey,
                            onPressed: () {
                              if (splitCount > 1) {
                                HapticFeedback.lightImpact();
                                setModalState(() { splitCount--; });
                                calculate(setModalState);
                              }
                            }
                          ),
                          Text("$splitCount Person${splitCount == 1 ? '' : 'en'}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            color: Colors.blueAccent,
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setModalState(() { splitCount++; });
                              calculate(setModalState);
                            }
                          ),
                        ],
                      )
                    ),
                    const SizedBox(height: 24),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3))
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Rechnung inkl. Tip:", style: TextStyle(color: isDark ? Colors.orangeAccent.shade100 : Colors.orange.shade900)),
                              Text("\$${totalBill.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.orangeAccent.shade100 : Colors.orange.shade900))
                            ]
                          ),
                          const Divider(height: 20),
                          Text("Jeder bezahlt", style: TextStyle(fontSize: 14, color: isDark ? Colors.orangeAccent.shade100 : Colors.orange.shade900, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            "\$${perPerson.toStringAsFixed(2)}",
                            style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: isDark ? Colors.orangeAccent.shade100 : Colors.orange.shade900)
                          ),
                          const SizedBox(height: 4),
                          Text("(davon \$${(totalTip/splitCount).toStringAsFixed(2)} Tip)", style: TextStyle(fontSize: 12, color: isDark ? Colors.orangeAccent.shade100 : Colors.orange.shade900)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                          foregroundColor: isDark ? Colors.white : Colors.black87
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(t('close'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))
                      )
                    )
                  ]
                )
              )
            );
          }
        );
      }
    );
  }

  void _showBudgetTracker() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    TextEditingController expenseController = TextEditingController();
    TextEditingController budgetController = TextEditingController(text: _dailyBudget.toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      enableDrag: true,
      builder: (BuildContext modalContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            double remaining = _dailyBudget - _spentToday;
            double progress = _dailyBudget > 0 ? (_spentToday / _dailyBudget).clamp(0.0, 1.0) : 0.0;
            Color progressColor = progress > 0.9 ? Colors.redAccent : (progress > 0.7 ? Colors.orangeAccent : Colors.greenAccent);

            return SafeArea(
              child: Container(
                margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, -10),
                    )
                  ]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10)
                        )
                      )
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10)
                          ),
                          child: const Icon(Icons.account_balance_wallet, color: Colors.indigoAccent, size: 28)
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            t('budget'),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: -0.5
                            )
                          )
                        )
                      ]
                    ),
                    const SizedBox(height: 24),
                    Text("Tages-Limit (Euro)", style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: budgetController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.euro, color: Colors.grey),
                        filled: true,
                        fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) async {
                        String cleanVal = val.replaceAll(',', '.');
                        double? b = double.tryParse(cleanVal);
                        if (b != null && b > 0) {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setDouble('naviyork_budget', b);
                          setModalState(() { _dailyBudget = b; });
                          setState(() { _dailyBudget = b; });
                        }
                      }
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: progressColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: progressColor.withValues(alpha: 0.3))
                      ),
                      child: Column(
                        children: [
                          Text("Noch übrig heute:", style: TextStyle(fontSize: 14, color: progressColor, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                            "${remaining.toStringAsFixed(2)} €",
                            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: progressColor)
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 12,
                              backgroundColor: isDark ? Colors.white12 : Colors.black12,
                              valueColor: AlwaysStoppedAnimation<Color>(progressColor)
                            )
                          ),
                          const SizedBox(height: 8),
                          Text("${_spentToday.toStringAsFixed(2)} € von ${_dailyBudget.toStringAsFixed(2)} € ausgegeben", style: const TextStyle(fontSize: 12, color: Colors.grey))
                        ]
                      )
                    ),
                    const SizedBox(height: 24),
                    Text("Ausgabe in Dollar hinzufügen (\$)", style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: expenseController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.attach_money, color: Colors.grey),
                              filled: true,
                              fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                            )
                          )
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(12)),
                          child: IconButton(
                            icon: const Icon(Icons.add, color: Colors.white),
                            onPressed: () async {
                              String cleanVal = expenseController.text.replaceAll(',', '.');
                              double? exp = double.tryParse(cleanVal);
                              if (exp != null && exp > 0) {
                                HapticFeedback.mediumImpact();
                                double expEur = exp * _usdToEurRate;
                                double newTotal = _spentToday + expEur;
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setDouble('naviyork_spent', newTotal);
                                setModalState(() {
                                  _spentToday = newTotal;
                                  expenseController.clear();
                                });
                                setState(() { _spentToday = newTotal; });
                              }
                            }
                          )
                        )
                      ]
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent)
                              ),
                              onPressed: () async {
                                HapticFeedback.heavyImpact();
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setDouble('naviyork_spent', 0.0);
                                setModalState(() { _spentToday = 0.0; });
                                setState(() { _spentToday = 0.0; });
                              },
                              child: const Text('Tag Reset', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                            )
                          )
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                foregroundColor: isDark ? Colors.white : Colors.black87
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: Text(t('close'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                            )
                          )
                        )
                      ]
                    )
                  ]
                )
              )
            );
          }
        );
      }
    );
  }

  void _showOmnyTracker() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      enableDrag: true,
      builder: (BuildContext modalContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            double progress = (_omnyRides / 12.0).clamp(0.0, 1.0);
            bool isFree = _omnyRides >= 12;

            return SafeArea(
              child: Container(
                margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, -10),
                    )
                  ]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10)
                        )
                      )
                    ),
                    const SizedBox(height: 24),
                    Text(
                      t('omny'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.5
                      )
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Die MTA deckelt deine Kosten bei 34\$ pro Woche. \n(12 Fahrten). Danach fährst du gratis.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)
                    ),
                    const SizedBox(height: 30),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 180,
                          height: 180,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 16,
                            backgroundColor: isDark ? Colors.white12 : Colors.black12,
                            valueColor: AlwaysStoppedAnimation<Color>(isFree ? Colors.greenAccent : Colors.blueAccent),
                          )
                        ),
                        Column(
                          children: [
                            Text(
                              "$_omnyRides / 12",
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: isFree ? Colors.greenAccent : (isDark ? Colors.white : Colors.black87)
                              )
                            ),
                            Text(
                              "Fahrten",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600
                              )
                            )
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 30),
                    if (isFree)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.greenAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Colors.greenAccent),
                            SizedBox(width: 8),
                            Text("Du fährst den Rest der Woche GRATIS!", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))
                          ],
                        )
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                        child: Text("Noch ${12 - _omnyRides} Fahrten bis zur Gratis-Woche.", style: TextStyle(color: isDark ? Colors.blueAccent.shade100 : Colors.blue.shade800, fontWeight: FontWeight.bold))
                      ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 60,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent)
                              ),
                              onPressed: () async {
                                HapticFeedback.heavyImpact();
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setInt('naviyork_omny', 0);
                                setModalState(() { _omnyRides = 0; });
                                setState(() { _omnyRides = 0; });
                              },
                              child: const Text('Reset', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                            )
                          )
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 60,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFree ? Colors.green : Colors.blueAccent,
                                foregroundColor: Colors.white
                              ),
                              onPressed: () async {
                                HapticFeedback.lightImpact();
                                if (_omnyRides < 12) {
                                  int newRides = _omnyRides + 1;
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setInt('naviyork_omny', newRides);
                                  setModalState(() { _omnyRides = newRides; });
                                  setState(() { _omnyRides = newRides; });
                                }
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Fahrt eintragen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                            )
                          )
                        )
                      ]
                    )
                  ]
                )
              )
            );
          }
        );
      }
    );
  }

  void _showSubwayMapFullscreen() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showGeneralDialog(
      context: context,
      barrierColor: isDark ? Colors.black : Colors.white,
      barrierDismissible: false,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Scaffold(
          backgroundColor: isDark ? Colors.black : Colors.white,
          appBar: AppBar(
            backgroundColor: isDark ? Colors.black : Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
            title: Text(t('subway'), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          body: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Center(
              child: Image.asset(
                'assets/mta_map.png',
                errorBuilder: (context, error, stackTrace) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map_outlined, color: isDark ? Colors.white54 : Colors.black54, size: 50),
                    const SizedBox(height: 16),
                    Text('MTA Karte nicht gefunden.', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Bitte füge "assets/mta_map.png" zu deinem Projekt hinzu.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
                  ]
                ),
              ),
            ),
          ),
        );
      }
    );
  }

  void _showSubwayStationDetails(String name, String lines, double lat, double lng) {
    if (!mounted) return;
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      enableDrag: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10)
                    )
                  )
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10)
                      ),
                      child: Icon(
                        Icons.directions_subway_outlined,
                        color: isDark ? Colors.white : Colors.black87,
                        size: 28
                      )
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5
                        )
                      )
                    )
                  ]
                ),
                const SizedBox(height: 12),
                Text(
                  'Linien: $lines',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontWeight: FontWeight.w500
                  )
                ),
                const SizedBox(height: 24),
                _buildDistanceAndTimeChip(isDark, lat, lng),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    icon: Icon(
                      Icons.directions_outlined,
                      color: isDark ? Colors.black : Colors.white
                    ),
                    label: Text(
                      t('calc_route'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.black : Colors.white
                      )
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _routeTo(lat, lng);
                    }
                  )
                )
              ]
            )
          )
        );
      }
    );
  }

  void _showCitiBikeDetails(String name, int bikesAvailable, double lat, double lng) {
    if (!mounted) return;
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      enableDrag: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10)
                    )
                  )
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blue.shade900.withValues(alpha: 0.5) : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10)
                      ),
                      child: Icon(
                        Icons.pedal_bike,
                        color: Colors.blue.shade600,
                        size: 28
                      )
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5
                        )
                      )
                    )
                  ]
                ),
                const SizedBox(height: 12),
                Text(
                  'Sofort verfügbare Fahrräder: $bikesAvailable',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.greenAccent : Colors.green.shade700,
                    fontWeight: FontWeight.w700
                  )
                ),
                const SizedBox(height: 24),
                _buildDistanceAndTimeChip(isDark, lat, lng),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white
                    ),
                    icon: const Icon(Icons.directions_outlined),
                    label: Text(
                      t('calc_route'),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _routeTo(lat, lng);
                    }
                  )
                )
              ]
            )
          )
        );
      }
    );
  }

  void _showToastNotification(String message, IconData icon, Color color) {
    if (_toastOverlay != null) {
      _toastOverlay!.remove();
      _toastOverlay = null;
    }
    _toastTimer?.cancel();
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    _toastOverlay = OverlayEntry(builder: (context) {
      return Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: IgnorePointer(
            child: Center(
              child: AnimatedBuilder(
                animation: _toastAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, -100 * (1 - _toastAnimation.value)),
                    child: Opacity(
                      opacity: _toastAnimation.value.clamp(0.0, 1.0),
                      child: child
                    )
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade900.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.black12,
                          width: 0.5
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4)
                          )
                        ]
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, color: color, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            message,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: isDark ? Colors.white : Colors.black87
                            )
                          )
                        ]
                      )
                    )
                  )
                )
              )
            )
          )
        )
      );
    });
    Overlay.of(context).insert(_toastOverlay!);
    _toastController.forward(from: 0.0);
    _toastTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _toastController.reverse().then((_) {
          if (_toastOverlay != null) {
            _toastOverlay!.remove();
            _toastOverlay = null;
          }
        });
      }
    });
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    _mapAnimController?.dispose();
    _mapAnimController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this
    );
    final Animation<double> animation = CurvedAnimation(
      parent: _mapAnimController!,
      curve: Curves.easeInOutCubic
    );
    final latTween = Tween<double>(
      begin: _mapController.camera.center.latitude,
      end: destLocation.latitude
    );
    final lngTween = Tween<double>(
      begin: _mapController.camera.center.longitude,
      end: destLocation.longitude
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: destZoom
    );
    _mapAnimController!.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation)
      );
    });
    _mapAnimController!.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        _mapAnimController!.dispose();
        _mapAnimController = null;
      }
    });
    _mapAnimController!.forward();
  }

  void _toggle3DMode() {
    HapticFeedback.mediumImpact();
    setState(() {
      _is3DMode = !_is3DMode;
      if (_is3DMode) {
        _tiltController.forward();
      } else {
        _tiltController.reverse();
      }
    });
  }

  Future<void> _toggleTracking() async {
    HapticFeedback.lightImpact();
    if (_isTracking) {
      setState(() {
        _isTracking = false;
      });
      _positionStream?.cancel();
      return;
    }
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    setState(() {
      _isTracking = true;
    });
    Position p = await Geolocator.getCurrentPosition();
    LatLng newPos = LatLng(p.latitude, p.longitude);
    setState(() {
      _currentLocation = newPos;
    });
    _animatedMapMove(newPos, 16.0);
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5
      )
    ).listen((Position position) {
      LatLng updatePos = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentLocation = updatePos;
      });
      if (_isTracking) {
        _mapController.move(updatePos, _mapController.camera.zoom);
      }
    });
  }

  void _toggleSurvivalMode() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isSurvivalModeActive = !_isSurvivalModeActive;
      _showToursList = false;
      _selectedTour = null;
      _buildAttractionMarkers();
      if (_isSurvivalModeActive) {
        _showToastNotification("SOS Modus aktiviert", Icons.health_and_safety, Colors.redAccent);
        _animatedMapMove(_mapController.camera.center, 13.0);
      } else {
        _showToastNotification("SOS Modus deaktiviert", Icons.explore, Colors.blueAccent);
      }
    });
  }

  List<Map<String, dynamic>> _getSearchResults() {
    if (_searchQuery.isEmpty) return [];
    final queryLower = _searchQuery.toLowerCase();
    return _allAttractions.where((a) {
      return a['name'].toLowerCase().contains(queryLower) || a['category'].toLowerCase().contains(queryLower);
    }).toList();
  }

  void _toggleFavorite(String name) {
    HapticFeedback.lightImpact();
    bool isAdded = false;
    setState(() {
      if (_favorites.contains(name)) {
        _favorites.remove(name);
        isAdded = false;
      } else {
        _favorites.add(name);
        isAdded = true;
      }
      _buildAttractionMarkers();
    });
    _showToastNotification(
      isAdded ? 'Gespeichert' : 'Entfernt',
      isAdded ? Icons.star_rounded : Icons.star_border_rounded,
      isAdded ? Colors.amber : Colors.grey.shade500
    );
    SharedPreferences.getInstance().then((prefs) {
      prefs.setStringList('naviyork_favorites', _favorites.toList());
    });
  }

  List<Marker> _getTourMarkers() {
    if (_selectedTour == null) return [];
    List<Marker> tourMarkers = [];
    List<dynamic> pts = _selectedTour!['points'];
    for (int i = 0; i < pts.length; i++) {
      tourMarkers.add(
        Marker(
          point: LatLng(pts[i]['lat'] as double, pts[i]['lng'] as double),
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2)
                )
              ]
            ),
            child: Center(
              child: Text(
                '${i + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16
                )
              )
            )
          )
        )
      );
    }
    return tourMarkers;
  }

  Future<void> _launchMultiStopTourInMaps(List<dynamic> points) async {
    if (points.length < 2) return;
    String enc(String s) => Uri.encodeComponent('$s, New York');
    final String start = enc(points.first['name'] as String);
    final String end = enc(points.last['name'] as String);

    String url = 'http://googleusercontent.com/maps.google.com/9?daddr=$end&saddr=$start&travelmode=walking';
    if (points.length > 2) {
      String wps = points.sublist(1, points.length - 1).map((p) => enc(p['name'] as String)).join('%7C');
      url += '&waypoints=$wps';
    }
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      debugPrint('Maps Error');
    }
  }

  Future<void> _showTourDetails(Map<String, dynamic> tour) async {
    if (!mounted) return;
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    List<dynamic> points = tour['points'];
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      enableDrag: true,
      builder: (BuildContext modalContext) {
        return SafeArea(
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10)
                )
              ]
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        stretch: true,
                        expandedHeight: 200,
                        automaticallyImplyLeading: false,
                        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                        flexibleSpace: FlexibleSpaceBar(
                          stretchModes: const [StretchMode.zoomBackground],
                          background: _buildTourImage(tour)
                        )
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8)
                                ),
                                child: const Text(
                                  'PERFECT DAY TOUR',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueAccent
                                  )
                                )
                              ),
                              const SizedBox(height: 12),
                              Text(
                                tour['title'],
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5
                                )
                              ),
                              Text(
                                tour['subtitle'],
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600
                                )
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    tour['duration'],
                                    style: const TextStyle(fontWeight: FontWeight.w600)
                                  ),
                                  const SizedBox(width: 16),
                                  const Icon(Icons.route_outlined, size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    tour['distance'],
                                    style: const TextStyle(fontWeight: FontWeight.w600)
                                  )
                                ]
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                "Was dich erwartet:",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold
                                )
                              ),
                              const SizedBox(height: 16),
                              ...points.asMap().entries.map((entry) {
                                int idx = entry.key;
                                var pt = entry.value;
                                String desc = pt['description'] ?? '';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: const BoxDecoration(
                                          color: Colors.blueAccent,
                                          shape: BoxShape.circle
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${idx + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold
                                            )
                                          )
                                        )
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              pt['name'],
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700
                                              )
                                            ),
                                            if (desc.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                desc,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                                  height: 1.4
                                                )
                                              )
                                            ]
                                          ]
                                        )
                                      )
                                    ]
                                  )
                                );
                              }),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white
                                  ),
                                  icon: const Icon(Icons.navigation_outlined),
                                  label: Text(
                                    t('route_maps'),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600
                                    )
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _launchMultiStopTourInMaps(points);
                                  }
                                )
                              )
                            ]
                          )
                        )
                      )
                    ]
                  ),
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10)
                            )
                          )
                        )
                      )
                    )
                  )
                ]
              )
            )
          )
        );
      }
    );
  }

  Widget _buildGuideParagraph(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          color: isDark ? Colors.grey.shade300 : Colors.black87,
          height: 1.5
        )
      )
    );
  }

  Widget _buildGuideRule(String title, String desc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.blueAccent, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87
                  )
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    height: 1.4
                  )
                ),
              ]
            )
          )
        ]
      )
    );
  }
void _showGuideSheet(String title, IconData icon, Color color, List<Widget> content) {
    if (!mounted) return;
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      enableDrag: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10)
                    )
                  )
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10)
                      ),
                      child: Icon(icon, color: color, size: 28)
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5
                        )
                      )
                    )
                  ]
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: content,
                  )
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      foregroundColor: isDark ? Colors.white : Colors.black87
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      t('understood'),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)
                    )
                  )
                )
              ]
            )
          )
        );
      }
    );
  }
  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    String mapUrl = isDarkMode 
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png' 
        : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
    final searchResults = _getSearchResults();

    return Scaffold(
      key: _scaffoldKey,
      drawerScrimColor: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.1),
      drawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.88,
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.only(top: 10, bottom: 24, left: 16, right: 16),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade900.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDarkMode ? Colors.white12 : Colors.black12,
                width: 0.5
              )
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 16, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            t('menu'),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.0,
                              color: isDarkMode ? Colors.white : Colors.black87
                            )
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                              shape: BoxShape.circle
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: isDarkMode ? Colors.white : Colors.black87,
                                size: 20
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(context);
                              }
                            )
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 20),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          // --- TRAVEL DASHBOARD ---
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Manhattan, NY", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                                      Icon(Icons.location_on, color: Colors.blueAccent, size: 14),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _nycTimeString, 
                                    style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87, letterSpacing: -1)
                                  ),
                                  Text(
                                    _nycDateString, 
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)
                                  ),
                                  const Divider(height: 30),
                                  Row(
                                    children: [
                                      Text(_nycWeatherString, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 10),
                                      Text(_nycWeatherCondition, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                                    ],
                                  ),
                                  if (_goldenHourText.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Icon(Icons.camera_alt, color: Colors.amber, size: 14),
                                        const SizedBox(width: 8),
                                        Text(_goldenHourText, style: const TextStyle(fontSize: 14, color: Colors.amber, fontWeight: FontWeight.bold)),
                                      ],
                                    )
                                  ]
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
                            child: Text(
                              t('my_places'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey,
                                letterSpacing: 1.2
                              )
                            )
                          ),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                            leading: const Icon(Icons.bed, color: Colors.indigoAccent),
                            title: Text(t('my_hotel'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            trailing: _hotelLocation != null ? const Icon(Icons.check_circle, color: Colors.green) : null,
                            onTap: () {
                              if (_hotelLocation != null) {
                                Navigator.pop(context);
                                _showHotelOptions();
                              } else {
                                _showToastNotification("Halte irgendwo auf der Karte lange gedrückt, um dein Hotel zu speichern.", Icons.info_outline, Colors.blueAccent);
                              }
                            },
                          ),
                          ExpansionTile(
                            shape: const Border(),
                            collapsedShape: const Border(),
                            leading: const Icon(Icons.star_rounded, color: Colors.amber),
                            iconColor: Colors.amber,
                            collapsedIconColor: Colors.grey,
                            title: Row(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        t('favorites'),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600
                                        )
                                      )
                                    )
                                  )
                                ),
                                Switch(
                                  value: _showFavoritesLayer,
                                  activeTrackColor: Colors.blueAccent,
                                  onChanged: (bool value) {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      _showFavoritesLayer = value;
                                      _buildAttractionMarkers();
                                    });
                                  }
                                )
                              ]
                            ),
                            children: _favorites.isEmpty
                                ? [
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 16.0),
                                      child: Text(
                                        t('no_favs'),
                                        style: const TextStyle(color: Colors.grey)
                                      )
                                    )
                                  ]
                                : _allAttractions.where((a) => _favorites.contains(a['name'])).map((attr) {
                                    return ListTile(
                                      contentPadding: const EdgeInsets.only(left: 72, right: 24),
                                      title: Text(
                                        attr['name'],
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: isDarkMode ? Colors.white : Colors.black87
                                        )
                                      ),
                                      onTap: () => _navigateToAttraction(attr, fromMenu: true)
                                    );
                                  }).toList(),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                            child: Text(
                              t('directory'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey,
                                letterSpacing: 1.2
                              )
                            )
                          ),
                          // --- VERZEICHNIS ALS KLAPPMENÜ ---
                          ExpansionTile(
                            shape: const Border(),
                            collapsedShape: const Border(),
                            leading: Icon(Icons.list_alt_rounded, color: isDarkMode ? Colors.white : Colors.black87),
                            iconColor: isDarkMode ? Colors.white : Colors.black87,
                            collapsedIconColor: Colors.grey,
                            title: Text(t('all_cats'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            children: _categoryVisibility.keys.map((String category) {
                              return ExpansionTile(
                                shape: const Border(),
                                collapsedShape: const Border(),
                                leading: Icon(
                                  _getCategoryIcon(category),
                                  color: isDarkMode ? Colors.white : Colors.black87
                                ),
                                iconColor: isDarkMode ? Colors.white : Colors.black87,
                                collapsedIconColor: Colors.grey,
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            category,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600
                                            )
                                          )
                                        )
                                      )
                                    ),
                                    Switch(
                                      value: _categoryVisibility[category] ?? true,
                                      activeTrackColor: Colors.blueAccent,
                                      onChanged: (bool value) {
                                        HapticFeedback.lightImpact();
                                        setState(() {
                                          _categoryVisibility[category] = value;
                                          _buildAttractionMarkers();
                                        });
                                      }
                                    )
                                  ]
                                ),
                                children: _allAttractions.where((a) => a['category'] == category).map((attr) {
                                  return ListTile(
                                    contentPadding: const EdgeInsets.only(left: 72, right: 24),
                                    title: Text(
                                      attr['name'],
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: isDarkMode ? Colors.white : Colors.black87
                                      )
                                    ),
                                    onTap: () => _navigateToAttraction(attr, fromMenu: true)
                                  );
                                }).toList(),
                              );
                            }).toList(),
                          ),
                          
                          const SizedBox(height: 24),

                          // --- SMART TOOLS (Währung, Trinkgeld, Budget, OMNY) ---
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                            child: Text(
                              t('tools'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey,
                                letterSpacing: 1.2
                              )
                            )
                          ),
                          ExpansionTile(
                            shape: const Border(),
                            collapsedShape: const Border(),
                            leading: Icon(Icons.calculate_outlined, color: isDarkMode ? Colors.white : Colors.black87),
                            iconColor: isDarkMode ? Colors.white : Colors.black87,
                            collapsedIconColor: Colors.grey,
                            title: Text(
                              t('calc_travel'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
                            ),
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.only(left: 72, right: 24),
                                title: Text(
                                  t('omny'),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode ? Colors.white : Colors.black87
                                  )
                                ),
                                trailing: const Icon(Icons.subway, size: 18, color: Colors.blueAccent),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pop(context);
                                  _showOmnyTracker();
                                },
                              ),
                              ListTile(
                                contentPadding: const EdgeInsets.only(left: 72, right: 24),
                                title: Text(
                                  t('currency'),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode ? Colors.white : Colors.black87
                                  )
                                ),
                                trailing: const Icon(Icons.currency_exchange, size: 18, color: Colors.green),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pop(context);
                                  _showCurrencyConverter();
                                },
                              ),
                              ListTile(
                                contentPadding: const EdgeInsets.only(left: 72, right: 24),
                                title: Text(
                                  t('tip'),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode ? Colors.white : Colors.black87
                                  )
                                ),
                                trailing: const Icon(Icons.receipt, size: 18, color: Colors.orangeAccent),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pop(context);
                                  _showTipCalculator();
                                },
                              ),
                              ListTile(
                                contentPadding: const EdgeInsets.only(left: 72, right: 24),
                                title: Text(
                                  t('budget'),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode ? Colors.white : Colors.black87
                                  )
                                ),
                                trailing: const Icon(Icons.account_balance_wallet, size: 18, color: Colors.indigoAccent),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pop(context);
                                  _showBudgetTracker();
                                },
                              ),
                            ]
                          ),

                          const SizedBox(height: 24),

                          // --- KARTEN & PLÄNE ---
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                            child: Text(
                              t('maps'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey,
                                letterSpacing: 1.2
                              )
                            )
                          ),
                          ExpansionTile(
                            shape: const Border(),
                            collapsedShape: const Border(),
                            leading: Icon(Icons.map_outlined, color: isDarkMode ? Colors.white : Colors.black87),
                            iconColor: isDarkMode ? Colors.white : Colors.black87,
                            collapsedIconColor: Colors.grey,
                            title: Text(
                              t('offline_maps'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
                            ),
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.only(left: 72, right: 24),
                                title: Text(
                                  t('subway'),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode ? Colors.white : Colors.black87
                                  )
                                ),
                                trailing: const Icon(Icons.zoom_out_map, size: 14, color: Colors.grey),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pop(context); 
                                  _showSubwayMapFullscreen();
                                },
                              ),
                            ]
                          ),

                          const SizedBox(height: 24),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                            child: Text(
                              t('guide'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey,
                                letterSpacing: 1.2
                              )
                            )
                          ),
                          ExpansionTile(
                            shape: const Border(),
                            collapsedShape: const Border(),
                            leading: Icon(Icons.menu_book_rounded, color: isDarkMode ? Colors.white : Colors.black87),
                            iconColor: isDarkMode ? Colors.white : Colors.black87,
                            collapsedIconColor: Colors.grey,
                            title: Text(
                              t('knowledge'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
                            ),
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.only(left: 72, right: 24),
                                title: Text(
                                  'Trinkgeld (Tipping)',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode ? Colors.white : Colors.black87
                                  )
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pop(context);
                                  _showGuideSheet(
                                    "Trinkgeld (Tipping)", 
                                    Icons.receipt_long, 
                                    Colors.green.shade600,
                                    [
                                      _buildGuideParagraph("In New York ist Trinkgeld kein Bonus, sondern das eigentliche Gehalt der Servicekräfte. Gibst du kein Trinkgeld, gilt das als extrem unhöflich.", isDarkMode),
                                      _buildGuideRule("Restaurant / Café", "Immer 18% bis 22% vom Gesamtbetrag (vor Steuern). Selbst bei mäßigem Service sind 18% Minimum.", isDarkMode),
                                      _buildGuideRule("Bars / Pubs", "Standard sind 1\$ bis 2\$ pro Drink, den dir der Barkeeper mixt. Bei aufwendigen Cocktails gerne mehr.", isDarkMode),
                                      _buildGuideRule("Taxi / Uber", "15% bis 20% des Fahrpreises. Bei Uber/Lyft einfach in der App am Ende auswählen.", isDarkMode),
                                      _buildGuideRule("Hotel Housekeeping", "2\$ bis 5\$ pro Tag auf dem Kopfkissen hinterlassen (nicht erst am Ende des Urlaubs).", isDarkMode),
                                    ]
                                  );
                                },
                              ),
                              ListTile(
                                contentPadding: const EdgeInsets.only(left: 72, right: 24),
                                title: Text(
                                  'U-Bahn Insider',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode ? Colors.white : Colors.black87
                                  )
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pop(context);
                                  _showGuideSheet(
                                    "U-Bahn Insider", 
                                    Icons.subway, 
                                    Colors.blueAccent,
                                    [
                                      _buildGuideParagraph("Die New Yorker U-Bahn ist alt, laut und kompliziert. Aber mit diesen Regeln fährst du wie ein Local.", isDarkMode),
                                      _buildGuideRule("Tickets (OMNY)", "Kauf keine Papiertickets mehr! Halte einfach deine kontaktlose Kreditkarte (oder Apple/Google Pay) ans Drehkreuz. Das System deckelt deine Kosten automatisch bei 34\$ pro Woche.", isDarkMode),
                                      _buildGuideRule("Local vs. Express", "Ganz wichtig: Auf dem U-Bahn-Plan bedeuten weiße Kreise, dass hier alle Züge halten. Schwarze Kreise bedeuten: Hier halten nur die (langsameren) Local-Trains, der Express brettert durch!", isDarkMode),
                                      _buildGuideRule("Die goldene Regel", "Wenn auf dem Bahnsteig ein Waggon komplett leer ist, steig NICHT ein. Meistens ist die Klimaanlage kaputt, es stinkt extrem oder jemand hat sich übergeben.", isDarkMode),
                                      _buildGuideRule("Uptown / Downtown", "Achte beim Treppen-Runtergehen auf die Schilder! 'Uptown' fährt nach Norden (Richtung Central Park), 'Downtown' nach Süden (Richtung Brooklyn/WTC).", isDarkMode),
                                    ]
                                  );
                                },
                              ),
                              ListTile(
                                contentPadding: const EdgeInsets.only(left: 72, right: 24),
                                title: Text(
                                  'Notfall & Nummern',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode ? Colors.white : Colors.black87
                                  )
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pop(context);
                                  _showGuideSheet(
                                    "Notfall & Nummern", 
                                    Icons.local_hospital, 
                                    Colors.redAccent,
                                    [
                                      _buildGuideParagraph("Falls mal etwas schiefgeht, behalte einen kühlen Kopf. New York ist extrem hilfsbereit.", isDarkMode),
                                      _buildGuideRule("911 - Der echte Notruf", "Gilt für Polizei, Feuerwehr und Krankenwagen. Achtung: Krankenwagen-Fahrten in den USA kosten hunderte Dollar. Nur bei echter Lebensgefahr rufen (oder eine Taxi/Uber zur Notaufnahme nehmen).", isDarkMode),
                                      _buildGuideRule("311 - Bürgertelefon", "Für alle Dinge, die kein Notfall sind (Ruhestörung, verlorene Dinge im Taxi).", isDarkMode),
                                      _buildGuideRule("+49 116 116", "Der deutsche Sperr-Notruf. Sofort anrufen, wenn dein Portemonnaie oder deine Kreditkarte geklaut wurde.", isDarkMode),
                                      _buildGuideRule("Reisekrankenversicherung", "Solltest du ins Krankenhaus müssen, zeige sofort an der Anmeldung deine Versicherungskarte. Unterschreibe nichts, ohne deine deutsche Versicherung angerufen zu haben.", isDarkMode),
                                    ]
                                  );
                                },
                              ),
                            ]
                          ),

                          const SizedBox(height: 24),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                            child: Text(
                              t('system'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey,
                                letterSpacing: 1.2
                              )
                            )
                          ),
                          ExpansionTile(
                            shape: const Border(),
                            collapsedShape: const Border(), 
                            leading: Icon(Icons.settings_outlined, color: isDarkMode ? Colors.white : Colors.black87), 
                            iconColor: isDarkMode ? Colors.white : Colors.black87, 
                            collapsedIconColor: Colors.grey,
                            title: Text(
                              t('settings'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
                            ),
                            children: [
                              SwitchListTile(
                                contentPadding: const EdgeInsets.only(left: 72, right: 24),
                                activeTrackColor: Colors.blueAccent,
                                title: Text(
                                  t('dark_mode'),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)
                                ),
                                value: appThemeNotifier.value == ThemeMode.dark || (appThemeNotifier.value == ThemeMode.system && isDarkMode),
                                onChanged: (bool value) {
                                  HapticFeedback.lightImpact();
                                  appThemeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                                },
                              ),
                              SwitchListTile(
                                contentPadding: const EdgeInsets.only(left: 72, right: 24),
                                activeTrackColor: Colors.blueAccent,
                                title: Text(
                                  t('metric'),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)
                                ),
                                value: _isMetric,
                                onChanged: (bool value) {
                                  HapticFeedback.lightImpact();
                                  _toggleMetricSystem(value);
                                },
                              ),
                              ListTile(
                                contentPadding: const EdgeInsets.only(left: 72, right: 24),
                                title: Text(
                                  t('language'),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12)
                                  ), 
                                  child: DropdownButton<String>(
                                    value: _currentLanguage,
                                    underline: const SizedBox(),
                                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.blueAccent, size: 16),
                                    items: ['DE', 'EN', 'ES'].map((String val) {
                                      return DropdownMenuItem<String>(
                                        value: val,
                                        child: Text(val, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 12)),
                                      );
                                    }).toList(),
                                    onChanged: (newVal) async {
                                      if (newVal != null) {
                                        final prefs = await SharedPreferences.getInstance();
                                        await prefs.setString('naviyork_lang', newVal);
                                        setState(() { _currentLanguage = newVal; });
                                        HapticFeedback.lightImpact();
                                      }
                                    },
                                  )
                                )
                              ),
                              ListTile(
                                contentPadding: const EdgeInsets.only(left: 72, right: 24),
                                title: Text(
                                  t('delete_favs'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.redAccent
                                  )
                                ),
                                onTap: () {
                                  HapticFeedback.heavyImpact();
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
                                      title: Text(t('delete_favs')),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: Text(t('cancel'))
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            final prefs = await SharedPreferences.getInstance();
                                            await prefs.remove('naviyork_favorites');
                                            setState(() {
                                              _favorites.clear();
                                              _buildAttractionMarkers();
                                            });
                                            if (!ctx.mounted) return;
                                            Navigator.pop(ctx);
                                            _showToastNotification(t('delete_favs'), Icons.delete, Colors.redAccent);
                                          }, 
                                          child: Text(t('delete'), style: const TextStyle(color: Colors.redAccent))
                                        ),
                                      ],
                                    )
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // HOTEL BUTTON
          if (_hotelLocation != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton(
                heroTag: 'hotelBtn',
                backgroundColor: Colors.indigoAccent,
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _animatedMapMove(_hotelLocation!, 15.0);
                  Future.delayed(const Duration(milliseconds: 600), () => _showHotelOptions());
                },
                child: const Icon(Icons.bed, color: Colors.white, size: 24), 
              ),
            ),
          FloatingActionButton(
            heroTag: 'subwayLayer',
            backgroundColor: _showSubwayLines ? Colors.blueAccent : (isDarkMode ? Colors.grey.shade800 : Colors.white),
            mini: true,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                _showSubwayLines = !_showSubwayLines;
              });
            },
            child: Icon(
              Icons.directions_subway_outlined,
              color: _showSubwayLines ? Colors.white : (isDarkMode ? Colors.white : Colors.black87),
              size: 20
            ), 
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'bikeLayer',
            backgroundColor: _showCitiBikes ? Colors.blueAccent : (isDarkMode ? Colors.grey.shade800 : Colors.white),
            mini: true,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                _showCitiBikes = !_showCitiBikes;
              });
            },
            child: Icon(
              Icons.pedal_bike,
              color: _showCitiBikes ? Colors.white : (isDarkMode ? Colors.white : Colors.black87),
              size: 20
            ), 
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'sosLayer',
            backgroundColor: _isSurvivalModeActive ? Colors.redAccent : (isDarkMode ? Colors.grey.shade800 : Colors.white),
            mini: true,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
            onPressed: _toggleSurvivalMode,
            child: Icon(
              Icons.health_and_safety,
              color: _isSurvivalModeActive ? Colors.white : Colors.redAccent,
              size: 20
            ), 
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'tiltLayer',
            backgroundColor: _is3DMode ? Colors.blueAccent : (isDarkMode ? Colors.grey.shade800 : Colors.white),
            mini: true,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
            onPressed: _toggle3DMode,
            child: Text(
              _is3DMode ? '2D' : '3D',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _is3DMode ? Colors.white : (isDarkMode ? Colors.white : Colors.black87)
              )
            ), 
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'locationBtn',
            backgroundColor: _isTracking ? Colors.blueAccent : (isDarkMode ? Colors.grey.shade800 : Colors.white),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), 
            onPressed: _toggleTracking,
            child: Icon(
              _isTracking ? Icons.my_location : Icons.near_me_outlined,
              color: _isTracking ? Colors.white : (isDarkMode ? Colors.white : Colors.black87)
            ), 
          ),
        ],
      ),
      
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _tiltAnimation,
            builder: (context, child) { 
              return Transform.scale(
                scale: 1.0 + (_tiltAnimation.value * 0.35),
                child: Transform(
                  alignment: Alignment.center, 
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateX(-_tiltAnimation.value * 0.85), 
                  child: child
                )
              ); 
            },
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _nycCenter,
                initialZoom: 13.5,
                minZoom: 11.0,
                maxZoom: 18.0,
                onLongPress: (tapPosition, point) {
                  _showSetHotelDialog(point);
                },
                onTap: (tapPosition, point) {
                  if (_isSearchActive) { _closeSearch(); }
                  if (_selectedAttractionName != null) {
                    setState(() {
                      _selectedAttractionName = null;
                      _buildAttractionMarkers();
                    });
                  }
                },
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture && _isTracking) {
                    setState(() { _isTracking = false; });
                  }
                  bool isNowZoomedIn = camera.zoom > 13.5;
                  bool wasZoomedIn = _currentZoom > 13.5;
                  if (isNowZoomedIn != wasZoomedIn || _currentRotation != camera.rotation) {
                    setState(() {
                      _currentZoom = camera.zoom;
                      _currentRotation = camera.rotation;
                    });
                  } else {
                    _currentZoom = camera.zoom;
                    _currentRotation = camera.rotation;
                  }
                  if (hasGesture && _isSearchActive) {
                    _closeSearch();
                  }
                },
              ),
              children: [
                TileLayer(urlTemplate: mapUrl, userAgentPackageName: 'com.pascal.naviyork'),
                if (_selectedTour != null) MarkerLayer(markers: _getTourMarkers()), 
                if (_isSurvivalModeActive)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: const [
                          LatLng(90, -180),
                          LatLng(90, 180),
                          LatLng(-90, 180),
                          LatLng(-90, -180)
                        ],
                        color: Colors.black.withValues(alpha: isDarkMode ? 0.6 : 0.4)
                      )
                    ]
                  ),
                if (_showSubwayLines) PolylineLayer(polylines: _subwayPolylines),
                if (_showSubwayLines && _currentZoom > 13.5) MarkerLayer(markers: _stationMarkers),
                if (_showCitiBikes && _currentZoom > 13.5) MarkerLayer(markers: _citiBikeMarkers),
                if (_selectedTour == null) MarkerLayer(markers: _attractionMarkers), 
                if (_currentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLocation!,
                        width: 140,
                        height: 140,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _radarAnimation,
                              builder: (context, child) {
                                return Container(
                                  width: 140 * _radarAnimation.value,
                                  height: 140 * _radarAnimation.value,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.blueAccent.withValues(alpha: (1.0 - _radarAnimation.value) * 0.4),
                                    border: Border.all(
                                      color: Colors.blueAccent.withValues(alpha: (1.0 - _radarAnimation.value) * 0.8),
                                      width: 1.5
                                    )
                                  )
                                );
                              }
                            ),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.blueAccent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2)
                                  )
                                ]
                              )
                            )
                          ]
                        )
                      )
                    ]
                  ),
              ],
            ),
          ),
          
          AnimatedBuilder(
            animation: _searchBlurAnimation,
            builder: (context, child) {
              if (_searchBlurAnimation.value == 0.0) return const SizedBox.shrink();
              return Positioned.fill(
                child: GestureDetector(
                  onTap: _closeSearch,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 20.0 * _searchBlurAnimation.value,
                      sigmaY: 20.0 * _searchBlurAnimation.value
                    ),
                    child: Container(
                      color: isDarkMode ? Colors.black.withValues(alpha: 0.4 * _searchBlurAnimation.value) : Colors.white.withValues(alpha: 0.2 * _searchBlurAnimation.value)
                    )
                  )
                )
              );
            },
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), 
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey.shade900.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDarkMode ? Colors.white12 : Colors.black12,
                      width: 0.5
                    )
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _isSearchActive 
                      ? Row(
                          key: const ValueKey('search_active'),
                          children: [
                            IconButton(
                              icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black87),
                              onPressed: _closeSearch
                            ),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                autofocus: true,
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500
                                ),
                                decoration: InputDecoration(
                                  hintText: t('search'),
                                  hintStyle: TextStyle(color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500),
                                  border: InputBorder.none
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value;
                                  });
                                }
                              )
                            ),
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                icon: Icon(Icons.clear, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500),
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _searchController.clear();
                                  });
                                }
                              )
                          ]
                        )
                      : Row(
                          key: const ValueKey('search_inactive'),
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: Icon(Icons.menu, color: isDarkMode ? Colors.white : Colors.black87),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                _scaffoldKey.currentState?.openDrawer();
                              }
                            ),
                            Text(
                              'NaviYork',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black87,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8
                              )
                            ),
                            IconButton(
                              icon: Icon(Icons.search, color: isDarkMode ? Colors.white : Colors.black87),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _isSearchActive = true;
                                });
                                _searchBlurController.forward();
                                Future.delayed(const Duration(milliseconds: 50), () {
                                  _searchFocusNode.requestFocus();
                                });
                              }
                            )
                          ]
                        ),
                  ),
                ),
              ),
            ),
          ),
          
          if (!_isSearchActive)
            Positioned(
              top: MediaQuery.of(context).padding.top + 72,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(), 
                  children: [
                    _buildFilterPill(
                      title: t('favorites'),
                      icon: Icons.star_rounded,
                      isActive: _showFavoritesLayer,
                      isDark: isDarkMode,
                      onTap: () {
                        setState(() {
                          _showFavoritesLayer = !_showFavoritesLayer;
                          _buildAttractionMarkers();
                        });
                      }
                    ),
                    ..._categoryVisibility.keys.map((cat) {
                      return _buildFilterPill(
                        title: cat,
                        icon: _getCategoryIcon(cat),
                        isActive: _categoryVisibility[cat] ?? true,
                        isDark: isDarkMode,
                        onTap: () {
                          setState(() {
                            _categoryVisibility[cat] = !(_categoryVisibility[cat] ?? true);
                            _buildAttractionMarkers();
                          });
                        }
                      );
                    }),
                  ],
                ),
              ),
            ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            bottom: (_showToursList && !_isSearchActive && _allTours.isNotEmpty) ? 140 : -200,
            left: 0,
            right: 0,
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal, 
              padding: const EdgeInsets.symmetric(horizontal: 16), 
              itemCount: _allTours.length, 
              itemBuilder: (context, index) {
                final tour = _allTours[index]; 
                bool isSelected = _selectedTour == tour;
                bool anythingSelected = _selectedTour != null;

                return GestureDetector(
                  onTap: () { 
                    if (isSelected) {
                      _showTourDetails(tour); 
                    } else { 
                      setState(() => _selectedTour = tour); 
                      List<dynamic> pts = tour['points'];
                      double minLat = pts.first['lat'];
                      double maxLat = pts.first['lat'];
                      double minLng = pts.first['lng'];
                      double maxLng = pts.first['lng'];
                      for (var p in pts) {
                        if (p['lat'] < minLat) { minLat = p['lat']; }
                        if (p['lat'] > maxLat) { maxLat = p['lat']; }
                        if (p['lng'] < minLng) { minLng = p['lng']; }
                        if (p['lng'] > maxLng) { maxLng = p['lng']; }
                      }
                      double centerLat = (minLat + maxLat) / 2;
                      double centerLng = (minLng + maxLng) / 2;
                      centerLat -= 0.008; 
                      double maxDiff = math.max(maxLat - minLat, maxLng - minLng);
                      double tZoom = 13.5;
                      if (maxDiff > 0.06) {
                        tZoom = 12.0;
                      } else if (maxDiff > 0.04) {
                        tZoom = 13.0;
                      } else if (maxDiff > 0.02) {
                        tZoom = 13.5;
                      } else {
                        tZoom = 14.5;
                      }
                      
                      _animatedMapMove(LatLng(centerLat, centerLng), tZoom); 
                    } 
                  }, 
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: (!anythingSelected || isSelected) ? 1.0 : 0.4,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      scale: (!anythingSelected || isSelected) ? 1.0 : 0.95,
                      child: Container(
                        width: 220,
                        margin: const EdgeInsets.only(right: 14), 
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24), 
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 15,
                              offset: const Offset(0, 8)
                            )
                          ]
                        ), 
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24), 
                          child: Stack(
                            fit: StackFit.expand, 
                            children: [
                              _buildTourImage(tour),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)]
                                  )
                                )
                              ), 
                              Padding(
                                padding: const EdgeInsets.all(16), 
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start, 
                                  mainAxisAlignment: MainAxisAlignment.end, 
                                  children: [
                                    Text(
                                      tour['title'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                        letterSpacing: -0.5
                                      )
                                    ), 
                                    const SizedBox(height: 4),
                                    Text(
                                      "${tour['duration']} • ${tour['distance']}",
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600
                                      )
                                    )
                                  ]
                                )
                              )
                            ]
                          )
                        )
                      )
                    )
                  )
                );
              }
            )
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            bottom: (!_isSearchActive && _allTours.isNotEmpty) ? 85 : -100, 
            left: 16,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() { 
                  _showToursList = !_showToursList; 
                  if (!_showToursList) {
                    _selectedTour = null;
                  }
                });
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey.shade900.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDarkMode ? Colors.white12 : Colors.black12,
                        width: 0.5
                      )
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.explore,
                          size: 18,
                          color: _showToursList ? Colors.blueAccent : (isDarkMode ? Colors.white : Colors.black87)
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _showToursList ? t('end_tour') : t('tours'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _showToursList ? Colors.blueAccent : (isDarkMode ? Colors.white : Colors.black87)
                          )
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _showToursList ? Icons.close : Icons.keyboard_arrow_up,
                          size: 18,
                          color: _showToursList ? Colors.blueAccent : (isDarkMode ? Colors.white : Colors.black87)
                        )
                      ]
                    )
                  )
                )
              )
            )
          ),

          if (!_isSearchActive && _currentWarningText != null && !_userDismissedWarning)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              top: MediaQuery.of(context).padding.top + 125,
              left: 16,
              right: 16,
              child: Dismissible(
                key: ValueKey(_currentWarningText!),
                direction: DismissDirection.horizontal,
                onDismissed: (_) {
                  setState(() {
                    _userDismissedWarning = true;
                  });
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey.shade900.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _currentWarningColor!.withValues(alpha: 0.6),
                          width: 1.5
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _currentWarningColor!.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4)
                          )
                        ]
                      ),
                      child: Row(
                        children: [
                          Icon(_currentWarningIcon, color: _currentWarningColor, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _currentWarningText!,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDarkMode ? Colors.white : Colors.black87,
                                height: 1.3
                              )
                            )
                          ),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _userDismissedWarning = true;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500
                              )
                            ),
                          )
                        ]
                      )
                    )
                  )
                )
              )
            ),

          if (!_isSearchActive && _nycTimeString.isNotEmpty && !_isSurvivalModeActive)
            Positioned(
              bottom: 30,
              left: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey.shade900.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDarkMode ? Colors.white12 : Colors.black12,
                        width: 0.5
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4)
                        )
                      ]
                    ),
                    child: Text(
                      '$_nycTimeString  •  $_nycWeatherString',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDarkMode ? Colors.white : Colors.black87
                      )
                    )
                  )
                )
              )
            ),

          if (_currentRotation.abs() > 0.1 && !_isSearchActive) 
            Positioned(
              top: MediaQuery.of(context).padding.top + (_currentWarningText != null && !_userDismissedWarning ? 190 : 125),
              right: 16,
              child: FloatingActionButton(
                heroTag: 'compassBtn',
                mini: true,
                backgroundColor: isDarkMode ? Colors.grey.shade800.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
                elevation: 4,
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _mapController.rotate(0.0);
                  setState(() => _currentRotation = 0.0);
                },
                child: Transform.rotate(
                  angle: -_currentRotation * (math.pi / 180),
                  child: const Icon(Icons.navigation, color: Colors.redAccent, size: 22)
                )
              )
            ),

          if (_isSearchActive && _searchQuery.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 16,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey.shade900.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDarkMode ? Colors.white12 : Colors.black12,
                        width: 0.5
                      )
                    ),
                    child: searchResults.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(
                              t('search'), 
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600
                              )
                            )
                          )
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: searchResults.length,
                            itemBuilder: (context, index) {
                              final attr = searchResults[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                                  child: Icon(
                                    Icons.place,
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                    size: 20
                                  )
                                ),
                                title: Text(
                                  attr['name'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode ? Colors.white : Colors.black87
                                  )
                                ),
                                subtitle: Text(
                                  attr['category'],
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600
                                  )
                                ),
                                onTap: () => _navigateToAttraction(attr, fromMenu: false)
                              );
                            }
                          )
                  )
                )
              )
            ),
        ],
      ),
    );
  }
}