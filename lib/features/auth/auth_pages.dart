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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(NrSpace.xxl), children: [
              const _Brand(),
              const SizedBox(height: NrSpace.sm),
              Text('Venta en ruta, inventario y supervisión.', style: NrText.bodySm(context)),
              const SizedBox(height: NrSpace.xxxl),
              TextField(
                controller: server,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Empresa o servidor', hintText: 'blanc  ·  blanc.nori.mx', prefixIcon: Icon(Icons.business_outlined)),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => setState(() => advanced = !advanced), child: Text(advanced ? 'Ocultar opciones' : 'Opciones avanzadas')),
              ),
              if (advanced) ...[
                TextField(
                  controller: tenant,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Código de empresa (dominio central)', helperText: 'Solo si el servidor es compartido, p. ej. api.nori.mx'),
                ),
                const SizedBox(height: NrSpace.md),
              ],
              TextField(
                controller: user,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Usuario', prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: NrSpace.md),
              TextField(
                controller: password,
                obscureText: obscure,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => obscure = !obscure)),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: NrSpace.md),
                Text(error!, style: NrText.bodySm(context).copyWith(color: context.nr.danger)),
              ],
              const SizedBox(height: NrSpace.xl),
              FilledButton(
                onPressed: busy ? null : _submit,
                child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Entrar'),
              ),
            ]),
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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(NrSpace.xxl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Spacer(),
            const _Brand(),
            const SizedBox(height: NrSpace.lg),
            Text('Hola, ${s?.userName ?? ''}', style: NrText.title(context)),
            Text(s?.tenantName ?? '', style: NrText.bodySm(context)),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => ref.read(authProvider.notifier).unlock(),
              icon: const Icon(Icons.fingerprint),
              label: const Text('Desbloquear'),
            ),
            const SizedBox(height: NrSpace.sm),
            TextButton(onPressed: () => ref.read(authProvider.notifier).logout(), child: const Text('Entrar con contraseña')),
          ]),
        ),
      ),
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
      body: ListView(padding: const EdgeInsets.all(NrSpace.gutter), children: [
        Text('Documentos, series y existencias parten de este almacén.', style: NrText.bodySm(context)),
        const SizedBox(height: NrSpace.lg),
        NrGroup(children: [
          for (final w in list)
            NrListRow(
              leading: Icon(Icons.warehouse_outlined, color: w['id'] == s.warehouseId ? context.nr.accent : context.nr.secondary),
              title: '${w['name']}',
              subtitle: '${w['code'] ?? ''}',
              trailing: busyId == w['id']
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : (w['id'] == s.warehouseId ? Icon(Icons.check, color: context.nr.accent) : null),
              onTap: () async {
                setState(() => busyId = (w['id'] as num).toInt());
                try {
                  await ref.read(authProvider.notifier).setWorkingWarehouse((w['id'] as num).toInt());
                  ref.read(syncEngineProvider)?.syncNow();
                  if (context.mounted) context.go('/');
                } on ApiException catch (e) {
                  if (context.mounted) showSnack(context, e.userMessage);
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
