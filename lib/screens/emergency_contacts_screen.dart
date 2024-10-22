import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class EmergencyContactsScreen extends StatefulWidget {
  final String userName;
  final String userEmail;

  const EmergencyContactsScreen({
    super.key,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final DatabaseReference ref = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> emergencyContacts =
      []; // Use dynamic instead of String
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchEmergencyContacts();
  }

  Future<void> fetchEmergencyContacts() async {
    String sanitizedEmail = widget.userEmail.replaceAll('.', ',');
    DatabaseReference contactsRef =
        ref.child("Users").child(sanitizedEmail).child('emergencyContacts');

    contactsRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        setState(() {
          emergencyContacts = data.entries.map((entry) {
            return {
              'contactKey': entry.key, // Save the contact's key for deletion
              'contactName': entry.value['contactName'],
              'contactEmail': entry.value['contactEmail'],
            };
          }).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          emergencyContacts = [];
          isLoading = false;
        });
      }
    });
  }

  // Function to show confirmation dialog before deleting a contact
  Future<void> confirmDeleteContact(String contactKey) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Confirm Deletion"),
          content: Text("Are you sure you want to delete this contact?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false); // Cancel
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true); // Confirm
              },
              child: Text("Delete"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ],
        );
      },
    );

    // If the user confirmed, delete the contact
    if (confirm == true) {
      deleteContact(contactKey);
    }
  }

  // Function to delete a contact from the database
  void deleteContact(String contactKey) {
    String sanitizedEmail = widget.userEmail.replaceAll('.', ',');
    DatabaseReference contactRef = ref
        .child("Users")
        .child(sanitizedEmail)
        .child('emergencyContacts')
        .child(contactKey);

    contactRef.remove().then((_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Contact deleted successfully."),
      ));
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Failed to delete contact: $error"),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userName}\'s Emergency Contacts'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : emergencyContacts.isEmpty
              ? Center(child: Text("No emergency contacts added yet."))
              : ListView.builder(
                  itemCount: emergencyContacts.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: 15,vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 10
                          )
                        ]
                      ),
                      child: ListTile(
                        leading: Icon(Icons.perm_identity, size: 50),
                        title:
                            Text(emergencyContacts[index]['contactName'] ?? ''),
                        subtitle:
                            Text(emergencyContacts[index]['contactEmail'] ?? ''),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            // Show confirmation dialog before deleting
                            confirmDeleteContact(
                                emergencyContacts[index]['contactKey']!);
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
