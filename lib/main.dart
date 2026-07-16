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
  int _mareaCm = 0;
  bool _isLive = false;
  double _speed = 0.0;
  double _totalDist = 0.0;
  LatLng _pos = const LatLng(45.4371, 12.3326);
  List<LatLng> _trail = [];
  final MapController _mapController = MapController();

  // --- LOGICA MAREA DEFINITIVA (Tunnel Pro) ---
  Future<void> _fetchMarea() async {
    setState(() {
      _marea = "...";
      _isLive = false;
    });
    const String api =
        "https://portale.comune.venezia.it/marea/esporta-dati?id=1";

    // Proviamo CorsProxy.io che è basato su Cloudflare (molto stabile)
    final String proxy = "https://corsproxy.io/?" + Uri.encodeComponent(api);

    try {
      final res =
          await http.get(Uri.parse(proxy)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        if (data.isNotEmpty) {
          String valStr =
              data[0]['valore'].toString().replaceAll('+', '').trim();
          setState(() {
            _mareaCm = int.parse(valStr);
            _marea = "$_mareaCm cm";
            _isLive = true; // DIVENTA AZZURRO SE REALE
          });
          return;
        }
      }
    } catch (e) {
      print("Errore T1: $e");
    }

    // Se fallisce, tenta il secondo tunnel
    try {
      final res2 = await http.get(Uri.parse(
          "https://api.codetabs.com/v1/proxy?quest=" +
              Uri.encodeComponent(api)));
      final List data2 = json.decode(res2.body);
      setState(() {
        _mareaCm =
            int.parse(data2[0]['valore'].toString().replaceAll('+', '').trim());
        _marea = "$_mareaCm cm";
        _isLive = true;
      });
    } catch (e) {
      setState(() => _marea = "38 cm (S)"); // Resta Arancione (Simulato)
    }
  }

  void _regolaManuale() {
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text("Marea Manuale"),
              content: TextField(
                  keyboardType: TextInputType.number,
                  onSubmitted: (v) {
                    setState(() {
                      _mareaCm = int.parse(v);
                      _marea = "$_mareaCm cm (M)";
                      _isLive = true;
                    });
                    Navigator.pop(c);
                  }),
            ));
  }

  void _attiva() async {
    _fetchMarea();
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
              MarkerLayer(markers: [
                Marker(
                    point: _pos,
                    width: 60,
                    height: 60,
                    child: const Icon(Icons.navigation,
                        color: Colors.blue, size: 45))
              ]),
            ],
          ),
          Positioned(
            top: 50,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: const Color(0xFF001529).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: _isLive ? Colors.cyanAccent : Colors.orangeAccent,
                      width: 2)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                      onTap: _regolaManuale,
                      child: _stat("MAREA", _marea,
                          _isLive ? Colors.cyanAccent : Colors.orangeAccent)),
                  _stat("PROF.", "${prof.toStringAsFixed(1)}m", Colors.white),
                  _stat("DIST.", "${(_totalDist / 1000).toStringAsFixed(2)}km",
                      Colors.greenAccent),
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
          Positioned(
              bottom: 30,
              right: 20,
              child: FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white24,
                  onPressed: _fetchMarea,
                  child: const Icon(Icons.refresh, color: Colors.white)))
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
