---
id: settings-redesign-as-grouped-lists-like-ios
status: backlog
priority: medium
area: "settings, design-system, profile"
created: 2026-09-15
source: Jürgen, comparación de capturas Yala vs Ajustes de iOS (2026-09-15)
---

# Los ajustes de Yala se ven más cargados que los de iOS: rediseñar como listas agrupadas

## Qué le pasa al usuario

Abre Personalización y cada fila es una tarjeta suelta con su texto de ayuda debajo. Entre la
tarjeta, el hueco, el párrafo gris y el siguiente hueco, una pantalla enseña cinco ajustes y hay
que hacer scroll para el resto. En la misma pantalla de iOS (Accesibilidad › Texto flotante)
caben once ajustes y se lee de un vistazo.

## Lo comparado (2026-09-15)

Dos capturas en `docs/design/referencias/`: `2026-09-15-ajustes-yala-personalizacion.png` y
`2026-09-15-ajustes-ios-texto-flotante.png`. Lo que hace iOS y Yala no:

1. **Filas agrupadas en un solo bloque** por sección, separadas por una línea fina, en vez de una
   tarjeta por fila. Es lo que más espacio ahorra.
2. **Cabecera de sección en gris y pequeña** («Texto», «Colores»), no un título negro grande
   («Calendario», «Indicadores»).
3. **Texto de ayuda solo cuando hace falta**, y bajo el bloque, no bajo cada fila. Yala lo pone
   en todas: «Muestra una línea de promedio en las gráficas de barras» repite lo que ya dice la
   fila.
4. **El interruptor maestro va solo, arriba**, en su propio bloque, y lo que gobierna va debajo.
5. **Valor a la derecha en gris + chevron**, igual que Yala; eso ya está bien.
6. **Fondo gris claro y bloques blancos**, sin sombra. Yala usa lo mismo; el problema no es el
   color, es la densidad.

## Dónde está

- `Yala/App/Views/Settings/PersonalizationSettingsView.swift` (1 286 líneas): `ScrollView` con
  `VStack(spacing: DS.Spacing.xxl)`, un `YalaSectionHeader` por sección y cada fila con su
  `DS.FormRow.paddingH/V` y su fondo propio.
- Las otras 32 vistas de `Yala/App/Views/Settings/` siguen el mismo patrón, así que el rediseño
  es del **contenedor de fila y sección** en el design system, no de una pantalla.
- Entrada desde `Yala/App/Views/Profile/ProfileView.swift:1010`.

## Qué se pide

Rediseñar el patrón de ajustes al estilo de las listas agrupadas de iOS —bloque por sección,
separador fino, cabecera gris, ayuda solo donde aporta— como un componente del design system, y
aplicarlo primero a Personalización. Las demás pantallas de Settings se migran después, cada una
en su commit. Es identidad, no polish: si el bloque blanco cambia de forma, decirlo antes
(ver memoria `feedback_tarjetas_blancas_identidad`).

## Cómo se sabe que está bien

Personalización enseña el doble de ajustes por pantalla que hoy sin perder ninguno, y cada
texto de ayuda que se quede dice algo que la fila no dice.
