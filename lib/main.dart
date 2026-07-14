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
  String _gpsStatus = "Premi ATTIVA";
  double _speed = 0.0;
  LatLng _pos = const LatLng(45.4371, 12.3326);
  final MapController _mapController = MapController();

  // --- LOGICA MAREA "ULTRA-BYPASS" ---
  Future<void> _fetchMarea() async {
    setState(() => _marea = "Sync...");

    // Indirizzo del Comune + Timestamp per evitare che GitHub usi la cache vecchia
    final String target =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1&t=${DateTime.now().millisecondsSinceEpoch}";

    // Usiamo AllOrigins in modalità RAW (è la più potente per saltare il blocco CORS)
    final String proxyUrl =
        "https://api.allorigins.win/raw?url=${Uri.encodeComponent(target)}";

    try {
      final res = await http.get(Uri.parse(proxyUrl));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        if (data.isNotEmpty) {
          setState(() {
            _marea = "${data[0]['valore']} cm";
          });
          return;
        }
      }
      setState(() => _marea = "Riprovando...");
      _fetchMareaAlternative(); // Se il primo fallisce, prova il secondo automaticamente
    } catch (e) {
      _fetchMareaAlternative();
    }
  }

  // Secondo proxy di emergenza
  Future<void> _fetchMareaAlternative() async {
    final String target =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1";
    final String proxyUrl =
        "https://corsproxy.io/?" + Uri.encodeComponent(target);
    try {
      final res = await http.get(Uri.parse(proxyUrl));
      final List data = json.decode(res.body);
      setState(() => _marea = "${data[0]['valore']} cm");
    } catch (e) {
      setState(() => _marea = "Offline");
    }
  }

  Future<void> _attivaSistema() async {
    _fetchMarea();
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      setState(() => _gpsStatus = "OK");
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation),
      ).listen((Position p) {
        setState(() {
          _pos = LatLng(p.latitude, p.longitude);
          _speed = p.speed * 3.6;
          _mapController.move(_pos, _mapController.camera.zoom);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                backgroundColor: Colors.transparent,
              ),
              MarkerLayer(markers: [
                Marker(
                    point: _pos,
                    width: 60,
                    height: 60,
                    child: const Icon(Icons.navigation,
                        color: Colors.red, size: 45))
              ]),
            ],
          ),

          // DASHBOARD PROFESSIONALE
          Positioned(
            top: 50,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF001529).withOpacity(0.9),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.cyanAccent, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat("MAREA", _marea, Colors.cyanAccent),
                  _stat("NODI", (_speed / 1.852).toStringAsFixed(1),
                      Colors.white),
                  _stat("GPS", _gpsStatus,
                      _gpsStatus == "OK" ? Colors.greenAccent : Colors.orange),
                ],
              ),
            ),
          ),

          if (_gpsStatus != "OK")
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.anchor, size: 30),
                label: const Text("ATTIVA NAVIGATORE"),
                onPressed: _attivaSistema,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.all(20),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace')),
        ],
      );
}
