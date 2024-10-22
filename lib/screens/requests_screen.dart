import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class PendingRequestsScreen extends StatefulWidget {
  final String userEmail;
  final String userName;

  const PendingRequestsScreen({super.key, required this.userEmail, required this.userName});

  @override
  State<PendingRequestsScreen> createState() => _PendingRequestsScreenState();
}

class _PendingRequestsScreenState extends State<PendingRequestsScreen> {
  final DatabaseReference ref = FirebaseDatabase.instance.ref();

  Future<List<Map<String, String>>> fetchPendingRequests() async {
    String sanitizedEmail = widget.userEmail.replaceAll('.', ',');
    DatabaseEvent event = await ref
        .child('Users')
        .child(sanitizedEmail)
        .child('pendingRequests')
        .once();

    List<Map<String, String>> requests = [];
    if (event.snapshot.exists) {
      Map<dynamic, dynamic> data =
          event.snapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        requests.add({
          'requesterName': value['requesterName'],
          'requesterEmail': value['requesterEmail'],
          'requestKey': key,
        });
      });
    }
    return requests;
  }

  void acceptRequest(Map<String, String> request) {
    String sanitizedEmail = widget.userEmail.replaceAll('.', ',');
    String requesterEmail = request['requesterEmail']!.replaceAll('.', ',');

    // Add the requester to the emergencyContacts of the current user
    DatabaseReference requesterRef =
        ref.child('Users').child(requesterEmail).child('emergencyContacts');
    String contactKey = requesterRef.push().key!;

    requesterRef.child(contactKey).set({
      "contactName": widget.userName, // This user's name
      "contactEmail": widget.userEmail, // This user's email
    }).then((_) {
      // Remove the request after acceptance
      ref
          .child('Users')
          .child(sanitizedEmail)
          .child('pendingRequests')
          .child(request['requestKey']!)
          .remove();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Request accepted!"),
      ));
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Failed to accept request: $error"),
      ));
    });
  }

  void rejectRequest(String requestKey) {
    String sanitizedEmail = widget.userEmail.replaceAll('.', ',');
    ref
        .child('Users')
        .child(sanitizedEmail)
        .child('pendingRequests')
        .child(requestKey)
        .remove()
        .then((_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Request rejected."),
      ));
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Failed to reject request: $error"),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Pending Requests")),
      body: FutureBuilder<List<Map<String, String>>>(
        future: fetchPendingRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                Map<String, String> request = snapshot.data![index];
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
                    title: Text(request['requesterName']!),
                    subtitle: Text(request['requesterEmail']!),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              rejectRequest(request['requestKey']!);
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () {
                            setState(() {
                              acceptRequest(request);
                            });
                          },
                        ),

                      ],
                    ),
                  ),
                );
              },
            );
          } else {
            return const Center(child: Text("No pending requests."));
          }
        },
      ),
    );
  }
}
