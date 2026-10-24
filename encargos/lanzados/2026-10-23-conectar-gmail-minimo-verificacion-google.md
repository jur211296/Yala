---
release: no
---
# Conectar Gmail mínimo, en el simulador, para grabar el video y pedir la verificación de Google

## Contexto
Roadmap de Yala (docs/ROADMAP.md, 2.3, «Correo del banco»): leer Gmail (`gmail.readonly`) es un permiso restringido. Google exige verificación de la app, con un video de demostración que muestre la pantalla de consentimiento REAL (client ID del proyecto `yala-502622`, número 295312853864), y una auditoría de seguridad anual (CASA). Jürgen quiere pedirla ya para que no frene 2.3.
La app ya integra GoogleSignIn-iOS con `GID_CLIENT_ID` de ese proyecto (ver `Yala.xcodeproj/project.pbxproj`). En la Mini, `gcloud` está autenticado como jur211296@gmail.com (proyecto por defecto: sat-lab-correo; usa siempre `--project yala-502622`). La API de Gmail está APAGADA en yala-502622.
No hay rama 2.3: trabaja sobre `origin/2.2` en tu worktree y deja el PR ABIERTO y SIN mergear (modo «cierras tú»); esto es de 2.3 y no debe entrar en la release 2.2. Todo detrás de un flag de desarrollo que no se vea en producción.
Dependencias: arranca sobre la rama base sin esperar CI ni merges; justo antes de abrir el PR, `git fetch` y un rebase sobre origin/2.2, y build/simulador una vez después.

## Qué se pide
Fase 1, lo mínimo para el video:
1. Activa la API de Gmail en yala-502622 con gcloud.
2. En la app (build de desarrollo, simulador): un punto de entrada «Conectar Gmail» que pide `gmail.readonly` con el login real de Google (añadiendo el scope a GoogleSignIn), lee los correos de alerta del banco del usuario (ej. remitente notificaciones@notificacionesbcp.com.pe) y convierte al menos uno en un borrador en la Bandeja de Yala. Para el video basta hacerlo en el dispositivo; deja anotado en el PR que la versión final va por el servidor (cuenta en la nube) según el roadmap.
3. Si el punto de entrada requiere diseño de UI sin decidir, haz lo más simple posible y deja propuestas; no inventes un diseño final.
Fase 2, el paquete de la solicitud (en `docs/verificacion-google/`):
- Justificación del scope en español y en inglés (Google la lee en inglés; es el único texto en inglés permitido, porque va a Google).
- Cambios propuestos a la política de privacidad y términos de yala-app.pe para cumplir la Google API Services User Data Policy (Limited Use). NO los publiques: déjalos como propuesta para Jürgen.
- Guion del video escena por escena.
- Checklist exacta de la consola (Google Auth Platform: agregar scope gmail.readonly, usuario de prueba jur211296@gmail.com, dominios autorizados, enviar a verificación), indicando qué ya está hecho. Frank hará los clics en la consola: no hace falta que Jürgen los haga.
Antes de diseñar, mira `~/Claude/referencias-ui/README.md` y usa lo que aplique como inspiración (no copies marcas ni pantallas).

## Qué NO hay que tocar
- No mergees el PR. No despliegues nada a producción ni toques la web publicada.
- No toques en ~/Yala el `Yala.xcscheme` sin commitear, `encargos/pendientes/` ni los `.ckdb` de CloudKit.
- No uses la palabra «OpenAI» en textos de la app.
- No toques las tmux `salud--…`, `sat-lab--…` ni `clinicas-dentales-bi--…`.
- No imprimas secretos ni tokens.
- Simulador solamente, nunca dispositivos reales.

## Pipeline serial (build + simulador)
1) limpiar (sims muertos, DerivedData y cachés de worktrees cerrados), 2) build con `xcodebuild -jobs 2` sin sim booteado, 3) bootear un solo sim (iPhone 17 Pro), 4) probar, 5) apagar y borrar ese sim. Prohibido solapar build, sim y UITests.

