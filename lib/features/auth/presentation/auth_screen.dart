import 'package:flutter/material.dart';
import '../../../app/app_controller.dart';
import '../../../core/widgets/feedback.dart';
import '../domain/auth_repository.dart';
import 'auth_messages.dart';
import 'register_screen.dart';
import 'widgets/auth_layout.dart';
import 'widgets/social_button.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.controller, required this.repository});
  final AppController controller;
  final AuthRepository repository;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}
class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false, obscure = true;
  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }
  Future<void> execute(Future<void> Function() action, {String? message}) async {
    if (busy) return;
    setState(() => busy = true);
    try { await action(); if (mounted && message != null) showMessage(context, message); }
    catch (error) { if (mounted) showMessage(context, authMessage(error)); }
    finally { if (mounted) setState(() => busy = false); }
  }
  void login() {
    if (form.currentState!.validate()) {
      execute(() => widget.repository.signIn(email.text.trim(), password.text));
    }
  }
  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'Vuelve a tu ritmo', subtitle: 'Tu música te está esperando.',
    child: AutofillGroup(child: Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextFormField(controller: email, enabled: !busy, keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email], textInputAction: TextInputAction.next,
        decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.alternate_email)), validator: validateEmail),
      const SizedBox(height: 16),
      TextFormField(controller: password, enabled: !busy, obscureText: obscure, autocorrect: false, enableSuggestions: false,
        autofillHints: const [AutofillHints.password], onFieldSubmitted: (_) { if (!busy) login(); },
        decoration: InputDecoration(labelText: 'Contraseña', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(
          tooltip: obscure ? 'Mostrar contraseña' : 'Ocultar contraseña', onPressed: () => setState(() => obscure = !obscure),
          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
        validator: (v) => v == null || v.isEmpty ? 'Escribe tu contraseña' : null),
      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: busy ? null : () {
        final error = validateEmail(email.text);
        if (error != null) { showMessage(context, 'Escribe un correo válido para recuperar la contraseña.'); return; }
        execute(() => widget.repository.resetPassword(email.text.trim()),
          message: 'Si existe una cuenta con ese correo, recibirás instrucciones. Revisa también spam.');
      }, child: const Text('Olvidé mi contraseña'))),
      FilledButton(onPressed: busy ? null : login, style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54), backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: Text(busy ? 'Espera…' : 'Iniciar sesión')),
      const Padding(padding: EdgeInsets.symmetric(vertical: 22), child: Row(children: [
        Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('o continúa con')), Expanded(child: Divider()),
      ])),
      SocialButton( onPressed: busy ? null : () => execute(() => widget.repository.signInWithProvider(AuthProvider.google))),
      const SizedBox(height: 20), const Text('¿Primera vez en MoodMusic?', textAlign: TextAlign.center),
      TextButton(onPressed: busy ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => RegisterScreen(repository: widget.repository))), child: const Text('Crear una cuenta')),
    ]))),
  );
}
