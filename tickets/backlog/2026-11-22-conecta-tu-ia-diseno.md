---
id: 2026-11-22-conecta-tu-ia-diseno
status: backlog
priority: medium
area: "design, ai-connector"
created: 2026-11-23
updated: 2026-11-23
source: "encargo 2026-11-23-conecta-tu-ia-diseno-opciones (decisiones de Jürgen t1900u, t1901u y t1902u del 2026-11-22)"
---

# «Conecta tu IA»: tres opciones para elegir (app y web del conector)

**Maqueta para decidir:** https://claude.ai/artifact/65CmVCQkr1JWd7JaFEXnRm (pública; las respuestas se guardan en
su sección «Decidir»). Copia del HTML: `docs/diseno/conecta-tu-ia/index.html`.

## Qué cambia para el usuario

Hoy la app no explica el conector: no hay dónde conectar, ver qué puede hacer la IA ni desconectarla, y la Bandeja
solo dice «Tu IA». La maqueta propone dónde vive «Conecta tu IA», cómo se descubre, cómo se ve el estado, cómo se
marca en la Bandeja lo que apunta la IA y cómo quedan con marca de Yala las pantallas web que abre Claude.

## Medido en 2.3 (no inventar)

- El borrador del conector ya trae el nombre de la IA (Claude, ChatGPT o Grok): `clientLabelFromRedirects` en
  `mcp/src/writeTool.ts` → `client` → `evidence` en `AIConnectorDraftLogic.swift`. La fila de la Bandeja no lo usa:
  pinta `inbox.sourceAIConnector` («Tu IA», `InboxDraftSourceName.swift`).
- No hay endpoint para listar ni revocar conexiones desde la app. Propuesta de servicio en
  `claude-mcp-connected-apps-in-the-app`. Desconectar desde Claude sí cierra todo (`mcp/src/revoke.ts`).
- No se guarda la «última actividad» de cada IA.
- Todas las herramientas son `plan: "gratis"` (`shared-core/src/toolCore.ts`, decisión del 26-sep).
- No existe página «listo»: tras el inicio de sesión se vuelve directo a la IA (`authorize.ts`).
- Las páginas web son `mcp/src/pages.ts`: CSS propio, sin JavaScript ni recursos externos (CSP
  `default-src 'none'`); la del permiso se sale de un teléfono (`mcp-consent-page-overflows-on-a-phone`).

## Opciones

- **A · Ajustes.** Fila «Tu IA» junto a «Tu cuenta de Yala»; página «Conecta tu IA»; lista con «Desconectar»
  (necesita el servicio nuevo); etiqueta con el nombre de la IA en la Bandeja.
- **B · Bandeja.** Botón de destello y tarjeta en la Bandeja vacía; hoja corta para conectar; estado a partir de los
  borradores; lo de la IA agrupado bajo «De Claude» con «Confirmar todo» (nuevo). Sin servicio nuevo.
- **C · Ajustes + puertas (recomendada).** Casa en Ajustes como A, descubrimiento desde Primeros pasos y la Bandeja
  vacía, aviso si falta la nube. Fase 1 solo app (estado desde los borradores, desconectar explicado); fase 2 con el
  servicio para listar y desconectar. Etiqueta con el nombre de la IA y filtro «De tu IA».
- **Web del conector (las tres opciones):** logo, colores (índigo, cian y rosa) y tipografía de la web; botones
  oficiales «Continuar con Apple» y «Continuar con Google» en claro y oscuro; permiso, inicio de sesión, error y
  «listo» (nuevo), en celular y escritorio. Para construirlo: solo `pages.ts`; logos en SVG dentro de la página;
  tipografía servida por el Worker (`font-src 'self'`) o la del sistema.

## Preguntas para Jürgen (recomendada primero)

1. ¿Qué opción? **C** / A / B.
2. ¿Gratis o Pro? **Gratis** / solo Pro / leer gratis y apuntar Pro.
3. Listar y desconectar desde la app: **fase 2** / todo junto / no hace falta.
4. ¿Guardar «última actividad»? **No, basta el último borrador** / sí, una marca por renovación.
5. ¿Página «Listo» en la web? **No, volver directo** / sí, con vuelta automática en 3 s.
6. Etiqueta en la Bandeja: **el nombre de la IA («Claude»)** / «Tu IA» y el nombre dentro.

## Criterio de hecho

- [x] Maqueta publicada con 2-3 opciones y una recomendada (app y web).
- [ ] Jürgen responde las seis preguntas.
- [ ] Encargo de construcción escrito con la opción elegida (app; web del conector; servicio si aplica).
