import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart'; // Import the intl package for formatting time

class RecievedAlertsScreen extends StatefulWidget {
  final String userEmail; // Email of the user

  const RecievedAlertsScreen({Key? key, required this.userEmail}) : super(key: key);

  @override
  _RecievedAlertsScreenState createState() => _RecievedAlertsScreenState();
}

class _RecievedAlertsScreenState extends State<RecievedAlertsScreen> {
  final DatabaseReference ref = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> alerts = [];
  bool isLoading = true; // Loading state

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    try {
      String sanitizedEmail = widget.userEmail.replaceAll('.', ',');
      DatabaseEvent event = await ref.child('Users/$sanitizedEmail/alerts').once();

      if (event.snapshot.exists) {
        Map<dynamic, dynamic> alertData = event.snapshot.value as Map<dynamic, dynamic>;
        alerts = alertData.entries.map((entry) {
          var value = entry.value; // Get alert value
          return {
            'alertId': entry.key.toString(),
            'message': value['message'] as String? ?? 'No message', // Default value for null
            'timestamp': value['timestamp'] as String? ?? 'No timestamp', // Default value for null
            'location': value['location'] ?? {}, // Default to empty map if null
            'senderName': value['senderName'] as String? ?? 'Unknown', // Default value for null
            'senderEmail': value['senderEmail'] as String? ?? 'Unknown', // Default value for null
            'imageUrl': value['imageUrl'] as String? ?? '', // Add image URL
          };
        }).toList();

        // Sort alerts by timestamp (assuming timestamp is a String that can be compared)
        alerts.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
      } else {
        Fluttertoast.showToast(
          msg: "No alerts found.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      print("Error fetching alerts: $e");
      Fluttertoast.showToast(
        msg: "Failed to fetch alerts: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
    } finally {
      setState(() {
        isLoading = false; // Update loading state
      });
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      // Assuming the timestamp is in ISO 8601 format, e.g., 2024-10-20T19:20:00Z
      DateTime dateTime = DateTime.parse(timestamp);
      return DateFormat.jm().format(dateTime); // Format to 7:20 PM
    } catch (e) {
      return timestamp; // Return the original timestamp if parsing fails
    }
  }

  void _launchMaps(double latitude, double longitude) async {
    final String googleMapsUrl =
        "https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude";
    if (await canLaunch(googleMapsUrl)) {
      await launch(googleMapsUrl);
    } else {
      Fluttertoast.showToast(
        msg: "Could not open maps.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Alerts"),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator()) // Show loading indicator
          : alerts.isNotEmpty
          ? ListView.builder(
        itemCount: alerts.length,
        itemBuilder: (context, index) {
          final alert = alerts[index];
          return Container(
            padding: EdgeInsets.all(10),
            margin: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.shade800,
                  blurRadius: 10,
                ),
              ],
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: const Text(
                    "Emergency Alert",
                    style: TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Sender Name: ${alert['senderName']}"),
                      Text("Sender Email: ${alert['senderEmail']}"),
                      SizedBox(height: 20,),
                      Text("Time: ${_formatTimestamp(alert['timestamp'])}"), // Use formatted time
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.location_on_outlined,
                      size: 40,
                      color: Colors.blueGrey,
                    ),
                    onPressed: () {
                      final location = alert['location'];
                      _launchMaps(location['latitude'], location['longitude']);
                    },
                  ),
                ),
                // Display the image if the URL is not empty
                if (alert['imageUrl']!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Image.network(
                      alert['imageUrl']!,
                      fit: BoxFit.cover,
                      height: 150, // Adjust height as necessary
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(child: Text('Image not available'));
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      )
          : Center(child: const Text("No alerts to display.")),
    );
  }
}
