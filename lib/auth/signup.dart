import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'login.dart';


class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey=GlobalKey<FormState>();
  final nameController=TextEditingController();
  final emailController=TextEditingController();
  final passwordController=TextEditingController();
  bool loading=false;

  final ref=FirebaseDatabase.instance.ref("Users");
  FirebaseAuth _auth=FirebaseAuth.instance;

  @override
  void dispose(){
    super.dispose();
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(15),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Sign Up",
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
                            onTapOutside: (event){
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                            controller: nameController,
                            decoration: InputDecoration(
                              hintText: "Name",
                              hintStyle: const TextStyle(color: Colors.grey),
                              contentPadding: const EdgeInsets.all(27),
                              enabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                      width: 3, color: Colors.black12),
                                  borderRadius: BorderRadius.circular(10)),
                              focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                      width: 3, color: Color.fromRGBO(251, 109, 169, 1)),
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (value){
                              if(value!.isEmpty){
                                return "Enter Name";
                              }
                              return null;
                            },
                            style: const TextStyle(color: Colors.black87),
                          ),
                          const SizedBox(
                            height: 15,
                          ),
                          TextFormField(
                            onTapOutside: (event){
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
                                      width: 3, color: Color.fromRGBO(251, 109, 169, 1)),
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (value){
                              if(value!.isEmpty){
                                return "Enter Email";
                              }
                              return null;
                            },
                            style: const TextStyle(color: Colors.black87),),
                          const SizedBox(
                            height: 15,
                          ),
                          TextFormField(
                            onTapOutside: (event){
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
                                      width: 3, color: Color.fromRGBO(251, 109, 169, 1)),
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (value){
                              if(value!.isEmpty){
                                return "Enter Password";
                              }
                              return null;
                            },
                            style: const TextStyle(color: Colors.black87),),
                          const SizedBox(
                            height: 20,
                          ),
                        ],
                      )
                  ),

                  Container(
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color.fromRGBO(187, 63, 221, 1),
                          Color.fromRGBO(251, 109, 169, 1)
                        ], begin: Alignment.bottomLeft, end: Alignment.topRight),
                        borderRadius: BorderRadius.circular(7)),
                    child: ElevatedButton(
                        onPressed: () {
                          if(_formKey.currentState!.validate()){
                            setState(() {
                              loading=true;
                            });

                            if(!emailController.text.endsWith("@gmail.com")){
                              setState(() {
                                loading=false;
                              });
                              return ;
                            }
                            if(passwordController.text.length<6){
                              setState(() {
                                loading=false;
                              });
                              return ;
                            }
                            _auth.createUserWithEmailAndPassword(
                                email: emailController.text.toString(),
                                password: passwordController.text.toString()).then((onValue){
                               String sanitizedEmail = emailController.text.replaceAll('.', ',');
                                  ref.child(sanitizedEmail).set({
                                    "email": emailController.text.toString(),
                                    "password": passwordController.text.toString(),
                                    "name":nameController.text.toString(),
                                    "emergencyContacts": []
                                  });
                                  Navigator.push(context, MaterialPageRoute(builder: (context)=>const LogInScreen()));
                              setState(() {
                                loading=false;
                              });
                            }).onError((error,stackTrace){

                              setState(() {
                                loading=false;
                              });
                            });
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
                        ):const Text("Sign Up", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: Colors.white),)),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (context) => const LogInScreen()));
                    },
                    child: RichText(
                        text: const TextSpan(
                            text: "Already have an account? ",
                            style: TextStyle(color: Colors.black54,fontWeight: FontWeight.bold,fontSize: 16),
                            children: [
                              TextSpan(
                                  text: "Log in",
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
