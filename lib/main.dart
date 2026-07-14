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
  String _debugLog = "Pronto";
  LatLng _pos = const LatLng(45.4292, 12.3205);
  final MapController _mapController = MapController();

  // --- MOTORE MAREA RESILIENTE ---
  Future<void> _fetchMarea() async {
    setState(() => _marea = "...");
    const String target =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1";

    // Lista di 3 diversi tunnel (proxy) per bypassare il blocco del telefono
    final List<String> proxies = [
      "https://api.allorigins.win/get?url=", // AllOrigins
      "https://corsproxy.io/?", // CorsProxy
      "https://api.codetabs.com/v1/proxy?quest=" // CodeTabs
    ];

    for (var proxy in proxies) {
      try {
        final res = await http
            .get(Uri.parse(proxy + Uri.encodeComponent(target)))
            .timeout(const Duration(seconds: 5));

        if (res.statusCode == 200) {
          var jsonData;
          if (proxy.contains("allorigins")) {
            jsonData = json.decode(json.decode(res.body)['contents']);
          } else {
            jsonData = json.decode(res.body);
          }

          if (jsonData != null && jsonData.isNotEmpty) {
            setState(() {
              _marea = "${jsonData[0]['valore']} cm";
              _debugLog = "Marea OK (via Proxy)";
            });
            return; // Successo! Esce dal ciclo.
          }
        }
      } catch (e) {
        debugPrint("Fallito con $proxy");
      }
    }
    setState(() {
      _marea = "45 cm (Fallback)";
      _debugLog = "Tutti i proxy bloccati. Riprova tra poco.";
    });
  }

  Future<void> _attivaGps() async {
    _fetchMarea(); // Carica la marea appena clicchi
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      setState(() => _gpsStatus = "GPS OK");
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation),
      ).listen((Position p) {
        setState(() {
          _pos = LatLng(p.latitude, p.longitude);
          _mapController.move(_pos, 16);
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

          // DASHBOARD SUPERIORE
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
                      _stat("GPS", _gpsStatus, Colors.white),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(_debugLog,
                      style:
                          const TextStyle(color: Colors.white30, fontSize: 8)),
                ],
              ),
            ),
          ),

          // TASTONE ATTIVAZIONE
          if (_gpsStatus == "Attesa")
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.anchor),
                label: const Text("ATTIVA NAVIGATORE"),
                onPressed: _attivaGps,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                ),
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
                TextStyle(color: c, fontSize: 20, fontWeight: FontWeight.bold))
      ]);
}
