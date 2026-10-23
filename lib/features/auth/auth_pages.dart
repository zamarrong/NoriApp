import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/widgets/nori_logo.dart';

/// [AnimatedSize] that steps aside when motion is reduced (a zero duration makes it re-layout itself).
Widget _resize(BuildContext context, Widget child, {Duration duration = NrMotion.base}) =>
    nrReduceMotion(context) ? child : AnimatedSize(duration: duration, curve: NrMotion.ease, alignment: Alignment.topCenter, child: child);

/// Background of the sign-in screens: plain white in light, the canvas in dark.
Color authBackground(NrColors nr) => nr.night ? nr.canvas : nr.surface;

enum _Step { company, credentials }

/// Sign-in in two steps: first the company (code, domain or server URL, checked
/// against the server), then user and password. A device that already signed in
/// starts on the second step with its company remembered. Signing in registers
/// this device (one token per device).
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late final prefs = ref.read(prefsProvider);
  late final server = TextEditingController(text: prefs.getString(AuthController.lastServerKey) ?? '');
  late final tenant = TextEditingController(text: prefs.getString(AuthController.lastTenantKey) ?? '');
  late final user = TextEditingController(text: prefs.getString(AuthController.lastUserKey) ?? '');
  final password = TextEditingController();
  final _userFocus = FocusNode();
  final _passwordFocus = FocusNode();

  late _Step step = server.text.trim().isEmpty ? _Step.company : _Step.credentials;
  late bool withCode = tenant.text.isNotEmpty;
  bool busy = false;
  bool obscure = true;
  String? companyError;
  String? codeError;
  String? userError;
  String? passwordError;

  /// Problem that is not about one field (no connection, server error).
  String? error;

  @override
  void dispose() {
    for (final c in [server, tenant, user, password]) {
      c.dispose();
    }
    _userFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  String? get _code => withCode && tenant.text.trim().isNotEmpty ? tenant.text.trim() : null;

  /// What the company chip shows: what the user typed, without the scheme.
  String get _companyLabel {
    final s = server.text.trim().replaceFirst(RegExp(r'^https?://'), '').replaceFirst(RegExp(r'/+$'), '');
    return _code == null ? s : '$s · $_code';
  }

  String _networkMessage() => 'No pudimos conectar con ${server.text.trim()}. Revisa la dirección o tu señal.';

  void _go(_Step to) {
    setState(() {
      step = to;
      error = null;
    });
  }

  Future<void> _checkCompany() async {
    FocusScope.of(context).unfocus();
    setState(() {
      error = null;
      companyError = server.text.trim().isEmpty ? 'Escribe el nombre de tu empresa.' : null;
      codeError = withCode && tenant.text.trim().isEmpty ? 'Escribe el código de empresa.' : null;
    });
    if (companyError != null || codeError != null) return;
    setState(() => busy = true);
    try {
      await ref.read(authProvider.notifier).checkCompany(server.text, tenantCode: _code);
      if (!mounted) return;
      _go(_Step.credentials);
      WidgetsBinding.instance.addPostFrameCallback((_) => (user.text.isEmpty ? _userFocus : _passwordFocus).requestFocus());
    } on FormatException catch (e) {
      setState(() => companyError = e.message);
    } on ApiException catch (e) {
      _companyFailed(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// A company problem found on either step lands on the company step.
  void _companyFailed(ApiException e) {
    setState(() {
      step = _Step.company;
      switch (e.code) {
        case 'network':
          error = _networkMessage();
        case 'tenant_not_found':
          if (_code != null) {
            codeError = 'No encontramos ese código de empresa.';
          } else {
            companyError = 'No encontramos esa empresa. Revisa cómo la escribiste.';
          }
        case 'tenant_required':
          withCode = true;
          codeError = 'Este servidor pide el código de empresa.';
        default:
          error = e.userMessage;
      }
    });
  }

  Future<void> _signIn() async {
    setState(() {
      error = null;
      userError = user.text.trim().isEmpty ? 'Escribe tu usuario.' : null;
      passwordError = password.text.isEmpty ? 'Escribe tu contraseña.' : null;
    });
    if (userError != null || passwordError != null) return;
    FocusScope.of(context).unfocus();
    setState(() => busy = true);
    try {
      await ref.read(authProvider.notifier).login(server: server.text, tenantCode: _code, username: user.text, password: password.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'network') {
        setState(() => error = _networkMessage());
      } else if (e.code.startsWith('tenant_')) {
        _companyFailed(e);
      } else if (e.code == 'invalid_credentials') {
        setState(() => passwordError = e.userMessage);
        password.clear();
        _passwordFocus.requestFocus();
      } else {
        setState(() => error = e.userMessage);
      }
    } on FormatException catch (e) {
      setState(() {
        step = _Step.company;
        companyError = e.message;
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final reduce = nrReduceMotion(context);
    final company = step == _Step.company;
    return PopScope(
      canPop: company,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy) _go(_Step.company);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: nr.night ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: authBackground(nr),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(NrSpace.xxl, NrSpace.lg, NrSpace.xxl, NrSpace.xl),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const NrEntrance(child: Align(alignment: Alignment.centerLeft, child: NoriLogo(height: 34))),
                        const SizedBox(height: NrSpace.xxxl + NrSpace.sm),
                        AnimatedSwitcher(
                          duration: reduce ? Duration.zero : NrMotion.base,
                          switchInCurve: NrMotion.emphasized,
                          switchOutCurve: Curves.easeIn,
                          layoutBuilder: (current, previous) => Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
                          transitionBuilder: (child, a) => FadeTransition(
                            opacity: a,
                            child: SlideTransition(position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(a), child: child),
                          ),
                          child: company ? _companyStep(context) : _credentialsStep(context),
                        ),
                        _resize(
                          context,
                          error == null
                              ? const SizedBox(width: double.infinity)
                              : Padding(
                                  padding: const EdgeInsets.only(top: NrSpace.xl),
                                  child: NrBanner(message: error!, tone: NrTone.danger, icon: Icons.error_outline_rounded),
                                ),
                        ),
                      ]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(NrSpace.xxl, NrSpace.sm, NrSpace.xxl, NrSpace.lg),
                    child: NrButton(
                      key: const ValueKey('login-submit'),
                      label: company ? 'Continuar' : 'Entrar',
                      busy: busy,
                      onPressed: company ? _checkCompany : _signIn,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _companyStep(BuildContext context) {
    final nr = context.nr;
    return Column(key: const ValueKey(_Step.company), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(header: true, child: Text('Entra a tu empresa', style: NrText.display(context))),
      const SizedBox(height: NrSpace.sm),
      Text('Escribe el nombre de tu empresa o la dirección de su servidor.', style: NrText.body(context).copyWith(color: nr.secondary)),
      const SizedBox(height: NrSpace.xxxl),
      AuthField(
        label: 'Empresa',
        controller: server,
        hint: 'miempresa',
        error: companyError,
        enabled: !busy,
        keyboardType: TextInputType.url,
        textInputAction: withCode ? TextInputAction.next : TextInputAction.go,
        onChanged: (_) => setState(() => companyError = null),
        onSubmitted: withCode ? null : (_) => _checkCompany(),
      ),
      _resize(
        context,
        withCode
            ? Padding(
                padding: const EdgeInsets.only(top: NrSpace.xl),
                child: AuthField(
                  label: 'Código de empresa',
                  controller: tenant,
                  hint: 'miempresa',
                  helper: 'Solo si tu servidor te lo pide.',
                  error: codeError,
                  enabled: !busy,
                  textInputAction: TextInputAction.go,
                  onChanged: (_) => setState(() => codeError = null),
                  onSubmitted: (_) => _checkCompany(),
                ),
              )
            : Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: NrSpace.sm),
                  child: TextButton(
                    onPressed: busy ? null : () => setState(() => withCode = true),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 44), foregroundColor: nr.secondary),
                    child: const Text('Agregar código de empresa'),
                  ),
                ),
              ),
      ),
    ]);
  }

  Widget _credentialsStep(BuildContext context) {
    return AutofillGroup(
      key: const ValueKey(_Step.credentials),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(header: true, child: Text('Inicia sesión', style: NrText.display(context))),
        const SizedBox(height: NrSpace.md),
        Align(alignment: Alignment.centerLeft, child: _CompanyChip(label: _companyLabel, onChange: busy ? null : () => _go(_Step.company))),
        const SizedBox(height: NrSpace.xxxl),
        AuthField(
          label: 'Usuario',
          controller: user,
          focusNode: _userFocus,
          error: userError,
          enabled: !busy,
          autofillHints: const [AutofillHints.username],
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() => userError = null),
          onSubmitted: (_) => _passwordFocus.requestFocus(),
        ),
        const SizedBox(height: NrSpace.xl),
        AuthField(
          label: 'Contraseña',
          controller: password,
          focusNode: _passwordFocus,
          error: passwordError,
          enabled: !busy,
          obscure: obscure,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.go,
          onChanged: (_) => setState(() => passwordError = null),
          onSubmitted: (_) => _signIn(),
          trailing: IconButton(
            tooltip: obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
            icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 22),
            onPressed: () => setState(() => obscure = !obscure),
          ),
        ),
      ]),
    );
  }
}

