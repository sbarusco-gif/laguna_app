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

  // --- LOGICA MAREA CON MULTI-PROXY (Per battere il blocco CORS) ---
  Future<void> _fetchMarea() async {
    setState(() => _marea = "...");
    final String target =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1";

    // Lista di ponti (proxy) per aggirare il blocco del browser
    final List<String> proxies = [
      "https://api.allorigins.win/get?url=",
      "https://corsproxy.io/?",
      "https://api.codetabs.com/v1/proxy?quest="
    ];

    for (var proxy in proxies) {
      try {
        final res =
            await http.get(Uri.parse(proxy + Uri.encodeComponent(target)));
        if (res.statusCode == 200) {
          var data;
          if (proxy.contains("allorigins")) {
            data = json.decode(json.decode(res.body)['contents']);
          } else {
            data = json.decode(res.body);
          }
          setState(() => _marea = "${data[0]['valore']} cm");
          return; // Uscita se successo
        }
      } catch (e) {
        print("Proxy fallito: $proxy");
      }
    }
    setState(() => _marea = "Dato Protetto");
  }

  Future<void> _attivaGps() async {
    _fetchMarea(); // Prova a caricare la marea al click
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
                        color: Colors.red, size: 40))
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
                border: Border.all(color: Colors.cyanAccent),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat("MAREA", _marea, Colors.cyanAccent),
                  _stat("VELOCITÀ", "${_speed.toStringAsFixed(1)} km/h",
                      Colors.white),
                  _stat(
                      "GPS",
                      _gpsStatus,
                      _gpsStatus == "OK"
                          ? Colors.greenAccent
                          : Colors.redAccent),
                ],
              ),
            ),
          ),

          // TASTONE ATTIVAZIONE
          Positioned(
            bottom: 40,
            left: 50,
            right: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.anchor),
              label: const Text("ATTIVA SISTEMA"),
              onPressed: _attivaGps,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Column(children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9)),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.bold))
      ]);
}
