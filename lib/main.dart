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
  String _marea = "Premi ATTIVA";
  String _gpsStatus = "GPS Spento";
  LatLng _pos = const LatLng(45.4371, 12.3326);
  final MapController _mapController = MapController();

  // RECUPERO MAREA CON PROXY ALLORIGINS (Metodo standard più compatibile)
  Future<void> _fetchMarea() async {
    setState(() => _marea = "Caricamento...");
    const String target =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1";
    final String proxyUrl =
        "https://api.allorigins.win/get?url=${Uri.encodeComponent(target)}";

    try {
      final res = await http.get(Uri.parse(proxyUrl));
      if (res.statusCode == 200) {
        final Map<String, dynamic> wrapped = json.decode(res.body);
        final List<dynamic> data = json.decode(wrapped['contents']);
        setState(() => _marea = "${data[0]['valore']} cm");
      } else {
        setState(() => _marea = "Errore Server");
      }
    } catch (e) {
      setState(() => _marea = "Marea: 45 cm (Fallback)");
    }
  }

  // ATTIVAZIONE GPS (Deve essere scatenato dall'utente)
  Future<void> _attivaSito() async {
    _fetchMarea(); // Carica la marea

    setState(() => _gpsStatus = "Permessi...");
    LocationPermission permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      setState(() => _gpsStatus = "Ricerca posizione...");

      // Prendi la posizione singola per sbloccare la mappa
      try {
        Position p = await Geolocator.getCurrentPosition();
        setState(() {
          _pos = LatLng(p.latitude, p.longitude);
          _gpsStatus = "Navigazione ON";
          _mapController.move(_pos, 15);
        });

        // Avvia l'aggiornamento continuo
        Geolocator.getPositionStream().listen((Position p) {
          setState(() {
            _pos = LatLng(p.latitude, p.longitude);
          });
        });
      } catch (e) {
        setState(() => _gpsStatus = "Timeout GPS");
      }
    } else {
      setState(() => _gpsStatus = "GPS Negato");
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
                    width: 50,
                    height: 50,
                    child: const Icon(Icons.navigation,
                        color: Colors.red, size: 40))
              ]),
            ],
          ),

          // Dashboard
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.cyanAccent)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _col("MAREA", _marea),
                  _col("STATO GPS", _gpsStatus),
                ],
              ),
            ),
          ),

          // Tasto di sblocco
          Positioned(
            bottom: 40,
            left: 40,
            right: 40,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.gps_fixed),
              label: const Text("ATTIVA SISTEMA"),
              onPressed: _attivaSito,
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

  Widget _col(String t, String v) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(t, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        Text(v,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))
      ]);
}
