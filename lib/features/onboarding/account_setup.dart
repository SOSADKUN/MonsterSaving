import 'package:flutter/material.dart';
import '../../app/widgets.dart';
import '../../core/localization/context.dart';

/// Account UI only. Firebase authentication will be connected separately.
class AccountSetup extends StatefulWidget {
  const AccountSetup({super.key, required this.onContinueAsGuest});
  final VoidCallback onContinueAsGuest;

  @override
  State<AccountSetup> createState() => _AccountSetupState();
}

class _AccountSetupState extends State<AccountSetup> {
  final _form = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _signUp = false, _hidePassword = true, _hideConfirmation = true;

  @override
  void dispose() {
    for (final controller in [_identifier, _email, _password, _confirmation]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (_form.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();
    // Do not create a fake session or persist/send prototype credentials.
    notice(context, context.tr('auth.notConnected'));
  }

  Widget _passwordField({bool confirmation = false}) {
    final hidden = confirmation ? _hideConfirmation : _hidePassword;
    return TextFormField(
      controller: confirmation ? _confirmation : _password,
      obscureText: hidden,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      textInputAction: _signUp && !confirmation
          ? TextInputAction.next
          : TextInputAction.done,
      onFieldSubmitted: _signUp && !confirmation ? null : (_) => _submit(),
      decoration: InputDecoration(
        labelText: context.tr(
          confirmation ? 'auth.confirmPassword' : 'auth.password',
        ),
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: context.tr(hidden ? 'common.showValue' : 'common.hideValue'),
          icon: Icon(
            hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() {
            if (confirmation) {
              _hideConfirmation = !_hideConfirmation;
            } else {
              _hidePassword = !_hidePassword;
            }
          }),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return context.tr('auth.required');
        if (confirmation && value != _password.text) {
          return context.tr('auth.passwordMismatch');
        }
        if (_signUp && !confirmation && value.length < 8) {
          return context.tr('auth.passwordLength');
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SegmentedButton<bool>(
        segments: [
          ButtonSegment(
            value: false,
            label: Text(context.tr('onboarding.012')),
          ),
          ButtonSegment(value: true, label: Text(context.tr('onboarding.013'))),
        ],
        selected: {_signUp},
        onSelectionChanged: (selection) {
          _form.currentState?.reset();
          _password.clear();
          _confirmation.clear();
          setState(() {
            _signUp = selection.single;
            _hidePassword = true;
            _hideConfirmation = true;
          });
        },
      ),
      const SizedBox(height: 20),
      Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _identifier,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: context.tr(
                  _signUp ? 'auth.username' : 'auth.identifier',
                ),
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.tr('auth.required')
                  : null,
            ),
            const SizedBox(height: 16),
            if (_signUp) ...[
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: context.tr('auth.email'),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                validator: (value) =>
                    RegExp(
                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                    ).hasMatch((value ?? '').trim())
                    ? null
                    : context.tr('auth.invalidEmail'),
              ),
              const SizedBox(height: 16),
            ],
            _passwordField(),
            if (_signUp) ...[
              const SizedBox(height: 16),
              _passwordField(confirmation: true),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submit,
              child: Text(
                context.tr(_signUp ? 'onboarding.013' : 'onboarding.012'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text(context.tr('auth.preview'), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      const Divider(),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: widget.onContinueAsGuest,
        icon: const Icon(Icons.person_outline),
        label: Text(context.tr('onboarding.046')),
      ),
      const SizedBox(height: 8),
      Text(context.tr('onboarding.011'), textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text(
        context.tr('onboarding.014'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}
