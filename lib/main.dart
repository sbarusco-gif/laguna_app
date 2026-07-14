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
  int _mareaCm = 40;
  String _gpsStatus = "Attesa";
  double _speed = 0.0;
  LatLng _pos = const LatLng(45.4371, 12.3326);
  final MapController _mapController = MapController();

  // --- DATABASE PUNTI DI INTERESSE (Benzina e Ospedali) ---
  final List<Marker> _poiMarkers = [
    // Distributori
    Marker(
        point: const LatLng(45.4265, 12.3218),
        child: const Icon(Icons.local_gas_station,
            color: Colors.orange, size: 25)), // Sacca Fisola
    Marker(
        point: const LatLng(45.4335, 12.3605),
        child: const Icon(Icons.local_gas_station,
            color: Colors.orange, size: 25)), // San Giorgio
    Marker(
        point: const LatLng(45.4495, 12.3312),
        child: const Icon(Icons.local_gas_station,
            color: Colors.orange, size: 25)), // San Leonardo
    // Emergenza
    Marker(
        point: const LatLng(45.4395, 12.3425),
        child: const Icon(Icons.medical_services,
            color: Colors.red, size: 30)), // Ospedale Civile
  ];

  Future<void> _fetchMarea() async {
    const String target =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1";
    final String proxyUrl = "https://api.codetabs.com/v1/proxy?quest=" +
        Uri.encodeComponent(target);
    try {
      final res = await http
          .get(Uri.parse(proxyUrl))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        setState(() {
          _mareaCm =
              int.parse(data[0]['valore'].toString().replaceAll('+', ''));
          _marea = "$_mareaCm cm";
        });
      }
    } catch (e) {
      setState(() => _marea = "$_mareaCm cm (Man)");
    }
  }

  void _regolaMareaManualmente() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Imposta Marea"),
        content: TextField(
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: "Centimetri (es: 60)"),
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
                  accuracy: LocationAccuracy.bestForNavigation))
          .listen((pos) {
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
                  backgroundColor: Colors.transparent),
              MarkerLayer(markers: _poiMarkers), // Mostra Benzina e Ospedali
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
                  border: Border.all(color: Colors.cyanAccent)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                      onTap: _regolaMareaManualmente,
                      child: _stat("MAREA", _marea, Colors.cyanAccent)),
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
                    label: const Text("ATTIVA"),
                    onPressed: _attiva,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.all(20)))),
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
