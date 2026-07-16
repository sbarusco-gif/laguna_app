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
  String _marea = "Sincro...";
  int _mareaCm = 0;
  bool _isLive = false; // Per sapere se il dato è vero o simulato
  double _speed = 0.0;
  double _totalDistance = 0.0;
  LatLng _pos = const LatLng(45.4371, 12.3326);
  List<LatLng> _breadcrumb = [];
  final MapController _mapController = MapController();

  // --- RECUPERO MAREA CON CACHE-BUSTER ---
  Future<void> _fetchMarea() async {
    setState(() => _marea = "...");

    // Generiamo un numero unico basato sul tempo per forzare il refresh totale
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String target =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1&t=$timestamp";
    final String proxyUrl =
        "https://api.allorigins.win/get?url=${Uri.encodeComponent(target)}";

    try {
      final res = await http.get(Uri.parse(proxyUrl));
      if (res.statusCode == 200) {
        final wrapped = json.decode(res.body);
        final List data = json.decode(wrapped['contents']);

        if (data.isNotEmpty) {
          setState(() {
            _mareaCm =
                int.parse(data[0]['valore'].toString().replaceAll('+', ''));
            _marea = "$_mareaCm cm";
            _isLive = true; // DATO REALE!
          });
          return;
        }
      }
    } catch (e) {
      debugPrint("Errore: $e");
    }

    // Se arriva qui, il download è fallito
    setState(() {
      _marea = "No Link";
      _isLive = false;
    });
  }

  void _attivaSistema() async {
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
          _breadcrumb.add(_pos);
        });
        _mapController.move(_pos, _mapController.camera.zoom);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double profondita = 12.0 + (_mareaCm / 100);

    return Scaffold(
      backgroundColor: const Color(0xFF000A12),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
                initialCenter: LatLng(45.4371, 12.3326), initialZoom: 15),
            children: [
              TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              TileLayer(
                  urlTemplate:
                      'https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png',
                  backgroundColor: Colors.transparent),
              if (_breadcrumb.length > 1)
                PolylineLayer(polylines: [
                  Polyline(
                      points: _breadcrumb,
                      strokeWidth: 4,
                      color: Colors.redAccent)
                ]),
              MarkerLayer(markers: [
                Marker(
                    point: _pos,
                    width: 60,
                    height: 60,
                    child: const Icon(Icons.navigation,
                        color: Colors.blue, size: 45))
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
                    color: _isLive ? Colors.cyanAccent : Colors.orangeAccent),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat("MAREA", _marea,
                      _isLive ? Colors.cyanAccent : Colors.orangeAccent),
                  _stat("PROF.", "${profondita.toStringAsFixed(1)}m",
                      Colors.white),
                  _stat(
                      "DISTANZA",
                      "${(_totalDistance / 1000).toStringAsFixed(2)} km",
                      Colors.greenAccent),
                ],
              ),
            ),
          ),

          if (_breadcrumb.isEmpty)
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.anchor),
                label: const Text("AVVIA NAVIGAZIONE"),
                onPressed: _attivaSistema,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.all(20)),
              ),
            ),

          // REFRESH FORZATO
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white24,
              onPressed: _fetchMarea,
              child: const Icon(Icons.refresh, color: Colors.white),
            ),
          )
        ],
      ),
    );
  }

  Widget _stat(String l, String v, Color c) => Column(children: [
        Text(l, style: const TextStyle(color: Colors.white60, fontSize: 9)),
        Text(v,
            style:
                TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.bold))
      ]);
}
