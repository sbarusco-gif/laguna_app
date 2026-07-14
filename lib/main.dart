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
  String _status = "Pronto. Clicca ATTIVA";
  LatLng _pos = const LatLng(45.4371, 12.3326);
  final MapController _mapController = MapController();

  // --- FUNZIONE MAREA CON PROXY ---
  Future<void> _fetchMarea() async {
    setState(() => _marea = "...");
    try {
      final url = Uri.parse(
          'https://api.allorigins.win/get?url=${Uri.encodeComponent('https://portale.comune.venezia.it/marea/esporta-dati?id=1')}');
      final res = await http.get(url);
      final data = json.decode(json.decode(res.body)['contents']);
      setState(() => _marea = "${data[0]['valore']} cm");
    } catch (e) {
      setState(() => _marea = "Errore");
    }
  }

  // --- FUNZIONE GPS CON DIAGNOSTICA ---
  Future<void> _attivaGps() async {
    setState(() => _status = "Verifica permessi...");

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      setState(() => _status = "Richiesta permesso...");
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _status = "GPS BLOCCATO NELLE IMPOSTAZIONI");
      return;
    }

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      setState(() => _status = "Ricerca Satelliti...");
      try {
        Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        setState(() {
          _pos = LatLng(pos.latitude, pos.longitude);
          _status = "GPS OK";
          _mapController.move(_pos, 15);
        });

        // Avvia aggiornamento continuo
        Geolocator.getPositionStream().listen((p) {
          setState(() {
            _pos = LatLng(p.latitude, p.longitude);
          });
        });
      } catch (e) {
        setState(() => _status = "Errore: Timeout GPS");
      }
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
                    child: const Icon(Icons.navigation,
                        color: Colors.red, size: 40))
              ]),
            ],
          ),
          Positioned(
            top: 50,
            left: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.all(15),
              color: Colors.black87,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(children: [
                    const Text("MAREA",
                        style: TextStyle(color: Colors.white54, fontSize: 10)),
                    Text(_marea,
                        style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold))
                  ]),
                  Column(children: [
                    const Text("STATO GPS",
                        style: TextStyle(color: Colors.white54, fontSize: 10)),
                    Text(_status,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12))
                  ]),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 50,
            right: 50,
            child: ElevatedButton(
              onPressed: () {
                _attivaGps();
                _fetchMarea();
              },
              child: const Text("ATTIVA"),
            ),
          )
        ],
      ),
    );
  }
}
