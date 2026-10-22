# Nori móvil

App Flutter de Nori para vendedores de ruta, la terminal de inventario y supervisores. Habla con la
**API v1 de nori-web** (`nori-web/docs/api/openapi.yaml` y `docs/api/README.md`) y trabaja sin señal:
guarda catálogos en SQLite y encola las escrituras con su llave de idempotencia.

Interfaz en español; código en inglés. El lenguaje visual viene de la app rediseñada de Recaudo (plano,
borde de 1 px, Inter, botón primario en tinta, claro y oscuro), con el acento de Nori.

## Puesta en marcha

Requisitos: Flutter 3.41+ (Dart 3.9+), Android SDK (minSdk 23) o Xcode.

```bash
flutter pub get
flutter analyze
flutter test
flutter run                 # dispositivo o emulador
flutter build apk --debug   # APK de prueba
```

No hay secretos en el repositorio: el token del dispositivo vive en el almacén seguro del teléfono
(`flutter_secure_storage`) y nunca en SQLite ni en preferencias.

La compilación web no está soportada: la base local usa `sqflite` (Android/iOS). Para web haría falta
`sqflite_common_ffi_web` o cambiar a `drift` con WASM.

## Cómo apuntar a una empresa

En la pantalla de inicio, campo **Empresa o servidor**:

| Escribes | Servidor | Encabezado |
|---|---|---|
| `miempresa` | `https://miempresa.nori.mx` | — (dominio de la empresa, recomendado) |
| `miempresa.nori.mx` o `https://miempresa.nori.mx` | ese dominio | — |
| `api.nori.mx` + *Opciones avanzadas → Código de empresa* `miempresa` | `https://api.nori.mx` | `X-Tenant: miempresa` (y `tenant` en el login) |
| `192.168.1.10:8000` (desarrollo) | `http://192.168.1.10:8000` | opcional `X-Tenant` |
| `http://miempresa.localhost:8000` (desarrollo local, como en el navegador) | `http://127.0.0.1:8000` | `X-Tenant: miempresa` |

La lógica está en `lib/core/api/server_config.dart` (`ServerConfig.resolve`). El dominio raíz por omisión
(`nori.mx`) está en `ServerConfig.defaultRootDomain`.

Para desarrollo local con `php artisan serve`, usa la IP de tu máquina y el código de empresa en
*Opciones avanzadas* (el dominio central de `NORI_CENTRAL_DOMAINS` debe incluir esa IP o host). En Android,
HTTP sin TLS requiere `android:usesCleartextTraffic="true"` en el manifiesto de depuración.

Al cambiar de usuario o de empresa se borra la base local (catálogos, cola y respuestas guardadas).

## Arquitectura

```
lib/
  main.dart                    abre SQLite y preferencias, tema claro/oscuro con el acento de la empresa
  core/
    api/                       ApiClient (dio), sobre de errores (ApiException, AuthorizationChallenge), ServerConfig
    auth/session.dart          sesión de /auth/login y /me: permisos, almacén de trabajo, formas de pago
    db/local_db.dart           SQLite: records (catálogos), sync_state, outbox, kv (respuestas guardadas)
    sync/
      sync_engine.dart         pull delta por entidad (cursor, tombstones, reset) + push de la cola por lotes
      outbox.dart              operación encolada (llave UUID, método, ruta, cuerpo, estado, error)
      writer.dart              toda escritura: cola → intento en línea con la misma llave → cola si no hay red
    authorizations/            hoja "Requiere autorización": pedir a distancia (con espera) o aprobar en sitio
    design/                    tokens NrColors/NrSpace/NrRadius, tema Material 3, tipografía y componentes Nr*
    widgets/                   indicador de sincronización, escáner, buscadores de artículos y clientes, compartir PDF
    router.dart                go_router: redirecciones por sesión y pestañas según permisos
    providers.dart             Riverpod: AuthController, ApiClient, SyncEngine, Writer, tema
  features/
    auth/                      login, desbloqueo biométrico, almacén de trabajo
    route/                     mi ruta (lista y mapa OSM), visita (llegada/salida con GPS, venta, pedido,
                               entrega, recolección, mantenimiento con fotos, cobro, no venta, no visita)
    sales/                     carrito con precio del motor (en línea) o de lista guardada (sin señal)
    customers/                 cartera y cliente 360 (saldo, crédito, antigüedad, documentos abiertos)
    collections/               cobro contra facturas (más vencidas primero) o pago a cuenta
    inventory/                 solicitudes, traslados (surtir solicitud escaneando), entradas/salidas con
                               causalidad, conteo físico (cifra grande, progreso, deshacer)
    supervisor/                indicadores (KPIs) y bandeja de autorizaciones con sondeo y notificación local
    more/                      sincronización (cola, errores, catálogos), mis documentos, preferencias
```