/// The company the user is signing in to, with a way back to change it.
class _CompanyChip extends StatelessWidget {
  const _CompanyChip({required this.label, required this.onChange});

  final String label;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    return Semantics(
      button: true,
      label: 'Empresa $label. Cambiar',
      excludeSemantics: true,
      child: Material(
        color: nr.raised,
        borderRadius: BorderRadius.circular(NrRadius.pill),
        child: InkWell(
          onTap: onChange,
          borderRadius: BorderRadius.circular(NrRadius.pill),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(NrSpace.md, NrSpace.sm, NrSpace.lg, NrSpace.sm),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.apartment_rounded, size: 18, color: nr.secondary),
                const SizedBox(width: NrSpace.sm),
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: NrText.label(context).copyWith(color: nr.headline))),
                const SizedBox(width: NrSpace.md),
                Text('Cambiar', style: NrText.label(context).copyWith(color: nr.link, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Filled input with its label on top and no outline until it has focus or an error.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.error,
    this.enabled = true,
    this.obscure = false,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.trailing,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final String? error;
  final bool enabled;
  final bool obscure;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final r = BorderRadius.circular(NrRadius.xl);
    final idle = nr.highContrast ? BorderSide(color: nr.borderStrong, width: 1.5) : BorderSide.none;
    final hasError = error != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(label, style: NrText.label(context).copyWith(color: hasError ? nr.danger : nr.secondary, fontWeight: FontWeight.w600)),
      const SizedBox(height: NrSpace.sm),
      TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        obscureText: obscure,
        autocorrect: false,
        enableSuggestions: !obscure,
        textCapitalization: TextCapitalization.none,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: NrText.body(context).copyWith(fontSize: 17, color: nr.headline),
        cursorColor: nr.accent,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: NrText.body(context).copyWith(fontSize: 17, color: nr.muted),
          filled: true,
          fillColor: hasError ? nr.dangerBg : nr.raised,
          isDense: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: NrSpace.lg, vertical: 17),
          suffixIcon: trailing,
          suffixIconColor: nr.secondary,
          border: OutlineInputBorder(borderRadius: r, borderSide: idle),
          enabledBorder: OutlineInputBorder(borderRadius: r, borderSide: hasError ? BorderSide(color: nr.danger, width: 1.5) : idle),
          disabledBorder: OutlineInputBorder(borderRadius: r, borderSide: idle),
          focusedBorder: OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: hasError ? nr.danger : nr.accent, width: 2)),
        ),
      ),
      _resize(
        context,
        duration: NrMotion.fast,
        hasError
            ? Padding(
                padding: const EdgeInsets.only(top: NrSpace.sm),
                child: Semantics(
                  liveRegion: true,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.only(top: 1), child: Icon(Icons.error_rounded, size: 16, color: nr.danger)),
                    const SizedBox(width: NrSpace.xs + 2),
                    Expanded(child: Text(error!, style: NrText.bodySm(context).copyWith(color: nr.danger, fontWeight: FontWeight.w500))),
                  ]),
                ),
              )
            : helper != null
                ? Padding(padding: const EdgeInsets.only(top: NrSpace.sm), child: Text(helper!, style: NrText.bodySm(context)))
                : const SizedBox(width: double.infinity),
      ),
    ]);
  }
}

