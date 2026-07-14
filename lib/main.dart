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
  String _marea = "Richiesta...";
  String _mareaLog = "Inizializzazione sistema...";
  String _gpsStatus = "Attesa";
  double _speed = 0.0;
  LatLng _pos = const LatLng(45.4371, 12.3326);
  final MapController _mapController = MapController();

  // --- LOGICA MAREA CON DIAGNOSTICA ---
  Future<void> _fetchMarea() async {
    setState(() => _mareaLog = "Chiamata al proxy...");
    const String target =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1";
    // Usiamo AllOrigins in modalità RAW (il metodo più potente per il web)
    final String proxyUrl =
        "https://api.allorigins.win/raw?url=${Uri.encodeComponent(target)}";

    try {
      final res = await http
          .get(Uri.parse(proxyUrl))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        String valoreGrezzo = data[0]['valore'].toString();
        setState(() {
          _marea = "${valoreGrezzo.replaceAll('+', '')} cm";
          _mareaLog = "Dato ricevuto con successo!";
        });
      } else {
        setState(() => _mareaLog = "Errore Server: ${res.statusCode}");
      }
    } catch (e) {
      setState(() {
        _mareaLog = "Blocco Browser (CORS/Network)";
        _marea = "45 cm (Fix)";
      });
      print(e);
    }
  }

  Future<void> _attiva() async {
    _fetchMarea();
    LocationPermission p = await Geolocator.requestPermission();
    if (p == LocationPermission.always || p == LocationPermission.whileInUse) {
      setState(() => _gpsStatus = "OK");
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation),
      ).listen((Position pos) {
        setState(() {
          _pos = LatLng(pos.latitude, pos.longitude);
          _speed = pos.speed * 3.6;
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
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat("MAREA", _marea, Colors.cyanAccent),
                      _stat("KM/H", _speed.toStringAsFixed(1), Colors.white),
                      _stat("GPS", _gpsStatus, Colors.greenAccent),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 20),
                  Text("LOG MAREA: $_mareaLog",
                      style:
                          const TextStyle(color: Colors.white30, fontSize: 8)),
                ],
              ),
            ),
          ),

          if (_gpsStatus == "Attesa")
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.anchor),
                label: const Text("ATTIVA SISTEMA"),
                onPressed: _attiva,
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

  Widget _stat(String l, String v, Color c) => Column(children: [
        Text(l, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        Text(v,
            style:
                TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.bold))
      ]);
}
