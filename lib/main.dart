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
  Marker _buildPoi(LatLng point, Color color, String name, bool isFamous) {
    return Marker(
      point: point,
      width: 45,
      height: 45,
      child: GestureDetector(
        onTap: () => _mostraInfo(name, isFamous),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
                color: isFamous ? color : Colors.orangeAccent, width: 3),
            boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: Icon(isFamous ? Icons.restaurant : Icons.set_meal,
              color: isFamous ? color : Colors.orange[800], size: 22),
        ),
      ),
    );
  }

  void _mostraInfo(String name, bool isFamous) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        "${isFamous ? '🌟' : '⚓'} $name",
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      duration: const Duration(seconds: 3),
      backgroundColor: isFamous ? Colors.green[800] : Colors.orange[900],
    ));
  }

  List<Marker> get _allMarkers {
    return [
      // --- TRATTORIE E OSTERIE DELLE ISOLE ---

      // LE VIGNOLE (Isola quasi sconosciuta ai turisti)
      _buildPoi(const LatLng(45.4510, 12.3785), Colors.green,
          "Trattoria alle Vignole (Solo barca)", false),

      // SANT'ERASMO (L'orto di Venezia)
      _buildPoi(const LatLng(45.4552, 12.4130), Colors.green,
          "Trattoria da Tedeschi (Molto locale)", false),
      _buildPoi(const LatLng(45.4480, 12.4050), Colors.green,
          "I Sapori di S.Erasmo", false),

      // MAZZORBO
      _buildPoi(const LatLng(45.4851, 12.4110), Colors.green,
          "Trattoria Maddalena (Autentica)", false),
      _buildPoi(const LatLng(45.4842, 12.4120), Colors.green,
          "Venissa (Stella Michelin)", true),

      // BURANO
      _buildPoi(const LatLng(45.4854, 12.4172), Colors.green,
          "Trattoria al Gatto Nero", true),
      _buildPoi(
          const LatLng(45.4848, 12.4185), Colors.green, "Da Romano", true),
      _buildPoi(const LatLng(45.4840, 12.4150), Colors.green,
          "Trattoria da Primo", false),

      // TORCELLO
      _buildPoi(const LatLng(45.4985, 12.4170), Colors.green,
          "Locanda Cipriani", true),
      _buildPoi(const LatLng(45.4970, 12.4165), Colors.green,
          "Ponte del Diavolo", false),

      // MURANO
      _buildPoi(const LatLng(45.4582, 12.3520), Colors.green,
          "Trattoria Ai Frati", true),
      _buildPoi(const LatLng(45.4545, 12.3565), Colors.green,
          "Osteria al Duomo", false),
      _buildPoi(const LatLng(45.4555, 12.3510), Colors.green,
          "Trattoria Valmarana", false),

      // MALAMOCCO (Lido Sud)
      _buildPoi(const LatLng(45.3715, 12.3395), Colors.green,
          "Trattoria da Scarso", true),
      _buildPoi(const LatLng(45.3710, 12.3390), Colors.green,
          "Trattoria da Gino", false),

      // PELLESTRINA / SAN PIETRO IN VOLTA
      _buildPoi(const LatLng(45.3055, 12.3115), Colors.green,
          "Da Memo (Specialità Pesce)", false),
      _buildPoi(
          const LatLng(45.3045, 12.3105), Colors.green, "Da Giani", false),
      _buildPoi(const LatLng(45.2735, 12.2985), Colors.green,
          "Da Celeste (Famoso)", true),
      _buildPoi(const LatLng(45.2910, 12.3050), Colors.green,
          "Agriturismo Le Valli (In mezzo alle valli)", false),

      // POSIZIONE BARCA
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
                initialCenter: LatLng(45.4500, 12.3800), initialZoom: 12.0),
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
                  _stat("GPS", _gpsStatus, Colors.greenAccent)
                ],
              ),
            ),
          ),
          if (_gpsStatus != "OK")
            Center(
                child: ElevatedButton.icon(
                    icon: const Icon(Icons.anchor),
                    label: const Text("ATTIVA NAVIGATORE"),
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
