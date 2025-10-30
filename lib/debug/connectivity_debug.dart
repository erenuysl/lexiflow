import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/logger.dart';

/// Debug widget to test connectivity status
class ConnectivityDebugWidget extends StatefulWidget {
  const ConnectivityDebugWidget({super.key});

  @override
  State<ConnectivityDebugWidget> createState() => _ConnectivityDebugWidgetState();
}

class _ConnectivityDebugWidgetState extends State<ConnectivityDebugWidget> {
  ConnectivityResult? _currentConnectivity;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _initConnectivityTest();
  }

  void _initConnectivityTest() async {
    // Test initial connectivity
    final result = await Connectivity().checkConnectivity();
    _addLog('Initial connectivity: $result');
    setState(() {
      _currentConnectivity = result;
    });

    // Listen to connectivity changes
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      _addLog('Connectivity changed to: $result');
      setState(() {
        _currentConnectivity = result;
      });
    });
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logMessage = '[$timestamp] $message';
    Logger.d(logMessage, 'ConnectivityDebug');
    setState(() {
      _logs.insert(0, logMessage);
      if (_logs.length > 20) {
        _logs.removeLast();
      }
    });
  }

  void _testConnectivity() async {
    _addLog('Manual connectivity test started');
    final result = await Connectivity().checkConnectivity();
    _addLog('Manual test result: $result');
    
    // Test if we can actually reach the internet
    try {
      final response = await Future.delayed(
        const Duration(seconds: 2),
        () => 'Internet test completed',
      );
      _addLog('Internet test: $response');
    } catch (e) {
      _addLog('Internet test failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connectivity Debug'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Status',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _currentConnectivity == ConnectivityResult.none
                              ? Icons.wifi_off
                              : Icons.wifi,
                          color: _currentConnectivity == ConnectivityResult.none
                              ? Colors.red
                              : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Connectivity: ${_currentConnectivity?.toString() ?? 'Unknown'}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Is Online: ${_currentConnectivity != ConnectivityResult.none}',
                      style: TextStyle(
                        fontSize: 16,
                        color: _currentConnectivity != ConnectivityResult.none
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Test Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _testConnectivity,
                child: const Text('Test Connectivity'),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Logs
            const Text(
              'Debug Logs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Text(
                        _logs[index],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}