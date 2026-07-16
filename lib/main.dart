import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

void main() => runApp(
    const MaterialApp(home: LagunaApp(), debugShowCheckedModeBanner: false));

class LagunaApp extends StatefulWidget {
  const LagunaApp({super.key});
  @override
  State<LagunaApp> createState() => _LagunaAppState();
}

class _LagunaAppState extends State<LagunaApp> {
  String _mareaDisplay = "40 cm (S)";
  int _mareaCm = 40;
  bool _isLive = false;
  double _speed = 0.0;
  double _heading = 0.0;
  LatLng _pos = const LatLng(45.4371, 12.3326);
  final MapController _mapController = MapController();
  bool _active = false;

  // --- LOGICA MAREA "LAST ATTEMPT" ---
  Future<void> _fetchMarea() async {
    const String target =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1";
    // Proxy alternativo ultra-veloce
    final String proxy = "https://api.codetabs.com/v1/proxy?quest=" +
        Uri.encodeComponent(target);

    try {
      final res =
          await http.get(Uri.parse(proxy)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        setState(() {
          _mareaCm =
              int.parse(data[0]['valore'].toString().replaceAll('+', ''));
          _mareaDisplay = "$_mareaCm cm (L)";
          _isLive = true;
        });
      }
    } catch (e) {
      debugPrint("CORS Block active");
    }
  }

  // --- IMPOSTAZIONE MANUALE (Per i piloti veri) ---
  void _setMareaManuale() {
    TextEditingController _txt = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Aggiorna Marea"),
        content: TextField(
          controller: _txt,
          keyboardType: TextInputType.number,
          decoration:
              const InputDecoration(hintText: "Inserisci cm attuali (es. 45)"),
        ),
        actions: [
          TextButton(
              onPressed: () {
                setState(() {
                  _mareaCm = int.parse(_txt.text);
                  _mareaDisplay = "$_mareaCm cm (M)";
                  _isLive = true; // Diventa azzurro
                });
                Navigator.pop(context);
              },
              child: const Text("IMPOSTA")),
        ],
      ),
    );
  }

  // --- CALCOLO PROFONDITÀ ---
  double _getDepth(LatLng p) {
    double base = 1.2; // Default secche
    if (p.latitude < 45.433 && p.latitude > 45.425)
      base = 12.0; // Giudecca
    else if (p.latitude > 45.450) base = 4.0; // Murano
    return base + (_mareaCm / 100);
  }

  void _avvia() async {
    _fetchMarea();
    LocationPermission p = await Geolocator.requestPermission();
    if (p == LocationPermission.always || p == LocationPermission.whileInUse) {
      setState(() => _active = true);
      Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.bestForNavigation,
                  distanceFilter: 2))
          .listen((pos) {
        setState(() {
          _pos = LatLng(pos.latitude, pos.longitude);
          _speed = pos.speed * 3.6;
          if (_speed > 1.8) _heading = pos.heading;
        });
        _mapController.move(_pos, 15.5);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double prof = _getDepth(_pos);
    bool alarm = prof < 1.8;

    return Scaffold(
      backgroundColor: Colors.black,
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
                  child: Transform.rotate(
                    angle: (_heading * (math.pi / 180)),
                    child: const Icon(Icons.navigation,
                        color: Colors.blue, size: 45),
                  ),
                )
              ]),
            ],
          ),

          // DASHBOARD HI-TECH
          Positioned(
            top: 40,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF001529).withOpacity(0.9),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                    color: _isLive ? Colors.cyanAccent : Colors.orangeAccent,
                    width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                    onTap: _setMareaManuale,
                    child: _stat("MAREA", _mareaDisplay,
                        _isLive ? Colors.cyanAccent : Colors.orangeAccent),
                  ),
                  _stat("PROF.", "${prof.toStringAsFixed(1)}m",
                      alarm ? Colors.red : Colors.white),
                  _stat("ROTTA", "${_heading.toInt()}°", Colors.orangeAccent),
                  _stat("KM/H", _speed.toStringAsFixed(1), Colors.greenAccent),
                ],
              ),
            ),
          ),

          // BUSSOLA ROTANTE
          Positioned(
            bottom: 30,
            left: 20,
            child: Container(
              width: 75,
              height: 75,
              decoration: BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24)),
              child: Transform.rotate(
                angle: (_heading * (math.pi / 180) * -1),
                child: const Icon(Icons.explore, color: Colors.white, size: 55),
              ),
            ),
          ),

          if (!_active)
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.anchor, size: 30),
                label: const Text("ATTIVA SISTEMA",
                    style: TextStyle(fontSize: 18)),
                onPressed: _avvia,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.all(25),
                ),
              ),
            ),

          // REFRESH RAPIDO
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white24,
              child: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _fetchMarea,
            ),
          )
        ],
      ),
    );
  }

  Widget _stat(String l, String v, Color c) => Column(children: [
        Text(l,
            style: const TextStyle(
                color: Colors.white60,
                fontSize: 8,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(v,
            style: TextStyle(
                color: c,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace')),
      ]);
}
