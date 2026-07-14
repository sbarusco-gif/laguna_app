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
  String _gpsStatus = "Pronto";
  double _speed = 0.0;
  LatLng _pos = const LatLng(45.4371, 12.3326);
  final MapController _mapController = MapController();

  // --- LOGICA MAREA PROFESSIONALE ---
  Future<void> _fetchMarea() async {
    setState(() => _marea = "Sync...");
    // URL ufficiale del Comune di Venezia (Punta della Salute)
    const String target =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1";

    // Proviamo i due proxy più affidabili al mondo per le Web App
    final List<String> proxyList = [
      "https://api.allorigins.win/get?url=",
      "https://corsproxy.io/?"
    ];

    for (var proxy in proxyList) {
      try {
        final res =
            await http.get(Uri.parse(proxy + Uri.encodeComponent(target)));
        if (res.statusCode == 200) {
          var jsonData;
          // Se AllOrigins, il JSON è dentro 'contents'
          if (proxy.contains("allorigins")) {
            jsonData = json.decode(json.decode(res.body)['contents']);
          } else {
            // Se CorsProxy, il JSON è diretto
            jsonData = json.decode(res.body);
          }

          if (jsonData != null && jsonData is List && jsonData.isNotEmpty) {
            setState(() {
              _marea = "${jsonData[0]['valore']} cm";
            });
            return; // Uscita vittoriosa
          }
        }
      } catch (e) {
        debugPrint("Tentativo fallito con $proxy");
      }
    }
    setState(() => _marea = "CORS Error");
  }

  Future<void> _attivaGps() async {
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

          // BOTTONE CENTRALE DI ATTIVAZIONE
          if (_gpsStatus != "OK")
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.anchor, size: 30),
                label: const Text("ATTIVA NAVIGATORE",
                    style: TextStyle(fontSize: 18)),
                onPressed: _attivaGps,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
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
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace')),
        ],
      );
}
