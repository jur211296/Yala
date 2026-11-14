---
id: yala-web-lote-1-beta
status: done
priority: high
area: web
created: 2026-11-14
updated: 2026-11-14
source: encargo 2026-11-14-yala-web-beta (card tablero-yala-web-beta-ver-tu-panel-y-apuntar-bor-4yc7)
---
# Yala web, lote 1: la beta (mirar y apuntar)

Segundo lote de Yala web (plan en `docs/web-app/index.html`), sobre los cimientos del lote 0. Las 13 decisiones del
artifact siguen con la opción recomendada (la colección `decisiones` está vacía el 14-nov: medido con `ArtifactData`).
Las que mandan aquí: D1 (Panel, Registros, Bandeja en lectura y sesiones), D5 (cerrar desde el iPhone en este lote),
D8 (el servidor de la web lee con el rol de solo lectura), D9 (cola de borradores común) y D12 (español e inglés).

## Alcance

1. Panel, Registros y Bandeja en el navegador, con el aspecto de la maqueta aprobada.
2. Apuntar un gasto desde la web: entra como borrador en la Bandeja del iPhone, que lo confirma.
3. Configurar en la web: cuenta, idioma, sesiones web, ocultar montos y salir.
4. En el iPhone, «Navegadores conectados»: ver las sesiones web y cerrarlas.
5. Español e inglés en la web.

## Paso 0 — decisiones

Medido antes de decidir (14-nov, rama 2.3, staging):

- `shared-core/src/toolCore.ts` ya trae los cuatro cálculos que pide la beta (`listar_cuentas`, `resumen_periodo`,
  `buscar_movimientos`, `listar_categorias`), con paridad contra Swift probada en `mcp/test/golden.test.ts`.
- `yala_mcp_reader` lee 9 tablas (`qa/cloud/mcp0_01_readonly_role.sql`); `inbox_drafts` no está entre ellas.
- La cola de borradores del correo vive en el D1 del gateway (`mail_drafts`, `gateway/src/mail/store.ts`): el iPhone la
  recoge con `GET /mail/drafts`, la confirma con `ack`, caduca a los 30 días y `/account/delete` la borra. Solo la
  recoge si la persona preparó el correo del banco (`BankEmailSetupStore`).
- El gateway y la web comparten cuenta de Cloudflare: un Worker puede montar el D1 del otro.
- No hay forma de cerrar una sesión web a distancia: los tokens van cifrados con una clave que sale de la cookie.
- La app solo cierra su propia sesión de Supabase.
- `DraftSourceType` no tiene un origen «web», y añadirlo toca el modelo, cuatro `switch` exhaustivos y cinco tests.
- Esta sesión corre en la Max. Los secretos de staging (Supabase, Cloudflare, usuarios de prueba) están en la Mini.