/// Quick unlock with fingerprint or face.
class UnlockPage extends ConsumerStatefulWidget {
  const UnlockPage({super.key});

  @override
  ConsumerState<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends ConsumerState<UnlockPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(authProvider.notifier).unlock());
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final nr = context.nr;
    return Scaffold(
      backgroundColor: authBackground(nr),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(NrSpace.xxl, NrSpace.lg, NrSpace.xxl, NrSpace.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Align(alignment: Alignment.centerLeft, child: NoriLogo(height: 34)),
            const Spacer(),
            NrAvatar(s?.userName ?? '', size: 64, color: nr.accent),
            const SizedBox(height: NrSpace.xl),
            Text('Hola, ${s?.userName ?? ''}', style: NrText.display(context)),
            const SizedBox(height: NrSpace.xs),
            Text(s?.tenantName ?? '', style: NrText.body(context).copyWith(color: nr.secondary)),
            const Spacer(flex: 2),
            NrButton(label: 'Desbloquear', icon: Icons.fingerprint_rounded, onPressed: () => ref.read(authProvider.notifier).unlock()),
            const SizedBox(height: NrSpace.sm),
            NrButton(label: 'Usar contraseña', variant: NrButtonVariant.ghost, onPressed: () => ref.read(authProvider.notifier).logout()),
          ]),
        ),
      ),
    );
  }
}