## Cómo se sabe que está bien
- En el simulador, «Conectar Gmail» abre la pantalla real de consentimiento de Google del proyecto Yala, y tras aceptar con una cuenta de prueba aparece en la Bandeja un borrador sacado de un correo del banco (si el login real no se puede completar sin Jürgen, deja todo listo y di exactamente qué falta).
- `docs/verificacion-google/` tiene justificación, propuesta de política, guion y checklist.
- PR abierto contra 2.2, sin mergear, con capturas en `capturas/` si hay cambio visible.
- Al terminar, cierra con /cerrar-total sin mergear el PR (deja el pendiente para Jürgen).

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Dónde vive «Conectar Gmail»?** → Un botón con sobre en la barra de la **Bandeja**, solo en `DEV_BUILD`, que abre una hoja simple: qué se lee, qué no, y «Continuar con Google».
Por qué: el video tiene que enseñar el permiso y su uso en el mismo hilo, y el borrador cae en la Bandeja. Alternativa descartada: el panel DEBUG de Almacenamiento (se lee «Panel DEBUG», mal para el revisor de Google y no está junto a donde aparece el resultado).

**D2 · ¿Cómo se pide `gmail.readonly`?** → `GIDSignIn.signIn(withPresenting:hint:additionalScopes:)` con el scope, aparte del inicio de sesión de la nube. El token no se guarda en Yala: lo custodia el SDK.
Por qué: es el consentimiento real del proyecto `yala-502622` y no toca el canje con Supabase. Alternativa descartada: `addScopes` sobre el usuario de la nube (no existe si la cuenta es de Apple o iCloud).

**D3 · ¿Cómo se convierte el correo en borrador?** → En el dispositivo, sin IA: un lector determinista de los avisos del BCP (importe, divisa, comercio, fecha), tolerante; si no saca importe, el borrador sale igual con el asunto y pide el importe. Origen `.emailAlert`, que ya existe con su icono y su nombre.
Por qué: lo mínimo para el video; la versión final va por el servidor (roadmap 2.3). Alternativa descartada: mandar el correo al gateway con IA (es la arquitectura final, y exige la política Limited Use publicada).

**D4 · ¿Cómo no duplicar al pulsar dos veces?** → El id del mensaje de Gmail viaja en `evidence` (`gmail:<id>`) y se salta si ya hay un borrador con esa marca.
Por qué: sin campo nuevo en el `@Model` (un campo nuevo es schema de CloudKit). Alternativa descartada: un `UserDefaults` propio.

**D5 · Textos** → En español, escritos a mano y dentro de `#if DEV_BUILD` (molde `CloudSyncDebugView`), fuera del pipeline de l10n. Las claves de verdad llegan con la versión final.
Por qué: no se ve en producción y no hay copy decidido. Alternativa descartada: 16 idiomas para una pantalla provisional.

**D6 · Idioma del video** → La app en español; la pantalla de Google con el selector de idioma (abajo a la izquierda) en **English**, que es lo que Google exige. En iOS nativo no hace falta enseñar el client ID en la barra.
Por qué: requisito medido en la ayuda de Google (answer 13804565).

**D7 · Consola de Google** → Hago yo, desde Chrome, lo que no depende del video: añadir `gmail.readonly` al acceso a datos, el usuario de prueba y revisar dominios. **No envío a verificación**: pide el video subido y la política publicada, y las dos cosas son de Jürgen.
Por qué: enviar sin video ni política se rechaza y gasta la ronda.

**D8 · Referencias de UI** → `~/Claude/referencias-ui/` no trae nada de permisos ni conexión de cuentas; la hoja sigue el molde de las del repo (icono, titular, viñetas, un botón). Queda una propuesta de diseño final en el PR.

**D9 · Entrega** → PR contra `2.2`, abierto y **sin auto-merge**: es de 2.3 y no entra en la release 2.2.

**D7 bis · Medido en la consola después de decidir D7** → La app de OAuth está **en producción**. La lista de usuarios de prueba solo existe en modo «Prueba», así que el usuario de prueba del encargo no aplica, y **no se vuelve a modo prueba**: cortaría el inicio de sesión con Google a los usuarios reales. Además, Google no deja pedir la verificación de Gmail sin la **marca verificada**, y eso exige el dominio verificado en Search Console. Queda en la checklist.
