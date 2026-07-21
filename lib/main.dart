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
  String _mareaDisplay = "40 cm (S)";
  int _mareaCm = 40;
  bool _isLive = false;
  double _speed = 0.0;
  double _heading = 0.0;
  double _distanzaTotale = 0.0;
  LatLng _pos = const LatLng(45.4371, 12.3326);
  List<LatLng> _scia = [];
  final MapController _mapController = MapController();
  bool _active = false;

  // --- MAREA ---
  Future<void> _fetchMarea() async {
    const String target =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1";
    final String proxy =
        "https://api.allorigins.win/get?url=${Uri.encodeComponent(target)}";
    try {
      final res =
          await http.get(Uri.parse(proxy)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = json.decode(json.decode(res.body)['contents']);
        setState(() {
          _mareaCm =
              int.parse(data[0]['valore'].toString().replaceAll('+', ''));
          _mareaDisplay = "$_mareaCm cm (A)";
          _isLive = true;
        });
      }
    } catch (e) {
      debugPrint("Marea error");
    }
  }

  void _setMareaManuale() {
    TextEditingController _txt = TextEditingController();
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text("Marea Manuale"),
              content: TextField(
                  controller: _txt,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: "cm")),
              actions: [
                TextButton(
                    onPressed: () {
                      if (_txt.text.isNotEmpty) {
                        setState(() {
                          _mareaCm = int.parse(_txt.text);
                          _mareaDisplay = "${_txt.text} cm (M)";
                          _isLive = true;
                        });
                      }
                      Navigator.pop(c);
                    },
                    child: const Text("OK"))
              ],
            ));
  }

  // --- PROFONDITÀ ---
  double _getDepth(LatLng p) {
    double base = 1.2;
    if (p.latitude < 45.433 && p.latitude > 45.425)
      base = 12.0;
    else if (p.latitude > 45.450) base = 4.0;
    return base + (_mareaCm / 100);
  }

  // --- GPS ---
  void _avvia() async {
    _fetchMarea();
    LocationPermission p = await Geolocator.requestPermission();
    if (p == LocationPermission.always || p == LocationPermission.whileInUse) {
      setState(() => _active = true);
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 3),
      ).listen((Position pos) {
        LatLng newPoint = LatLng(pos.latitude, pos.longitude);
        setState(() {
          if (_scia.isNotEmpty) {
            _distanzaTotale += Geolocator.distanceBetween(_pos.latitude,
                _pos.longitude, newPoint.latitude, newPoint.longitude);
          }
          _pos = newPoint;
          _scia.add(_pos);
          _speed = pos.speed * 3.6;
          if (_speed > 1.5) _heading = pos.heading;
        });
        _mapController.move(_pos, 16);
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

              // LA SCIA ROSSA
              PolylineLayer(polylines: [
                Polyline(points: _scia, strokeWidth: 4, color: Colors.red),
              ]),

              // LA BARCA
              MarkerLayer(markers: [
                Marker(
                  point: _pos,
                  width: 60,
                  height: 60,
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
            top: 40,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFF001529).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: _isLive ? Colors.cyanAccent : Colors.orangeAccent,
                      width: 2)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                      onTap: _setMareaManuale,
                      child: _stat("MAREA", _mareaDisplay,
                          _isLive ? Colors.cyanAccent : Colors.orangeAccent)),
                  _stat("PROF.", "${prof.toStringAsFixed(1)}m",
                      prof < 2.0 ? Colors.red : Colors.white),
                  _stat(
                      "DIST.",
                      "${(_distanzaTotale / 1000).toStringAsFixed(2)}km",
                      Colors.greenAccent),
                  _stat("ROTTA", "${_heading.toInt()}°", Colors.white),
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
              decoration: BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24)),
              child: Transform.rotate(
                angle: (_heading * (math.pi / 180) * -1),
                child: const Icon(Icons.explore, color: Colors.white, size: 55),
              ),
            ),
          ),

          if (!_active)
            Center(
                child: ElevatedButton.icon(
                    icon: const Icon(Icons.anchor),
                    label: const Text("AVVIA SISTEMA"),
                    onPressed: _avvia,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.all(20)))),
        ],
      ),
    );
  }

  Widget _stat(String l, String v, Color c) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(l,
            style: const TextStyle(
                color: Colors.white60,
                fontSize: 8,
                fontWeight: FontWeight.bold)),
        Text(v,
            style: TextStyle(
                color: c,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace'))
      ]);
}
