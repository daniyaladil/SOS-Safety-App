import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart'; // Import the intl package for formatting time
import 'package:url_launcher/url_launcher.dart'; // For launching maps

class SendedAlertsScreen extends StatefulWidget {
  final String userEmail; // Email of the user

  const SendedAlertsScreen({Key? key, required this.userEmail}) : super(key: key);

  @override
  _SendedAlertsScreenState createState() => _SendedAlertsScreenState();
}

class _SendedAlertsScreenState extends State<SendedAlertsScreen> {
  final DatabaseReference ref = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> sendedAlerts = [];
  bool isLoading = true; // Loading state

  @override
  void initState() {
    super.initState();
    _fetchSendedAlerts();
  }

  Future<void> _fetchSendedAlerts() async {
    try {
      String sanitizedEmail = widget.userEmail.replaceAll('.', ',');
      DatabaseEvent event = await ref.child('Users/$sanitizedEmail/sendedAlerts').once();

      if (event.snapshot.exists) {
        Map<dynamic, dynamic> alertData = event.snapshot.value as Map<dynamic, dynamic>;
        sendedAlerts = alertData.entries.map((entry) {
          var value = entry.value; // Get alert value
          return {
            'alertId': entry.key.toString(),
            'message': value['message'] as String? ?? 'No message',
            'timestamp': value['timestamp'] as String? ?? 'No timestamp',
            'contactNames': (value['contactNames'] as List<dynamic>? ?? []).cast<String>(), // Fetch list of contact names
            'location': value['location'] ?? {}, // Default to empty map if null
            'imageUrl': value['imageUrl'] as String? ?? '', // Add this line to get the image URL
          };
        }).toList();

        // Sort alerts by timestamp
        sendedAlerts.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
      } else {
        Fluttertoast.showToast(
          msg: "No sent alerts found.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      print("Error fetching sent alerts: $e");
      Fluttertoast.showToast(
        msg: "Failed to fetch sent alerts: $e",
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
      DateTime dateTime = DateTime.parse(timestamp);
      return DateFormat.jm().format(dateTime); // Format to time like 7:20 PM
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
        title: const Text("Sended Alerts"),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator()) // Show loading indicator
          : sendedAlerts.isNotEmpty
          ? ListView.builder(
        itemCount: sendedAlerts.length,
        itemBuilder: (context, index) {
          final alert = sendedAlerts[index];
          final location = alert['location'];

          return Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.shade800,
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
                    "Sent Emergency Alert",
                    style: TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Location Shared with:"),
                      // For each contact name, create a new Text widget
                      ...alert['contactNames'].map<Widget>((name) => Text(name)).toList(),
                      SizedBox(height: 20,),
                      Text("Sent at: ${_formatTimestamp(alert['timestamp'])}"),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.location_on_outlined,
                      size: 40,
                      color: Colors.blueGrey,
                    ),
                    onPressed: () {
                      if (location.isNotEmpty) {
                        _launchMaps(location['latitude'], location['longitude']);
                      } else {
                        Fluttertoast.showToast(
                          msg: "No location available for this alert.",
                          toastLength: Toast.LENGTH_LONG,
                          gravity: ToastGravity.BOTTOM,
                        );
                      }
                    },
                  ),
                ),
                // Display image if exists
                if (alert['imageUrl'] != null && alert['imageUrl']!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Image.network(alert['imageUrl']),
                  ),
              ],
            ),
          );
        },
      )
          : const Center(child: Text("No sent alerts to display.")),
    );
  }
}
