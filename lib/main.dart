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

  // --- FUNZIONE PER CREARE ICONE ---
  Marker _buildPoi(LatLng point, IconData icon, Color color, String name) {
    return Marker(
      point: point,
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () => _mostraNome(name),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  void _mostraNome(String name) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(name, textAlign: TextAlign.center),
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.blueGrey,
    ));
  }

  List<Marker> get _allMarkers {
    return [
      // --- DISTRIBUTORI (Arancio) ---
      _buildPoi(const LatLng(45.4265, 12.3218), Icons.local_gas_station,
          Colors.orange, "Benzina: Sacca Fisola"),
      _buildPoi(const LatLng(45.4542, 12.3515), Icons.local_gas_station,
          Colors.orange, "Benzina: Murano"),
      _buildPoi(const LatLng(45.4855, 12.4165), Icons.local_gas_station,
          Colors.orange, "Benzina: Burano"),
      _buildPoi(const LatLng(45.2205, 12.2815), Icons.local_gas_station,
          Colors.orange, "Benzina: Chioggia"),

      // --- RISTORANTI E TRATTORIE ISOLE (Verde) ---
      // MURANO
      _buildPoi(const LatLng(45.4582, 12.3520), Icons.restaurant, Colors.green,
          "Trattoria Ai Frati (Murano)"),
      _buildPoi(const LatLng(45.4545, 12.3565), Icons.restaurant, Colors.green,
          "Osteria al Duomo (Murano)"),
      // BURANO / MAZZORBO
      _buildPoi(const LatLng(45.4854, 12.4172), Icons.restaurant, Colors.green,
          "Trattoria al Gatto Nero (Burano)"),
      _buildPoi(const LatLng(45.4842, 12.4120), Icons.restaurant, Colors.green,
          "Venissa (Mazzorbo)"),
      // TORCELLO
      _buildPoi(const LatLng(45.4985, 12.4170), Icons.restaurant, Colors.green,
          "Locanda Cipriani (Torcello)"),
      _buildPoi(const LatLng(45.4975, 12.4160), Icons.restaurant, Colors.green,
          "Taverna di Torcello"),
      // SANT'ERASMO
      _buildPoi(const LatLng(45.4560, 12.4125), Icons.restaurant, Colors.green,
          "Il Lato Azzurro (S.Erasmo)"),
      // MALAMOCCO / LIDO
      _buildPoi(const LatLng(45.3715, 12.3395), Icons.restaurant, Colors.green,
          "Trattoria da Scarso (Malamocco)"),
      // PELLESTRINA
      _buildPoi(const LatLng(45.2735, 12.2985), Icons.restaurant, Colors.green,
          "Da Celeste (Pellestrina)"),
      _buildPoi(const LatLng(45.3055, 12.3115), Icons.restaurant, Colors.green,
          "Da Memo (S.Piero in Volta)"),

      // --- EMERGENZA (Rosso) ---
      _buildPoi(const LatLng(45.4395, 12.3425), Icons.medical_services,
          Colors.red, "Ospedale Civile Venezia"),

      // BARCA (Blu)
      Marker(
          point: _pos,
          width: 60,
          height: 60,
          child: const Icon(Icons.navigation, color: Colors.blue, size: 45)),
    ];
  }

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
        _mapController.move(_pos, _mapController.camera.zoom);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
                initialCenter: LatLng(45.4600, 12.3600), initialZoom: 12.0),
            children: [
              TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              TileLayer(
                  urlTemplate:
                      'https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png',
                  backgroundColor: Colors.transparent),
              MarkerLayer(markers: _allMarkers),
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
                  _stat("MAREA", _marea, Colors.cyanAccent),
                  _stat("KM/H", _speed.toStringAsFixed(1), Colors.white),
                  _stat("GPS", _gpsStatus, Colors.greenAccent),
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
                TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.bold))
      ]);
}
