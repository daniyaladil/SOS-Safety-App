import 'package:flutter/material.dart';
import 'dart:async';
import 'package:testing_safety_app/auth/signup.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true); // Repeat the animation in reverse

    _animation = Tween<double>(begin: 1.0, end: 1.5).animate(_controller); // Zooming effect

    // Navigate to the next screen after 3 seconds
    Timer(Duration(seconds: 1), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => SignUpScreen()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose(); // Dispose of the controller when not needed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.scale(
              scale: _animation.value, // Scale the text based on the animation
              child: const Text(
                "باخبر",
                style: TextStyle(
                  fontFamily: 'Jameel Noori Nastaleeq', // Use your custom font
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.black, // Change color as needed
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
