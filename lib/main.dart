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

  // --- LOGICA MAREA "MULTI-ATTACK" ---
  Future<void> _fetchMarea() async {
    setState(() => _marea = "Sync...");
    final String target =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1";

    // TENTATIVO 1: Proxy AllOrigins in modalità RAW (il più potente)
    try {
      final res = await http.get(Uri.parse(
          "https://api.allorigins.win/raw?url=${Uri.encodeComponent(target)}"));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() => _marea = "${data[0]['valore']} cm");
        return;
      }
    } catch (e) {
      print("T1 fallito");
    }

    // TENTATIVO 2: Proxy CorsProxy.io
    try {
      final res = await http.get(
          Uri.parse("https://corsproxy.io/?${Uri.encodeComponent(target)}"));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() => _marea = "${data[0]['valore']} cm");
        return;
      }
    } catch (e) {
      print("T2 fallito");
    }

    // TENTATIVO 3: Fallback simulato se la rete è totalmente bloccata
    setState(() => _marea = "Dato Criptato");
  }

  Future<void> _attiva() async {
    _fetchMarea();
    LocationPermission p = await Geolocator.requestPermission();
    if (p == LocationPermission.always || p == LocationPermission.whileInUse) {
      setState(() => _gpsStatus = "OK");
      Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.bestForNavigation))
          .listen((pos) {
        setState(() {
          _pos = LatLng(pos.latitude, pos.longitude);
          _speed = pos.speed * 3.6;
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
                  backgroundColor: Colors.transparent),
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
                  _stat("MAREA", _marea, Colors.cyanAccent),
                  _stat("KM/H", _speed.toStringAsFixed(1), Colors.white),
                  _stat("GPS", _gpsStatus, Colors.greenAccent),
                ],
              ),
            ),
          ),

          // TASTO ATTIVAZIONE
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
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.all(15)),
                    child: const Text("ATTIVA SISTEMA",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  onPressed: _fetchMarea,
                  backgroundColor: Colors.white24,
                  child: const Icon(Icons.refresh, color: Colors.white),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _stat(String l, String v, Color c) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(l, style: const TextStyle(color: Colors.white60, fontSize: 9)),
        Text(v,
            style:
                TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.bold))
      ]);
}
