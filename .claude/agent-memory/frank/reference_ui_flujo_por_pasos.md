---
name: reference-ui-flujo-por-pasos
description: Referencia de UI que Jürgen señaló el 2026-09-15 para todo lo que en Yala requiera pasos — captura en docs/design/referencias, con los seis rasgos que la hacen buena
metadata:
  type: reference
---

Jürgen mandó el 2026-09-15 una pantalla de otra app («Cancel in the App Store», pasos para
anular una prueba gratuita) con «esta UI está interesante para cosas que requieran pasos en
Yala». La captura está en `docs/design/referencias/2026-09-15-flujo-por-pasos-cancelar-suscripcion.jpg`.

**Lo que tiene y por qué funciona:**
1. **Progreso arriba, doble**: tres barras de color y «Step 1 of 3» en texto. Se sabe dónde estás
   sin contar.
2. **Cabecera con contexto**: icono de la cosa + título de la acción + una línea de datos
   (`Headspace · free trial · ends Sat 12 pm`). El título dice qué se hace, no en qué pantalla.
3. **Lista vertical numerada con hilo**: el paso activo en color, los siguientes en gris, cada uno
   con título y una línea de ayuda (`Settings › your name › Subscriptions`). El único botón dentro
   de la lista es la acción del paso activo, con icono de «te saca de la app».
4. **«What you'll see»**: una réplica en miniatura de la pantalla ajena a la que se manda al
   usuario, con el botón rojo tal cual lo verá. Quita el miedo a perderse fuera de la app.
5. **Una línea de garantía** con escudo: «You keep the trial until Sep 12 and nothing is charged».
   Dice qué NO va a pasar.
6. **Dos salidas al pie, con jerarquía**: botón negro lleno «I've cancelled» y un enlace
   subrayado «I got stuck». La salida de fallo existe y no compite.

**Dónde encaja en Yala:** los flujos que ya existen por pasos —onboarding
(`OnboardingTelemetryEventBuilder`), activación del modo completo
(`FullModeActivationFlowLogic`), crear grupo (`GroupCreateRoutingLogic`), alta de cuenta
(`AccountFormViewModel`)— y sobre todo cualquier paso que **mande al usuario fuera de la app**
(Ajustes de iOS, iCloud, permisos): ahí van el «what you'll see» y la línea de garantía.

**How to apply:** cuando toque diseñar o retocar un flujo de pasos, abrir la captura antes de
maquetar y contrastar contra los seis rasgos; los que falten se proponen, no se meten sin
decir. Sigue mandando [[feedback-tarjetas-blancas-identidad]] para lo que toque identidad.
