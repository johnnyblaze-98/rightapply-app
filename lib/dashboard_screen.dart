
import 'package:flutter/material.dart';
import 'services/api.dart';
import 'utils/mac.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  String? _deviceId;
  Map<String, dynamic>? _deviceStatus;
  bool _loadingDevice = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentDevice();
  }

  Future<void> _loadCurrentDevice() async {
    setState(() { _loadingDevice = true; });
    final id = await getPrimaryMacOrId();
    final status = await ApiService.getStatus(id);
    setState(() {
      _deviceId = id;
      _deviceStatus = status;
      _loadingDevice = false;
    });
  }

  List<_TabItem> get _tabs => [
    _TabItem(icon: Icons.dashboard, label: 'Overview', content: Center(child: Text('Overview'))),
    _TabItem(icon: Icons.devices, label: 'Devices', content: _buildDevicesTab()),
    _TabItem(icon: Icons.settings, label: 'Settings', content: Center(child: Text('Settings'))),
    _TabItem(icon: Icons.info_outline, label: 'About', content: Center(child: Text('About'))),
  ];

  Widget _buildDevicesTab() {
    if (_loadingDevice) {
      return Center(child: CircularProgressIndicator());
    }
    if (_deviceId == null || _deviceStatus == null) {
      return Center(child: Text('Unable to load device info'));
    }
    return Center(
      child: Card(
        elevation: 4,
        margin: EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.devices, color: Colors.deepPurple, size: 32),
                  SizedBox(width: 12),
                  Text('This Device', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
              SizedBox(height: 16),
              Text('Device ID: ${maskId(_deviceId!)}', style: TextStyle(fontSize: 16)),
              SizedBox(height: 8),
              Text('Status: ${_deviceStatus!['status']}', style: TextStyle(fontSize: 16, color: _deviceStatus!['approved'] == true ? Colors.green : Colors.orange)),
              SizedBox(height: 8),
              Text('Approved: ${_deviceStatus!['approved'] == true ? 'Yes' : 'No'}', style: TextStyle(fontSize: 16)),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadCurrentDevice,
                icon: Icon(Icons.refresh),
                label: Text('Refresh'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 80,
            color: Colors.deepPurple.shade50,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_tabs.length, (index) {
                final selected = _selectedIndex == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: IconButton(
                    icon: Icon(_tabs[index].icon, color: selected ? Colors.deepPurple : Colors.grey, size: 32),
                    onPressed: () => setState(() => _selectedIndex = index),
                    tooltip: _tabs[index].label,
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: _tabs[_selectedIndex].content,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  final Widget content;
  const _TabItem({required this.icon, required this.label, required this.content});
}
