# Lote T4 · Datos de prueba y relanzar
toca: `Yala/Seed/`, `UITestHooks.swift`

Rama base: 2.3. Un solo PR. Máquina: cualquiera. Usa simulador (pipeline serial).
Lote tests (cola-2-3-propuesta.md §3 T4).

Cards:
1. Ningún perfil de seed de Grupos tiene un heredero.
2. No hay datos de prueba con una solicitud de grupo rechazada.
3. Relanzar un UI-test con la misma siembra y sin reset duplica todos los datos.
4. Relanzar sin `-uitest-reset` a veces enseña el Panel con todas las secciones.
5. El botón «OK» del aviso de cierre de sesión bloqueado no tiene identificador.

Hecha cuando: las cinco hechas, seeds nuevos usables, tests en verde.

PREGUNTAR, NO SALTAR. `tablero` + /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D0 · Rama base** → `origin/2.3`, como dice el encargo (el worktree nació de 2.2 y se reubicó antes de tocar nada).
Por qué: el encargo es de la cola 2.3. Alternativa descartada: quedarse en 2.2 (mezclaría el lote con la versión anterior).

**D1 · Heredero: ¿tocar `grupos` o perfil nuevo?** → perfil nuevo `grupos-con-heredero`: el dataset de `grupos` con `userID` y `memberKey` en los co-miembros.
Por qué: `grupos` sostiene el callejón «dueño con deuda y sin heredero» y el test de «Beto sin cuenta»; hacen falta los dos casos. Alternativa descartada: poblar `grupos` (rompe esos tests y el caso complementario).

**D2 · Solicitud rechazada** → perfil nuevo `grupos-rechazado`: un grupo de Ana donde yo estoy `rejected`, identidad por `cloudKitUserRecordID` (como `grupos-pendiente`).
Por qué: es como llega por el pull (sin `isCurrentUser`). Alternativa descartada: un seam que fuerce el banner (probaría el flujo, no la decisión).

**D3 · Relanzar con la misma siembra sin reset** → no se vuelve a sembrar si el último perfil sembrado es el mismo Y el almacén tiene datos; lo dice por consola. Con otro perfil y sin reset, siembra encima como antes y avisa de que lo limpio exige `-uitest-reset`. La cuenta «QA FX» gana su guard de presencia.
Por qué: el guard mira el almacén y no solo el flag (un almacén vaciado a mano vuelve a sembrar). Alternativa descartada: saltar cualquier siembra con datos (cambiar de perfil no haría nada, en silencio).

**D4 · Panel con todas las secciones tras relanzar** → causa medida en código: el reset borra las claves del disco y resiembra sobre una copia en memoria que ya tenía esos valores, así que ningún `didSet` escribe. El reset limpia también la copia en memoria antes de sembrar.
Por qué: arregla la causa en su sitio. Alternativa descartada: fijar el Panel por argumentos (es el rodeo de la ficha).

**D5 · «OK» del aviso de cierre bloqueado** → un identificador por aviso (`signout_blocked_ok`, `signout_pending_ok`), medido con un XCUITest que lo pulsa por id.
Por qué: los dos avisos comparten botón; uno por aviso deja distinguir cuál salió.

Nada de esto pide ADR: son datos de prueba y testabilidad.
