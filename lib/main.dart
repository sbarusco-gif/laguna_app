import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(
    const MaterialApp(home: LagunaNavApp(), debugShowCheckedModeBanner: false));

class LagunaNavApp extends StatefulWidget {
  const LagunaNavApp({super.key});
  @override
  State<LagunaNavApp> createState() => _LagunaNavAppState();
}

class _LagunaNavAppState extends State<LagunaNavApp> {
  String _marea = "---";
  double _fondaleBase = 12.0; // Profondità media Canale Giudecca

  @override
  void initState() {
    super.initState();
    _fetchMareaWeb();
  }

  // Metodo specifico per far funzionare la marea sul WEB (bypass CORS)
  Future<void> _fetchMareaWeb() async {
    try {
      final url = Uri.parse(
          'https://api.allorigins.win/get?url=${Uri.encodeComponent('https://portale.comune.venezia.it/marea/esporta-dati?id=1')}');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(json.decode(res.body)['contents']);
        setState(() {
          _marea = "${data[0]['valore']} cm";
        });
      }
    } catch (e) {
      setState(() => _marea = "Errore");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(45.4300, 12.3350),
              initialZoom: 15.0,
            ),
            children: [
              // LIVELLO 1: MAPPA STRADALE
              TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              // LIVELLO 2: MAPPA NAUTICA (Briccole e Canali evidenziati)
              TileLayer(
                urlTemplate:
                    'https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png',
                backgroundColor: Colors.transparent,
              ),
            ],
          ),
          // DASHBOARD NAUTICA
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF001529).withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.cyanAccent),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _info("MAREA", _marea),
                  _info("ZONA", "Giudecca"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(String t, String v) => Column(
        children: [
          Text(t, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          Text(v,
              style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
        ],
      );
}
