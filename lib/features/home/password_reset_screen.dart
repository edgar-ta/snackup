import 'package:flutter/material.dart';
import 'package:snackup/theme/app_colors.dart';
import 'package:snackup/theme/app_text.dart';
import 'package:snackup/api/user.dart' as user_api;
import 'dart:async';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  String _successMessage = '';

  // Rate limiting variables
  List<DateTime> _emailSendTimes = [];
  int _remainingSeconds = 0;
  Timer? _countdownTimer;
  bool _isRateLimited = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() {
      setState(() => _errorMessage = '');
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  /// Validates if the email format is valid
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Checks if the user has exceeded the rate limit (3 emails per minute)
  bool _checkRateLimit() {
    final now = DateTime.now();
    final oneMinuteAgo = now.subtract(const Duration(minutes: 1));

    // Remove timestamps older than 1 minute
    _emailSendTimes.removeWhere((time) => time.isBefore(oneMinuteAgo));

    // Check if already at limit
    if (_emailSendTimes.length >= 3) {
      return false; // Rate limited
    }

    return true; // Not rate limited
  }

  /// Starts the countdown timer for rate limiting
  void _startCountdown() {
    _isRateLimited = true;
    _remainingSeconds = 60;

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Remove timestamps older than 1 minute to reset rate limit
      final now = DateTime.now();
      final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
      _emailSendTimes.removeWhere((time) => time.isBefore(oneMinuteAgo));

      setState(() {
        _remainingSeconds--;
        // Check if we can send again (all timestamps are now older than 1 minute)
        if (_emailSendTimes.isEmpty && _remainingSeconds <= 0) {
          _isRateLimited = false;
          timer.cancel();
          _countdownTimer = null;
        }
      });
    });
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = _emailController.text.trim();

    // Validate email format
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Por favor, ingresa un correo');
      return;
    }

    if (!_isValidEmail(email)) {
      setState(() => _errorMessage = 'Por favor, ingresa un correo válido');
      return;
    }

    // Check rate limit
    if (!_checkRateLimit()) {
      setState(() {
        _errorMessage =
            'Has excedido el límite de intentos. Intenta de nuevo después de 1 minuto.';
        _isRateLimited = true;
      });
      _startCountdown();
      return;
    }

    // Record this send attempt
    _emailSendTimes.add(DateTime.now());

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      await user_api.sendPasswordResetEmail(email);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _successMessage =
              'Correo de recuperación enviado. Revisa tu bandeja de entrada.';
          _emailController.clear();
        });

        // Show success toast
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _successMessage,
              style: AppText.body.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Ocurrió un error. Intenta de nuevo más tarde.';
        });
      }
    }
  }

  /// Builds the send button with loading state
  Widget _buildSendButton() {
    final isEnabled =
        _isValidEmail(_emailController.text.trim()) &&
        !_isLoading &&
        !_isRateLimited;

    return SizedBox(
      width: double.infinity,
      child: _isLoading
          ? Container(
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          : ElevatedButton(
              onPressed: isEnabled ? _sendPasswordResetEmail : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isEnabled
                    ? AppColors.primary
                    : AppColors.primary.withOpacity(0.4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: isEnabled ? 2 : 0,
                shadowColor: AppColors.primary.withOpacity(0.3),
              ),
              child: Text(
                'Enviar correo',
                style: AppText.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar Contraseña'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // HEADER CON EXPLICACIÓN
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.1),
                        AppColors.accent.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Recuperar Contraseña',
                        style: AppText.h1.copyWith(
                          fontSize: 32,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Ingresa el correo asociado a tu cuenta y te enviaremos un enlace para restablecer tu contraseña.',
                        style: AppText.body.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // FORMULARIO
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Correo Electrónico',
                              style: AppText.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _emailController,
                              style: AppText.body,
                              enabled: !_isLoading && !_isRateLimited,
                              decoration: InputDecoration(
                                hintText: 'tu.correo@utsjr.edu.mx',
                                hintStyle: AppText.notes.copyWith(
                                  color: AppColors.textSecondary.withOpacity(
                                    0.6,
                                  ),
                                ),
                                prefixIcon: Icon(
                                  Icons.email_rounded,
                                  color: AppColors.textSecondary.withOpacity(
                                    0.8,
                                  ),
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // SEND BUTTON
                        _buildSendButton(),

                        // ERROR MESSAGE
                        if (_errorMessage.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.error.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _errorMessage,
                                        style: AppText.notes.copyWith(
                                          color: AppColors.error,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      // Show countdown timer if rate limited
                                      if (_isRateLimited &&
                                          _remainingSeconds > 0) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Intenta de nuevo en $_remainingSeconds segundo${_remainingSeconds != 1 ? 's' : ''}',
                                          style: AppText.notes.copyWith(
                                            color: AppColors.error.withOpacity(
                                              0.7,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // SUCCESS MESSAGE
                        if (_successMessage.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.success.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.success,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _successMessage,
                                    style: AppText.notes.copyWith(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // INFO BOX
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.tertiary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_rounded,
                            color: AppColors.tertiary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Información Importante',
                            style: AppText.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.tertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '• El enlace de recuperación expirará en 24 horas\n• Revisa tu carpeta de spam si no ves el correo\n• Por seguridad, solo puedes solicitar 3 correos por minuto',
                        style: AppText.notes.copyWith(
                          color: AppColors.tertiary,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
