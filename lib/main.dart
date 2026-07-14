import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

void main() => runApp(
    const MaterialApp(home: LagunaApp(), debugShowCheckedModeBanner: false));

class LagunaApp extends StatefulWidget {
  const LagunaApp({super.key});
  @override
  State<LagunaApp> createState() => _LagunaAppState();
}

class _LagunaAppState extends State<LagunaApp> {
  double _speed = 0.0;
  String _marea = "Caricamento...";
  LatLng _currentPos = const LatLng(45.4371, 12.3326); // Piazza San Marco
  final MapController _mapController = MapController();
  List<Polyline> _canali = [];

  @override
  void initState() {
    super.initState();
    _loadCanali();
    _fetchMarea();
    _startGps();
  }

  // CARICAMENTO E CORREZIONE COORDINATE
  Future<void> _loadCanali() async {
    try {
      final String jsonStr = await rootBundle.loadString('assets/canali.json');
      final data = json.decode(jsonStr);
      List<Polyline> tempLines = [];

      for (var feature in data['features']) {
        var coords = feature['geometry']['coordinates'];
        List<LatLng> points = [];

        for (var c in coords) {
          // LOGICA DI SICUREZZA:
          // In un GeoJSON standard: c[0] è Longitudine (~12), c[1] è Latitudine (~45)
          double lon = c[0].toDouble();
          double lat = c[1].toDouble();

          // Se per errore sono invertiti nel file, li scambiamo qui
          if (lon > 40) {
            // Se il primo numero è 45, allora è la latitudine
            double temp = lon;
            lon = lat;
            lat = temp;
          }

          points.add(LatLng(lat, lon));
        }

        tempLines.add(Polyline(
          points: points,
          strokeWidth: 5,
          color: Colors.blue.withOpacity(0.7),
        ));
      }
      setState(() => _canali = tempLines);
    } catch (e) {
      debugPrint("Errore JSON: $e");
    }
  }

  Future<void> _fetchMarea() async {
    try {
      final res = await http.get(Uri.parse(
          'https://portale.comune.venezia.it/marea/esporta-dati?id=1'));
      final data = json.decode(res.body);
      setState(() => _marea = "${data[0]['valore']} cm");
    } catch (e) {
      setState(() => _marea = "N/D");
    }
  }

  Future<void> _startGps() async {
    await Geolocator.requestPermission();
    Geolocator.getPositionStream(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.bestForNavigation),
    ).listen((pos) {
      setState(() {
        _currentPos = LatLng(pos.latitude, pos.longitude);
        _speed = pos.speed * 3.6;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPos,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              PolylineLayer(polylines: _canali),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentPos,
                    child: const Icon(Icons.navigation,
                        color: Colors.red, size: 40),
                  ),
                ],
              ),
            ],
          ),

          // DASHBOARD INFRASTRUTTURA
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _box("VELOCITÀ", "${_speed.toStringAsFixed(1)} km/h",
                    _speed > 7 ? Colors.red : Colors.greenAccent),
                _box("MAREA", _marea, Colors.lightBlueAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _box(String t, String v, Color c) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.black87, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text(t, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          Text(v,
              style: TextStyle(
                  color: c, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
