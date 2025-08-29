import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'signalr_service.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController(text: '923212255434');
  final passwordController = TextEditingController(text: 'Ba@leno99');

  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool obscure = true;

  Future<void> loginUser() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await ApiService.attemptLogin(
        emailController.text.trim(),
        passwordController.text,
      );

      if (!mounted) return;
      if (response['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        // await SignalRService.instance.start(token!).then((_) {
        //   print("SignalR started!");
        // }).catchError((err) {
        //   print("Error starting SignalR: $err");
        // });
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        final msg = (response['message'] ?? 'Login failed').toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Something went wrong: $e')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      // Let the global gradient show through:
      backgroundColor: Colors.transparent,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Image.asset('assets/images/logo.png', height: 100),
              const SizedBox(height: 16),
              Text('Welcome Back!',
                  style: t.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  )),
              const SizedBox(height: 30),

              // Glass card container that matches theme InputDecoration
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(2, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Email / Phone
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email or Phone Number',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscure,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => obscure = !obscure),
                          ),
                        ),
                        validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                      ),

                      const SizedBox(height: 24),

                      // Login button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : loginUser,
                          child: SizedBox(
                            height: 20,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Opacity(
                                  opacity: isLoading ? 0 : 1,
                                  child: const Text('Login', style: TextStyle(fontSize: 16)),
                                ),
                                if (isLoading)
                                  const SizedBox(
                                    height: 20, width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Forgot password?',
                            style: TextStyle(color: Colors.white70)),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Don\'t have an account? Sign Up',
                            style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
