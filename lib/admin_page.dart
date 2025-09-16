// lib/admin_page.dart
// COPILOT TODO (admin_page):
// - Replace placeholder UI with a "Pending Device Requests" list:
//   * Uses ApiService.listPending() to load (on init and on Refresh button in AppBar).
//   * Each item shows mac, requesterEmail, platform, model, osVersion, createdAt.
//   * Two buttons: Approve (green) and Deny (red) -> ApiService.decide(requestId, approve, decidedBy:'admin@example.com').
//   * Show SnackBar on success/failure; reload list after decision.
//   * Empty state: "No pending requests".
// - Keep deepPurple AppBar, cards, nice spacing, StadiumBorder buttons.
// - No crashes on network error: show an error message and allow retry.
import 'package:flutter/material.dart';
import 'services/api.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _pending = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await ApiService.listPending();
      setState(() { _pending = list; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _decide(String id, bool approve) async {
    final ok = await ApiService.decide(requestId: id, approve: approve, decidedBy: 'admin@example.com');
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Approved' : 'Denied')),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action failed')), 
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Error: $_error'),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _pending.isEmpty
                  ? const Center(child: Text('No pending requests'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _pending.length,
                      itemBuilder: (context, i) {
                        final d = _pending[i];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d['mac'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text('Email: ${d['requesterEmail'] ?? ''}'),
                                Text('Platform: ${d['platform'] ?? ''}'),
                                Text('Model: ${d['model'] ?? ''}'),
                                Text('OS: ${d['osVersion'] ?? ''}'),
                                Text('Role: ${d['role'] ?? 'user'}'),
                                Text('App: ${d['appVersion'] ?? ''}'),
                                Text('Created: ${d['createdAt'] ?? ''}'),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => _decide(d['id'], true),
                                      icon: const Icon(Icons.check),
                                      label: const Text('Approve'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () => _decide(d['id'], false),
                                      icon: const Icon(Icons.close),
                                      label: const Text('Deny'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
