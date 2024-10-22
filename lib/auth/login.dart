import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:testing_safety_app/auth/signup.dart';

import '../hive/globals.dart';
import '../screens/home_screen.dart';

class LogInScreen extends StatefulWidget {
  const LogInScreen({super.key});

  @override
  State<LogInScreen> createState() => _LogInScreenState();
}

class _LogInScreenState extends State<LogInScreen> {
  final myBox = Hive.box("SOS");
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  FirebaseAuth _auth = FirebaseAuth.instance;
  bool loading = false;

  void _writeData(){
    myBox.put(1, globalName);
    myBox.put(2, globalEmail);
  }

  @override
  void dispose() {
    super.dispose();
    emailController.dispose();
    passwordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(15),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Log In",
                    style: TextStyle(
                        fontSize: 50,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54),
                  ),
                  const SizedBox(
                    height: 30,
                  ),
                  Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            onTapOutside: (event) {
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                            controller: emailController,
                            decoration: InputDecoration(
                              hintText: "Email",
                              hintStyle: const TextStyle(color: Colors.grey),
                              contentPadding: const EdgeInsets.all(27),
                              enabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                      width: 3, color: Colors.black12),
                                  borderRadius: BorderRadius.circular(10)),
                              focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                      width: 3,
                                      color: Color.fromRGBO(251, 109, 169, 1)),
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (value) {
                              if (value!.isEmpty) {
                                return "Enter Email";
                              }
                              return null;
                            },
                            style: const TextStyle(color: Colors.black87),
                          ),
                          const SizedBox(
                            height: 15,
                          ),
                          TextFormField(
                            onTapOutside: (event) {
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                            controller: passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              hintText: "Password",
                              hintStyle: const TextStyle(color: Colors.grey),
                              contentPadding: const EdgeInsets.all(27),
                              enabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                      width: 3, color: Colors.black12),
                                  borderRadius: BorderRadius.circular(10)),
                              focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                      width: 3,
                                      color: Color.fromRGBO(251, 109, 169, 1)),
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (value) {
                              if (value!.isEmpty) {
                                return "Enter Password";
                              }
                              return null;
                            },
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ],
                      )),
                  const SizedBox(
                    height: 20,
                  ),
                  Container(
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [
                              Color.fromRGBO(187, 63, 221, 1),
                              Color.fromRGBO(251, 109, 169, 1)
                            ],
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight),
                        borderRadius: BorderRadius.circular(7)),
                    child: // Import FCM

                        ElevatedButton(
                      onPressed: () {
                        setState(() {
                          if (_formKey.currentState!.validate()) {
                            setState(() {
                              loading = true;
                            });

                            // Sign in with Firebase Auth
                            _auth
                                .signInWithEmailAndPassword(
                              email: emailController.text.toString(),
                              password: passwordController.text.toString(),
                            )
                                .then((onValue) async {
                              final ref =
                                  FirebaseDatabase.instance.ref("Users");
                              String sanitizedEmail =
                                  emailController.text.replaceAll('.', ',');

                              // Retrieve user/artist details
                              await ref
                                  .child(sanitizedEmail)
                                  .get()
                                  .then((snapshot) async {
                                if (snapshot.exists) {
                                  var artistData =
                                      snapshot.value as Map<dynamic, dynamic>;
                                  String artistName = artistData[
                                      'name']; // Assuming 'name' is the key for artist's name

                                  print("Artist Name: $artistName");

                                  // Generate FCM token for the user
                                  FirebaseMessaging messaging =
                                      FirebaseMessaging.instance;
                                  String? fcmToken = await messaging.getToken();
                                  print("FCM Token: $fcmToken");

                                  // Store FCM token in Firebase under the user's node
                                  await ref
                                      .child('$sanitizedEmail/fcmToken')
                                      .set(fcmToken);
                                  globalName=artistData['name'];
                                  globalEmail=sanitizedEmail.toString();
                                  _writeData();

                                  // Navigate to the HomeScreen
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => HomeScreen(
                                            userName: artistData['name'],
                                            userEmail: artistData['email'])),
                                  );
                                } else {
                                  print("No data available for this user.");
                                }
                              }).catchError((error) {
                                print("Error fetching user details: $error");
                              }).whenComplete(() {
                                setState(() {
                                  loading = false;
                                });
                              });
                            }).onError((error, stackTrace) {
                              print("Login error: $error");
                              setState(() {
                                loading = false;
                              });
                            });
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        fixedSize: const Size(395, 55),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      child: loading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            )
                          : const Text(
                              "Log In",
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 17,
                                  color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SignUpScreen()));
                    },
                    child: RichText(
                        text: const TextSpan(
                            text: "Don't have an account? ",
                            style: TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                            children: [
                          TextSpan(
                              text: "Sign Up",
                              style: TextStyle(
                                  color: Color.fromRGBO(251, 109, 169, 1),
                                  fontWeight: FontWeight.bold))
                        ])),
                  ),
                ],
              ),
            ),
          ),
        ),
        backgroundColor: Colors.white);
  }
}
