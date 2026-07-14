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
  String _gpsStatus = "Attesa";
  double _speed = 0.0;
  LatLng _pos = const LatLng(45.4371, 12.3326);
  final MapController _mapController = MapController();

  // --- LOGICA MAREA "SMART-TEXT" ---
  Future<void> _fetchMarea() async {
    setState(() => _marea = "Sync...");
    final String target =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1";

    // Usiamo il ponte AllOrigins ma chiediamo il dato come 'contents' grezzo
    final String proxyUrl =
        "https://api.allorigins.win/get?url=${Uri.encodeComponent(target)}";

    try {
      final res = await http.get(Uri.parse(proxyUrl));
      if (res.statusCode == 200) {
        // AllOrigins restituisce un oggetto con una stringa 'contents'
        final Map<String, dynamic> wrapped = json.decode(res.body);
        final String contents = wrapped['contents'];

        // Decodifichiamo la stringa interna che contiene il vero JSON della marea
        final List<dynamic> data = json.decode(contents);

        if (data.isNotEmpty) {
          setState(() {
            _marea = "${data[0]['valore']} cm";
          });
          return;
        }
      }
      setState(() => _marea = "Riprovando...");
      _fetchAlternative();
    } catch (e) {
      _fetchAlternative();
    }
  }

  // Secondo tentativo con proxy diverso se il primo fallisce
  Future<void> _fetchAlternative() async {
    final String target =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1";
    final String proxyUrl =
        "https://corsproxy.io/?" + Uri.encodeComponent(target);
    try {
      final res = await http.get(Uri.parse(proxyUrl));
      final List data = json.decode(res.body);
      setState(() => _marea = "${data[0]['valore']} cm");
    } catch (e) {
      setState(() => _marea = "CORS Locked");
    }
  }

  Future<void> _attiva() async {
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
          _mapController.move(_pos, 15);
        });
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
                  _stat("MAREA", _marea, Colors.cyanAccent),
                  _stat("KM/H", _speed.toStringAsFixed(1), Colors.white),
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
                label: const Text("ATTIVA SISTEMA"),
                onPressed: _attiva,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.all(20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
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