Estado: Riverpod 2 (`Notifier`, `FutureProvider`). Navegación: go_router. Red: dio. Importes: `Dec`
(punto fijo sobre `BigInt`, `lib/core/util/decimal.dart`), nunca `double` para dinero.

### Sin señal

1. **Catálogos** (`GET /sync` decide cuáles): artículos, precios, existencias (almacén de trabajo y
   permitidos), clientes (`scope=mine` para vendedores), listas, formas de pago, almacenes, causalidades y
   motivos de visita. Se sigue el algoritmo de la API: `meta.reset` vacía la tabla, se aplican `deleted`
   antes que `data`, se sigue `next_cursor` y el `sync_token` se guarda solo al terminar.
2. **Cola**: cada escritura se guarda con un UUID generado cuando el usuario actúa. Se intenta en línea con
   ese `Idempotency-Key`; si no hay red (o 5xx/429) queda pendiente y se manda por `POST /sync/push` en
   lotes de 100, en orden. Las respuestas `ok` salen de la cola; las de validación/regla de negocio quedan
   con su mensaje en **Más → Sincronización** para reintentar o descartar; las que piden autorización
   permiten pedirla desde ahí y reenviar.
3. **Respuestas guardadas** (`kv`): ruta del día, visitas, cliente 360 y documentos abiertos, para
   consultarlos sin señal. Los cambios hechos sin señal (llegada, salida, no visita) se reflejan en lo
   guardado mientras la cola espera.
4. Sincroniza al entrar, cada 3 minutos y al recuperar conexión. La píldora de la barra superior muestra
   *Al día · Sin señal · N por enviar · N con error* y abre la cola.

### Autorizaciones

Si una escritura responde `422 authorization_required`, la app muestra la hoja de autorización:

- **Pedir a distancia**: `POST /authorizations {token, comment}` y consulta `GET /authorizations/{id}`
  cada 4 s hasta que se apruebe, rechace o venza.
- **Autorizar aquí**: usuario del supervisor + contraseña o PIN → `POST /authorizations/on-site`.

Aprobada, reenvía la misma operación con la **misma llave** y `authorizations: [id]` en el cuerpo (como las
pantallas web; las fallas no quedan guardadas en el servidor, así que la llave sigue libre).

El supervisor (`approvals.grant`) ve la bandeja en **Indicadores**, con número en la pestaña; se consulta
cada 20 s y las nuevas llegan como notificación local. Aprueba o rechaza (con motivo) con
`POST /authorizations/{id}/decide`.

### Permisos

Las pestañas y acciones salen de `/me.permissions` (Spatie, iguales que en la web): `route_execution.use`
(Hoy), `business_partners.view`/`sales_orders.create`/`quotations.create`/`incoming_payments.create`
(Clientes), `transfer_requests.*`, `inventory_transfers.create`, `goods_receipts.create`,
`goods_issues.create`, `inventory_counts.*` (Inventario), `approvals.grant` (bandeja). El servidor siempre
vuelve a verificar.

### Acento de la empresa

