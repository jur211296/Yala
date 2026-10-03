---
id: step-flows-should-match-the-sep15-reference
status: qa
priority: medium
area: "ux, onboarding, design-system"
created: 2026-09-17
updated: 2026-10-02
qa-status: needs-testing
source: "Pack UI 15-sep (Dan) — Jürgen 2026-09-17: cada punto del pack = ticket aparte"
---

# Los flujos por pasos de Yala deben acercarse a la referencia del 15-sep

## Qué quiere Jürgen

Todo lo que en Yala requiera **pasos** (cancelar, migrar, activar, etc.) debe alinearse con la referencia que señaló el 15-sep: captura en `docs/design/referencias/` (flujo cancelar suscripción) y memoria `.claude/agent-memory/frank/reference_ui_flujo_por_pasos.md`.

## Rasgos a llevar (de la referencia)

1. Progreso doble arriba (barras + «Paso N de M»).
2. Cabecera con contexto (qué se hace + datos vivos).
3. Lista numerada con hilo; solo el paso activo es accionable.
4. Miniatura «lo que vas a ver» cuando se sale de la app.
5. Línea de garantía (qué NO va a pasar).
6. Dos salidas al pie con jerarquía (éxito / me atasqué).

## No inventar

Usar la referencia ya escrita. Ticket hermano del pack: chat IA, ajustes iOS, onboarding login, reglas de pulido.

## Paso 0 — decisiones (2026-10-02)

### Inventario medido (no la lista del ticket)

