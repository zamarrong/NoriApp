import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/widgets/nori_logo.dart';

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => const Align(alignment: Alignment.centerLeft, child: NoriLogo(height: 44));
}

/// Inicio de sesión: empresa (código o servidor), usuario y contraseña. El
/// login registra este dispositivo (un token por dispositivo).
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
  late bool advanced = tenant.text.isNotEmpty;
  bool busy = false;
  bool obscure = true;
  String? error;

  Future<void> _submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(authProvider.notifier).login(
            server: server.text,
            tenantCode: advanced ? tenant.text : null,
            username: user.text,
            password: password.text,
          );
    } on ApiException catch (e) {
      setState(() => error = switch (e.code) {
            'network' => 'No hay conexión con ${server.text}. Revisa la dirección o tu señal.',
            'tenant_not_found' => 'No existe esa empresa.',
            'tenant_required' => 'Este servidor pide el código de empresa (opciones avanzadas).',
            _ => e.userMessage,
          });
    } on FormatException catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    return Scaffold(
      body: Stack(children: [
        const _Glow(),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(NrSpace.xxl, NrSpace.xl, NrSpace.xxl, NrSpace.xxl), children: [
                const NrEntrance(child: _Brand()),
                const SizedBox(height: NrSpace.xxl),
                NrEntrance(index: 1, child: Text('Entra a tu empresa', style: NrText.display(context))),
                const SizedBox(height: NrSpace.xs),
                NrEntrance(index: 1, child: Text('Venta en ruta, inventario y supervisión. Funciona sin señal.', style: NrText.body(context).copyWith(color: nr.secondary))),
                const SizedBox(height: NrSpace.xxl),
                NrEntrance(
                  index: 2,
                  child: NrCard(
                    depth: NrDepth.floating,
                    radius: NrRadius.hero,
                    padding: const EdgeInsets.all(NrSpace.xl),
                    child: AutofillGroup(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        TextField(
                          controller: server,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Empresa o servidor', hintText: 'miempresa  ·  miempresa.nori.mx', prefixIcon: Icon(Icons.business_rounded)),
                        ),
                        AnimatedSize(
                          duration: NrMotion.base,
                          curve: NrMotion.ease,
                          child: advanced
                              ? Padding(
                                  padding: const EdgeInsets.only(top: NrSpace.md),
                                  child: TextField(
                                    controller: tenant,
                                    autocorrect: false,
                                    decoration: const InputDecoration(
                                      labelText: 'Código de empresa (dominio central)',
                                      helperText: 'Solo si el servidor es compartido, p. ej. api.nori.mx',
                                      prefixIcon: Icon(Icons.key_rounded),
                                    ),
                                  ),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                        const SizedBox(height: NrSpace.md),
                        TextField(
                          controller: user,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.username],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Usuario', prefixIcon: Icon(Icons.person_rounded)),
                        ),
                        const SizedBox(height: NrSpace.md),
                        TextField(
                          controller: password,
                          obscureText: obscure,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_rounded),
                            suffixIcon: IconButton(
                              tooltip: obscure ? 'Mostrar' : 'Ocultar',
                              icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => obscure = !obscure),
                            ),
                          ),
                        ),
                        AnimatedSize(
                          duration: NrMotion.base,
                          curve: NrMotion.ease,
                          child: error == null
                              ? const SizedBox(width: double.infinity)
                              : Padding(
                                  padding: const EdgeInsets.only(top: NrSpace.md),
                                  child: NrBanner(message: error!, tone: NrTone.danger, icon: Icons.error_outline_rounded),
                                ),
                        ),
                        const SizedBox(height: NrSpace.xl),
                        NrButton(label: 'Entrar', icon: Icons.arrow_forward_rounded, busy: busy, onPressed: _submit),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: NrSpace.md),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => advanced = !advanced),
                    child: Text(advanced ? 'Ocultar opciones avanzadas' : 'Opciones avanzadas'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Halo suave del acento detrás del inicio de sesión (como el punto de venta de nori-web).
class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.9, -1.1),
              radius: 1.2,
              colors: [nr.accent.withValues(alpha: nr.night ? 0.22 : 0.14), nr.accent.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Desbloqueo rápido con huella o rostro.
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
      body: Stack(children: [
        const _Glow(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(NrSpace.xxl),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Spacer(),
              const _Brand(),
              const SizedBox(height: NrSpace.xxl),
              Row(children: [
                NrAvatar(s?.userName ?? '', size: 56, color: nr.accent),
                const SizedBox(width: NrSpace.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Hola, ${s?.userName ?? ''}', style: NrText.title(context)),
                    Text(s?.tenantName ?? '', style: NrText.bodySm(context)),
                  ]),
                ),
              ]),
              const Spacer(flex: 2),
              NrButton(label: 'Desbloquear', icon: Icons.fingerprint_rounded, onPressed: () => ref.read(authProvider.notifier).unlock()),
              const SizedBox(height: NrSpace.sm),
              NrButton(label: 'Entrar con contraseña', variant: NrButtonVariant.ghost, onPressed: () => ref.read(authProvider.notifier).logout()),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Almacén de trabajo de este dispositivo.
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
