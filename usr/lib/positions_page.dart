
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Position {
  final String index;
  final String size;
  final String profit;
  final dynamic entry;
  final String stoploss;
  final String open;
  final String? close;

  Position({
    required this.index,
    required this.size,
    required this.profit,
    required this.entry,
    required this.stoploss,
    required this.open,
    this.close,
  });

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      index: json['index'] ?? '',
      size: json['size'] ?? '',
      profit: json['profit'] ?? '',
      entry: json['entry'] ?? 0,
      stoploss: json['stoploss'] ?? 'N/A',
      open: json['open'] ?? '',
      close: json['close'],
    );
  }
}

class PositionsPage extends StatefulWidget {
  const PositionsPage({super.key});

  @override
  State<PositionsPage> createState() => _PositionsPageState();
}

class _PositionsPageState extends State<PositionsPage> {
  List<Position> _positions = [];
  bool _isLoading = true;
  String? _error;
  Timer? _timer;

  final Map<String, Map<String, String>> algoMap = {
    "Germany 40 Cash (E1)": {
      "1.2": "PA-DAX 5M V1.0",
      "0.8": "PA-DAX 15M V0.10",
      "0.5": "PA-DAX 1H V0.01",
      "0.6": "PA-DAX 30M V0.20",
      "1.1": "PA-DAX 10M V1.25"
    },
    "Spot Gold (£1 contract)": {
      "8.0": "PA-GOLD 1D V0.10",
      "4.0": "PA-GOLD 1H V0.10"
    },
    "US Tech 100 Cash (£1)": {
      "0.7": "PA-NAS 1H V0.90",
      "0.8": "PA-NAS 3M V0.2",
      "0.5": "PA-NAS 30M V0.250"
    },
    "Wall Street Cash (£1)": {
      "0.3": "PA-WS 3M V1.6"
    },
    "GBP/USD Mini": {
      "2.5": "PA-GBP/USD 4H V0.10"
    }
  };

  @override
  void initState() {
    super.initState();
    _fetchPositions();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) => _fetchPositions());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPositions() async {
    try {
      final response = await http.get(Uri.parse("https://profitalgos.com/api/get_live_positions.php"));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final cutoff = DateTime.parse("2025-08-04T00:00:00Z");
        setState(() {
          _positions = data
              .map((json) => Position.fromJson(json))
              .where((p) {
                if (p.close == null) return true;
                try {
                  final closeDate = DateTime.parse(p.close!);
                  return closeDate.isAfter(cutoff) || closeDate.isAtSameMomentAs(cutoff);
                } catch (e) {
                  return false;
                }
              })
              .toList();
          _isLoading = false;
          _error = null;
        });
      } else {
        setState(() {
          _error = "Failed to load positions: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Failed to load positions: $e";
        _isLoading = false;
      });
    }
  }

  String _normalizeIndexName(String index) {
    final clean = index.trim();
    if (clean.contains("Spot Gold")) return "Spot Gold (£1 contract)";
    if (clean.contains("Germany 40")) return "Germany 40 Cash (E1)";
    if (clean.contains("US Tech 100")) return "US Tech 100 Cash (£1)";
    if (clean.contains("Wall Street")) return "Wall Street Cash (£1)";
    if (clean.contains("GBP/USD")) return "GBP/USD Mini";
    return index;
  }

  String _getAlgoName(String index, String size) {
    final cleanIndex = _normalizeIndexName(index);
    final absSize = (double.tryParse(size) ?? 0.0).abs().toStringAsFixed(1);
    return algoMap[cleanIndex]?[absSize] ?? "Okänd Algo";
  }

  Widget _buildPositionList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }

    if (_positions.isEmpty) {
      return const Center(child: Text("Inga öppna positioner att visa."));
    }

    return ListView.builder(
      itemCount: _positions.length,
      itemBuilder: (context, index) {
        final position = _positions[index];
        final profitValue = double.tryParse(position.profit.replaceAll('E', '').replaceAll(',', '.')) ?? 0.0;
        final profitColor = profitValue < 0 ? Colors.red : Colors.green;
        final direction = (double.tryParse(position.size) ?? 0.0) > 0 ? "Long" : "Short";
        final algoName = _getAlgoName(position.index, position.size);

        String openDate = '';
        String openTime = '';
        if (position.open.isNotEmpty) {
          try {
            final dateObj = DateTime.parse("${position.open}Z");
            openDate = "${dateObj.toLocal().year}-${dateObj.toLocal().month.toString().padLeft(2, '0')}-${dateObj.toLocal().day.toString().padLeft(2, '0')}";
            openTime = "${dateObj.toLocal().hour.toString().padLeft(2, '0')}:${dateObj.toLocal().minute.toString().padLeft(2, '0')}";
          } catch (e) {
            openDate = position.open;
          }
        }
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(algoName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(position.index, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoColumn("Direction", direction),
                    _buildInfoColumn("Size", position.size),
                    _buildInfoColumn("Profit", "${position.profit.replaceFirst('E', '€')}", textColor: profitColor),
                  ],
                ),
                const SizedBox(height: 8),
                 Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     _buildInfoColumn("Entry", (position.entry ?? 0).toString()),
                    _buildInfoColumn("Stop Loss", position.stoploss),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                        _buildInfoColumn("Open Date", "$openDate $openTime"),
                    ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoColumn(String title, String value, {Color textColor = Colors.black}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w500)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Positioner"),
        backgroundColor: const Color(0xFF222b32),
        foregroundColor: Colors.white,
      ),
      body: _buildPositionList(),
    );
  }
}
