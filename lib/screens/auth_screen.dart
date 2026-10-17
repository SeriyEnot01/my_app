import 'package:flutter/material.dart';

import '../core/scope.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _register = false;
  bool _show = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _email.text = StoreScope.read(context).lastEmail ?? '';
  }

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final store = StoreScope.read(context);
    final email = _email.text.trim();
    final pw = _pw.text;
    setState(() {
      _error = null;
      _info = null;
    });
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Введите почту полностью, например name@mail.ru.');
      return;
    }
    String? problem;
    if (_register) {
      if (pw.length < 10) {
        problem = 'Пароль должен быть не короче 10 символов.';
      } else if (pw != _pw2.text) {
        problem = 'Пароли не совпадают.';
      }
    } else if (pw.isEmpty) {
      problem = 'Введите пароль.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() => _busy = true);
    try {
      if (_register) {
        final signedIn = await store.signUp(email, pw);
        if (!signedIn && mounted) {
          setState(() {
            _register = false;
            _pw.clear();
            _pw2.clear();
            _info = 'Мы отправили письмо на $email. Подтвердите адрес по ссылке и войдите с этим паролем.';
          });
        }
      } else {
        await store.signIn(email, pw);
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Не получилось: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final lead = store.authHint.isNotEmpty
        ? store.authHint
        : _register
            ? 'Задачи шифруются на устройстве. Пароль от 10 символов, он же ключ шифрования.'
            : 'Войдите тем же аккаунтом, что и на сайте: задачи синхронизируются между телефоном и компьютером.';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                decoration: BoxDecoration(
                  color: C.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: C.line),
                ),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(children: [Dot(C.deadline, size: 10), SizedBox(width: 6), Dot(C.workout, size: 10), SizedBox(width: 6), Dot(C.faint, size: 10)]),
                      const SizedBox(height: 14),
                      Text(_register ? 'Создать аккаунт' : 'Вход', style: display(24, weight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(lead, style: const TextStyle(color: C.muted, fontSize: 14)),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.email, AutofillHints.username],
                        decoration: const InputDecoration(labelText: 'Почта'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pw,
                        obscureText: !_show,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
                        decoration: const InputDecoration(labelText: 'Пароль'),
                        onSubmitted: (_) => _register ? null : _submit(),
                      ),
                      if (_register) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _pw2,
                          obscureText: !_show,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(labelText: 'Повторите пароль'),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(children: [
                        Checkbox(value: _show, onChanged: (v) => setState(() => _show = v ?? false)),
                        GestureDetector(
                          onTap: () => setState(() => _show = !_show),
                          child: const Text('Показать пароль', style: TextStyle(color: C.muted)),
                        ),
                      ]),
                      if (_error != null) Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(_error!, style: const TextStyle(color: C.overdue, fontSize: 13.5)),
                      ),
                      if (_info != null) Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(_info!, style: const TextStyle(color: C.workout, fontSize: 13.5)),
                      ),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const Row(mainAxisSize: MainAxisSize.min, children: [
                                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: C.accentInk)),
                                SizedBox(width: 10),
                                Text('Вычисляем ключ шифрования…'),
                              ])
                            : Text(_register ? 'Создать аккаунт' : 'Войти'),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _register = !_register;
                                  _error = null;
                                  _info = null;
                                }),
                        child: Text(_register ? 'Уже есть аккаунт? Войти' : 'Нет аккаунта? Создать'),
                      ),
                      const SizedBox(height: 6),
                      const Text.rich(
                        TextSpan(children: [
                          TextSpan(text: 'Пароль нельзя восстановить. ', style: TextStyle(fontWeight: FontWeight.w600, color: C.muted)),
                          TextSpan(text: 'Им шифруются задачи, и без него их не прочитает никто, включая вас. Храните его в менеджере паролей.'),
                        ]),
                        style: TextStyle(fontSize: 12.5, color: C.faint, height: 1.45),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
