# Play Console: borradores de declaraciones

App: Nori (`software.nori.app`). Respuestas armadas leyendo el código de nori-mobile (pubspec, AndroidManifest, llamadas a la API) al 23 oct 2026. Todo lo marcado **[CONFIRMAR]** lo decide el dueño antes de enviar.

Contexto que pesa en casi todas las respuestas:

- La app no tiene registro. Las cuentas las crea el administrador de cada empresa en nori-web; el usuario entra con código de empresa, usuario y contraseña.
- La app habla solo con el servidor de Nori de la empresa (API v1). No usa Firebase, Crashlytics, Sentry, Analytics ni anuncios. La única excepción es ML Kit (lector de códigos de barras de Google, dentro de `mobile_scanner`), que manda diagnósticos de uso a Google; ver 2.1.1.
- El mapa usa teselas de OpenStreetMap (`flutter_map`): el teléfono descarga imágenes del mapa del servidor de teselas, que ve la IP y la zona que se consulta. **[CONFIRMAR]** si en producción se cambia a un proveedor propio o de pago; con las teselas públicas de OSM conviene revisar su política de uso para apps.
- Nori trata los datos por cuenta de la empresa cliente (encargado). La empresa es la responsable frente a sus empleados y clientes.

---

## 1. Seguridad de los datos (Data safety)

### Preguntas generales

| Pregunta | Respuesta |
|---|---|
| ¿La app recopila o comparte alguno de los tipos de datos requeridos? | **Sí** |
| ¿Todos los datos se encriptan en tránsito? | **Sí**, siempre que el servidor de producción sea HTTPS. Ver nota abajo. |
| ¿Ofreces una forma de que los usuarios pidan que se borren sus datos? | **Sí** (por correo y URL; ver sección 1.3). |
| ¿La app cumple con la política de familias? | No aplica (no está dirigida a niños). |
| Revisión de seguridad independiente | No |

Nota sobre cifrado: `ServerConfig.resolve` arma `https://<empresa>.nori.mx` para un código de empresa y también usa `https://` para cualquier dominio. Solo pone `http://` cuando escribes una IP o `localhost` (desarrollo local). No hay `networkSecurityConfig` ni `usesCleartextTraffic` en el manifiesto principal. Con eso, en producción todo va por TLS. **[CONFIRMAR]** que el servidor público solo responda en HTTPS.

### 1.1 Tipos de datos

"Recopilado" en Play significa que sale del teléfono hacia tu servidor. "Compartido" es enviarlo a un tercero; mandarlo al servidor propio de Nori (como proveedor de la empresa) no cuenta como compartir.

