# QA en el iPhone físico de Jürgen con Device MCP: guiarlo paso a paso
toca: Device MCP, qa/device-fisico, videos de dispositivo; sin YalaUITests ni .github/workflows

Jürgen pidió ahora (16:55 Lima) lanzar en la Max. Tiene el móvil a la mano y quiere que la sesión arranque y lo guíe. Corre en paralelo con el lote-t3 de XCUITest en la Mini: no toques YalaUITests ni esos tickets.

Base: origin/2.2 en jur211296/Yala, después del barrido de QA final (PR #813). Una sola sesión, un cierre. Máquina: Max.

## Qué se pide
1. Instala Device MCP (versión gratis) en la Max si falta: https://devicemcp.ai — y agrégalo a Claude Code con `claude mcp add --scope user device-mcp -- "/Applications/Device MCP.app/Contents/MacOS/device-mcp"`.
2. Verifica que el iPhone de Jürgen esté conectado a la Max (USB o red), confiado y con Modo de desarrollador. Si no está, pídele por `preguntar-bot` que lo conecte a la Max y confirme.
3. Guía a Jürgen por el chat (vía Frank / preguntar-bot): cada paso del guion en lenguaje claro; no asumas clics. Si pide Face ID o código, detente y avísale.
4. Corre en el iPhone real cada guion de las cards 2.2 en «in qa» que dependan de dispositivo físico: widgets, Siri, Live Activities, voz, cámara y Duo. Incluye el guion pendiente del 30-oct: unirse a un grupo con dos aparatos, iCloud real, barra de abajo personalizada y compra sandbox (~50 min).
5. Graba un video por guion. Si pasa: nota «verificado en dispositivo» en la card. Si falla: arreglo chico en este PR o card de bug en 2.2.
6. Termina con tabla de resultados + videos y /cerrar-total.

## Qué NO tocar
marketing/, App Store Connect salvo lo del guion, YalaUITests/, .github/workflows/, force-push, la Mini.

## Cómo se sabe que está bien
Tabla de resultados, videos, cards actualizadas, /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué guiones entran?** → Los 4 montajes del 30-oct, 8 cards: A (`046l`, `7xnd`, `ywm1`), B (`ppxk`, `n5zw`, `7e60`), C (`fozu`), D (`7c97`).
Por qué: medido en el tablero (17:00) y en la tanda del barrido final del 5-nov: de las cards 2.2 en «in qa», ninguna de widgets, Live Activities, voz, cámara o Duo queda retenida por el iPhone físico («Para tu iPhone: 0 nuevas»). `laik` (Siri gratis) es una decisión, no un guion. Alternativa descartada: re-probar widgets/Siri/voz a ciegas — no hay card que lo pida y el encargo dice «que dependan de dispositivo físico».

**D2 · Build** → Yala Dev, configuración `Debug-Dev`, desde esta base (`origin/2.2` en el merge de #809), firmado para su iPhone.
Por qué: los guiones piden Yala Dev contra staging. El barrido final (#813) sigue abierto y no toca estas 8 cards.

**D3 · Orden** → C, B2, B1, B3, D y A al final.
Por qué: A pide borrar Yala Dev del iPhone y reinstalarla; B necesita los datos que hay. De lo corto a lo largo.

**D4 · Montaje A necesita un segundo aparato y otra cuenta** → se pregunta a Jürgen (iPad propio o el simulador del iPad en la Max contra staging); no se da por resuelto.
Por qué: es una decisión de acceso (cuentas reales), no técnica.

**D5 · Vídeos** → uno por guion con la grabación de Device MCP; si la versión gratis no graba, la grabación de pantalla de iOS que Jürgen pasa por AirDrop. Van a `~/Claude/entregas/2026-11-05-qa-dispositivo-fisico-device-mcp/evidencia/`.

**D6 · Lo que pida su pantalla** (Confiar, Face ID, código, permisos y servidor MCP de Device MCP) → lo da Jürgen; se anota y se espera, sin scriptear la UI de Device MCP.

**D7 · Si un guion falla** → arreglo en este PR solo si es de una línea y con test; si no, card de bug 2.2 con el vídeo.

**D8 · Entrega** → worktree: rama + PR. Si al final el diff es solo `docs/`/`tickets/`, va igualmente en el PR del cierre para que el parte quede en su cuerpo.

**D4 resuelta por Jürgen (17:2x):** quien invita = simulador del iPad en la Max con su cuenta de siempre. La segunda cuenta sin grupos para el iPhone llega «más tarde»: el montaje A queda en espera, no saltado.
**Cuentas del montaje A (Jürgen, 17:2x):** iPad = Google `admin@yala-app.pe` (invita y crea «Depa Miraflores»); iPhone = Google `jur211296@gmail.com` (se une). Sin medir si esta última tiene grupos en staging: en la tanda TF20 de 2.1 se unió a «QA unión 20».
**Staging limpio (Jürgen, 17:3x):** antes del montaje A se limpia staging y se dejan las cuentas sin datos, para empezar de cero. Mismas cuentas: iPad `admin@yala-app.pe`, iPhone `jur211296@gmail.com`. Desde la Max no hay acceso a staging: la limpieza llega por instrucciones del bot.
**Staging medido por el bot (conector de Supabase, 17:4x):** las dos cuentas con 0 membresías, 0 grupos propios vivos y 0 invitaciones abiertas. El SQL de limpieza no se corre. Medido por el bot, no desde la Max.
**Aparato (Jürgen, 17:5x):** las pruebas van en el **iPhone 14** por cable («iPhone de JURGEN»), no en su iPhone 18 Pro Max. Instalé Yala Dev en el 18 por error (sin abrir más que el arranque).
