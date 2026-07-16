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
  String _marea = "40 cm (S)";
  int _mareaCm = 40;
  double _speed = 0.0;
  double _heading = 0.0; // Direzione rilevata dal movimento GPS
  double _totalDist = 0.0;
  LatLng _pos = const LatLng(45.4371, 12.3326);
  List<LatLng> _trail = [];
  final MapController _mapController = MapController();
  bool _isNavigating = false;

  // --- LOGICA MAREA ---
  Future<void> _fetchMarea() async {
    const String target =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1";
    final String proxy =
        "https://api.allorigins.win/raw?url=${Uri.encodeComponent(target)}";
    try {
      final res =
          await http.get(Uri.parse(proxy)).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        setState(() {
          _mareaCm =
              int.parse(data[0]['valore'].toString().replaceAll('+', ''));
          _marea = "$_mareaCm cm";
        });
      }
    } catch (e) {
      print("Marea error");
    }
  }

  // --- ATTIVAZIONE GPS E ROTAZIONE ---
  void _attivaNavigazione() async {
    _fetchMarea();
    LocationPermission p = await Geolocator.requestPermission();
    if (p == LocationPermission.always || p == LocationPermission.whileInUse) {
      setState(() => _isNavigating = true);
      Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.bestForNavigation,
                  distanceFilter: 2))
          .listen((Position pos) {
        setState(() {
          if (_trail.isNotEmpty) {
            _totalDist += Geolocator.distanceBetween(
                _pos.latitude, _pos.longitude, pos.latitude, pos.longitude);
          }
          _pos = LatLng(pos.latitude, pos.longitude);
          _speed = pos.speed * 3.6;

          // LA BUSSOLA GPS: Ruota la freccia solo se ci stiamo muovendo
          if (_speed > 1.5) {
            _heading = pos.heading;
          }
        });
        _mapController.move(_pos, 15);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double prof = 12.0 + (_mareaCm / 100);
    return Scaffold(
      backgroundColor: Colors.black,
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
              PolylineLayer(polylines: [
                Polyline(
                    points: _trail, strokeWidth: 4, color: Colors.redAccent)
              ]),
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
                  border: Border.all(color: Colors.cyanAccent)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat("MAREA", _marea),
                  _stat("PROF.", "${prof.toStringAsFixed(1)}m"),
                  _stat("KM/H", _speed.toStringAsFixed(1)),
                ],
              ),
            ),
          ),

          // BUSSOLA VISIVA (Rotante)
          Positioned(
            bottom: 30,
            left: 20,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24)),
              child: Transform.rotate(
                angle: (_heading * (math.pi / 180) * -1),
                child: const Icon(Icons.explore,
                    color: Colors.cyanAccent, size: 50),
              ),
            ),
          ),

          if (!_isNavigating)
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text("INIZIA NAVIGAZIONE"),
                onPressed: _attivaNavigazione,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.all(20)),
              ),
            ),

          Positioned(
              bottom: 20,
              right: 20,
              child: Text("${(_totalDist / 1000).toStringAsFixed(2)} KM",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _stat(String l, String v) => Column(children: [
        Text(l, style: const TextStyle(color: Colors.white60, fontSize: 9)),
        Text(v,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
      ]);
}
