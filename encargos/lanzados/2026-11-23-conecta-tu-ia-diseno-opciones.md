Yala
# Diseñar en maqueta «Conecta tu IA», el conector dentro de la app y las pantallas de inicio de sesión del conector
---
toca: docs/diseno/conecta-tu-ia/,tickets/backlog/2026-11-22-conecta-tu-ia-diseno.md
esfuerzo: medium
cierre: cierra-sola
---

El 22-nov Jürgen probó con éxito el conector de Claude en producción (`https://mcp.yala-app.pe/mcp`, OAuth con Apple o Google, `mcp/src/authorize.ts`). Preguntó qué hay del conector dentro de la app y si la interfaz es buena. Hoy en la app de iPhone (2.3) solo existe el borrador en la Bandeja con el origen «Tu IA» (`InboxDraftSourceName.swift`, `InboxDraftRowView.swift`, `inbox.sourceAIConnector`). No hay pantalla para conectar, explicar permisos, ver IA conectadas ni desconectar. Jürgen pidió una maqueta con opciones (decisión registrada con la clave t1900u).

## Qué hacer (SOLO DISEÑO, sin código de la app)
- Revisa primero lo que ya existe: el código del conector (`mcp/`), la pantalla de permiso OAuth, los tickets y análisis de conectores (`docs/analisis/` préstamos y conectores de IA frente a Vuelto, Neto y Qalta), la guía de producción del conector y el sistema de diseño de la app (`.claude/rules/swiftui-ds.md`).
- Entrega un artifact visual de Claude (nunca Markdown ni PDF) con 2 o 3 opciones comparables lado a lado, cada una con su recorrido completo en iPhone (claro y oscuro):
  1. Dónde vive la entrada (Ajustes, Panel, Bandeja o Primeros pasos) y cómo se descubre.
  2. Pantalla «Conecta tu IA»: pasos para Claude (y ChatGPT si aplica), botón para copiar la URL, qué puede ver y hacer la IA (lee, propone borradores, nunca guarda sin tu aprobación).
  3. Estado: IA conectadas, última actividad y cómo desconectar o revocar.
  4. Cómo se ve en la Bandeja lo que apunta la IA (distintivo más claro que «Tu IA»).
  5. Si es solo Pro o gratis, y cómo encaja con la oferta Pro.
  6. Pantallas web del conector en mcp.yala-app.pe (las que abre Claude): inicio de sesión, permiso o consentimiento, error y «listo, ya puedes volver a Claude». Hoy son una tarjeta genérica sin marca (captura de Jürgen del 22-nov: «Inicia sesión en Yala», «Continuar con Apple», «Continuar con Google»). Jürgen (t1901u, t1902u) pidió estilo de la web de Yala: logo de Yala, colores y tipografía de la web, y los botones OFICIALES de Apple (Sign in with Apple, Human Interface Guidelines) y Google (Sign in with Google, guías de marca), en claro y oscuro, en celular y escritorio. Revisa cómo se generan hoy en `mcp/src/` (por ejemplo `authorize.ts`) y la web en `web/` o `webapp/` para reutilizar estilos y logo; indica qué haría falta para construirlo (solo maqueta en esta sesión).
- Marca la opción recomendada con su porqué y lo que haría falta en backend (por ejemplo, si hoy no hay forma de listar o revocar conexiones desde la app, dilo claro).
- Deja el artifact o su export en `docs/diseno/conecta-tu-ia/` y un ticket en backlog con las opciones y las preguntas para Jürgen.
- No inventes capacidades del conector: todo lo que muestres debe existir hoy o estar marcado como «nuevo, requiere trabajo».

## Criterios de aceptación
- Artifact visual con 2 o 3 opciones comparables y una recomendada, fácil para que Jürgen elija.
- Ticket en backlog con las preguntas a decidir.
- PR (solo docs y ticket) mergeado en 2.3.

## Dispositivos
No hace falta simulador. Si quieres capturas de la Bandeja real, antes comprueba si el iPhone 14 por DeviceMCP está libre (no lo des por ocupado sin comprobarlo). En la Max puedes usar un segundo simulador si otra sesión ya usa uno (tope 2); en la Mini, 1.

## Cierre
Commits y PR sin firma de IA. Espera el merge real del PR en 2.3 antes de `/cerrar-total`. Si a los ~45 min el CI sigue rojo por algo ajeno al PR, cierra y anótalo. El cierre incluye el link del artifact, «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada».

## Paso 0 — decisiones (resueltas en semiautónomo, sin preguntar: todas menores y reversibles; es solo diseño)

1. **Tres opciones, no dos**: A (Ajustes), B (Bandeja) y C (Ajustes + puertas de descubrimiento), recomendada C. Motivo: A y B son los dos extremos naturales; C los combina y puede salir en fase 1 sin backend.
2. **Nada inventado**: medido en `mcp/src/` y `shared-core/`: el borrador ya trae el nombre de la IA (`clientLabelFromRedirects` → `evidence`), no hay endpoint para listar/revocar conexiones, no se guarda «última actividad», todo es `plan: "gratis"`, no existe página «listo». Lo nuevo se marca «nuevo, requiere trabajo».
3. **Un solo artifact HTML** en `docs/diseno/conecta-tu-ia/index.html`, con conmutador claro/oscuro y celular/escritorio en vez de duplicar cada pantalla; preguntas con respuesta guardada en la `db` del artifact (solo escribe el dueño).
4. **Sin capturas del iPhone**: la fila de la Bandeja se dibuja a partir del código (`InboxDraftRowView`, `InboxDraftSourceName`); no hace falta simulador ni teléfono.
5. **Ticket nuevo** `tickets/backlog/2026-11-22-conecta-tu-ia-diseno.md` con opciones y preguntas; el ticket previo `conecta-tu-ia-maqueta-visual-y-pantallas-web` se marca con el criterio «propuestas publicadas» cumplido y apunta al nuevo.
6. **Decisiones pendientes de incorporar** (Salud financiera, semana 7 de marketing, CloudKit por Dan): no son de este encargo de diseño y dos tocan `marketing/` o casa; no se incorporan aquí, se dice en el cierre.
