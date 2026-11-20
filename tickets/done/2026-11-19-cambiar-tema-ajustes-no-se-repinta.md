---
id: 2026-11-19-cambiar-tema-ajustes-no-se-repinta
status: done
priority: high
area: "design-system, temas"
created: 2026-11-19
updated: 2026-11-19
source: "Jürgen, 19-nov 21:13, build 2.3 (5) en su iPhone"
---

# Al cambiar de tema, la hoja de Ajustes queda con los colores viejos y no se lee hasta cerrarla

## Qué le pasaba al usuario

En Ajustes › Temas, al pasar de Claro a Oscuro, la pantalla de Temas y la lista de Ajustes se quedaban con el texto del
modo claro: gris oscuro sobre negro, casi ilegible. Se arreglaba al cerrar Ajustes y volver a abrirlo.

## Por qué pasaba (medido en el simulador, iOS 27.2)

Claro y Oscuro pintan el texto con `Color.primary` / `.secondary`, que se resuelven con el modo claro u oscuro de la
hoja. `preferredColorScheme` en la raíz no alcanza a una hoja ya presentada: SwiftUI le fija el modo al presentarla. El
fondo y las tarjetas sí cambiaban porque son colores fijos del tema. Poner el modo solo en la `UIWindow` no bastó
(medido: el texto seguía a 36/255 sobre negro).

## Arreglo

`Yala/App/Theme/ThemeWindowStyle.swift`: una sonda en la raíz de cada ventana (`appliesThemeStyleToWindow`, en
`YalaApp.rootView`) pone el claro u oscuro del tema en la ventana y, al cambiar de tema, en cada controlador presentado.
Vale para todas las hojas, no solo Ajustes. «Sistema» lo suelta y manda iOS.

## Pruebas

- `YalaTests/TemasRepintadoYContraste/ThemeWindowStyleTests`: estilo por tema, la sonda en la ventana y en una hoja
  presentada, cableado.
- `YalaUITests/TemasRepintadoYContraste/TemasRepintadoUITests`: con Ajustes › Temas abierto, Claro → Oscuro → Claro y
  Claro → Índigo, Rosa, Liquid Glass y Sistema; mide en píxeles que el título y la fila «Temas» se leen. Sin el arreglo
  cae con el título a 0,0 sobre negro (mutante comprobado).

## Falta

Verlo en el iPhone (la build 2.3 (5) es anterior al arreglo): Ajustes › Temas, pasar de Claro a Oscuro y de vuelta, sin
cerrar la hoja.
