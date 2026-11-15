Yala
# Yala web beta: Panel, Registros, Bandeja, ajustes y «Navegadores conectados» en el iPhone
---
card: tablero-yala-web-beta-ver-tu-panel-y-apuntar-bor-4yc7
toca: webapp/, shared-core/, Yala/App/Views/ConnectedBrowsers/, Yala/Services/ConnectedBrowsers/, YalaTests/ConnectedBrowsers/, docs/web-app/, tickets/backlog/yala-web-lote-1-beta.md, tickets/done/yala-web-lote-1-beta.md
depende: Yala/yala-web-cimientos
esfuerzo: high
cierre: cierra-sola
---

Segundo lote de Yala web, sobre los cimientos del Lote 0 (ya mergeado). Sigue el Lote 1 de `docs/web-app/index.html` y las decisiones aprobadas por Jürgen (colección `decisiones` del artifact https://claude.ai/artifact/JN7jw8J1UXBQGNNpLNErAe).

Alcance del Lote 1 (beta, versión 2.3), solo para cuentas en la nube:
1. Panel, Registros y Bandeja en el navegador, leyendo con `shared-core/`, con el aspecto de la maqueta aprobada.
2. Apuntar un gasto desde la web: entra como borrador en la Bandeja y se confirma en la app.
3. Ajustes básicos de la web: cuenta, idioma y salir.
4. En el iPhone, una pantalla «Navegadores conectados» para ver las sesiones web abiertas y cerrarlas (vistas nuevas en `Yala/App/Views/ConnectedBrowsers/`). La entrada desde Ajustes es un cambio mínimo fuera de `toca:`: anótalo.
5. Español e inglés en la web.

Si el Services ID de Apple o el cliente web de Google todavía no existen (card `tablero-services-id-de-apple-y-cliente-web-de-go-zioy`), avanza con dobles y deja el inicio real pendiente en la card. No inventes credenciales. Los cambios en el servidor de producción son vitales y se preguntan según el modo.

**Pruebas:** web con tests y prueba de punta a punta en staging. Lo del iPhone, de punta a punta en el iPhone 14 por DeviceMCP (conectado a la Mini); si está ocupado, usa un segundo simulador. Tests nuevos de iOS en `YalaTests/ConnectedBrowsers/`. Tope de 30 minutos en pruebas de interfaz, y nunca más de 3 minutos sin escribir avance.

**Archivos:** puede correr en paralelo con otra sesión de Yala en la otra máquina, así que te quedas dentro de `toca:`. Si de verdad hace falta tocar algo fuera, que sea un cambio mínimo: lo anotas en «Decidido sin consultar» y rebasas sobre 2.3 antes del PR. Si hace falta un texto nuevo en el iPhone, añade solo las claves nuevas en los Localizable y anótalo.

**Entrega:** un PR contra 2.3, mergeado si CI pasa, el ticket en done y la card en QA. Commits y PR sin firma de IA. El resumen va como artifact visual de Claude. Lo menor y reversible lo decides y lo anotas en «Decidido sin consultar». Lo vital se pregunta según el modo de la sesión. Si el trabajo queda completo y el modo lo permite, cierra con `/cerrar-total`.

## Paso 0 — decisiones (resueltas en semi; la tabla completa con su porqué está en `tickets/*/yala-web-lote-1-beta.md`)

1. La web calcula con los `ToolCore` de `shared-core` tal cual (saldos, resumen, movimientos, categorías): sin cálculo nuevo.
2. La Bandeja se lee de `inbox_drafts` con el rol de solo lectura; `web1_01` (staging) le da SELECT sobre esa tabla.
3. «Apuntar» escribe en la cola común: `mail_drafts` del D1 del gateway de staging, montado en el Worker de la web, con `source: "web"`. Tope 30 al día. El gateway no cambia.
4. El iPhone lo recoge con la recogida de siempre, que también corre si hay sesiones web; entra con su cuenta y subcategoría, origen `.automation` y evidencia «Yala web".
5. Lista de sesiones: una clave del KV por sesión (`u:<cuenta>:<id>`) con navegador, ciudad aproximada y fechas.
6. «Cerrar» borra la sesión del KV y cierra su sesión de Supabase con `yala_web_close_session` (solo del cliente web y de la propia cuenta). La página pregunta `/api/me` cada 30 s.
7. El iPhone se identifica con el token de su sesión (role `authenticated`, sin `client_id`), sin App Attest.
8. La pantalla del iPhone solo sale en Yala Dev (web de staging), como fila dentro de «Tu cuenta de Yala».
9. Configurar en la web: cuenta, idioma, sesiones, ocultar montos y salir; el tema sigue al sistema.
10. Los secretos de staging se usan desde la Mini por `ssh`, sin copiarlos. Producción: nada.
