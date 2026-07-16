import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(const MaterialApp(home: LagunaApp(), debugShowCheckedModeBanner: false));

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

  // --- DATABASE POI LAGUNA TOTALE ---
  final List<Marker> _poiMarkers = [
    // --- DISTRIBUTORI BENZINA ---
    Marker(point: const LatLng(45.4265, 12.3218), child: const Icon(Icons.local_gas_station, color: Colors.orange, size: 20)), // Sacca Fisola
    Marker(point: const LatLng(45.4335, 12.3605), child: const Icon(Icons.local_gas_station, color: Colors.orange, size: 20)), // San Giorgio
    Marker(point: const LatLng(45.4542, 12.3515), child: const Icon(Icons.local_gas_station, color: Colors.orange, size: 20)), // Murano
    Marker(point: const LatLng(45.4855, 12.4165), child: const Icon(Icons.local_gas_station, color: Colors.orange, size: 20)), // Burano (Mazzorbo)
    Marker(point: const LatLng(45.3412, 12.3025), child: const Icon(Icons.local_gas_station, color: Colors.orange, size: 20)), // Pellestrina
    Marker(point: const LatLng(45.2205, 12.2815), child: const Icon(Icons.local_gas_station, color: Colors.orange, size: 20)), // Chioggia
    
    // --- EMERGENZA E OSPEDALI ---
    Marker(point: const LatLng(45.4395, 12.3425), child: const Icon(Icons.medical_services, color: Colors.red, size: 25)), // Venezia Civile
    Marker(point: const LatLng(45.2185, 12.2785), child: const Icon(Icons.medical_services, color: Colors.red, size: 25)), // Chioggia Ospedale
  ];

  // --- LOGICA PROFONDITÀ DINAMICA ---
  double _getFondaleStimato(LatLng pos) {
    // Canale della Giudecca e Bocche di Porto (Malamocco, Lido, Chioggia)
    if (pos.latitude < 45.435 && pos.latitude > 45.425) return 12.0; 
    if (pos.latitude < 45.350 && pos.latitude > 45.330) return 14.0; // Bocca di Malamocco
    if (pos.latitude < 45.230) return 8.0; // Zona Chioggia
    
    // Canali interni (Murano, Burano, Torcello)
    if (pos.latitude > 45.450) return 4.5;
    
    // Tutto il resto (secche e barene)
    return 1.2;
  }

  Future<void> _fetchMarea() async {
    const String target = "https://portale.comune.venezia.it/marea/esporta-dati?id=1";
    final String proxyUrl = "https://api.codetabs.com/v1/proxy?quest=" + Uri.encodeComponent(target);
    try {
      final res = await http.get(Uri.parse(proxyUrl)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        setState(() {
          _mareaCm = int.parse(data[0]['valore'].toString().replaceAll('+', ''));
          _marea = "$_mareaCm cm";
        });
      }
    } catch (e) { setState(() => _marea = "$_mareaCm cm (Man)"); }
  }

  void _regolaMareaManualmente() {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("Imposta Marea"),
      content: TextField(keyboardType: TextInputType.number, onSubmitted: (val) {
        setState(() { _mareaCm = int.parse(val); _marea = "$_mareaCm cm (Man)"; });
        Navigator.pop(context);
      }),
    ));
  }

  Future<void> _attiva() async {
    _fetchMarea();
    LocationPermission p = await Geolocator.requestPermission();
    if (p == LocationPermission.always || p == LocationPermission.whileInUse) {
      setState(() => _gpsStatus = "OK");
      Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation)).listen((pos) {
        setState(() { _pos = LatLng(pos.latitude, pos.longitude); _speed = pos.speed * 3.6; });
        _mapController.move(_pos, _mapController.camera.zoom);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double profondita = _getFondaleStimato(_pos) + (_mareaCm / 100);

    return Scaffold(
      backgroundColor: const Color(0xFF000A12),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(45.4000, 12.3500), // Centro laguna
              initialZoom: 11.0, // Visuale ampia su tutta la laguna
            ),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              // LIVELLO NAUTICO (Copre tutta la laguna!)
              TileLayer(urlTemplate: 'https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png', backgroundColor: Colors.transparent),
              MarkerLayer(markers: _poiMarkers),
              MarkerLayer(markers: [Marker(point: _pos, width: 60, height: 60, child: const Icon(Icons.navigation, color: Colors.red, size: 40))]),
            ],
          ),
          // DASHBOARD
          Positioned(
            top: 50, left: 10, right: 10,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: const Color(0xFF001529).withOpacity(0.9), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.cyanAccent)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(onTap: _regolaMareaManualmente, child: _stat("MAREA", _marea, Colors.cyanAccent)),
                  _stat("PROF.", "${profondita.toStringAsFixed(1)}m", profondita < 2.0 ? Colors.red : Colors.white),
                  _stat("KM/H", _speed.toStringAsFixed(1), Colors.greenAccent),
                ],
              ),
            ),
          ),
          if (_gpsStatus != "OK")
            Center(child: ElevatedButton.icon(icon: const Icon(Icons.anchor), label: const Text("ATTIVA"), onPressed: _attiva, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black, padding: const EdgeInsets.all(20)))),
        ],
      ),
    );
  }

  Widget _stat(String l, String v, Color c) => Column(mainAxisSize: MainAxisSize.min, children: [Text(l, style: const TextStyle(color: Colors.white60, fontSize: 9)), Text(v, style: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.bold))]);
}