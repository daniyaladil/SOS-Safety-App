import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AddEmergencyContactsScreen extends StatefulWidget {
  final String userName;
  final String userEmail;

  const AddEmergencyContactsScreen({super.key, required this.userName, required this.userEmail});

  @override
  State<AddEmergencyContactsScreen> createState() => _AddEmergencyContactsScreenState();
}

class _AddEmergencyContactsScreenState extends State<AddEmergencyContactsScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final DatabaseReference ref = FirebaseDatabase.instance.ref();

  bool loading = false;

  Future<bool> isEmailRegistered(String email) async {
    String sanitizedEmail = email.replaceAll('.', ',');
    DatabaseEvent event = await ref.child('Users').child(sanitizedEmail).once();
    return event.snapshot.exists;
  }


  void sendEmergencyRequest(String name, String email) {
    String sanitizedEmail = widget.userEmail.replaceAll('.', ',');
    String sanitizedContactEmail = email.replaceAll('.', ',');

    // Send a request to the user being added (email owner)
    DatabaseReference contactRef = ref.child('Users').child(sanitizedContactEmail).child('pendingRequests');

    String requestKey = contactRef.push().key!;

    contactRef.child(requestKey).set({
      "requesterName": widget.userName,  // The name of the user sending the request
      "requesterEmail": widget.userEmail, // The email of the user sending the request
    }).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Emergency contact request sent!"),
      ));
      // Clear the fields after sending the request
      nameController.clear();
      emailController.clear();
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Failed to send request: $error"),
      ));
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Emergency Contact"),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            SizedBox(height: 20,),
            Container(
              width: double.infinity,
              height: 320,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 10
                  )
                ]
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20,),
                    TextFormField(
                      onTapOutside: (event){
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: "Enter Name",
                        hintStyle:  TextStyle(color: Colors.grey),
                        contentPadding: const EdgeInsets.all(27),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              width: 3, color: Colors.black26),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              width: 3, color: Color.fromRGBO(251, 109, 169, 1)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return "Enter Name";
                        }
                        return null;
                      },
                      style: const TextStyle(color: Colors.black),
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      onTapOutside: (event){
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      controller: emailController,
                      decoration: InputDecoration(
                        hintText: "Enter Email",
                        hintStyle: const TextStyle(color: Colors.grey),
                        contentPadding: const EdgeInsets.all(27),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              width: 3, color: Colors.black26),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              width: 3, color: Color.fromRGBO(251, 109, 169, 1)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return "Enter Email";
                        }
                        if (!value.contains('@')) {
                          return "Enter a valid email";
                        }
                        return null;
                      },
                      style: const TextStyle(color: Colors.black),
                    ),
                    SizedBox(height: 30),

                    Container(
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [
                            Color.fromRGBO(187, 63, 221, 1),
                            Color.fromRGBO(251, 109, 169, 1)
                          ], begin: Alignment.bottomLeft, end: Alignment.topRight),
                          borderRadius: BorderRadius.circular(7)),
                      child: ElevatedButton(
                          onPressed: () async{
                            String name = nameController.text.trim();
                            String email = emailController.text.trim();
                            if (name.isNotEmpty && email.isNotEmpty) {
                              // Check if the email is registered
                              bool registered = await isEmailRegistered(email);
                              if (registered) {
                                sendEmergencyRequest(name, email);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text("Invalid email! Please enter a registered email."),
                                ));
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text("Please fill out both fields."),
                              ));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            fixedSize: const Size(395, 55),
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          child: loading?const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ):const Text("Add Contact", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: Colors.white),)),
                    ),

                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
