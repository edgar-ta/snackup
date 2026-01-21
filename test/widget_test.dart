import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snackup/features/auth/login_screen.dart';
import 'package:snackup/features/auth/role_selection_screen.dart';

void main() {
  group('Login Screen Tests', () {
    testWidgets('LoginScreen muestra campos de email y contraseña', (
      WidgetTester tester,
    ) async {
      // Construir el widget
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      // Verificar que existen los campos de email y contraseña
      expect(find.byType(TextField), findsWidgets);

      // Verificar que existe el botón de "Iniciar Sesión"
      expect(find.byType(ElevatedButton), findsWidgets);

      // Verificar que el mensaje de error está vacío inicialmente
      expect(find.text('Correo o contraseña incorrectos'), findsNothing);
    });

    testWidgets('LoginScreen valida campos vacíos correctamente', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      // Encontrar y presionar el botón de inicio de sesión
      final buttonFinder = find.byType(ElevatedButton).first;
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      // Verificar que se muestra mensaje de error para campos vacíos
      expect(find.text('Por favor, llena ambos campos'), findsOneWidget);
    });
  });

  group('Role Selection Tests', () {
    testWidgets('RoleSelectionScreen muestra opciones de rol', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: RoleSelectionScreen(userId: 'test-user-id')),
      );

      // Verificar que se muestra el título
      expect(find.text('¿Quién eres?'), findsOneWidget);

      // Verificar que existe el botón para seleccionar "Alumno / Personal"
      expect(find.text('Soy Alumno / Personal'), findsOneWidget);

      // Verificar que se muestra el mensaje sobre contactar al administrador
      expect(
        find.text('Si eres un negocio, contacta al administrador.'),
        findsOneWidget,
      );
    });
  });
}
