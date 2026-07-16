import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
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
  String _marea = "40 cm (S)";
  int _mareaCm = 40;
  Color _statusColor = Colors.orangeAccent;
  double _speed = 0.0;
  double _totalDist = 0.0;
  double _heading = 0.0; // Gradi della bussola
  LatLng _pos = const LatLng(45.4371, 12.3326);
  List<LatLng> _trail = [];
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
  }

  // --- LOGICA BUSSOLA ---
  void _initCompass() {
    FlutterCompass.events?.listen((event) {
      setState(() {
        _heading = event.heading ?? 0;
      });
    });
  }

  Future<void> _fetchMarea() async {
    const String target =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1";
    final String proxy =
        "https://api.allorigins.win/raw?url=${Uri.encodeComponent(target)}";
    try {
      final res =
          await http.get(Uri.parse(proxy)).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        setState(() {
          _mareaCm =
              int.parse(data[0]['valore'].toString().replaceAll('+', ''));
          _marea = "$_mareaCm cm (A)";
          _statusColor = Colors.cyanAccent;
        });
      }
    } catch (e) {
      debugPrint("Marea auto fallita");
    }
  }

  void _regolaManuale() {
    TextEditingController ctl = TextEditingController();
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text("Marea Manuale"),
              content: TextField(
                  controller: ctl, keyboardType: TextInputType.number),
              actions: [
                TextButton(
                    onPressed: () {
                      setState(() {
                        _mareaCm = int.parse(ctl.text);
                        _marea = "$_mareaCm cm (M)";
                        _statusColor = Colors.yellowAccent;
                      });
                      Navigator.pop(c);
                    },
                    child: const Text("OK"))
              ],
            ));
  }

  void _attiva() async {
    _fetchMarea();
    _initCompass(); // Attiva sensori bussola
    LocationPermission p = await Geolocator.requestPermission();
    if (p == LocationPermission.always || p == LocationPermission.whileInUse) {
      Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.bestForNavigation,
                  distanceFilter: 5))
          .listen((pos) {
        LatLng newPos = LatLng(pos.latitude, pos.longitude);
        setState(() {
          if (_trail.isNotEmpty)
            _totalDist += Geolocator.distanceBetween(_pos.latitude,
                _pos.longitude, newPos.latitude, newPos.longitude);
          _pos = newPos;
          _speed = pos.speed * 3.6;
          _trail.add(_pos);
        });
        _mapController.move(_pos, 15);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double prof = 12.0 + (_mareaCm / 100);
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
              PolylineLayer(polylines: [
                Polyline(
                    points: _trail, strokeWidth: 4, color: Colors.redAccent)
              ]),
              // Freccia posizione ruotabile con la bussola
              MarkerLayer(markers: [
                Marker(
                  point: _pos,
                  width: 60,
                  height: 60,
                  child: Transform.rotate(
                    angle: (_heading * (math.pi / 180) * -1),
                    child: const Icon(Icons.navigation,
                        color: Colors.blue, size: 45),
                  ),
                )
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
                  border: Border.all(color: _statusColor, width: 2)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                      onTap: _regolaManuale,
                      child: _stat("MAREA", _marea, _statusColor)),
                  _stat("PROF.", "${prof.toStringAsFixed(1)}m", Colors.white),
                  _stat("KM/H", _speed.toStringAsFixed(1), Colors.greenAccent),
                ],
              ),
            ),
          ),

          // --- BUSSOLA VISIVA (In basso a sinistra) ---
          Positioned(
            bottom: 30,
            left: 20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Text("N",
                      style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                  Transform.rotate(
                    angle: (_heading * (math.pi / 180) * -1),
                    child: const Icon(Icons.explore,
                        color: Colors.white, size: 60),
                  ),
                ],
              ),
            ),
          ),

          if (_trail.isEmpty)
            Center(
                child: ElevatedButton.icon(
                    icon: const Icon(Icons.anchor),
                    label: const Text("ATTIVA"),
                    onPressed: _attiva,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.all(20)))),

          // DISTANZA
          Positioned(
              bottom: 30,
              right: 20,
              child: Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.black87,
                  child: Text("${(_totalDist / 1000).toStringAsFixed(2)} KM",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold))))
        ],
      ),
    );
  }

  Widget _stat(String l, String v, Color c) => Column(children: [
        Text(l, style: const TextStyle(color: Colors.white60, fontSize: 9)),
        Text(v,
            style:
                TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.bold))
      ]);
}
