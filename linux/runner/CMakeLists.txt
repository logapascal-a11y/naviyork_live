import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NaviYork',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1C1C1E),
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.5),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1C1C1E),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final LatLng _nycCenter = const LatLng(40.7500, -73.9850); 
  final LatLngBounds _nycBounds = LatLngBounds(
    const LatLng(40.4774, -74.2589),
    const LatLng(40.9176, -73.7004),
  );

  bool _showSubwayLines = false;
  bool _showCitiBikes = false; 
  bool _showOnlyFavorites = false; 
  
  List<Polyline> _subwayPolylines = [];
  List<Marker> _stationMarkers = [];
  List<Marker> _citiBikeMarkers = []; 
  
  List<Map<String, dynamic>> _allAttractions = [];
  List<Marker> _attractionMarkers = [];
  Map<String, bool> _categoryVisibility = {}; 
  Set<String> _favorites = {}; 

  @override
  void initState() {
    super.initState();
    _loadSubwayData();
    _loadAttractions();
    _loadCitiBikes(); 
  }

  Future<void> _loadCitiBikes() async {
    try {
      final String response = await rootBundle.loadString('assets/citibike.json');
      final data = await json.decode(response);
      List<Marker> loadedMarkers = [];

      if (data['data'] != null && data['data']['stations'] != null) {
        for (var station in data['data']['stations']) {
          double lat = (station['lat'] as num).toDouble();
          double lon = (station['lon'] as num).toDouble(); 
          String name = station['name'] ?? 'Citi Bike Station';
          int capacity = station['capacity'] ?? 0; 
          
          loadedMarkers.add(
            Marker(
              point: LatLng(lat, lon),
              width: 32, height: 32, 
              child: GestureDetector(
                onTap: () => _showCitiBikeDetails(context, name, capacity, lat, lon),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600, 
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: const Icon(Icons.pedal_bike, color: Colors.white, size: 16),
                ),
              ),
            )
          );
        }
      }
      setState(() {
        _citiBikeMarkers = loadedMarkers;
      });
    } catch (e) {
      debugPrint("Fehler beim Laden der Citi Bikes: $e");
    }
  }

  void _showCitiBikeDetails(BuildContext context, String name, int capacity, double lat, double lng) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8), 
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)), 
                    child: Icon(Icons.pedal_bike, color: Colors.blue.shade600, size: 28)
                  ),
                  const SizedBox(width: 16), 
                  Expanded(child: Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5))),
                ],
              ),
              const SizedBox(height: 12),
              Text('Fahrrad-Docks hier: $capacity', style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity, height: 54, 
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  icon: const Icon(Icons.directions_outlined, color: Colors.white), 
                  label: const Text('Route berechnen', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)), 
                  onPressed: () { Navigator.pop(context); _routeTo(lat, lng); }
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    String cat = category.toLowerCase();
    if (cat.contains('aussicht') || cat.contains('view')) return Icons.visibility_outlined;
    if (cat.contains('museum') || cat.contains('museen') || cat.contains('kunst')) return Icons.account_balance_outlined;
    if (cat.contains('park') || cat.contains('natur')) return Icons.park_outlined;
    if (cat.contains('essen') || cat.contains('food')) return Icons.restaurant_outlined;
    if (cat.contains('shop') || cat.contains('kauf')) return Icons.shopping_bag_outlined;
    if (cat.contains('tour') || cat.contains('boot')) return Icons.directions_boat_outlined;
    return Icons.place_outlined; 
  }

  List<String> _smartCsvSplit(String line, String separator) {
    List<String> row = [];
    StringBuffer current = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      if (line[i] == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          current.write('"'); 
          i++; 
        } else {
          inQuotes = !inQuotes; 
        }
      } else if (line[i] == separator && !inQuotes) {
        row.add(current.toString().trim());
        current.clear();
      } else {
        current.write(line[i]);
      }
    }
    row.add(current.toString().trim());
    return row;
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
          if (char == '\r' && i + 1 < response.length && response[i + 1] == '\n') i++; 
          currentRow.add(currentCell.toString().trim());
          currentCell.clear();
          if (currentRow.isNotEmpty && currentRow.length > 3) rows.add(List.from(currentRow));
          currentRow.clear();
        } else {
          currentCell.write(char);
        }
      }
      if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
        currentRow.add(currentCell.toString().trim());
        if (currentRow.length > 3) rows.add(List.from(currentRow));
      }

      for (var row in rows) {
        if (row.length < 7 || row[0].toLowerCase().contains('name') || row[0].toLowerCase().contains('tabelle')) continue;
        
        String name = row[0];
        String category = row[1].replaceAll('"', '').trim(); 
        if (category.isEmpty) category = "Sonstiges";
        
        double lat = double.tryParse(row[3].replaceAll(',', '.')) ?? 0.0;
        double lng = double.tryParse(row[4].replaceAll(',', '.')) ?? 0.0;
        if (lng > 0) lng = -lng; 
        
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
          });
        }
      }
      
      setState(() {
        _allAttractions = loadedData;
        _categoryVisibility = categories;
        _buildAttractionMarkers(); 
      });
    } catch (e) {
      debugPrint("Fehler beim Laden der Attraktionen: $e");
    }
  }

  void _buildAttractionMarkers() {
    List<Marker> markers = [];
    for (var attr in _allAttractions) {
      String cat = attr['category'];
      String name = attr['name'];
      
      bool isFavorite = _favorites.contains(name);
      if (_showOnlyFavorites && !isFavorite) continue;
      if (_categoryVisibility[cat] == false) continue;
      
      markers.add(
        Marker(
          point: LatLng(attr['lat'], attr['lng']),
          width: 45, height: 45,
          child: GestureDetector(
            onTap: () => _showAttractionDetails(context, attr),
            child: Container(
              decoration: BoxDecoration(
                color: isFavorite ? Colors.amber : const Color(0xFF1C1C1E), 
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Icon(
                isFavorite ? Icons.star_rounded : _getCategoryIcon(cat), 
                color: Colors.white, 
                size: 22
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

  Widget _buildDescriptionWidget(String text) {
    const String highlight = "Dein NaviYork Insider-Tipp:";
    if (text.contains(highlight)) {
      List<String> parts = text.split(highlight);
      return RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 16, color: Colors.grey.shade700, height: 1.4, fontFamily: 'San Francisco'),
          children: [
            if (parts[0].isNotEmpty) TextSpan(text: parts[0]),
            const TextSpan(
              text: highlight, 
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)
            ),
            TextSpan(text: parts[1]),
          ],
        ),
      );
    }
    return Text(text, style: TextStyle(fontSize: 16, color: Colors.grey.shade700, height: 1.4));
  }

  void _showAttractionDetails(BuildContext context, Map<String, dynamic> attr) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext modalContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            bool isFav = _favorites.contains(attr['name']);
            
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (attr['imageUrl'].toString().isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: Image.network(
                        attr['imageUrl'],
                        height: 220, width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(height: 220, color: Colors.grey.shade200, child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40)),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text(attr['category'].toString().toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                            ),
                            if (attr['price'].toString().isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.sell_outlined, size: 14, color: Colors.green),
                                    const SizedBox(width: 4),
                                    Text('${attr['price']} €', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(attr['name'], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                            ),
                            IconButton(
                              icon: Icon(
                                isFav ? Icons.star_rounded : Icons.star_border_rounded,
                                color: isFav ? Colors.amber : Colors.grey.shade400,
                                size: 36,
                              ),
                              onPressed: () {
                                setState(() {
                                  if (isFav) _favorites.remove(attr['name']);
                                  else _favorites.add(attr['name']);
                                  _buildAttractionMarkers();
                                });
                                setModalState(() {});
                              },
                            )
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        _buildDescriptionWidget(attr['description']),
                        const SizedBox(height: 24),
                        
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.local_activity_outlined, color: Colors.white),
                            label: const Text('Tickets & Infos ansehen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            onPressed: () {
                              Navigator.pop(context);
                              _launchUrl(attr['affiliateUrl']); 
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent, 
                            ),
                            icon: const Icon(Icons.directions_outlined, color: Colors.white),
                            label: const Text('Route hierher berechnen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            onPressed: () {
                              Navigator.pop(context);
                              _routeTo(attr['lat'], attr['lng']); 
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) debugPrint('Link blockiert.');
  }

  Future<void> _routeTo(double lat, double lng) async {
    final Uri appleUrl = Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&dirflg=r'); 
    if (await canLaunchUrl(appleUrl)) await launchUrl(appleUrl);
    else await launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=transit'));
  }

  Color _getSubwayColor(String name) {
    if (name.isEmpty) return Colors.grey.withOpacity(0.5);
    name = name.toUpperCase();
    if (RegExp(r'\b(1|2|3)\b').hasMatch(name)) return const Color(0xFFEE352E); 
    if (RegExp(r'\b(4|5|6)\b').hasMatch(name)) return const Color(0xFF00933C); 
    if (RegExp(r'\b(7)\b').hasMatch(name)) return const Color(0xFFB933AD); 
    if (RegExp(r'\b(A|C|E)\b').hasMatch(name)) return const Color(0xFF0039A6); 
    if (RegExp(r'\b(B|D|F|M)\b').hasMatch(name)) return const Color(0xFFFF6319); 
    if (RegExp(r'\b(N|Q|R|W)\b').hasMatch(name)) return const Color(0xFFFCCC0A); 
    if (RegExp(r'\b(G)\b').hasMatch(name)) return const Color(0xFF6CBE45); 
    if (RegExp(r'\b(J|Z)\b').hasMatch(name)) return const Color(0xFF996633); 
    if (RegExp(r'\b(L)\b').hasMatch(name)) return const Color(0xFFA7A9AC); 
    if (RegExp(r'\b(S)\b').hasMatch(name)) return const Color(0xFF808183); 
    return Colors.grey.withOpacity(0.5); 
  }

  Future<void> _loadSubwayData() async {
    try {
      final String linesRes = await rootBundle.loadString('assets/subway.json');
      final linesData = await json.decode(linesRes);
      List<Polyline> loadedLines = [];
      if (linesData['features'] != null) {
        for (var f in linesData['features']) {
          if (f['geometry'] == null || f['geometry']['coordinates'] == null) continue;
          var props = f['properties'] ?? {};
          String lName = props['rt_symbol']?.toString() ?? props['route_id']?.toString() ?? props['name']?.toString() ?? '';
          if (lName.isEmpty) {
            props.forEach((key, value) {
              if (value is String && value.length < 5) lName += " $value";
            });
          }
          Color lColor = _getSubwayColor(lName);
          if (f['geometry']['type'] == 'LineString') {
            List<LatLng> pts = [];
            for (var c in f['geometry']['coordinates']) { if (c != null && c.length >= 2) pts.add(LatLng(c[1], c[0])); }
            loadedLines.add(Polyline(points: pts, color: lColor, strokeWidth: 4.0));
          } else if (f['geometry']['type'] == 'MultiLineString') {
            for (var l in f['geometry']['coordinates']) {
              if (l == null) continue;
              List<LatLng> pts = [];
              for (var c in l) { if (c != null && c.length >= 2) pts.add(LatLng(c[1], c[0])); }
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
            loadedSt.add(Marker(
              point: LatLng(lat, lng), width: 80, height: 30,
              child: GestureDetector(
                onTap: () => _showSubwayStationDetails(context, sName, lines, lat, lng),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 1.5))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade300, width: 0.5)),
                      child: Text(dName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ));
          }
        }
      }
      setState(() { _subwayPolylines = loadedLines; _stationMarkers = loadedSt; });
    } catch (e) { debugPrint("Subway Fehler: $e"); }
  }

  void _showSubwayStationDetails(BuildContext context, String name, String lines, double lat, double lng) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.directions_subway_outlined, color: Colors.black87, size: 28)),
                  const SizedBox(width: 16), Expanded(child: Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5))),
                ],
              ),
              const SizedBox(height: 12),
              Text('Linien: $lines', style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity, height: 54, 
                child: ElevatedButton.icon(icon: const Icon(Icons.directions_outlined, color: Colors.white), label: const Text('Route berechnen', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)), onPressed: () { Navigator.pop(context); _routeTo(lat, lng); }),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    Position p = await Geolocator.getCurrentPosition();
    _mapController.move(LatLng(p.latitude, p.longitude), 15.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NaviYork')),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            Container(
              height: 120, width: double.infinity,
              decoration: const BoxDecoration(color: Color(0xFF1C1C1E)),
              alignment: Alignment.bottomLeft, padding: const EdgeInsets.fromLTRB(24, 0, 0, 20),
              child: const Text('Menü', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Text('NAVIGATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                  ),
                  
                  SwitchListTile(
                    secondary: const Icon(Icons.star_rounded, color: Colors.amber),
                    title: const FittedBox(
                      fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                      child: Text('Nur Favoriten zeigen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    ),
                    value: _showOnlyFavorites,
                    activeColor: Colors.amber,
                    onChanged: (bool value) {
                      setState(() {
                        _showOnlyFavorites = value;
                        _buildAttractionMarkers(); 
                      });
                      Navigator.pop(context); 
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.directions_subway_outlined, color: Colors.black87),
                    title: const Text('U-Bahn Netz', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    value: _showSubwayLines,
                    activeColor: const Color(0xFF1C1C1E),
                    onChanged: (bool value) {
                      setState(() => _showSubwayLines = value);
                      Navigator.pop(context);
                    },
                  ),
                  
                  SwitchListTile(
                    secondary: const Icon(Icons.pedal_bike, color: Colors.blue),
                    title: const Text('Citi Bikes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    value: _showCitiBikes,
                    activeColor: Colors.blue.shade600,
                    onChanged: (bool value) {
                      setState(() => _showCitiBikes = value);
                      Navigator.pop(context);
                    },
                  ),
                  
                  const Divider(height: 30),
                  
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Text('KATEGORIEN FILTERN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                  ),
                  ..._categoryVisibility.keys.map((String category) {
                    return SwitchListTile(
                      secondary: Icon(_getCategoryIcon(category), color: Colors.black87),
                      title: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(category, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      ),
                      value: _categoryVisibility[category]!,
                      activeColor: const Color(0xFF1C1C1E),
                      onChanged: (bool value) {
                        setState(() {
                          _categoryVisibility[category] = value;
                          _buildAttractionMarkers(); 
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
        child: const Icon(Icons.near_me_outlined, color: Colors.black87), onPressed: _getCurrentLocation,
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(initialCenter: _nycCenter, initialZoom: 13.5, minZoom: 11.0, maxZoom: 18.0, cameraConstraint: CameraConstraint.contain(bounds: _nycBounds)),
        children: [
          TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png', userAgentPackageName: 'com.pascal.naviyork'),
          MarkerLayer(markers: _attractionMarkers), 
          
          // --- HIER IST DIE SPERRE KOMPLETT WEG! ---
          if (_showSubwayLines) PolylineLayer(polylines: _subwayPolylines),
          if (_showSubwayLines) MarkerLayer(markers: _stationMarkers),
          if (_showCitiBikes) MarkerLayer(markers: _citiBikeMarkers),
        ],
      ),
    );
  }
}