import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  final AuthService authService;

  const AuthScreen({super.key, required this.authService});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await widget.authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await widget.authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim().isEmpty
              ? null
              : _nameController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Compte cree ! Verifiez votre email pour confirmer.'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_translateError(e.message)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrez votre email pour reinitialiser le mot de passe'),
          backgroundColor: AppColors.accent,
        ),
      );
      return;
    }

    try {
      await widget.authService.resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email de reinitialisation envoye !'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _translateError(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Email ou mot de passe incorrect';
    }
    if (message.contains('User already registered')) {
      return 'Un compte existe deja avec cet email';
    }
    if (message.contains('Password should be at least')) {
      return 'Le mot de passe doit faire au moins 6 caracteres';
    }
    if (message.contains('Unable to validate email')) {
      return 'Adresse email invalide';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / Title
                Icon(
                  Icons.menu_book_rounded,
                  size: 72,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Al-Hafiz',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Memorisation du Quran',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 48),

                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Name field (signup only)
                      if (!_isLogin) ...[
                        TextFormField(
                          controller: _nameController,
                          decoration: _inputDecoration(
                            label: 'Nom (optionnel)',
                            icon: Icons.person_outline,
                            isDark: isDark,
                          ),
                          style: _fieldTextStyle(isDark),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Email
                      TextFormField(
                        controller: _emailController,
                        decoration: _inputDecoration(
                          label: 'Email',
                          icon: Icons.email_outlined,
                          isDark: isDark,
                        ),
                        style: _fieldTextStyle(isDark),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Entrez votre email';
                          }
                          if (!value.contains('@')) {
                            return 'Email invalide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        decoration: _inputDecoration(
                          label: 'Mot de passe',
                          icon: Icons.lock_outline,
                          isDark: isDark,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        style: _fieldTextStyle(isDark),
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Entrez votre mot de passe';
                          }
                          if (!_isLogin && value.length < 6) {
                            return 'Minimum 6 caracteres';
                          }
                          return null;
                        },
                      ),

                      // Forgot password
                      if (_isLogin) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _resetPassword,
                            child: Text(
                              'Mot de passe oublie ?',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ),
                      ] else
                        const SizedBox(height: 24),

                      const SizedBox(height: 8),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _isLogin ? 'Se connecter' : 'Creer un compte',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Toggle login/signup
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLogin ? 'Pas encore de compte ?' : 'Deja un compte ?',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _isLogin = !_isLogin);
                        _formKey.currentState?.reset();
                      },
                      child: Text(
                        _isLogin ? 'Creer un compte' : 'Se connecter',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    required bool isDark,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(
        color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
      ),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: isDark ? AppColors.surfaceLight : AppColors.dividerLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  TextStyle _fieldTextStyle(bool isDark) => GoogleFonts.poppins(
    fontSize: 14,
    color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
  );
}
