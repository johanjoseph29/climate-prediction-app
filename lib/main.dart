import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';

// --- API Configuration ---
// IMPORTANT: Replace with your computer's IP address on your local network.
const String yourPcIpAddress = '192.168.56.1'; // <-- REPLACE THIS
const String apiUrl = 'http://$yourPcIpAddress:5000/predict';
const String chartApiUrl = 'http://$yourPcIpAddress:5000/historical-chart';

void main() {
  runApp(const ClimatePredictionApp());
}

class ClimatePredictionApp extends StatelessWidget {
  const ClimatePredictionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Climate Prediction',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: Color(0xFFDDE2E7)),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        ),
        cardTheme: CardTheme(
          elevation: 1.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: const BorderSide(color: Color(0xFFE5E9F0)),
          ),
          color: Colors.white,
        ),
      ),
      home: const ClimatePredictionScreen(),
    );
  }
}

class ClimatePredictionScreen extends StatefulWidget {
  const ClimatePredictionScreen({super.key});

  @override
  State<ClimatePredictionScreen> createState() => _ClimatePredictionScreenState();
}

class _ClimatePredictionScreenState extends State<ClimatePredictionScreen> {
  final _locationController = TextEditingController();
  final _dateController = TextEditingController();
  final _summaryController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  // State variables
  bool _isLoading = false;
  String _errorMessage = '';
  String _temperature = '--';
  String _rainfall = '--';
  String _windspeed = '--';
  List<FlSpot> _chartSpots = [];

  Map<String, bool> _variables = {
    'Temperature': true,
    'Rainfall/Precipitation': true,
    'Windspeed': true,
    'Air Quality / Dust': false,
  };
  String? _selectedThreshold = 'Show probability of Temp>30°C';

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('MMMM d').format(_selectedDate);
  }

  @override
  void dispose() {
    _locationController.dispose();
    _dateController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('MMMM d').format(picked);
      });
    }
  }

  Future<void> _getClimatePrediction() async {
    if (_locationController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter a location.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _chartSpots = [];
    });

    try {
      final requestBody = json.encode({
        'city': _locationController.text,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      });
      final headers = {'Content-Type': 'application/json'};

      final predictionRequest = http.post(Uri.parse(apiUrl), headers: headers, body: requestBody);
      final chartRequest = http.post(Uri.parse(chartApiUrl), headers: headers, body: requestBody);

      final responses = await Future.wait([predictionRequest, chartRequest]);
      final predictionResponse = responses[0];
      final chartResponse = responses[1];

      // Process prediction data
      if (predictionResponse.statusCode == 200) {
        final data = json.decode(predictionResponse.body);
        setState(() {
          _temperature = data['statistics']['average_max_temp'];
          _rainfall = data['statistics']['chance_of_rain'];
          _windspeed = '--';
          _summaryController.text = data['summary'];
        });
      } else {
        final errorData = json.decode(predictionResponse.body);
        setState(() => _errorMessage = errorData['error'] ?? 'Failed to load prediction.');
      }

      // Process chart data
      if (chartResponse.statusCode == 200) {
        final List<dynamic> chartData = json.decode(chartResponse.body);
        setState(() {
          _chartSpots = chartData.map((point) {
            return FlSpot(
              (point['year'] as int).toDouble(),
              (point['avg_temp'] as num).toDouble(),
            );
          }).toList();
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Connection failed. Is the Python server running?');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Climate Prediction', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1C2A40))),
            const SizedBox(height: 8),
            Text('Historical likelihood of weather conditions for any location & day', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 32),
            ResponsiveLayout(
              leftPanel: _buildFormCard(),
              rightPanel: _buildResultsPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Location', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(controller: _locationController, decoration: const InputDecoration(hintText: 'Enter city/location name')),
            const SizedBox(height: 20),
            const Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _dateController,
              readOnly: true,
              decoration: InputDecoration(suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: () => _selectDate(context))),
              onTap: () => _selectDate(context),
            ),
            const SizedBox(height: 20),
            const Text('Variables to display', style: TextStyle(fontWeight: FontWeight.bold)),
            ..._variables.keys.map((key) => CheckboxListTile(
              title: Text(key),
              value: _variables[key],
              onChanged: (value) => setState(() => _variables[key] = value!),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            )),
            const SizedBox(height: 20),
            const Text('Threshold Options', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedThreshold,
              items: ['Show probability of Temp>30°C', 'Show probability of Rain>10mm'].map((label) => DropdownMenuItem(value: label, child: Text(label))).toList(),
              onChanged: (newValue) => setState(() => _selectedThreshold = newValue),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _getClimatePrediction,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) : const Text('Get Prediction'),
              ),
            ),
            if (_errorMessage.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 16.0), child: Text(_errorMessage, style: const TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsPanel() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: MetricCard(label: 'Avg. High Temp', value: _temperature, color: const Color(0xFFFEE6E6))),
            const SizedBox(width: 16),
            Expanded(child: MetricCard(label: 'Chance of Rain', value: _rainfall, color: const Color(0xFFE3F5E9))),
            const SizedBox(width: 16),
            Expanded(child: MetricCard(label: 'Windspeed', value: _windspeed, color: const Color(0xFFE4F2FF))),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                TextFormField(controller: _summaryController, maxLines: 6, readOnly: true, decoration: const InputDecoration(hintText: 'AI summary will appear here...')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Historical Temperature Trend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Average high for this week over the last 20 years', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 20),
                TemperatureTrendChart(chartData: _chartSpots),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          child: const Text('Download CSV/JSON'),
        ),
      ],
    );
  }
}

// =============================================================================
// CUSTOM WIDGETS
// =============================================================================

class MetricCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const MetricCard({super.key, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10.0)),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class ResponsiveLayout extends StatelessWidget {
  final Widget leftPanel, rightPanel;
  const ResponsiveLayout({super.key, required this.leftPanel, required this.rightPanel});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth > 800) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 2, child: leftPanel),
          const SizedBox(width: 24),
          Expanded(flex: 3, child: rightPanel),
        ]);
      } else {
        return Column(children: [leftPanel, const SizedBox(height: 24), rightPanel]);
      }
    });
  }
}

class TemperatureTrendChart extends StatelessWidget {
  final List<FlSpot> chartData;
  const TemperatureTrendChart({super.key, required this.chartData});

  @override
  Widget build(BuildContext context) {
    if (chartData.isEmpty) {
      return const SizedBox(height: 250, child: Center(child: Text("Press 'Get Prediction' to see the chart.")));
    }
    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: 5)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.black26, width: 1)),
          lineBarsData: [
            LineChartBarData(
              spots: chartData,
              isCurved: true,
              color: Colors.blueAccent,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: Colors.blueAccent.withOpacity(0.3)),
            )
          ],
        ),
      ),
    );
  }
}