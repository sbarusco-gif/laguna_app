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
  int _cmMarea = 0;
  LatLng _pos = const LatLng(45.4371, 12.3326);
  final MapController _mapController = MapController();

  // --- LOGICA MAREA "ULTRA-ROBUSTA" ---
  Future<void> _fetchMarea() async {
    setState(() => _marea = "Recupero...");

    // Proviamo il proxy più pulito (CodeTabs)
    final String target =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1";
    final String proxyUrl = "https://api.codetabs.com/v1/proxy?quest=" + target;

    try {
      final res = await http.get(Uri.parse(proxyUrl));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        setState(() {
          _cmMarea = int.parse(data[0]['valore']);
          _marea = "$_cmMarea cm";
        });
      } else {
        _fetchMareaBackup(); // Se il primo fallisce, prova AllOrigins
      }
    } catch (e) {
      _fetchMareaBackup();
    }
  }

  Future<void> _fetchMareaBackup() async {
    try {
      final url = "https://api.allorigins.win/get?url=" +
          Uri.encodeComponent(
              "https://portale.comune.venezia.it/marea/esporta-dati?id=1");
      final res = await http.get(Uri.parse(url));
      final wrapped = json.decode(res.body);
      final List data = json.decode(wrapped['contents']);
      setState(() {
        _cmMarea = int.parse(data[0]['valore']);
        _marea = "$_cmMarea cm";
      });
    } catch (e) {
      setState(() => _marea = "RETE OFF");
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
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calcolo profondità nel canale (12m fondale + marea)
    double profondita = 12.0 + (_cmMarea / 100);

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
                border: Border.all(color: Colors.cyanAccent),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat("MAREA", _marea, Colors.cyanAccent),
                  _stat("PROF. CANALE", "${profondita.toStringAsFixed(1)} m",
                      Colors.white),
                  _stat("KM/H", _speed.toStringAsFixed(1), Colors.greenAccent),
                ],
              ),
            ),
          ),

          // TASTI AZIONE
          Positioned(
            bottom: 40,
            left: 30,
            right: 30,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _attiva,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black),
                    child: const Text("ATTIVA SISTEMA"),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  onPressed: _fetchMarea,
                  backgroundColor: Colors.blueGrey,
                  child: const Icon(Icons.refresh, color: Colors.white),
                ),
              ],
            ),
          )
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
                  fontSize: 9,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace')),
        ],
      );
}
