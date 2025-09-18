import 'package:flutter/material.dart';
import 'package:tutorium_frontend/pages/login/user_login.dart';

class LoginKuPage extends StatefulWidget {
  const LoginKuPage({super.key});
  
  @override
  State<LoginKuPage> createState() => _LoginKuPageState();

}
class _LoginKuPageState extends State<LoginKuPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightGreen,
      appBar: AppBar(
        title: const Text(""),
        backgroundColor: Colors.lightGreen,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            // mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 100),
              Image.asset("assets/images/KT.png",width: 100, height: 100,),
              const SizedBox(height: 215),
              
              ElevatedButton(
                onPressed: () async {
                  Navigator.push(context, MaterialPageRoute(builder: (ctx)=> UserLoginPage()));
                },
                style: ElevatedButton.styleFrom(
                  fixedSize: Size(300, 40)
                ),
                child: Row(
                  children: [
                    Image.asset("assets/images/KU-logo.jpg", width: 20, height: 20),
                    SizedBox(width: 65),
                    Text("KU ALL Login", style: TextStyle(color: Colors.black)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextButton(onPressed: () {},
              child: Text("Trouble signing in?", style: TextStyle(color: Colors.black)))
            ],
          ),
        ),
      )
    );
  }
}