| # | Pregunta | Decisión | Por qué |
|---|---|---|---|
| P1 | ¿Con qué calcula la web? | Llama a los `ToolCore` de `shared-core` tal cual, con el token de solo lectura de la sesión. `shared-core` no cambia. | R1. Mismas cifras que el conector y que la app, sin un cálculo nuevo que portar. |
| P2 | ¿Cómo lee la Bandeja? | `inbox_drafts` con `status_raw = pending`, con el mismo rol. `web1_01` le da SELECT sobre esa tabla (solo staging). | D1 pide la Bandeja en lectura. La política es la de las otras 9: solo las filas propias. |
| P3 | ¿Por dónde entra un gasto apuntado? | En la cola del correo (`mail_drafts` del D1 del gateway de staging), montada en el Worker de la web, con `source: "web"` en el payload. Tope: 30 al día por cuenta. | D9: la cola común. El gateway no cambia y la cola hereda el `ack`, la caducidad y el borrado de cuenta. |
| P4 | ¿Cómo lo recoge el iPhone? | La recogida de siempre (`BankEmailDraftService`) también corre si hay sesiones web. Lo de la web entra con su cuenta y su subcategoría por id, origen `.automation` y la línea de evidencia «Yala web». | Un origen nuevo es un cambio grande fuera de este lote. La web enseña «Yala web» en su Bandeja; la etiqueta propia en el iPhone queda en card. |
| P5 | ¿Cómo sabe el iPhone si hay sesiones web? | Pregunta a la web al volver a primer plano, como mucho cada 2 minutos, y guarda la respuesta. | Sin eso, cada teléfono en la nube preguntaría a la cola en cada vuelta. |
| P6 | ¿Dónde vive la lista de sesiones? | Un índice en el KV por cuenta (`u:<cuenta>:<id>`), con el navegador, la ciudad aproximada y las fechas en los metadatos. | KV no tiene escrituras atómicas: una clave por sesión evita perder una al entrar dos a la vez. |
| P7 | ¿Qué hace «Cerrar»? | Borra la sesión del KV y su entrada del índice, y cierra su sesión de Supabase con `yala_web_close_session` (función de `web1_01`: solo sesiones del cliente web y de la propia cuenta). | Con la sesión de Supabase cerrada, la pestaña abierta deja de valer al instante aunque el KV tarde en propagar el borrado. |
| P8 | ¿Cómo se vacía la pestaña cerrada? | La página pregunta `/api/me` cada 30 s y cada vez que vuelve a primer plano. | «Al cerrar, esa pestaña se vacía en menos de un minuto» (maqueta). |
| P9 | ¿Cómo se identifica el iPhone ante la web? | Con el token de su sesión de Supabase: firma por JWKS, `role = authenticated` y sin `client_id`. Sin App Attest. | Listar y cerrar sesiones propias es de bajo riesgo, y cerrar protege. Un token de la web o del conector no sirve. |
| P10 | ¿En qué builds sale la pantalla del iPhone? | Solo en Yala Dev, que apunta a la web de staging. Producción no tiene web todavía. | Una fila que abre una web que no existe sería un error. |
| P11 | ¿Dónde está la entrada del iPhone? | Una fila «Navegadores conectados» dentro de «Tu cuenta de Yala». | La sesión web es de la cuenta. Así no hace falta un destino nuevo en Ajustes, que pide tocar varios `switch`. |
| P12 | ¿Qué trae Configurar de la web? | Cuenta (nombre y correo), idioma, sesiones web (cerrar las demás), ocultar montos al abrir y salir. El tema sigue al sistema. | Lo del encargo más lo que la maqueta ya enseña en lote 1. Elegir tema no aporta con el del sistema. |
| P13 | ¿Cómo se usan los secretos de la Mini? | Por `ssh mini`, sin copiarlos: despliegue con su `wrangler`, SQL con su llave de la Management API y e2e con sus usuarios de prueba. | Son accesos ya autorizados para staging. Moverlos de máquina sería otra decisión. |

Cambios en Supabase **staging** (`webapp/supabase/web1_01_bandeja_y_sesiones.sql`, con marcha atrás): SELECT de
`inbox_drafts` para `yala_mcp_reader`, la función `yala_web_close_session` y el barrido diario de sesiones huérfanas
del cliente web. **Producción: nada.**

Fuera de `toca:`, mínimo y anotado: `Yala/App/Views/Profile/YalaAccountView.swift` (la fila),
`Yala/App/Services/BankEmailDraftService.swift` y `Yala/Services/BankEmail/BankEmailClient.swift` (recoger lo de la web),
`Yala/App/AppBootstrapper.swift` (preguntar por sesiones web antes de recoger), las claves nuevas en los 16 Localizable y
`qa/coverage-index.json`.

## Fuera de este lote

- Origen propio «Yala web» en la Bandeja del iPhone (hoy sale como «Automatización», con «Yala web» en la evidencia).
- Cerrar sesión en el iPhone no cierra las sesiones web (borrar la cuenta sí: se van con la cuenta).
- La política de privacidad tiene que nombrar la web: sesión, navegador y ciudad aproximada.
- El widget real de Turnstile y producción, como en el lote 0.

## Resultado (14-nov)

