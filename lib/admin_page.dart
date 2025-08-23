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

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Admin Dashboard"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome to the Admin Dashboard!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Add future admin functionality here
                print("Admin functionality will go here.");
              },
              child: Text("Admin Action"),
            ),
          ],
        ),
      ),
    );
  }
}
