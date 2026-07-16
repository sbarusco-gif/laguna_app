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
  String _marea = "---";
  double _speed = 0.0;
  double _heading = 0.0; // Direzione GPS (Course Over Ground)
  LatLng _pos = const LatLng(45.4371, 12.3326);
  final MapController _mapController = MapController();
  bool _isLive = false;

  // --- LOGICA MAREA ---
  Future<void> _fetchMarea() async {
    const String target =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1";
    final String proxy =
        "https://api.allorigins.win/raw?url=${Uri.encodeComponent(target)}";
    try {
      final res =
          await http.get(Uri.parse(proxy)).timeout(const Duration(seconds: 7));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        setState(() {
          _marea = "${data[0]['valore'].toString().replaceAll('+', '')} cm";
        });
      }
    } catch (e) {
      setState(() => _marea = "45 cm (S)");
    }
  }

  // --- ATTIVAZIONE GPS E BUSSOLA DI MOVIMENTO ---
  void _iniziaNavigazione() async {
    _fetchMarea();
    LocationPermission p = await Geolocator.requestPermission();
    if (p == LocationPermission.always || p == LocationPermission.whileInUse) {
      setState(() => _isLive = true);

      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 2, // Aggiorna ogni 2 metri
        ),
      ).listen((Position pos) {
        setState(() {
          _pos = LatLng(pos.latitude, pos.longitude);
          _speed = pos.speed * 3.6; // km/h

          // USA LA DIREZIONE DEL MOVIMENTO (Heading GPS)
          // Funziona solo se ci si muove > 1 km/h
          if (_speed > 1.0) {
            _heading = pos.heading;
          }
        });
        _mapController.move(_pos, 15);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              TileLayer(
                  urlTemplate:
                      'https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png',
                  backgroundColor: Colors.transparent),

              // FRECCIA BARCA (RUOTA CON LA TUA DIREZIONE REALE)
              MarkerLayer(markers: [
                Marker(
                  point: _pos,
                  width: 70,
                  height: 70,
                  child: Transform.rotate(
                    angle: (_heading * (math.pi / 180)),
                    child: const Icon(Icons.navigation,
                        color: Colors.blue, size: 50),
                  ),
                )
              ]),
            ],
          ),

          // DASHBOARD
          Positioned(
            top: 50,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF001529).withOpacity(0.9),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.cyanAccent),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat("MAREA", _marea),
                  _stat("ROTTA", "${_heading.toInt()}°"),
                  _stat("KM/H", _speed.toStringAsFixed(1)),
                ],
              ),
            ),
          ),

          // BUSSOLA VISIVA (QUADRANTE)
          Positioned(
            bottom: 30,
            left: 20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Text("N",
                      style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 10)),
                  Transform.rotate(
                    angle: (_heading * (math.pi / 180) * -1),
                    child: const Icon(Icons.explore,
                        color: Colors.cyanAccent, size: 60),
                  ),
                ],
              ),
            ),
          ),

          if (!_isLive)
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.anchor, size: 30),
                label: const Text("INIZIA NAVIGAZIONE",
                    style: TextStyle(fontSize: 18)),
                onPressed: _iniziaNavigazione,
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

  Widget _stat(String l, String v) => Column(children: [
        Text(l, style: const TextStyle(color: Colors.white60, fontSize: 9)),
        Text(v,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace')),
      ]);
}