| Categoría Play | Tipo | ¿Recopilado? | ¿Compartido? | ¿Opcional? | Finalidad (Play) | De dónde sale en el código |
|---|---|---|---|---|---|---|
| Ubicación | Ubicación precisa (Precise location) | Sí | No | Sí (si niegas el permiso, la visita se registra sin coordenadas) | Funcionalidad de la app (App functionality) | `currentGps()` en `visit_page.dart`: una lectura al registrar llegada y salida de una visita de ruta. Se manda a `/route/visits/{id}/check-in` y `/check-out`; el servidor guarda lat/lng y calcula la distancia al cliente. No hay rastreo continuo ni en segundo plano. |
| Ubicación | Ubicación aproximada | Sí (el permiso COARSE viene con FINE) | No | Sí | Funcionalidad de la app | Mismo flujo. **[CONFIRMAR]** si Play exige declararla aparte; lo seguro es marcarla también. |
| Información personal | Nombre (Name) | Sí | No | No | Funcionalidad de la app; Administración de la cuenta (Account management) | Nombre del usuario (viene del servidor, se muestra en la app) y nombres de clientes que el usuario da de alta (`POST /customers`). |
| Información personal | Dirección de correo (Email address) | Sí | No | Sí | Funcionalidad de la app | Enviar un documento por correo al cliente (`POST {documento}/email`). El correo del usuario viene del servidor. |
| Información personal | Teléfono (Phone number) | Sí | No | Sí | Funcionalidad de la app | Teléfono del cliente al darlo de alta. |
| Información personal | ID de usuario (User IDs) | Sí | No | No | Administración de la cuenta | Usuario y código de empresa al iniciar sesión (`/auth/login`). |
| Información personal | Otra información (Other info) | Sí | No | Sí | Funcionalidad de la app | RFC del cliente (opcional al darlo de alta). |
| Información financiera | Historial de compras (Purchase history) | Sí | No | No | Funcionalidad de la app | Ventas, pedidos, facturas y cobros que captura el usuario (`/documents`, `/payments`). Son operaciones de la empresa con sus clientes. **[CONFIRMAR]**: algunos lo declaran como "Otra información financiera"; cualquiera de las dos es razonable. No se capturan números de tarjeta. |
| Información financiera | Otra información financiera | Sí | No | No | Funcionalidad de la app | Saldos, crédito y referencias de transferencia que el usuario escribe al cobrar. |
| Fotos y videos | Fotos (Photos) | Sí | No | Sí | Funcionalidad de la app | Fotos tomadas con la cámara en el servicio a un equipo del cliente (refrigerador, etc.), `asset-service` en `visit_actions.dart`. Solo cámara, no galería. |
| Mensajes / contenido | Otro contenido generado por el usuario (Other user-generated content) | Sí | No | Sí | Funcionalidad de la app | Notas de visita, comentarios en autorizaciones y, cuando salga, notas del CRM. Solo las ve la empresa. |
| Actividad en la app | Otras acciones en la app (Other actions) | Sí | No | No | Funcionalidad de la app | Registro de visitas, autorizaciones pedidas o decididas, conteos y traspasos de inventario. |
| Información y rendimiento de la app | Registros de fallas (Crash logs) | **No** | | | | No hay SDK de reportes de fallas. |
| Información y rendimiento de la app | Diagnósticos | **Sí [CONFIRMAR]** | No | No | Analíticas (de Google, por ML Kit) | Lo manda ML Kit, no Nori. Ver 2.1.1. |
| IDs de dispositivo u otros | Device or other IDs | **No** | | | | `device_info_plus` solo se usa para armar el nombre del token de sesión ("Samsung SM-A245M"): fabricante y modelo, sin IMEI, Android ID ni ID de publicidad. **[CONFIRMAR]**: es un texto descriptivo, no un identificador; si quieres ir a lo seguro, decláralo como "Device or other IDs" con finalidad "Administración de la cuenta". |

No se recopila: contactos, calendario, SMS, audio, archivos, historial web, salud, IDs de publicidad.

### 1.2 Prácticas de seguridad

- Cifrado en tránsito: Sí (HTTPS).
- Almacenamiento en el equipo: el token de sesión va en `flutter_secure_storage` (Keystore). El catálogo y la cola sin señal van en SQLite local, dentro del espacio privado de la app. Al cerrar sesión o entrar con otro usuario se borra la base local.
- Biometría: `local_auth` solo desbloquea la app en el teléfono; ninguna huella ni rostro sale del equipo.

### 1.3 Eliminación de cuenta y datos

Play pide una URL donde se pueda pedir el borrado de la cuenta, aunque la cuenta no se cree en la app.

- Propuesta de URL: `https://nori.software/eliminar-cuenta` **[CONFIRMAR: no existe; hay que crearla en nori-web]**. Puede ser una página corta que explique:
  1. Tu cuenta de Nori la administra tu empresa. Pide a tu administrador que la desactive o la borre.
  2. Si no puedes, escribe a hola@nori.software desde el correo de tu cuenta con el nombre de tu empresa; Nori lo pasa a la empresa y confirma por correo.
  3. Qué se borra (acceso, tokens de sesión, datos personales del usuario) y qué conserva la empresa por obligación fiscal (facturas, CFDI y movimientos contables, que en México se guardan 5 años según el CFF).
- Hoy nori-web no tiene borrado de usuario hecho por el propio usuario; el administrador desactiva usuarios. **[CONFIRMAR]** si el borrado de datos personales de un usuario desactivado está implementado o es manual.
- "¿Pueden pedir que se borren algunos datos sin borrar la cuenta?": Sí, por el mismo correo (derechos ARCO).

