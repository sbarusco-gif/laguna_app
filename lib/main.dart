import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

void main() => runApp(
    const MaterialApp(home: LagunaApp(), debugShowCheckedModeBanner: false));

class LagunaApp extends StatefulWidget {
  const LagunaApp({super.key});
  @override
  State<LagunaApp> createState() => _LagunaAppState();
}

class _LagunaAppState extends State<LagunaApp> {
  String _mareaText = "---";
  int _cmMarea = 0;
  double _speed = 0.0;
  double _heading = 0.0;
  LatLng _pos = const LatLng(45.4371, 12.3326);
  final MapController _mapController = MapController();
  bool _isActive = false;

  // --- LOGICA PROFONDITÀ DINAMICA ---
  double _getDepth(LatLng p) {
    double base = 1.2; // Secche
    // Canale della Giudecca
    if (p.latitude < 45.433 &&
        p.latitude > 45.425 &&
        p.longitude > 12.310 &&
        p.longitude < 12.365)
      base = 12.0;
    // Canale Grande
    else if (p.latitude < 45.445 &&
        p.latitude > 45.432 &&
        p.longitude > 12.325 &&
        p.longitude < 12.348)
      base = 5.0;
    // Murano/Burano
    else if (p.latitude > 45.450) base = 4.0;

    return base + (_cmMarea / 100);
  }

  Future<void> _fetchMarea() async {
    const String target =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1";
    final String proxy =
        "https://api.allorigins.win/get?url=${Uri.encodeComponent(target)}";
    try {
      final res =
          await http.get(Uri.parse(proxy)).timeout(const Duration(seconds: 7));
      final data = json.decode(json.decode(res.body)['contents']);
      setState(() {
        _cmMarea = int.parse(data[0]['valore'].toString().replaceAll('+', ''));
        _mareaText = "$_cmMarea cm";
      });
    } catch (e) {
      setState(() => _mareaText = "40 cm (S)");
    }
  }

  void _attivaNavigatore() async {
    _fetchMarea();
    LocationPermission p = await Geolocator.requestPermission();
    if (p == LocationPermission.always || p == LocationPermission.whileInUse) {
      setState(() => _isActive = true);
      Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.bestForNavigation,
                  distanceFilter: 2))
          .listen((Position pos) {
        setState(() {
          _pos = LatLng(pos.latitude, pos.longitude);
          _speed = pos.speed * 3.6;
          if (_speed > 1.5)
            _heading = pos.heading; // Aggiorna rotta solo in movimento
        });
        _mapController.move(_pos, 15);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double prof = _getDepth(_pos);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. MAPPA (Sempre visibile)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _pos, initialZoom: 14),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'it.venezia.laguna',
              ),
              // LIVELLO NAUTICO (Briccole e batimetriche tratteggiate)
              TileLayer(
                urlTemplate:
                    'https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png',
                backgroundColor: Colors.transparent,
              ),
              MarkerLayer(markers: [
                Marker(
                  point: _pos,
                  width: 60,
                  height: 60,
                  child: Transform.rotate(
                    angle: (_heading * (math.pi / 180)),
                    child: const Icon(Icons.navigation,
                        color: Colors.red, size: 45),
                  ),
                )
              ]),
            ],
          ),

          // 2. DASHBOARD (4 STATS)
          Positioned(
            top: 40,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF001529).withOpacity(0.9),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                    color: prof < 2.0 ? Colors.red : Colors.cyanAccent,
                    width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _stat("MAREA", _mareaText, Colors.cyanAccent),
                  _stat("PROF.", "${prof.toStringAsFixed(1)}m",
                      prof < 2.0 ? Colors.red : Colors.white),
                  _stat("ROTTA", "${_heading.toInt()}°", Colors.orangeAccent),
                  _stat("KM/H", _speed.toStringAsFixed(1), Colors.greenAccent),
                ],
              ),
            ),
          ),

          // BUSSOLA VISIVA
          Positioned(
            bottom: 30,
            left: 20,
            child: Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
              child: Transform.rotate(
                angle: (_heading * (math.pi / 180) * -1),
                child: const Icon(Icons.explore, color: Colors.white, size: 55),
              ),
            ),
          ),

          if (!_isActive)
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_circle_fill, size: 40),
                label: const Text("AVVIA SISTEMA NAUTICO",
                    style: TextStyle(fontSize: 18)),
                onPressed: _attivaNavigatore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.all(25),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String l, String v, Color c) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l,
              style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 8,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(v,
              style: TextStyle(
                  color: c,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace')),
        ],
      );
}