- **Web** (`webapp/`), desplegada en <https://yala-web-staging.misty-surf-6866.workers.dev>: Panel (saldo total, entradas
  y salidas del mes, cuentas, últimos registros y en qué se gastó), Registros (por días, de 50 en 50, con mes, cuenta,
  categoría y búsqueda, y el detalle), Bandeja (lo pendiente en el iPhone y lo enviado que aún no recogió), «Apuntar»
  (gasto o ingreso, con categoría, cuenta y fecha) y Configurar (cuenta, sesiones web, ocultar montos al abrir, idioma,
  salir). Español e inglés, escritorio y móvil, claro y oscuro.
- **Cola común**: lo apuntado entra en `mail_drafts` del D1 del gateway de staging con `source: "web"`. El gateway no
  cambió.
- **Sesiones**: Durable Object por cuenta (`SessionIndex`). Primero se probó con un índice en el KV y el e2e de staging lo
  tumbó: el `list` del KV tardaba en ver una sesión recién abierta, así que «cerrar todas» no la cerraba.
- **iPhone**: «Navegadores conectados» en Ajustes › Tu cuenta de Yala (solo Yala Dev), y la recogida de borradores
  también con sesiones web. Textos en los 16 idiomas.
- **Supabase staging**: `web1_01` aplicado (SELECT de `inbox_drafts`, `yala_web_close_session`, barrido diario).
- **Revisión de seguridad independiente**: sin fugas entre cuentas ni CSRF. Cazó diez defectos, todos arreglados: el
  alto, una sesión cerrada que podía «resucitar» fuera de la lista si fallaba el cierre en Supabase (ahora la lista manda
  en cada petición); además, sesiones del lote 0 sin id, el conector podía usar la función de cierre, la Bandeja daba al
  rol de lectura columnas que no usa (`raw_text`), lo apuntado en un equipo compartido podía no llegar al iPhone (ahora
  recoge 30 días tras la última sesión web), el tope diario se vaciaba con el `ack`, tokens de la app ya cerrados,
  validación del borrador, subcategoría oculta o del tipo contrario, y borradores caducados como «esperando».
- **Pruebas**: 70 unitarias de la web; e2e contra staging 14/14 (también tras los arreglos) (las 9 del lote 0 y 5 nuevas: mirar, saldos contra las
  filas, apuntar y que B no lo vea, cerrar desde otra pestaña y cerrar todas desde el token de la app). iOS: 60 casos en
  12 suites (las 4 nuevas de `YalaTests/ConnectedBrowsers/`, las del correo del banco y la paridad de traducciones).
  Recorrido visual de «Navegadores conectados» en el simulador con la web de mentira (`-uitest-connected-browsers-demo`).

## Guion de prueba en el iPhone 14 (device-QA)

Lo que no se automatiza: entrar con Apple (Face ID) en el iPhone y en la web.

1. En el iPhone 14, abre **Yala Dev** y toca «Entrar con Apple» con tu cuenta que tiene la nube en staging.
2. En el Mac (o en Safari del mismo iPhone), abre <https://yala-web-staging.misty-surf-6866.workers.dev> y toca
   «Continuar con Apple» con la misma cuenta. Tiene que salir tu **Panel** con los mismos saldos que en el iPhone.
3. En la web, toca **«+ Apuntar»**: 12,50, «Prueba web», una categoría y una cuenta. «Enviar a la Bandeja». En la Bandeja
   de la web sale en «Enviado, esperando a tu iPhone».
4. En el iPhone, manda Yala Dev a segundo plano y vuelve a abrirla (o espera hasta 2 minutos). En la **Bandeja** tiene
   que estar «Prueba web» con esa categoría y esa cuenta, y en su detalle la línea «Yala web». Apruébalo: entra en tus
   saldos, y en la Bandeja de la web desaparece de «Enviado».
5. En el iPhone: Ajustes › Tu cuenta de Yala › **Navegadores conectados**. Tiene que salir el navegador del paso 2
   («Chrome en Mac», con la ciudad y «ahora»).
6. Toca **«Cerrar»** en esa sesión. En menos de un minuto, la pestaña de la web vuelve a la pantalla de entrar con
   «Esta sesión se cerró desde otro aparato».