### 1.4 Aviso de privacidad

**[CONFIRMAR] Bloqueante.** `https://nori.software/privacy` (nori-web, `lang/es/privacy.php`) hoy solo cubre el sitio: formularios de contacto y demo. Para Play debe mencionar la app móvil:

- ubicación precisa al registrar llegada y salida de visitas (solo en ese momento, en primer plano);
- fabricante y modelo del teléfono para nombrar la sesión;
- fotos tomadas en servicios a equipos del cliente;
- datos de clientes de la empresa que captura el usuario (nombre, teléfono, RFC, correo);
- que Nori actúa como encargado de la empresa;
- teselas de mapa de OpenStreetMap;
- cómo pedir el borrado (sección 1.3).

Además, el sitio no está publicado: Play revisa que la URL abra.

---

## 2. Permisos de Android

### 2.1 Lista (de los manifiestos del proyecto y de los plugins)

Comprobada contra el manifiesto fusionado de un build de debug (23 oct 2026, mismo código y plugins). La de release sale igual menos lo que solo agrega debug (`INTERNET` ya viene en main). Los 14 permisos fusionados: `INTERNET`, `ACCESS_NETWORK_STATE`, `CAMERA`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `USE_BIOMETRIC`, `USE_FINGERPRINT`, `POST_NOTIFICATIONS`, `VIBRATE`, `BLUETOOTH` (maxSdk 30), `BLUETOOTH_ADMIN` (maxSdk 30), `BLUETOOTH_SCAN` (neverForLocation), `BLUETOOTH_CONNECT` y `software.nori.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` (interno de AndroidX, de firma; no se declara).

| Permiso | Origen | Para qué lo usa Nori | Texto de justificación (si Play lo pide) |
|---|---|---|---|
| `INTERNET` | app, print_bluetooth_thermal | Hablar con el servidor de Nori | No requiere declaración. |
| `ACCESS_NETWORK_STATE` | app, connectivity_plus | Saber si hay señal para mandar la cola pendiente | No requiere declaración. |
| `ACCESS_FINE_LOCATION` | app | Coordenadas al registrar llegada y salida de una visita | "Nori registra la ubicación del vendedor solo cuando toca Llegada o Salida en una visita de su ruta, para que la empresa compruebe que la visita se hizo en el domicilio del cliente. La app no rastrea en segundo plano." |
| `ACCESS_COARSE_LOCATION` | app | Requerido junto con FINE desde Android 12 | Mismo texto. |
| `CAMERA` | app, mobile_scanner | Escanear códigos de barras (checador, venta, inventario) y tomar fotos del servicio a equipos | "La cámara escanea códigos de barras de productos y toma fotos del servicio a equipos del cliente." |
| `USE_BIOMETRIC` | app, local_auth | Desbloquear la app con huella o rostro (opcional) | No requiere declaración. |
| `POST_NOTIFICATIONS` | app, flutter_local_notifications | Avisar al supervisor de autorizaciones nuevas | No requiere declaración (se pide en tiempo de ejecución). |
| `USE_FINGERPRINT` | local_auth | Versión antigua del permiso de huella (Android 9 o anterior) | No requiere declaración. |
| `VIBRATE` | flutter_local_notifications | Vibración de la notificación | No requiere declaración. |
| `BLUETOOTH` (maxSdk 30) | app, print_bluetooth_thermal | Impresora térmica en Android 11 o anterior | No requiere declaración. En el manifiesto fusionado queda con `maxSdkVersion=30` (gana el de la app). |
| `BLUETOOTH_ADMIN` (maxSdk 30) | app, print_bluetooth_thermal | Buscar impresoras en Android 11 o anterior | Igual que el anterior. |
| `BLUETOOTH_SCAN` (`neverForLocation`) | app, print_bluetooth_thermal | Buscar impresoras cercanas (Android 12+) | No requiere declaración. Con `neverForLocation` no se usa para ubicación. |
| `BLUETOOTH_CONNECT` | app, print_bluetooth_thermal | Conectarse a la impresora emparejada | No requiere declaración. |

