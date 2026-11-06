Yala
# Tu IA registra en Yala: borradores desde Claude / ChatGPT (y Grok si se puede)
toca: `mcp/` (herramienta de escritura estrecha), guía en la app si aplica. No toques Web/ de Lola ni despliegues a producción sin OK.

Rama base: 2.3. Un solo PR contra 2.3, un solo cierre. Máquina: Mini (o la libre). No usa simulador si solo es MCP + docs; si toca UI de guía, pipeline serial.

## Contexto
Card: «Tu IA registra en Yala: Claude y ChatGPT (y Grok si se puede) crean borradores en la Bandeja» (tablero-tu-ia-registra-en-yala-claude-y-chatgpt-o9b0). Cierre autónomo. Decisión Jürgen 21-oct.

Requisito previo cumplido: «Endurecer el conector MCP en producción» mergeado (PR 790) y login Apple/Google del conector (PR 801). Seguridad: misma del ADR del conector 2026-09-26 (escritura estrecha → borradores).

## Qué se pide
1. Herramienta de escritura estrecha: «apunta 25 soles de almuerzo» (y variantes) deja un borrador en la Bandeja.
2. Alta / documentación para ChatGPT; medir si Grok acepta conectores (anotar resultado; no bloquear Claude/ChatGPT).
3. Guía breve en la app si hace falta para descubrirlo.
4. Sin desplegar producción del MCP sin OK de Jürgen; staging sí si el encargo lo necesita y está documentado.
5. `tablero`: en curso → in qa al cerrar.

## Hecha cuando
- Desde Claude (y ChatGPT si el alta está lista), «apunta 25 soles de almuerzo» deja un borrador en la Bandeja aprobable con un toque (verificado en staging o con test del conector).
- Card en in qa.
- `/cerrar-total` con «Saltado o asumido sin preguntar».

PREGUNTAR, NO SALTAR. `tablero` + /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR. D5 y D6 las contestó
> Jürgen por el bot (2026-11-05, 21:5x).

**D1 · ¿Dónde escribe el conector el movimiento?** → En una cola por cuenta en el D1 del gateway
(`connector_drafts`), como el correo del banco. La app la recoge, crea el borrador local en la Bandeja y confirma.
Por qué: la sesión de Supabase del conector es de solo lectura (ADR del 2026-09-26) y escribir `inbox_drafts` en la
nube obliga a estampar HLC del protocolo de sync desde un Worker. Alternativa descartada: escribir en Supabase con otro
rol (abre escritura en la base a un Worker expuesto a la IA).

**D2 · ¿Cómo llega el conector a esa cola?** → Llamada interna entre Workers (service binding a una clase
`ConnectorDrafts` del gateway, RPC), sin ruta pública. Por qué: el conector solo puede hacer UNA cosa (encolar para el
`sub` que ya verificó). Alternativa descartada: darle al conector el binding del D1 del gateway (podría tocar
entitlements, correo, etc.).

**D3 · ¿Quién resuelve cuenta y categoría?** → El conector, contra los datos de la persona (ya los lee): si la IA nombra
una cuenta o subcategoría que no existe o es ambigua, la herramienta devuelve error con las opciones; si no nombra,
cuenta única en la divisa o ninguna. La cola lleva el `sync_id` (= `shortcutID`) y el nombre; la app busca por id y,
si no está, por nombre. Por qué: «aprobable con un toque» exige cuenta y subcategoría, y la IA puede corregirse en la
misma conversación.

**D4 · Etiqueta en la Bandeja** → Fuente nueva `.aiConnector`, etiqueta «Tu IA» (16 idiomas) y la IA concreta
(«Claude», «ChatGPT», «Grok») como evidencia. Por qué: «Automatización» no dice de dónde vino. Riesgo aceptado: una app
anterior a 2.3 con la nube la ve como «Voz» (su fallback); la nube sale con 2.3.

**D5 · Guía en la app** → Diferida al deploy de producción del conector (no hay dominio ni URL que enseñar). Jürgen,
opción A.

**D6 · ChatGPT y Grok** → URLs de vuelta de ChatGPT documentadas por OpenAI en la lista; las demás (Grok) por
configuración (`EXTRA_REDIRECT_URIS`), y el primer intento rechazado deja la URL en el log para fijarla. Jürgen: de
acuerdo, documentado en el PR.

**D7 · Gratis o Pro** → Gratis (decisión del 21-oct: la IA la paga la persona). Techo anti-abuso: 50 al día y 100 en
cola por cuenta.

**D8 · ¿Cuándo pregunta la app?** → Al volver a primer plano (con la nube y sesión, como el correo), como mucho cada
5 min, y siempre al abrir la Bandeja… solo si el encargo no crece: si abrir la Bandeja exige tocar su vista, se queda
en primer plano + recarga.

**D9 · (tras la review adversarial) ¿Una conexión vieja gana la escritura al desplegar?** → No: el permiso guarda si
dijo «podrá apuntar» (`GrantProps.drafts`) y la herramienta solo se ofrece entonces; quien conectó como solo lectura
reconecta. Por qué: el consentimiento tiene que cubrir lo que la IA puede hacer. Alternativa descartada: comparar
`authorizedAt` con la fecha del deploy (frágil ante un rollback del binding).

**D10 · Fecha** → Hasta hoy (no «mañana»): la app descarta lo que cae más de 24 h tras la llegada y la IA habría
contestado una fecha que no es la que queda.
