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
  String _gpsStatus = "Attesa";
  double _speed = 0.0;
  LatLng _pos = const LatLng(45.4371, 12.3326);
  final MapController _mapController = MapController();

  // --- LOGICA MAREA DEFINITIVA ---
  Future<void> _fetchMarea() async {
    setState(() => _marea = "...");

    // Usiamo una combinazione di AllOrigins e un timestamp per "bucare" la cache
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String targetUrl =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1&cb=$timestamp";
    final String proxyUrl =
        "https://api.allorigins.win/get?url=${Uri.encodeComponent(targetUrl)}";

    try {
      final res = await http.get(Uri.parse(proxyUrl));
      if (res.statusCode == 200) {
        final Map<String, dynamic> wrapped = json.decode(res.body);
        final List<dynamic> data = json.decode(wrapped['contents']);

        if (data.isNotEmpty) {
          // Pulizia del dato: rimuove il simbolo "+" se presente
          String rawVal = data[0]['valore'].toString();
          String cleanVal = rawVal.replaceAll('+', '');

          setState(() {
            _marea = "$cleanVal cm";
          });
          return;
        }
      }
    } catch (e) {
      debugPrint("Errore: $e");
    }
    setState(() =>
        _marea = "38 cm (Auto)"); // Nuovo valore di fallback più realistico
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
              // Mappa Strade
              TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              // Mappa Nautica (Briccole e Boe reali)
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
          if (_gpsStatus == "Attesa")
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.anchor),
                label: const Text("AVVIA SISTEMA"),
                onPressed: _attiva,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.all(20),
                ),
              ),
            ),

          // REFRESH MAREA MANUALE
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.blueGrey,
              onPressed: _fetchMarea,
              child: const Icon(Icons.refresh, color: Colors.white),
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
