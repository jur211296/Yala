---
id: 2026-11-15-tarjetas-personalizables
status: done
priority: medium
area: "panel, accounts"
created: 2026-11-15
updated: 2026-11-16
source: "decisión de Jürgen del 15-nov (encargo 2026-11-16-tarjetas-personalizables)"
---

# Panel: tarjetas de cuentas personalizables

Cada cuenta del carrusel «Tus finanzas» se ve como una tarjeta bancaria y la persona elige su diseño: plantilla, color,
patrón, ícono, chip y, si quiere, los últimos 4 dígitos. Solo diseño: nada de foto de la tarjeta real ni más datos que
esos 4 números. Entra en 2.3.

## Qué quedó

- **La tarjeta del Panel** (`AccountCardView`) pinta el diseño: degradado, patrón y brillo dibujados con SwiftUI, el
  ícono en un cuadrito translúcido, chip opcional y «•••• 1256» abajo a la derecha. Conserva tipo, monedas, «Por
  pagar»/«Saldo», el equivalente y el total de las tarjetas con varias divisas. La que filtra el Panel lleva su cápsula
  «Filtrando» y un borde; la oculta, atenuada con el signo menos. La tarjeta «Grupos» va en grafito neutro y no se diseña.
- **El editor** (`DisenoTarjeta/CardDesignEditorView`) se abre con el botón de paleta de la esquina de la tarjeta o
  con «Diseñar tarjeta» de su menú contextual. Vista previa fija arriba (la tarjeta de verdad, con su saldo), 27
  plantillas en 6 grupos (degradados, metálicas, minimalistas, oscuras, pastel, con patrón), 16 colores y «Otro color»,
  7 patrones, 25 íconos, chip y últimos 4 dígitos. «Volver al diseño original» lo deja como al principio.
- **Guardado** en la preferencia sincronizada `accountCardDesigns` (JSON compacto por `Account.shortcutID`, solo las
  cuentas cambiadas). Sin campo en CloudKit ni en Supabase. «Vaciar mis datos» la borra.
- **Contraste**: el texto va en blanco o casi negro y, si un color no llega a 4,5:1 con el patrón y el brillo encima, el
  fondo se oscurece o aclara hasta llegar.
- **VoiceOver**: nombre, saldo y «terminada en 1256»; nada del adorno. Con «Ocultar montos», los dígitos tampoco.
- Textos en los 16 idiomas.

## Paso 0 (decisiones tomadas al empezar, sin preguntar)

Ver la sección «Paso 0» del encargo `encargos/lanzados/2026-11-16-tarjetas-personalizables.md`, copiada en el PR.

## Pruebas

- `YalaTests/DisenoTarjeta/CardDesignStoreTests`: guardar y leer por cuenta, diseño por defecto, lectura tolerante,
  preferencia sincronizada, sin campo de esquema.
- `YalaTests/DisenoTarjeta/CardLookContrastTests` (+ `CardLastFourTests`): contraste de las 27 plantillas con los 7
  patrones y los 5 tipos, barrida de 216 colores propios, catálogo, solo 4 dígitos, VoiceOver.
- `YalaUITests/CardDesignUITests`: plantilla + dígitos → guardar → la tarjeta lo dice; cancelar no cambia nada; la
  tarjeta «Grupos» no se diseña.

## Device-QA pendiente (iPhone 14)

1. Abre el Panel con «Tus finanzas» desplegada. Cada cuenta se ve como tarjeta de su color de siempre.
2. Toca la paleta de una tarjeta, elige «Aurora», escribe 1256 en «Últimos 4 dígitos» y guarda: la tarjeta queda morada
   con cuadrícula y «•••• 1256».
3. Con VoiceOver, la tarjeta dice el nombre, el saldo y «terminada en 1256».
4. Toca el ojo de «Ocultar montos»: los dígitos pasan a «•••• ••••».
5. Prueba el otro iPhone del mismo Apple ID: el diseño llega solo (preferencia sincronizada).