/// Working warehouse of this device.
class WarehousePage extends ConsumerStatefulWidget {
  const WarehousePage({super.key});

  @override
  ConsumerState<WarehousePage> createState() => _WarehousePageState();
}

class _WarehousePageState extends ConsumerState<WarehousePage> {
  int? busyId;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    if (s == null) return const SizedBox.shrink();
    final allowed = s.allowedWarehouseIds.toSet();
    final list = s.warehouses.where((w) => allowed.isEmpty || allowed.contains(w['id'])).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Almacén de trabajo'), automaticallyImplyLeading: !s.mustChooseWarehouse),
      body: ListView(padding: const EdgeInsets.fromLTRB(NrSpace.gutter, NrSpace.xs, NrSpace.gutter, NrSpace.xxxl), children: [
        Text('Documentos, series y existencias parten de este almacén.', style: NrText.bodySm(context)),
        const SizedBox(height: NrSpace.lg),
        NrGroup(inset: 64, children: [
          for (final w in list)
            NrListRow(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: w['id'] == s.warehouseId ? context.nr.accentSoft : context.nr.raised, borderRadius: BorderRadius.circular(NrRadius.lg)),
                child: Icon(Icons.warehouse_rounded, size: 20, color: w['id'] == s.warehouseId ? context.nr.accent : context.nr.secondary),
              ),
              title: '${w['name']}',
              subtitle: '${w['code'] ?? ''}',
              trailing: busyId == w['id']
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : (w['id'] == s.warehouseId ? Icon(Icons.check_circle_rounded, color: context.nr.accent) : null),
              onTap: () async {
                setState(() => busyId = (w['id'] as num).toInt());
                try {
                  await ref.read(authProvider.notifier).setWorkingWarehouse((w['id'] as num).toInt());
                  ref.read(syncEngineProvider)?.syncNow();
                  if (context.mounted) context.go('/');
                } on ApiException catch (e) {
                  if (context.mounted) showSnack(context, e.userMessage, tone: NrTone.danger);
                } finally {
                  if (mounted) setState(() => busyId = null);
                }
              },
            ),
        ]),
      ]),
    );
  }
}
