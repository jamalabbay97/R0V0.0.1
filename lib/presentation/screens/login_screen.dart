import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:r0/presentation/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await context.read<AuthProvider>().signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Email is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (value) => (value == null || value.length < 6)
                        ? 'Password must be at least 6 characters'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  if (auth.errorMessage != null) ...[
                    Text(
                      auth.errorMessage!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _signIn,
                      child: auth.isLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Login'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
