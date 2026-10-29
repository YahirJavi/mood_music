import '../../../core/validation/form_validators.dart';
import 'package:flutter/material.dart';
import '../domain/password_policy.dart';
import '../../../core/widgets/feedback.dart';
import '../domain/auth_repository.dart';
import 'auth_messages.dart';
import 'widgets/auth_layout.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.repository});
  final AuthRepository repository;
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}
class _RegisterScreenState extends State<RegisterScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(), email = TextEditingController();
  final password = TextEditingController(), confirmation = TextEditingController();
  bool busy = false, hidePassword = true, hideConfirmation = true;
  @override
  void dispose() { name.dispose(); email.dispose(); password.dispose(); confirmation.dispose(); super.dispose(); }
  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.repository.register(name.text.trim(), email.text.trim(), password.text);
      // El observador de sesión existente abre el catálogo y elimina esta ruta.
      // No se envían enlaces ni códigos de verificación de correo.
    } catch (error) { if (mounted) showMessage(context, authMessage(error)); }
    finally { if (mounted) setState(() => busy = false); }
  }
  InputDecoration passwordDecoration(String label, bool hidden, VoidCallback toggle) => InputDecoration(
    labelText: label, prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(
      tooltip: hidden ? 'Mostrar contraseña' : 'Ocultar contraseña', onPressed: toggle,
      icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined)));
  @override
  Widget build(BuildContext context) => PopScope(canPop: !busy, child: AuthLayout(
    title: 'Crea tu cuenta', subtitle: 'Un nuevo ritmo empieza contigo.', canGoBack: true,
    child: AutofillGroup(child: Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextFormField(controller: name, enabled: !busy, textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next, autofillHints: const [AutofillHints.name], maxLength: 40,
        decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.person_outline)),
        validator: validatePersonName),
      const SizedBox(height: 12),
      TextFormField(controller: email, enabled: !busy, keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next, autofillHints: const [AutofillHints.email],
        decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.alternate_email)), validator: validateEmail),
      const SizedBox(height: 16),
      const Text('De 8 a 20 caracteres, con una letra, un número y un símbolo.'),
      const SizedBox(height: 8),
      TextFormField(controller: password, maxLength: 20, enabled: !busy, obscureText: hidePassword,
        autocorrect: false, enableSuggestions: false, textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.newPassword],
        decoration: passwordDecoration('Contraseña', hidePassword, () => setState(() => hidePassword = !hidePassword)),
        validator: validateNewPassword),
      const SizedBox(height: 16),
      TextFormField(controller: confirmation, maxLength: 20, enabled: !busy, obscureText: hideConfirmation,
        autocorrect: false, enableSuggestions: false, onFieldSubmitted: (_) => submit(),
        decoration: passwordDecoration('Confirmar contraseña', hideConfirmation, () => setState(() => hideConfirmation = !hideConfirmation)),
        validator: (v) => v == null || v.isEmpty ? 'Repite tu contraseña' : v != password.text ? 'Las contraseñas no coinciden' : null),
      const SizedBox(height: 24),
      FilledButton(onPressed: busy ? null : submit, style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54), backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: Text(busy ? 'Creando cuenta…' : 'Crear cuenta')),
      const SizedBox(height: 16), TextButton(onPressed: busy ? null : () => Navigator.of(context).pop(), child: const Text('Ya tengo cuenta · Iniciar sesión')),
    ]))),
  ));
}
