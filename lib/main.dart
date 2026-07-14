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
  String _marea = "Sincronizza";
  String _gpsStatus = "GPS Spento";
  double _speed = 0.0;
  LatLng _pos = const LatLng(45.4371, 12.3326);
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _fetchMarea();
  }

  // --- LOGICA MAREA DEFINITIVA PER WEB ---
  Future<void> _fetchMarea() async {
    setState(() => _marea = "...");
    final String target =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1";

    // Usiamo AllOrigins, che è il proxy più potente per aggirare i blocchi dei browser
    final String proxyUrl =
        "https://api.allorigins.win/get?url=${Uri.encodeComponent(target)}";

    try {
      final res = await http.get(Uri.parse(proxyUrl));
      if (res.statusCode == 200) {
        // AllOrigins impacchetta il JSON dentro un campo chiamato 'contents'
        final wrappedData = json.decode(res.body);
        final List data = json.decode(wrappedData['contents']);

        setState(() {
          _marea = "${data[0]['valore']} cm";
        });
      } else {
        setState(() => _marea = "Err ${res.statusCode}");
      }
    } catch (e) {
      setState(() => _marea = "Blocco CORS");
      print("Errore: $e");
    }
  }

  Future<void> _attivaGps() async {
    _fetchMarea(); // Ricarica anche la marea al click
    setState(() => _gpsStatus = "Ricerca...");

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation),
      ).listen((Position p) {
        setState(() {
          _pos = LatLng(p.latitude, p.longitude);
          _speed = p.speed * 3.6;
          _gpsStatus = "OK";
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
            options: MapOptions(initialCenter: _pos, initialZoom: 14),
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
                    child: const Icon(Icons.navigation,
                        color: Colors.red, size: 40))
              ]),
            ],
          ),

          // DASHBOARD
          Positioned(
            top: 50,
            left: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF001529).withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.cyanAccent),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat("MAREA", _marea),
                  _stat("VELOCITÀ", "${_speed.toStringAsFixed(1)} km/h"),
                  _stat("GPS", _gpsStatus),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 40,
            left: 50,
            right: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.anchor),
              label: const Text("ATTIVA"),
              onPressed: _attivaGps,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black),
            ),
          )
        ],
      ),
    );
  }

  Widget _stat(String t, String v) => Column(children: [
        Text(t, style: const TextStyle(color: Colors.white60, fontSize: 9)),
        Text(v,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))
      ]);
}
