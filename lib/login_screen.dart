import 'package:flutter/material.dart';
import 'dart:ui';
import 'auth_service.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLogin = true; 
  bool _isLoading = false; 

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- BACKEND LOGIC UNTOUCHED ---
  void _submitAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text("Please fill all fields"))
       );
       return;
    }

    setState(() => _isLoading = true);

    if (_isLogin) {
      var user = await _authService.signIn(
        _emailController.text.trim(), 
        _passwordController.text.trim()
      );
      
      if (user != null) {
        var userData = await _authService.getUserData(user.uid);
        
        if (userData != null && mounted) {
          int savedSkillElo = userData['skillElo'] ?? 0;
          int savedEffortElo = userData['effortElo'] ?? 0;
          print("Success! Skill: $savedSkillElo, Effort: $savedEffortElo");
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Login Failed. Check your credentials."))
          );
        }
      }
    } else {
      var user = await _authService.signUp(
        _emailController.text.trim(), 
        _passwordController.text.trim(),
        0, 0, 0, 0 
      );

      if (user != null) {
         print("Account Created!");
      } else {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Sign Up Failed. Try a different email."))
           );
         }
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13), 
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              
              // Liquid Glass Container for Login Form
              ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.lock_outline, size: 80, color: Colors.white24),
                        const SizedBox(height: 20),
                        Text(
                          _isLogin ? "WELCOME BACK" : "CREATE ACCOUNT",
                          style: const TextStyle(
                            fontSize: 22, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.white, 
                            letterSpacing: 2
                          ),
                        ),
                        const SizedBox(height: 40),
                        
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.email_outlined, color: Colors.white38),
                            labelText: "Email",
                            labelStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20), 
                              borderSide: BorderSide.none
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),

                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.vpn_key_outlined, color: Colors.white38),
                            labelText: "Password",
                            labelStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20), 
                              borderSide: BorderSide.none
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : ElevatedButton(
                              onPressed: _submitAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                minimumSize: const Size(double.infinity, 60),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)
                                ),
                              ),
                              child: Text(
                                _isLogin ? "LOGIN" : "SIGN UP", 
                                style: const TextStyle(fontWeight: FontWeight.bold)
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                  });
                },
                child: Text(
                  _isLogin ? "Need an account? Sign Up" : "Already have an account? Login",
                  style: const TextStyle(color: Colors.white54),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}