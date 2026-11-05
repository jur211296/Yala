# Correo del banco por reenvío: dirección propia, guía, Bandeja y política de privacidad
toca: correo/inbox del banco (gateway de ingestión de correos, guía de reenvío en la app, Bandeja), y la política de privacidad de la web (`Web/` páginas de privacidad). No toques `MigrationRunner.swift` ni `mcp/`

Rama base: 2.3. Un solo PR contra 2.3, un solo cierre. Máquina: la Mini, con simulador.
Ola 2 de la 2.3 (sesión S2 de `docs/planning/cola-2-3-propuesta.md`). En paralelo corren Activar la nube (N2: `MigrationRunner.swift` / `MigrationWorkExecutor.swift`, en la Max) y Conectores ola 2 (S4: `mcp/` y conectores, sin simulador). Por esa separación de ficheros las tres pueden ir a la vez. **Espera a que S1 (control del coste de la IA) esté mergeada antes de tocar rutas de IA del gateway**: el correo llama a la IA y el roadmap pide el tope de coste primero. Si S1 aún no entró, no empieces la parte de lectura con IA; prepara buzón, guía y política, y pregunta.

Objetivo: que cada persona reenvíe las alertas de su banco a una dirección de Yala, que el movimiento llegue a la Bandeja por confirmar, y que la política de privacidad ya diga que el correo pasa por el servidor.

Decisiones de Jürgen ya cerradas (2026-11-04). No las preguntes otra vez:
- Dirección: `auto@yala-app.pe` con código único por persona (`auto+código@yala-app.pe`). Jürgen activa el dominio y el buzón.
- Cupo de prueba gratis: 5 correos leídos.
- Bancos: todos los de Perú desde el inicio.
- Política de privacidad: card en la web de 2.3; cuando salga el release de 1.0, esa misma página pasa a 1.0.
- Gasto de Cloudflare: esta sesión lo estima, propone un tope y se lo muestra a Jürgen. Nada de desplegar sin su OK.

Cards del tablero de Yala (abiertas):

1. «Registrar movimientos desde correos de alertas del banco». Cada persona tiene su dirección, reenvía con un filtro de su correo (Gmail, Outlook o iCloud Mail), la app trae la guía paso a paso y recoge el código con el que Gmail confirma la dirección. El gateway lee el correo con IA y el movimiento llega a la Bandeja. Exige cuenta en la nube. Es Pro, con el cupo de prueba de arriba. Criterio de salida del roadmap: con alertas de un banco peruano, al menos el 90 % de los movimientos de una semana llegan bien (cuenta y divisa, también dólares).
2. «Política de privacidad al día para el correo del banco (web 2.3, pasa a 1.0 al release)». Actualiza las páginas de privacidad de la web para el reenvío de correos. Sale en la web de 2.3; el paso a 1.0 es al release, no en este PR.

Hecha cuando: una persona con cuenta en la nube ve su dirección `auto+…@yala-app.pe`, completa la guía, reenvía una alerta de un banco peruano y el borrador aparece en la Bandeja; el cupo de 5 correos de prueba se respeta; la política de la web describe el correo; la estimación de Cloudflare está en el cierre para el OK de Jürgen; los tickets pasan a `tickets/done`, hay tests (unitarios o XCUITest de la guía/Bandeja) en verde y `/gate` pasa. El cierre trae un guion corto de prueba.

Restricciones:
- Usa el simulador solo cuando haga falta (guía y Bandeja), pidiendo turno como siempre.
- No toques `MigrationRunner.swift`, `MigrationWorkExecutor.swift`, ni `mcp/`.
- No toques `gateway/src/ai/` hasta que S1 esté mergeada; si el correo necesita cambios ahí y S1 sigue viva, para y pregunta.
- Nada de despliegues a producción (Workers, Email Routing, DNS) sin el OK de Jürgen. Staging sí, si hace falta para medir.
- PREGUNTAR, NO SALTAR: si alguna duda bloquea o cambia el resultado, pregunta con `preguntar-bot "pregunta con opciones"`. No asumas ni te saltes nada.

