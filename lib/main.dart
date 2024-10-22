import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:testing_safety_app/screens/home_screen.dart';
import 'package:testing_safety_app/splash/splash_screen.dart';
import 'auth/signup.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Hive
  await Hive.initFlutter();

  // Opening the Box for Hive storage
  var box = await Hive.openBox("SOS");

  // Initialize Firebase Messaging (FCM)
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  runApp(MyApp(box: box));
}

class MyApp extends StatelessWidget {
  final Box box;

  const MyApp({required this.box, super.key});

  @override
  Widget build(BuildContext context) {
    // Load data from Hive
    String globalName = box.get(1, defaultValue: "");
    String globalEmail = box.get(2, defaultValue: "");
    String sanitizedEmail = globalEmail.replaceAll('.', ',');

    // Determine the initial screen based on whether email exists in Hive
    Widget initialScreen = globalEmail.isNotEmpty
        ? HomeScreen(userName: globalName.toString(), userEmail: sanitizedEmail.toString(),)
        : const SignUpScreen();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: initialScreen,
    );
  }
}


