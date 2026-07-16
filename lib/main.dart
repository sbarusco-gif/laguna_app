import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(
    const MaterialApp(home: LagunaApp(), debugShowCheckedModeBanner: false));

class LagunaApp extends StatefulWidget {
  const LagunaApp({super.key});
  @override
  State<LagunaApp> createState() => _LagunaAppState();
}

class _LagunaAppState extends State<LagunaApp> {
  String _marea = "---";
  int _mareaCm = 40;
  double _speed = 0.0;
  double _totalDistance = 0.0;
  LatLng _pos = const LatLng(45.4371, 12.3326);
  List<LatLng> _breadcrumb = []; // Memorizza la scia rossa
  final MapController _mapController = MapController();

  // --- STIMA PROFONDITÀ ---
  double _getDepth(LatLng pos) {
    double fondaleBase = 1.2;
    if (pos.latitude < 45.435 && pos.latitude > 45.425)
      fondaleBase = 12.0;
    else if (pos.latitude > 45.445 && pos.latitude < 45.460) fondaleBase = 5.0;
    return fondaleBase + (_mareaCm / 100);
  }

  Future<void> _fetchMarea() async {
    const String target =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1";
    final String proxyUrl = "https://api.codetabs.com/v1/proxy?quest=" +
        Uri.encodeComponent(target);
    try {
      final res = await http.get(Uri.parse(proxyUrl));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        setState(() {
          _mareaCm =
              int.parse(data[0]['valore'].toString().replaceAll('+', ''));
          _marea = "$_mareaCm cm";
        });
      }
    } catch (e) {
      setState(() => _marea = "40 cm");
    }
  }

  void _attivaNavigazione() async {
    _fetchMarea();
    LocationPermission p = await Geolocator.requestPermission();
    if (p == LocationPermission.always || p == LocationPermission.whileInUse) {
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 5),
      ).listen((Position pos) {
        LatLng newPoint = LatLng(pos.latitude, pos.longitude);
        setState(() {
          if (_breadcrumb.isNotEmpty) {
            _totalDistance += Geolocator.distanceBetween(_pos.latitude,
                _pos.longitude, newPoint.latitude, newPoint.longitude);
          }
          _pos = newPoint;
          _speed = pos.speed * 3.6;
          _breadcrumb.add(_pos); // Aggiunge punto al percorso
        });
        _mapController.move(_pos, _mapController.camera.zoom);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double profondita = _getDepth(_pos);

    return Scaffold(
      backgroundColor: const Color(0xFF000A12),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
                initialCenter: LatLng(45.4371, 12.3326), initialZoom: 14),
            children: [
              TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              TileLayer(
                  urlTemplate:
                      'https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png',
                  backgroundColor: Colors.transparent),

              // DISEGNO DELLA SCIA (Solo se abbiamo almeno 2 punti)
              if (_breadcrumb.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _breadcrumb,
                      strokeWidth: 4,
                      color: Colors.red,
                    ),
                  ],
                ),

              MarkerLayer(markers: [
                Marker(
                    point: _pos,
                    width: 60,
                    height: 60,
                    child: const Icon(Icons.navigation,
                        color: Colors.blue, size: 40))
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
                border: Border.all(
                    color: profondita < 2.0 ? Colors.red : Colors.cyanAccent),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat("MAREA", _marea),
                      _stat("PROF.", "${profondita.toStringAsFixed(1)}m"),
                      _stat("DISTANZA",
                          "${(_totalDistance / 1000).toStringAsFixed(2)} km"),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_breadcrumb.isEmpty)
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text("INIZIA TRACKING"),
                onPressed: _attivaNavigazione,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.all(20)),
              ),
            )
        ],
      ),
    );
  }

  Widget _stat(String l, String v) => Column(children: [
        Text(l, style: const TextStyle(color: Colors.white60, fontSize: 9)),
        Text(v,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))
      ]);
}
