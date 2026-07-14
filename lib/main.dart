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
  String _gpsStatus = "GPS Spento";
  LatLng _pos = const LatLng(45.4371, 12.3326); // Piazza San Marco
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _fetchMarea();
  }

  // --- SOLUZIONE MAREA (Proxy alternativo) ---
  Future<void> _fetchMarea() async {
    try {
      // Usiamo un proxy diverso per il Web
      final url = Uri.parse(
          'https://api.codetabs.com/v1/proxy?quest=https://portale.comune.venezia.it/marea/esporta-dati?id=1');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() => _marea = "${data[0]['valore']} cm");
      }
    } catch (e) {
      setState(() => _marea = "Errore Marea");
    }
  }

  // --- SOLUZIONE GPS (Richiede interazione utente) ---
  Future<void> _attivaGps() async {
    setState(() => _gpsStatus = "Ricerca segnale...");

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation),
      ).listen((Position position) {
        setState(() {
          _pos = LatLng(position.latitude, position.longitude);
          _gpsStatus = "GPS Attivo";
          _mapController.move(_pos, 15);
        });
      });
    } else {
      setState(() => _gpsStatus = "Permesso negato");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _pos, initialZoom: 14),
            children: [
              TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              // LIVELLO NAUTICO
              TileLayer(
                urlTemplate:
                    'https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png',
                backgroundColor: Colors.transparent,
              ),
              MarkerLayer(markers: [
                Marker(
                  point: _pos,
                  child:
                      const Icon(Icons.navigation, color: Colors.red, size: 40),
                )
              ]),
            ],
          ),

          // DASHBOARD
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(15)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _box("MAREA", _marea),
                  _box("GPS", _gpsStatus),
                ],
              ),
            ),
          ),

          // PULSANTE ATTIVAZIONE (Necessario per sbloccare il browser)
          Positioned(
            bottom: 40,
            left: 50,
            right: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.gps_fixed),
              label: const Text("ATTIVA NAVIGAZIONE"),
              style:
                  ElevatedButton.styleFrom(padding: const EdgeInsets.all(15)),
              onPressed: _attivaGps,
            ),
          )
        ],
      ),
    );
  }

  Widget _box(String t, String v) => Column(children: [
        Text(t, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        Text(v,
            style: const TextStyle(
                color: Colors.cyanAccent,
                fontSize: 18,
                fontWeight: FontWeight.bold))
      ]);
}
