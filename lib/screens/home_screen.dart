import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart'; // For getting location
import 'package:firebase_database/firebase_database.dart'; // For Firebase interaction
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:testing_safety_app/auth/signup.dart';
import 'package:testing_safety_app/hive/globals.dart';
import 'package:testing_safety_app/main.dart';
import 'package:testing_safety_app/screens/recieved_alerts_screen.dart'; // For showing notifications
import 'package:testing_safety_app/screens/requests_screen.dart';
import 'package:testing_safety_app/screens/sended_alerts_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // For JSON encoding


import 'add_emergency_contacts_screen.dart';
import 'emergency_contacts_screen.dart'; // Sended Alerts screen

class HomeScreen extends StatefulWidget {
  final String userName;
  final String userEmail;

  const HomeScreen({super.key, required this.userName, required this.userEmail});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final myBox = Hive.box("SOS");
  DatabaseReference ref = FirebaseDatabase.instance.ref();
  bool isSending = false; // To track the alert sending status

  CameraController? cameraController; // Define cameraController
  List<CameraDescription>? cameras; // Define cameras

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    requestLocationPermission(); // Initialize the camera when the widget is created
  }

  // Function to request location permissions
  Future<void> requestLocationPermission() async {
    var status = await Permission.location.status;
    if (!status.isGranted) {
      // Request permission if not granted
      await Permission.location.request();
    }
  }


  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras?.isNotEmpty == true) { // Use null-aware access
        cameraController = CameraController(cameras![0], ResolutionPreset.high); // Use ! to assert it's not null
        await cameraController!.initialize();
      } else {
        throw Exception("No cameras available");
      }
    } catch (e) {
      print("Error initializing camera: $e");
      throw e; // Rethrow the error for further handling
    }
  }




  Future<Position> _getCurrentLocation() async {
    // Ensure permissions are granted before fetching location
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      await Permission.camera.request();
    }
  }

  Future<String> _takePicture() async {
    if (cameraController != null && cameraController!.value.isInitialized) {
      final XFile image = await cameraController!.takePicture(); // Capture the picture
      return image.path; // Return the path of the captured image
    }
    throw Exception("Camera not initialized");
  }


  Future<void> _alertContacts() async {
    setState(() {
      isSending = true; // Show the circular progress indicator
    });

    try {
      // 1. Get current location
      Position position = await _getCurrentLocation();
      String currentUserEmail = widget.userEmail.replaceAll('.', ','); // Sanitize email

      // 2. Fetch the user's emergency contacts
      DatabaseEvent event = await ref.child('Users/$currentUserEmail/emergencyContacts').once();

      if (event.snapshot.exists) {
        Map<dynamic, dynamic> emergencyContacts = event.snapshot.value as Map<dynamic, dynamic>;
        List<String> contactNames = [];

        // 3. Request camera permission
        await _requestCameraPermission();

        // 4. Take a picture using the camera
        String imagePath = await _takePicture(); // Automatically takes a picture

        // 5. Upload the image to Firebase Storage
        String imageUrl = '';
        if (imagePath.isNotEmpty) {
          final Reference storageRef = FirebaseStorage.instance.ref().child('emergency_alerts/$imagePath');
          await storageRef.putFile(File(imagePath));
          imageUrl = await storageRef.getDownloadURL();
        }

        String alertId = DateTime.now().millisecondsSinceEpoch.toString(); // Generate unique ID for alert
        Map<String, dynamic> alertData = {
          'message': 'Emergency alert sent!',
          'timestamp': DateTime.now().toString(),
          'location': {
            'latitude': position.latitude,
            'longitude': position.longitude,
          },
          'senderName': widget.userName.toString(),
          'senderEmail': widget.userEmail.toString(),
          'imageUrl': imageUrl, // Add image URL to the alert data
        };

        // Loop through each contact and send the alert
        for (var contactId in emergencyContacts.keys) {
          if (emergencyContacts[contactId]['contactEmail'] != null && emergencyContacts[contactId]['contactName'] != null) {
            String contactEmail = emergencyContacts[contactId]['contactEmail'];
            String contactName = emergencyContacts[contactId]['contactName'];

            contactNames.add(contactName);
            print("Sending alert to: $contactEmail ($contactName)");

            // Create an alert under the contact's node
            await ref.child('Users/${contactEmail.replaceAll('.', ',')}/alerts/$alertId').set(alertData);

            // Send an email alert
            await sendEmail(contactEmail, contactName, position, imageUrl);
          }
        }

        // Save the alert under the user's 'sendedAlerts' node
        Map<String, dynamic> sendedAlertData = {
          ...alertData,
          'contactNames': contactNames,
        };
        await ref.child('Users/$currentUserEmail/sendedAlerts/$alertId').set(sendedAlertData);

        Fluttertoast.showToast(
          msg: "Alerts sent to emergency contacts!",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
      } else {
        Fluttertoast.showToast(
          msg: "No emergency contacts found.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      print("Error: $e");
      Fluttertoast.showToast(
        msg: "Failed to send alert: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
    } finally {
      setState(() {
        isSending = false; // Hide the circular progress indicator
      });
    }
  }

// Function to send an email to a contact
  Future<void> sendEmail(String contactEmail, String contactName, Position position, String imageUrl) async {
    // Predefined email details
    final String subject = 'Emergency Alert from ${widget.userName}';
    final String locationLink = 'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

    final String body = '''
Hello $contactName,

You have received an emergency alert from ${widget.userName}.

Please take action immediately!

Location: 
Latitude: ${position.latitude}
Longitude: ${position.longitude}

You can view the location on [Google Maps]($locationLink).

An image has been captured and is attached: $imageUrl

Thank you!
''';

    // Replace with your email credentials
    final String username = 'actionreaction218@gmail.com'; // Your email address
    final String password = 'sswr lnch bwde xohw'; // App password generated from Google

    final smtpServer = gmail(username, password);

    // Create the email message
    final message = Message()
      ..from = Address(username, 'Bakhabar') // Your name or email
      ..recipients.add(contactEmail)
      ..subject = subject
      ..text = body;

    try {
      // Send the email
      final sendReport = await send(message, smtpServer);
      print('Message sent: ' + sendReport.toString());
    } on MailerException catch (e) {
      print('Message not sent. ${e.toString()}');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "باخبر",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        // backgroundColor: Color(0xFFF0F8FF),
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),  // Shadow color with transparency// Only show shadow at bottom and sides (no shadow at top)
                  blurRadius: 5,  // How fuzzy the shadow is
                  spreadRadius: 3,  // Spread the shadow a bit
                ),
              ],
            ),
            margin: const EdgeInsets.all(11),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: ListTile(
              leading: const Icon(Icons.person, size: 50,color: Colors.white,),
              title: Text(
                widget.userName,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 18),
              ),
              subtitle: Text(
                widget.userEmail,
                style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                    fontSize: 16),
              ),
            ),
          ),
          SizedBox(height: 5,),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(10), // Rounded corners
              ),
              clipBehavior: Clip.antiAlias, // Ensures child widgets are clipped to the rounded corners
              child: Image(
                image: NetworkImage("https://zedcor.com/wp-content/uploads/elementor/thumbs/business-security-systems-pb2u8hkolggp9eqvu2o5d0n1x3ul9pw6nqgurlggi0.jpg"),
                fit: BoxFit.cover, // Use BoxFit.cover to maintain aspect ratio
              ),
            ),
          ),

          SizedBox(height: 10,),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      // Navigate to Sended Alerts screen
                      Navigator.push(context, MaterialPageRoute(builder: (context) => SendedAlertsScreen(userEmail: widget.userEmail)));
                    },
                    child: Container(
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.green.shade500,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),  // Shadow color with transparency
                            offset: Offset(0, 4),  // Only show shadow at bottom and sides (no shadow at top)
                            blurRadius: 10,  // How fuzzy the shadow is
                            spreadRadius: 2,  // Spread the shadow a bit
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Icon(Icons.upload_outlined,
                                size: 50, color: Colors.white),
                            Text(
                              "Sended",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: isSending
                        ? null
                        : () {
                      _alertContacts(); // Send the alert when pressed
                    },
                    child: Container(
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.red.shade500,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),  // Shadow color with transparency
                            offset: Offset(0, 4),  // Only show shadow at bottom and sides (no shadow at top)
                            blurRadius: 10,  // How fuzzy the shadow is
                            spreadRadius: 2,  // Spread the shadow a bit
                          ),
                        ],
                      ),
                      child: Center(
                        child: isSending
                            ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                            : const Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Icon(Icons.add_alert_outlined,
                                size: 50, color: Colors.white),
                            Text(
                              "Alert Now",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  RecievedAlertsScreen(userEmail: widget.userEmail)));
                    },
                    child: Container(
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade500,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),  // Shadow color with transparency
                            offset: Offset(0, 4),  // Only show shadow at bottom and sides (no shadow at top)
                            blurRadius: 10,  // How fuzzy the shadow is
                            spreadRadius: 2,  // Spread the shadow a bit
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Icon(Icons.download_outlined,
                                size: 50, color: Colors.white),
                            Text(
                              "Received",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10,),

          const SizedBox(height: 10,),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddEmergencyContactsScreen(userEmail: widget.userEmail, userName: widget.userName,),
                        ),
                      );
                    },
                    child: Container(
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),  // Shadow color with transparency
                            offset: Offset(0, 4),  // Only show shadow at bottom and sides (no shadow at top)
                            blurRadius: 10,  // How fuzzy the shadow is
                            spreadRadius: 2,  // Spread the shadow a bit
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Icon(Icons.add_comment_rounded,size: 50,color: Colors.blue,),
                            Text(
                              "Add Contact",
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EmergencyContactsScreen(userEmail: widget.userEmail, userName: widget.userName,),
                        ),
                      );
                    },
                    child: Container(
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),  // Shadow color with transparency
                            offset: Offset(0, 4),  // Only show shadow at bottom and sides (no shadow at top)
                            blurRadius: 10,  // How fuzzy the shadow is
                            spreadRadius: 2,  // Spread the shadow a bit
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Icon(Icons.contact_page_outlined,size: 50,color: Colors.blue,),
                            Text(
                              "My Contacts",
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PendingRequestsScreen(userEmail: widget.userEmail,userName: widget.userName,),
                        ),
                      );
                    },
                    child: Container(
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),  // Shadow color with transparency
                            offset: Offset(0, 4),  // Only show shadow at bottom and sides (no shadow at top)
                            blurRadius: 10,  // How fuzzy the shadow is
                            spreadRadius: 2,  // Spread the shadow a bit
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Icon(Icons.pending_actions,size: 50,color: Colors.blue,),
                            Text(
                              "Requests",
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
      drawer: Drawer(
        child: Container(
          color: Colors.blueGrey.shade200,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade500,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black,
                      blurRadius: 12,
                    )
                  ],
                ),
                currentAccountPicture: Icon(Icons.person),
                accountName: Text(widget.userName),
                accountEmail: Text(widget.userEmail),
              ),
              ListTile(
                onTap: () {
                   Navigator.push(context, MaterialPageRoute(builder: (context)=>AddEmergencyContactsScreen(userName: widget.userName, userEmail: widget.userEmail)));
                },
                leading: const Icon(Icons.add_comment_rounded),
                title: const Text("Add Contacts"),
              ),
              buildDivider(),
              ListTile(
                onTap: () {
                     Navigator.push(context, MaterialPageRoute(builder: (context)=>EmergencyContactsScreen(userName: widget.userName, userEmail: widget.userEmail)));
                },
                leading: const Icon(Icons.contact_page_outlined),
                title: const Text("My Contacts"),
              ),
              buildDivider(),
              ListTile(
                onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context)=>PendingRequestsScreen(userEmail: widget.userEmail,userName: widget.userName)));
                },
                leading: const Icon(Icons.pending_actions),
                title: const Text("Requests"),
              ),
              buildDivider(),
              ListTile(
                onTap: () {
                    setState(() {
                      _alertContacts();
                    });
                },
                leading: const Icon(Icons.add_alert_outlined),
                title: const Text("Alert Contacts"),
              ),

              buildDivider(),
              ListTile(
                onTap: () {
                 Navigator.push(context, MaterialPageRoute(builder: (context)=>RecievedAlertsScreen(userEmail: widget.userEmail)));
                },
                leading:  const Icon(Icons.download_outlined),
                title: const Text("Recieved Alerts"),
              ),

              buildDivider(),
              ListTile(
                onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context)=>SendedAlertsScreen(userEmail: widget.userEmail)));
                },
                leading: const Icon(Icons.upload_outlined),
                title: const Text("Sended Alerts"),
              ),

              buildDivider(),
              ListTile(
                onTap: () {
                  setState(() {
                    globalEmail="";
                    globalName="";

                      myBox.put(1, globalName);
                      myBox.put(2, globalEmail);
                  });
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>SignUpScreen()));
                },
                leading: const Icon(Icons.logout),
                title: const Text("Logout"),
              ),
            ],
          ),
        ),
      ),
      // backgroundColor: Color(0xFFF0F8FF), // ARGB format
backgroundColor: Colors.white,
    );
  }
  Widget buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 15),
      child: Divider(
        color: Colors.grey,
      ),
    );
  }
}