La web guarda el color en `company.accent_color` (ajustes de apariencia, `#2563eb` por omisión), pero la
API v1 **todavía no lo expone**. La app ya lo lee si llega como `tenant.accent_color` (o
`tenant.appearance.accent_color`) en `/auth/login`; mientras tanto usa `#2563EB`. Propuesta para nori-web:
agregar `accent_color` y `logo_url` al objeto `tenant` de `TokenSession` y a `/me`.

### Captura rápida

Más › Configuración › *Modo de captura rápida* (por equipo). La venta abre una libreta con un renglón
por artículo: lo cargado en el camión del día (`/route/plans/{id}/stock`) o, sin ruta, los favoritos
del equipo o lo más vendido por el usuario en 30 días (`/items/frequent`). Se teclea la cantidad y
"Siguiente" pasa al renglón de abajo; los ceros no van. Al continuar, las líneas entran al carrito
normal (precio del motor, cobro, guardado). Sin señal usa la carga y los precios guardados y descuenta
del camión guardado lo vendido. "Repetir último" toma lo último que se le vendió al cliente en este equipo.

### Impresión Bluetooth

Más › Impresora: buscar, elegir, papel de 58 u 80 mm, acentos, copias, logo, pie, código del folio
(QR o barras) e impresión automática por tipo. Formatos fijos en `lib/features/printing/templates.dart`
(venta, pedido, cotización, recibo de cobro, visita/no venta, liquidación y hoja de carga) que se
convierten a ESC/POS en `escpos.dart`. Reimprimir: Mis documentos y las confirmaciones de venta y cobro.

- Android: Bluetooth clásico (SPP, la impresora se empareja antes en Ajustes) con
  `print_bluetooth_thermal` y BLE con `flutter_blue_plus` (fijado en 1.x, licencia BSD).
- iOS: solo BLE. Las impresoras de solo Bluetooth clásico necesitan certificación MFi de Apple y no se
  pueden usar; la mayoría de las térmicas baratas de 58 mm son de modo dual y sí exponen BLE.
- Acentos: CP858 (`ESC t 19`) por omisión; CP850 si la impresora no tiene CP858; "Como imagen" pinta el
  texto en el teléfono y lo manda como mapa de bits cuando no hay página de códigos útil.
- El logo sale de la sesión (`company.logo`, data URI PNG/JPG); un SVG no se imprime.

## Pruebas

`test/core_test.dart`: decimales, resolución de servidor, sobre de errores, clasificación de resultados de
`/sync/push`, reparto de cobros, precio estimado sin señal, base local (sync con borrados y búsqueda por
código de barras) y cola. `test/widget_test.dart`: pestañas por permisos e indicador de sincronización.

## Pendiente

- Probar de punta a punta contra un nori-web real (login, sync, ruta, pedido, cobro, autorización): aquí
  solo se verificó con análisis estático y pruebas unitarias/widget.
- Fotos de visita sueltas (`/route/visits/{id}/photos`) y cola de fotos sin señal (hoy el mantenimiento
  con fotos pide señal).
- Cliente rápido sin señal con `$ref` en la cola (`POST /customers` + documento que lo use).
- Edición de borradores (`PATCH /documents/{id}`), factura/entrega con cobro (`tenders`) fuera de ruta,
  listado de cobros, correo con destinatarios elegidos.
- Paquetes/kits con opciones (`/items/{id}/package`, `choices`), unidades de medida por línea, descuentos
  manuales según la vista del usuario.
- Existencias en el buscador (por almacén) y stock del camión (`/route/plans/{plan}/stock`).
- Paradas no planeadas (`POST /route/plans/{plan}/visits` + `/route/customers`).
- Notificaciones push reales (FCM) en lugar del sondeo; tareas en segundo plano para enviar la cola con la
  app cerrada (WorkManager / BGTaskScheduler).
- Revocar dispositivos (`/auth/devices`), asistente (`/assistant/*`), catálogos de referencia (`/catalogs`).
- Íconos y pantalla de arranque con la marca de Nori; traducciones (`intl`/ARB) si se requiere otro idioma.
- Soporte web (ver arriba) y pruebas de integración con un servidor simulado.
