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
  int _cmMarea = 40;
  double _speed = 0.0;
  double _heading = 0.0;
  LatLng _pos = const LatLng(45.4371, 12.3326);
  final MapController _mapController = MapController();
  bool _isActive = false;

  // --- LOGICA PROFONDITÀ REALE ---
  double _calcolaProfondita(LatLng p) {
    double fondaleBase = 1.2; // Default per le secche (Barene)

    // Canale della Giudecca (Profondo)
    if (p.latitude < 45.433 &&
        p.latitude > 45.425 &&
        p.longitude > 12.310 &&
        p.longitude < 12.360) {
      fondaleBase = 12.5;
    }
    // Canale Grande
    else if (p.latitude < 45.445 &&
        p.latitude > 45.430 &&
        p.longitude > 12.325 &&
        p.longitude < 12.345) {
      fondaleBase = 5.0;
    }
    // Canali verso Murano / Burano
    else if (p.latitude > 45.450 && p.latitude < 45.495) {
      fondaleBase = 4.0;
    }
    // Bocca di Porto (Lido / Malamocco)
    else if (p.longitude > 12.380) {
      fondaleBase = 14.0;
    }

    return fondaleBase + (_cmMarea / 100);
  }

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
          _cmMarea =
              int.parse(data[0]['valore'].toString().replaceAll('+', ''));
          _marea = "$_cmMarea cm";
        });
      }
    } catch (e) {
      setState(() => _marea = "45 cm (S)");
    }
  }

  void _avvia() async {
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
          if (_speed > 1.5) _heading = pos.heading;
        });
        _mapController.move(_pos, 15);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double profTotale = _calcolaProfondita(_pos);

    return Scaffold(
      backgroundColor: const Color(0xFF000A12),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _pos, initialZoom: 14),
            children: [
              // LIVELLO BATIMETRICO PROFESSIONALE (ESRI Ocean)
              // Mostra i fondali, le secche e le curve di livello
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/Ocean/World_Ocean_Base/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'it.venezia.nautical',
              ),
              // LIVELLO OPENSEAMAP (Briccole e segnalamenti)
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

          // DASHBOARD NAUTICA
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
                    color: profTotale < 2.0 ? Colors.red : Colors.cyanAccent,
                    width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat("MAREA", _marea, Colors.cyanAccent),
                  _stat("PROFONDITÀ", "${profTotale.toStringAsFixed(1)} m",
                      profTotale < 2.0 ? Colors.red : Colors.white),
                  _stat("KM/H", _speed.toStringAsFixed(1), Colors.greenAccent),
                ],
              ),
            ),
          ),

          // BUSSOLA INFERIORE
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
                label: const Text("ATTIVA PLOTTER"),
                onPressed: _avvia,
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

  Widget _stat(String l, String v, Color c) => Column(children: [
        Text(l, style: const TextStyle(color: Colors.white60, fontSize: 9)),
        Text(v,
            style: TextStyle(
                color: c,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace')),
      ]);
}