Mueve las cards con `tablero`: en curso al empezar e in qa al cerrar.
El cierre trae la sección «Saltado o asumido sin preguntar».
Cierra sola: termina con /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR. La de la IA la contestó Jürgen (vía el bot, 2026-11-04 21:40).

**D1 · ¿La lectura con IA espera al control del coste (S1)?** → No. Opción B de Jürgen: módulo propio `gateway/src/mail/`, fuera de `gateway/src/ai/`, que llama al adaptador de OpenAI existente con su propio tope de tokens (entrada recortada a 6.000 caracteres, salida a 400 tokens). Al rebasar sobre S1 se cambia por su tope y su registro de uso.
Por qué: S1 sigue esperando una decisión y no entra hoy. Alternativa descartada: esperar (bloquea la ola) o dejar la IA fuera (el correo no serviría).

**D2 · ¿Cómo llega el movimiento del servidor a la Bandeja?** → El Worker guarda el movimiento leído en una cola propia en D1 y la app la recoge (`GET /mail/drafts`), crea el borrador local y confirma (`POST /mail/drafts/ack`). El borrador sincroniza después como cualquier otro.
Por qué: el servidor no escribe en los datos de la nube de la persona sin su sesión (HLC, `server_seq`, conflictos); hacerlo exigiría un rol de máquina nuevo en Supabase. Alternativa descartada: insertar en `inbox_drafts` con un rol propio.

**D3 · ¿Qué se guarda del correo?** → Nada del correo: solo el movimiento (importe, divisa, comercio, fecha, banco, 4 últimos dígitos), hasta que la app lo recoge o 30 días. Del aviso de Gmail, solo el código.
Por qué: es lo mínimo que hace falta y lo que la política puede prometer.

**D4 · ¿Qué cuenta contra el cupo de 5?** → Cada correo que la IA lee sin Pro, sea o no un movimiento. Un fallo del proveedor (5xx, red) devuelve el uso. El código de Gmail no gasta. Con el cupo agotado el correo no se lee y se cuenta aparte para que la app lo diga.
Por qué: «5 correos leídos» literal, y así el cupo acota el coste.

**D5 · ¿Pro se decide cómo?** → Por la cuenta (`account_entitlements`, la misma tabla que `/account/entitlement`).
Por qué: el correo llega sin dispositivo; la cuenta es lo único que hay.

**D6 · ¿Qué guard llevan las rutas nuevas?** → `requireUserAndAttest`, como `/sync/*`: son datos financieros personales. La app las llama con `AttestSessionProvider.live`.

**D7 · ¿Dónde vive la guía en la app y para quién sale?** → Fila «Correo del banco» en Ajustes, junto a «Siri y Atajos», solo con los datos en la nube y sesión. Dentro, la dirección, el cupo y una guía por pasos (`YalaStepGuide`) por cada correo: Gmail, Outlook e iCloud Mail. El código de Gmail aparece en el paso que lo pide.
Por qué: exige cuenta en la nube; a quien no la tiene no se le ofrece algo que no puede usar. Alternativa descartada: enseñarla a todos con «activa la nube» (no hay copy decidido para ese camino).

**D8 · ¿Qué cuenta elige el borrador?** → La que nombra el aviso (banco + 4 dígitos) por la lógica de medio de pago que ya existe; si no, la única cuenta en esa divisa; si no, ninguna y la Bandeja la pide.

**D9 · Antiabuso** → Techo de 50 correos por dirección y día; el mismo aviso (mismo Message-ID) se lee una vez; correo de más de 256 KB se rechaza.

**D10 · Despliegue** → Nada a producción. La estimación de Cloudflare y el tope propuesto van en el cierre para el OK de Jürgen. Staging no se despliega: sin el buzón activado no hay correo que medir.

**D11 · El criterio del 90 %** → No se puede medir sin una semana de avisos reales; queda como paso de Jürgen tras activar el buzón, con un banco de fixtures sintéticos de los bancos peruanos en los tests.