`flutter_blue_plus` no agrega permisos (su manifiesto está vacío a propósito). `image_picker`, `share_plus` y `url_launcher` no agregan permisos peligrosos.

### 2.1.1 Servicios de Google dentro de la app (ML Kit)

El manifiesto fusionado trae servicios de `com.google.mlkit` y `com.google.android.datatransport`: son de **ML Kit Barcode Scanning**, que usa `mobile_scanner` para leer códigos de barras. Según la ficha de datos de Google para ML Kit, la biblioteca envía a Google métricas de uso y diagnóstico (rendimiento, errores de la API, modelo del equipo) para mejorar el servicio. **[CONFIRMAR]** En "Seguridad de los datos" conviene declarar *Diagnóstico* (Diagnostics) como recopilado por un SDK de terceros, finalidad "Analíticas" / "Funcionalidad de la app", no compartido para publicidad. Ver https://developers.google.com/ml-kit/android-data-disclosure antes de contestar.

### 2.2 Ubicación en segundo plano y servicios en primer plano

- **No hay `ACCESS_BACKGROUND_LOCATION`.** La ubicación se pide solo con la app abierta (una lectura por llegada o salida). En el formulario de permisos de ubicación, responder que la app **no** accede a la ubicación en segundo plano.
- **No hay `FOREGROUND_SERVICE` ni `FOREGROUND_SERVICE_LOCATION`.** El plugin `geolocator_android` declara un `<service android:foregroundServiceType="location">` en su manifiesto, pero la app nunca lo arranca y sin el permiso no puede correr. **[CONFIRMAR]** si la consola pide la declaración de "Foreground service types" al ver ese servicio en el manifiesto fusionado; si la pide, responder que no se usa, o quitar el servicio con `tools:node="remove"` en el manifiesto de la app (cambio de una línea, no lo hice).
- Cámara y Bluetooth no requieren formulario de permisos sensibles.

---

## 3. Clasificación de contenido (cuestionario IARC)

- Correo de contacto: hola@nori.software
- Categoría: **Todas las demás categorías de apps** (All other app types) / Utilidad, productividad, comunicación u otro. No es juego.

| Pregunta | Respuesta |
|---|---|
| Violencia | No |
| Miedo / horror | No |
| Contenido sexual o desnudos | No |
| Lenguaje soez | No |
| Drogas, alcohol, tabaco | No. **[CONFIRMAR]**: el catálogo de una empresa cliente puede incluir cerveza o cigarros como artículos a la venta, pero la app no promueve su consumo; la respuesta sigue siendo No. |
| Apuestas / juegos de azar simulados | No |
| ¿Los usuarios pueden interactuar o intercambiar contenido? (Users interact) | **No** con el público. Los mensajes (notas, comentarios de autorización) solo los ven usuarios de la misma empresa. Si la consola pregunta por "contenido generado por usuarios compartido", responder No. |
| ¿Comparte la ubicación del usuario con otros usuarios? | **[CONFIRMAR]** Sí, de forma limitada: el supervisor y la oficina de la misma empresa ven dónde se registró cada visita. Lo honesto es contestar **Sí**; suele dejar la clasificación igual en apps de empresa, pero puede subir la clasificación en algunas regiones. |
| ¿Permite compras digitales? | No |
| ¿Contiene anuncios? | No |
| ¿Es un navegador web o buscador? | No |

Resultado esperado: Todos / PEGI 3 / Clasificación A, o 12+ en algunas regiones si se marca que comparte ubicación.

---

## 4. Público objetivo y contenido

- Grupo de edad: **18 años o más** únicamente.
- ¿La app podría atraer a niños? No. Es una herramienta de trabajo para empleados con cuenta de empresa.
- No se incluye en "Diseñado para familias".

## 5. Anuncios

- ¿La app contiene anuncios? **No.**

## 6. Acceso a la app (instrucciones para el revisor)

Toda la app está detrás del inicio de sesión, así que hay que dar credenciales.

Propuesta:

