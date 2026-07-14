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
  String _marea = "Richiesta...";
  String _gpsStatus = "GPS Spento";
  LatLng _pos = const LatLng(45.4371, 12.3326); // San Marco
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _fetchMarea();
  }

  // --- SOLUZIONE MAREA (Nuovo Proxy) ---
  Future<void> _fetchMarea() async {
    try {
      // Usiamo corsproxy.io che è più pulito per il Web
      final url = Uri.parse('https://corsproxy.io/?' +
          Uri.encodeComponent(
              'https://portale.comune.venezia.it/marea/esporta-dati?id=1'));
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        setState(() => _marea = "${data[0]['valore']} cm");
      } else {
        setState(() => _marea = "Errore ${res.statusCode}");
      }
    } catch (e) {
      setState(() => _marea = "Errore CORS");
      print(e);
    }
  }

  // --- SOLUZIONE GPS (Richiede interazione) ---
  Future<void> _attivaGps() async {
    setState(() => _gpsStatus = "Ricerca...");

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _gpsStatus = "Attiva GPS nel tel");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _pos = LatLng(position.latitude, position.longitude);
        _gpsStatus = "OK";
        _mapController.move(_pos, 15);
      });

      // Avvia lo streaming continuo
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation),
      ).listen((pos) {
        setState(() {
          _pos = LatLng(pos.latitude, pos.longitude);
        });
      });
    } else {
      setState(() => _gpsStatus = "Permesso Negato");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _pos, initialZoom: 14),
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
                  child:
                      const Icon(Icons.navigation, color: Colors.red, size: 40),
                )
              ]),
            ],
          ),
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(15)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _col("MAREA", _marea),
                  _col("GPS", _gpsStatus),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 50,
            right: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.gps_fixed),
              label: const Text("ATTIVA GPS E MAREA"),
              onPressed: () {
                _attivaGps();
                _fetchMarea();
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _col(String t, String v) => Column(children: [
        Text(t, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        Text(v,
            style: const TextStyle(
                color: Colors.cyanAccent,
                fontSize: 18,
                fontWeight: FontWeight.bold))
      ]);
}
