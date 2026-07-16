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
  String _mareaText = "40 cm (S)";
  int _cmMarea = 40;
  double _speed = 0.0;
  double _heading = 0.0;
  LatLng _pos = const LatLng(45.4371, 12.3326);
  final MapController _mapController = MapController();
  bool _isActive = false;

  // --- LOGICA MAREA "RAW BYPASS" ---
  Future<void> _fetchMareaLive() async {
    setState(() => _mareaText = "...");
    // URL originale e Proxy AllOrigins in modalità RAW (senza filtri)
    const String target =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1";
    final String proxyUrl =
        "https://api.allorigins.win/raw?url=${Uri.encodeComponent(target)}";

    try {
      final res = await http
          .get(Uri.parse(proxyUrl))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        // Leggiamo la risposta come testo puro
        final List data = json.decode(res.body);
        if (data.isNotEmpty) {
          setState(() {
            _cmMarea =
                int.parse(data[0]['valore'].toString().replaceAll('+', ''));
            _mareaText = "$_cmMarea cm (L)"; // L = Live (Reale!)
          });
          return;
        }
      }
    } catch (e) {
      debugPrint("Errore: $e");
    }
    setState(
        () => _mareaText = "$_cmMarea cm (S)"); // Resta in simulato se fallisce
  }

  // --- LOGICA PROFONDITÀ ---
  double _getDepth(LatLng p) {
    double base = 1.2;
    if (p.latitude < 45.433 && p.latitude > 45.425)
      base = 12.0; // Canale Giudecca
    else if (p.latitude > 45.450) base = 4.0; // Murano/Burano
    return base + (_cmMarea / 100);
  }

  Future<void> _attiva() async {
    _fetchMareaLive();
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
          if (_speed > 1.5) _heading = pos.heading; // COG (Course Over Ground)
        });
        _mapController.move(_pos, 15);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double prof = _getDepth(_pos);

    return Scaffold(
      backgroundColor: const Color(0xFF000A12),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _pos, initialZoom: 15),
            children: [
              TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              // LIVELLO NAUTICO (Briccole e segnalamenti)
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
                        color: Colors.blue, size: 45),
                  ),
                )
              ]),
            ],
          ),

          // DASHBOARD (Alta visibilità)
          Positioned(
            top: 50,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF001529).withOpacity(0.9),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                    color: _mareaText.contains("(L)")
                        ? Colors.cyanAccent
                        : Colors.orangeAccent,
                    width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat("MAREA", _mareaText, Colors.cyanAccent),
                  _stat("PROF.", "${prof.toStringAsFixed(1)}m", Colors.white),
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
                child: const Icon(Icons.explore, color: Colors.white, size: 50),
              ),
            ),
          ),

          if (!_isActive)
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.anchor, size: 30),
                label: const Text("ATTIVA SISTEMA"),
                onPressed: _attiva,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.all(25),
                ),
              ),
            ),

          // TASTO SYNC MANUALE (In caso di S)
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white24,
              child: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _fetchMareaLive,
            ),
          )
        ],
      ),
    );
  }

  Widget _stat(String l, String v, Color c) => Column(children: [
        Text(l,
            style: const TextStyle(
                color: Colors.white60,
                fontSize: 8,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(v,
            style: TextStyle(
                color: c,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace')),
      ]);
}
