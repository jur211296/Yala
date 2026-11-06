---
id: panel-eye-hides-amounts
status: qa
priority: medium
area: panel
created: 2026-11-06
updated: 2026-11-06
source: "tablero: «Ojo para ocultar montos en el Panel» (tablero-ojo-para-ocultar-montos-en-el-panel-kzvm) y «Ocultar montos con un botón» (tablero-ocultar-montos-con-un-boton-33qw), roadmap 2.3"
---

# Un ojo en el Panel para ocultar los montos

## Qué cambia para quien usa la app

Junto a la cifra grande del Panel hay un ojo. Al tocarlo, todas las cifras de dinero del Panel pasan a verse como
`S/ •••••`: la cifra grande, las píldoras de entradas y salidas, las cuentas, los presupuestos, los pagos, los últimos
registros y los ejes y promedios de las gráficas. Las gráficas conservan su forma y los porcentajes se siguen viendo.
Al volver a abrir la app los montos siguen ocultos; otro toque al ojo los devuelve.

Lo que se abre desde el Panel (el detalle de una cuenta o de un registro) enseña sus cifras: abrir un detalle es pedir
verlo. Estadísticas, Registros y el resto de la app no cambian.

## Decisiones (Paso 0 del encargo, en autónomo)

- Un solo control para las dos cards: piden lo mismo.
- El ojo va a la derecha de la cifra grande. Junto al rótulo «Balance del período» no cabía: en un iPhone 17 Pro
  apartaba «Ver detalle» (medido en el simulador).
- La preferencia es local del teléfono y no se sincroniza (`AppPreferences.panelAmountsHidden`). «Vaciar datos» y
  `-uitest-reset` la borran.
- La máscara tiene siempre el mismo largo, para que el ancho no delate la cifra. VoiceOver dice «Monto oculto».

## Lo que fija los tests

- `AmountPrivacyTests` (unidad): máscara, largo fijo, «Monto oculto» para VoiceOver, preferencia apagada por defecto,
  que sobrevive a un relanzamiento y que no se sincroniza.
- `PanelAmountsVisibilityUITests` (XCUITest): tocar el ojo oculta los montos, siguen ocultos tras relanzar y otro toque
  los devuelve.

## Guion de QA en el iPhone (Yala Dev)

1. Abre Yala Dev en el iPhone de pruebas y entra en la pestaña **Panel**.
2. Toca el **ojo** a la derecha de la cifra grande. Comprueba que la cifra, las dos píldoras de debajo y las tarjetas de
   cuentas pasan a `•••••`.
3. Baja por todo el Panel: presupuestos, pagos planificados, últimos registros y las gráficas de Tendencias. Ninguna
   cifra de dinero debe verse; los porcentajes sí.
4. Cierra Yala del todo (desliza hacia arriba en el selector de apps) y vuelve a abrirla. Los montos deben seguir ocultos.
5. Toca el ojo otra vez: vuelven todas las cifras.
6. Pásalo a **Estadísticas** y **Registros** con los montos ocultos: ahí las cifras se ven (es solo el Panel).
