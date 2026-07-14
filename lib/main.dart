import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(const MaterialApp(
      home: LagunaNauticalApp(),
      debugShowCheckedModeBanner: false,
    ));

class LagunaNauticalApp extends StatefulWidget {
  const LagunaNauticalApp({super.key});

  @override
  State<LagunaNauticalApp> createState() => _LagunaNauticalAppState();
}

class _LagunaNauticalAppState extends State<LagunaNauticalApp> {
  String _marea = "Sincronizza";
  String _gpsStatus = "GPS Spento";
  double _speedKmh = 0.0;
  LatLng _userPos = const LatLng(45.4371, 12.3326); // Piazza San Marco
  final MapController _mapController = MapController();

  // --- FUNZIONE MAREA (Multi-Proxy per evitare 404/CORS) ---
  Future<void> _fetchMarea() async {
    setState(() => _marea = "...");

    // Proviamo corsproxy.io che è il più stabile per il Comune di Venezia
    final String target =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1";
    final String proxyUrl =
        "https://corsproxy.io/?" + Uri.encodeComponent(target);

    try {
      final res = await http.get(Uri.parse(proxyUrl));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        setState(() => _marea = "${data[0]['valore']} cm");
      } else {
        setState(() => _marea = "Err ${res.statusCode}");
      }
    } catch (e) {
      setState(() => _marea = "Errore");
    }
  }

  // --- FUNZIONE GPS (Attivazione tramite gesto utente) ---
  Future<void> _attivaSistema() async {
    // 1. Richiedi marea
    _fetchMarea();

    // 2. Gestione GPS
    setState(() => _gpsStatus = "Ricerca...");

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      // Prendi posizione iniziale
      Position pos = await Geolocator.getCurrentPosition();
      setState(() {
        _userPos = LatLng(pos.latitude, pos.longitude);
        _gpsStatus = "Attivo";
        _mapController.move(_userPos, 15);
      });

      // Avvia streaming continuo
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation),
      ).listen((Position p) {
        setState(() {
          _userPos = LatLng(p.latitude, p.longitude);
          _speedKmh = p.speed * 3.6;
        });
      });
    } else {
      setState(() => _gpsStatus = "Negato");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000A12),
      body: Stack(
        children: [
          // MAPPA CON LIVELLO NAUTICO
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userPos,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'it.venezia.laguna_nav',
              ),
              // Layer OpenSeaMap (Briccole e Boe)
              TileLayer(
                urlTemplate:
                    'https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png',
                backgroundColor: Colors.transparent,
              ),
              MarkerLayer(markers: [
                Marker(
                  point: _userPos,
                  width: 50,
                  height: 50,
                  child:
                      const Icon(Icons.navigation, color: Colors.red, size: 40),
                )
              ]),
            ],
          ),

          // DASHBOARD SUPERIORE
          Positioned(
            top: 50,
            left: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF001529).withOpacity(0.9),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.cyanAccent, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat("MAREA", _marea),
                  _stat("VELOCITÀ", "${_speedKmh.toStringAsFixed(1)} km/h"),
                  _stat("GPS", _gpsStatus),
                ],
              ),
            ),
          ),

          // TASTO DI ATTIVAZIONE (OBBLIGATORIO PER WEB/TELEFONO)
          Positioned(
            bottom: 40,
            left: 50,
            right: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.anchor),
              label: const Text("ATTIVA NAVIGAZIONE"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: _attivaSistema,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}