- Elegir "Todas o algunas funciones están restringidas" y dar estos datos:
  - **Empresa:** la dirección del servidor público del demo, por ejemplo `demo.nori.software` **[CONFIRMAR: URL final]**.
  - **Usuario:** `revisor` (usuario dedicado del tenant demo "La Nogalera", empresa ficticia).
  - **Contraseña:** una fija para el revisor, que no expire y que no se use en otro lado. No ponerla en este archivo.
- Texto para la consola:

  > Nori es una app de trabajo para empleados de empresas que usan el sistema Nori. Las cuentas las crea el administrador de cada empresa; no hay registro en la app. Para revisar, usa la empresa de demostración "La Nogalera" (datos ficticios): en la primera pantalla escribe `demo.nori.software` en Empresa, toca Continuar y entra con el usuario y la contraseña de abajo. Puedes vender, cobrar, revisar clientes, el checador de precios, inventario y el tablero de supervisor. La impresión necesita una impresora térmica Bluetooth; sin impresora, la venta se guarda igual. La ruta del día puede estar vacía si el demo no tiene ruta asignada ese día.

Lo que falta para que esto funcione:

1. **[CONFIRMAR] Bloqueante: el servidor tiene que estar publicado** con el tenant demo accesible desde internet. `http://demo.localhost:8000` no le sirve a Google.
2. **[CONFIRMAR] Bloqueante: el dominio del código de empresa.** `ServerConfig.defaultRootDomain` es `nori.mx`, así que si alguien escribe solo `demo` la app va a `https://demo.nori.mx`. La marca y el sitio son `nori.software`. O se cambia esa constante en la app antes de publicar, o se confirma que `*.nori.mx` existe y apunta al servidor. Mientras, en las instrucciones conviene dar el dominio completo (con punto), que la app usa tal cual con `https://`.
3. Crear el usuario `revisor` en el demo del servidor publicado, con roles **Vendedor + Supervisor** (así ve venta, ruta, inventario, tablero y autorizaciones). En local ya existe uno igual en el tenant demo, creado para las capturas; su contraseña es aleatoria y no se publica.
4. **[CONFIRMAR]** Que `nori:demo-tenant --fresh` u otro proceso de limpieza del demo no borre o cambie al usuario `revisor`, y que el demo tenga una ruta asignada a ese usuario en días hábiles (el revisor puede abrir la app cualquier día). Si no, la pantalla Hoy sale vacía; no rompe la revisión, pero se ve pobre.
5. Si el servidor bloquea por número de dispositivos o asientos, dejar al usuario `revisor` sin límite.

## 7. Funciones de gobierno, financieras, salud y noticias

| Declaración | Respuesta | Nota |
|---|---|---|
| App gubernamental | No | |
| Funciones financieras (Financial features) | **No** | Nori registra ventas y cobros que la empresa hace a sus propios clientes (efectivo, transferencia, referencias) y emite CFDI a través del servidor de la empresa. No mueve dinero, no es banco, billetera, préstamo, inversión ni procesador de pagos, y no pide datos de tarjeta. **[CONFIRMAR]** si en el futuro se integra un cobro con terminal o link de pago; ahí habría que revisar esta respuesta. |
| Salud (Health apps) | No | |
| Noticias (News apps) | No | |
| COVID-19, rastreo de contactos | No | |
| ¿Usa la API de accesibilidad? | No | |
| ¿Es una VPN? | No | |

---

## Resumen de pendientes [CONFIRMAR]

1. Publicar nori.software con /privacy y ampliar el aviso de privacidad para cubrir la app (bloqueante).
2. Crear `https://nori.software/eliminar-cuenta` o definir otra URL de borrado (bloqueante para Data safety).
3. Servidor público con el tenant demo y usuario `revisor` (bloqueante para App access).
4. `defaultRootDomain = 'nori.mx'` frente a la marca `nori.software` (bloqueante si el revisor escribe solo el código).
5. Revisar el servicio de primer plano de geolocator en el manifiesto fusionado (el `maxSdkVersion` de Bluetooth ya quedó bien).
6. Si "ubicación compartida con otros usuarios" se responde Sí en IARC.
7. Si el nombre y modelo del teléfono se declaran como "Device or other IDs".
8. Teselas de OpenStreetMap en producción.
