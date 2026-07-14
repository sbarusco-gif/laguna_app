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
  int _mareaCm = 40; // Valore numerico per calcoli
  String _gpsStatus = "Attesa";
  double _speed = 0.0;
  LatLng _pos = const LatLng(45.4371, 12.3326);
  final MapController _mapController = MapController();

  // --- LOGICA MAREA "GHOST" (Tenta 3 proxy diversi) ---
  Future<void> _fetchMarea() async {
    setState(() => _marea = "Sync...");
    const String target =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1";

    // Lista Proxy in ordine di potenza
    final List<String> proxies = [
      "https://api.codetabs.com/v1/proxy?quest=",
      "https://api.allorigins.win/get?url=",
      "https://corsproxy.io/?"
    ];

    for (var proxy in proxies) {
      try {
        final res = await http
            .get(Uri.parse(proxy + Uri.encodeComponent(target)))
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          var data;
          if (proxy.contains("allorigins")) {
            data = json.decode(json.decode(res.body)['contents']);
          } else {
            data = json.decode(res.body);
          }
          setState(() {
            _mareaCm =
                int.parse(data[0]['valore'].toString().replaceAll('+', ''));
            _marea = "$_mareaCm cm";
          });
          return;
        }
      } catch (e) {
        print("Fallito proxy: $proxy");
      }
    }
    setState(() => _marea = "$_mareaCm cm (Man)");
  }

  // Permette all'utente di regolare la marea a mano se internet fallisce
  void _regolaMareaManualmente() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Imposta Marea Manuale"),
        content: TextField(
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: "Esempio: 50"),
          onSubmitted: (val) {
            setState(() {
              _mareaCm = int.parse(val);
              _marea = "$_mareaCm cm (Man)";
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _attiva() async {
    _fetchMarea();
    LocationPermission p = await Geolocator.requestPermission();
    if (p == LocationPermission.always || p == LocationPermission.whileInUse) {
      setState(() => _gpsStatus = "OK");
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 2),
      ).listen((Position pos) {
        setState(() {
          _pos = LatLng(pos.latitude, pos.longitude);
          _speed = pos.speed * 3.6;
        });
        _mapController.move(_pos, 15);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Profondità calcolata: 12 metri (Canale Giudecca) + marea
    double profondita = 12.0 + (_mareaCm / 100);

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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                    onTap: _regolaMareaManualmente,
                    child: _stat("MAREA", _marea, Colors.cyanAccent),
                  ),
                  _stat("PROF.", "${profondita.toStringAsFixed(1)}m",
                      Colors.white),
                  _stat("KM/H", _speed.toStringAsFixed(1), Colors.greenAccent),
                ],
              ),
            ),
          ),

          if (_gpsStatus != "OK")
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.anchor),
                label: const Text("ATTIVA NAVIGATORE"),
                onPressed: _attiva,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.all(20)),
              ),
            ),

          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.blueGrey,
              onPressed: _fetchMarea,
              child: const Icon(Icons.refresh, color: Colors.white),
            ),
          )
        ],
      ),
    );
  }

  Widget _stat(String l, String v, Color c) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l, style: const TextStyle(color: Colors.white60, fontSize: 9)),
          Text(v,
              style: TextStyle(
                  color: c,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace')),
        ],
      );
}