| Flujo | Forma hoy | En esta sesión |
|---|---|---|
| Tutoriales › **Registrar con Apple Pay** | carrusel de vídeo, 4 pasos que se hacen en Atajos | **migrado** (primero, lo pidió Jürgen) |
| Ajustes › Seguridad › **Protege Yala con Face ID** | lista fija de 3 pasos en la pantalla de inicio | **migrado** |
| Los otros 11 tutoriales | carrusel de vídeo de cosas que se hacen DENTRO de Yala | fuera: no salen de la app; el carrusel con vídeo les sirve |
| Onboarding principal | pasos | fuera: ticket hermano `onboarding-login-should-match-the-sep15-reference` |
| Onboarding de Yala IA | carrusel con puntos | fuera: chat (#332) |
| Onboarding de Grupos, activación del modo completo, puerta de iCloud, Restaurar, aviso tardío | pasos / fases | fuera: Cola A |
| «Configura tu Yala» del Panel | tarjeta con checklist | fuera: es una tarjeta del Panel, no un flujo; tocarla es identidad del Panel. Candidato si Jürgen la quiere |
| Avisos de permiso (notificaciones, cámara, micrófono) → Ajustes de iOS | `.alert` con «Abrir Ajustes» | fuera: hoy no son flujos por pasos; convertirlos sería un flujo nuevo |

### Decisiones de Jürgen (AskUserQuestion, 2026-10-02 ~20:35 Lima)

1. **Progreso**: «Hecho» en el paso activo marca y pasa al siguiente. iOS no le dice a Yala si el paso se hizo fuera.
2. **«Me atasqué»** abre el formulario de soporte de siempre (`SupportFormSheet`). Sin flujo nuevo.
3. **Copy nuevo sí**, en los 16 idiomas: garantía, «Lo que vas a ver», «Hecho», «Me atasqué».
4. Mensaje a mitad de sesión: «Me gustaría hacer ese flujo para enseñar a usar el Apple Pay automation en atajos» ⇒ Apple Pay pasa a ser el primer flujo.

### Decisiones técnicas (mías)

- Componente en el design system: `Yala/App/DesignSystem/StepGuide.swift` (`YalaStepGuide`); estado puro en
  `StepGuideLogic.swift` (`StepGuideProgress`), con test.
- Apple Pay: el paso 1 lleva «Abrir Atajos» y queda hecho si iOS abre la app; los demás, «Hecho». «Lo que vas a
  ver» es el vídeo ya grabado del paso activo (no se imita la interfaz de Apple). La ayuda larga solo se ve en el paso
  activo. Datos vivos de la cabecera: pagos de Apple Pay esperando en la bandeja. «Listo» marca el tutorial como hecho.
- Face ID: «Lo que vas a ver» es el menú del icono con «Requerir Face ID» y el icono que la persona tiene puesto. El
  nombre de la opción sale del mismo término que ya usa el paso 2 en cada idioma. Sin datos vivos: la guía no usa
  LocalAuthentication a propósito.
- Ancho: contenido y pie a `DS.Adaptive.readableWidth` (700), centrados. Decide el ancho, no el aparato.
- Pie con `safeAreaBar` (iOS 26): el borde del scroll lo pone el sistema.

## Hecho (2026-10-02)

- **Registrar con Apple Pay** (Ajustes › Tutoriales) es una guía por pasos: barras y «Paso N de M» arriba; cabecera con
  los pagos de Apple Pay que esperan en la bandeja; cuatro pasos con hilo y un solo botón, «Abrir Atajos» en el
  primero; el vídeo del paso activo como «Lo que vas a ver»; garantía «Cada pago llega como borrador: nada se registra
  sin que lo apruebes»; «Listo» y «Me atasqué» al pie.
- **Protege Yala con Face ID** (Ajustes › Seguridad), con el mismo componente: «Hecho» avanza; «Lo que vas a ver» es el
  menú del icono con «Requerir Face ID»; garantía «Yala nunca ve tu rostro: lo comprueba iOS».
- Componente `YalaStepGuide` en el design system; contenido y pie a 700 pt centrados en ventanas anchas.
- Tests: `YalaTests/StepGuideLogicTests` (estado) y `YalaUITests/StepGuideUITests` (antes → después en las dos;
  mutante «Apple Pay vuelve al carrusel + Face ID vieja» medido: los dos casos caen).
- Capturas: `qa/evidencia-step-guides-20261002/` (iPhone 17 Pro, vertical y horizontal).

## Guion de QA en iPhone (Jürgen)

1. Instala el build de este PR en tu iPhone.
2. Abre Yala › tu avatar (arriba a la derecha) › baja hasta **Ayuda** › **Tutoriales** › **Registrar con Apple Pay**.
3. Comprueba arriba «Paso 1 de 4» con la primera barra llena, y bajo el título «Pagos de Apple Pay en tu bandeja: N».
4. Toca **Abrir Atajos**: debe abrirse la app Atajos. Vuelve a Yala (deslizando desde abajo o con el botón de apps).
5. Al volver, la guía debe estar en «Paso 2 de 4», con el paso 1 marcado con ✓ y el vídeo del paso 2 abajo.
6. Toca **Hecho** dos veces y comprueba que llega a «Paso 4 de 4»; toca el vídeo para que se reproduzca.
7. Toca **Me atasqué**: debe abrirse el formulario de soporte. Ciérralo.
8. Toca **Listo**: vuelves a Tutoriales y «Registrar con Apple Pay» lleva el ✓ de completado.
9. Repite el camino con Ajustes › Seguridad › **Protege Yala con Face ID**: «Hecho» avanza los 3 pasos y en «Lo que vas
   a ver» sale el icono de Yala que tienes puesto.
10. Opcional: gira el iPhone; el contenido debe quedar centrado y no más ancho que una columna cómoda.

## Fuera de esta sesión

- **«Configura tu Yala» del Panel** (`SetupChecklistCard`): es la otra pieza con pasos que queda. Es una tarjeta del
  Panel, no un flujo; pasarla a esta forma toca la identidad del Panel. Lo decide Jürgen.
- **Avisos de permiso → Ajustes de iOS** (notificaciones, cámara, micrófono): hoy son `.alert`. Convertirlos en guía
  sería un flujo nuevo.
- Onboarding (ticket hermano), Yala IA (#332) y los flujos de la Cola A, por el encargo.
