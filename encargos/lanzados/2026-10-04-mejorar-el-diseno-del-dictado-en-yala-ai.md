# Mejorar el diseño del dictado en Yala AI

## Contexto
Card del tablero: `tablero-mejorar-el-diseno-del-dictado-en-yala-ai-apsc` (backlog → in progress, asignada a frank, medium, deadline 2026-10-03). Versión 2.1. Jürgen 2026-10-03: esta noche y el domingo se ataca todo el diseño posible antes del QA del lunes. El dictado se ve pobre. Cola: va después de las cards de registro nuevo (PR #347/#348/#349 ya hechos o en cola). Siguiente en cola tras esto: registro por voz → registro por imagen → vistas del registro en grupos → barrido QA → TestFlight.

## Que se pide
Mejorar el diseño del control de dictado y del estado mientras se dicta en Yala AI, para que se sienta claro y de producto, no pobre.

Si el diseño no está cerrado: deja 2–3 propuestas concretas (con capturas si puedes), mueve la card a blocked o déjala esperando decisión, y PARA preguntando a Jürgen cuál elige. No inventes la decisión ni implementes a ciegas una opción ambigua.

Si el diseño ya está claro en el código/referencia o Jürgen ya eligió en conversación previa de esta sesión: implementa, prueba, abre PR a 2.1 con auto-merge cuando toque, ticket a qa con guion device-QA si hay cambio visible, capturas antes/después, y cierra con /cerrar-total.

## Que NO hay que tocar
- No tocar revisión de uso de IA / modelos / coste, ni partir nube/privado, ni «Yala AI haga más que crear registros», ni respuesta por voz ni mascota (eso es 2.2, no se lanza antes del QA).
- No reabrir el formulario de cuenta (#341) ni el detent medium de selectores de registro nuevo (#349) salvo que el dictado los use mal y haya que acoplarse.
- No CloudAgent. Pipeline serial Mini: limpiar → build xcodebuild -jobs 2 sin sim → boot 1 sim → tests → apagar/limpiar. Norma 1 sim.

## Como se sabe que esta bien
- El dictado en Yala AI se ve y se entiende mejor (control + estado mientras dicta).
- Si hubo decisión de diseño: quedó documentada y aplicada.
- Si hubo implementación: PR a 2.1, capturas antes/después en `_capturas/`, device-QA pendiente en ticket si aplica.
- Mini limpia al cerrar (sim apagado/erase, worktree solo si PR mergeado).
- /cerrar-total al terminar de forma autónoma (si paras por decisión de diseño, no cierres: espera la respuesta).

## Paso 0 — decisiones

*Diseño elegido por Jürgen (AskUserQuestion, 2026-10-04): **B · Panel de escucha**. Lo demás, resuelto en autónomo (bypass).*

- **Qué se construye:** mientras dictas, la caja de escribir se sustituye por un panel con título, una pista, un orbe que late con tu voz, el tiempo y dos botones: Cancelar (descarta sin transcribir) y Listo (transcribe). Al transcribir, el orbe gira, el panel dice «Revisa tu texto antes de enviarlo.» y enseña lo grabado; sin botones, porque cancelar a media transcripción no corta la petición.
- **Copy (Jürgen, mid-turno):** textos sencillos. Título: se reusa «Escuchando…» (ya traducido en 16 locales). Pista: «Prueba: «Gasté 25 en el almuerzo con la tarjeta»», sin moneda para que sirva en cualquier país (BRAND-VOICE §2.3). Cancelar/Listo: `action.cancel`/`action.done`.
- **Nivel de voz:** `AVAudioRecorder.isMeteringEnabled` + `averagePower` normalizado a 0…1 en el temporizador que ya existe (0,1 s). Sin dependencia nueva.
- **Descartar:** `cancelVoiceInput()` ya existía sin llamadores; ahora lo usa Cancelar. Se le añade soltar la sesión de audio, como hace `stopRecording`.
- **Reduce motion:** halo quieto y spinner del sistema.
- **Fuera:** registro por voz (`VoiceRecordingSheet`), respuesta por voz, mascota, formulario de cuenta, detents.
