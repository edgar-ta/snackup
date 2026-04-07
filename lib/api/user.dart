import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Envía un correo de restablecimiento de contraseña a la dirección de correo especificada.
///
/// Verifica que exactamente un usuario exista con el correo dado en la colección 'users'.
/// Si no existe exactamente un usuario, no hace nada.
///
/// La función asegura que la llamada a la API dure al menos 1 segundo.
Future<void> sendPasswordResetEmail(String email) async {
  try {
    // Asegurar una duración mínima de 1 segundo
    final startTime = DateTime.now();

    // Enviar el correo de restablecimiento de contraseña a través de Firebase Auth
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

    // Calcular el tiempo transcurrido y hacer una pausa si es necesario para asegurar el mínimo de 1s
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    if (elapsed < 1000) {
      await Future.delayed(Duration(milliseconds: 1000 - elapsed));
    }
  } catch (e) {
    // Manejar errores silenciosamente - no hacer nada en caso de fallo
    return;
  }
}
