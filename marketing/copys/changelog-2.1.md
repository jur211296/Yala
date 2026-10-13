# Yala 2.1 — Novedades en lenguaje de usuario

> **Borrador. No está publicado en ningún sitio.**
> Fuente: `~/Claude/lola-borradores/2.1/changelog-2.1.md` (2026-10-12), corregido el 2026-10-13 con el
> criterio de copy de 2.1 (PR #469). Lo que se cuenta está en [`../funcionalidades/`](../funcionalidades/), cada cosa con su evidencia.
> Handle de X: **@yalaapp** (aún sin reclamar). Enlace: https://apps.apple.com/app/id6758253109
> Apple Pay, la voz y compartir imagen ya existían en 2.0: aquí se cuentan como **mejoras**, no como funciones nuevas.

## X: post único (≤280)

```
Llegó Yala 2.1 🎉
Dictas tu gasto y lo confirmas en la misma pantalla. Compartes varias capturas a la vez. Lee tu estado de cuenta en PDF, aunque tenga clave. Y en Grupos ves al instante cuánto te toca.
Anotar tus gastos, ahora con menos pasos 👇
apps.apple.com/app/id6758253109
```
(268/280: X cuenta el enlace como 23.)

## X: hilo (5 posts)

1/
```
Yala 2.1 ya está aquí 🙌 Lo hicimos para que anotar tus gastos te tome segundos. Te contamos qué trae 🧵
```
2/
```
🎙️ Voz: tocas el botón, dices «25 soles de taxi y 12 de café» y ahí mismo ves lo que Yala entendió. Revisas, guardas y listo. Sin pantallas de más.
```
3/
```
📸 Compartir: elige varias capturas en Fotos (el Yape, la transferencia, el recibo) → Compartir → Yala. Lee hasta 10 a la vez.
📄 ¿Estado de cuenta en PDF? Lo lee página por página. Si tiene clave, te la pide y no la guarda.
```
4/
```
👥 Grupos: cada gasto te dice «Le debes a Ana · S/ 40». Repartes en una frase y mandas al chat un resumen del viaje en imagen, con quién puso qué y cómo quedar a mano.
```
5/
```
Y además: exportar todos tus datos es gratis, una guía nueva para Apple Pay, el efecto del tipo de cambio en tu Panel, Yala IA con forma de chat y Yala en iPad 💚
Actualiza aquí 👉 apps.apple.com/app/id6758253109
```
(202/280.)

## App Store — Novedades (ES)

La versión final para la tienda vive en [`app-store-2.1.md`](app-store-2.1.md). Es la misma:

```
Yala 2.1 llega con menos pasos para anotar tus gastos:

• Voz en una sola hoja: dicta tus gastos y confirma ahí mismo lo que Yala entendió.
• Varias capturas a la vez: elige hasta 10 imágenes en Fotos, compártelas con Yala y las lee de una vez.
• Estados de cuenta en PDF: Yala los lee página por página. Si tienen contraseña, te la pide y no la guarda.
• Grupos más claros: cada gasto te dice cuánto te toca, repartes en una frase y compartes el resumen del viaje en una imagen. Además: un tope de gasto para el grupo y un recordatorio amable cuando una deuda lleva tiempo pendiente.
• Apple Pay: una guía nueva, paso a paso, para que tus pagos lleguen solos a Yala y solo tengas que aprobarlos.
• Tipo de cambio: tu Panel te muestra cuánto ganaste o perdiste por el tipo de cambio, y los totales aproximados llevan «≈».
• Exporta gratis: todos tus datos, de cualquier período, en CSV o Excel.
• Panel y Yala IA renovados: tus cuentas en tarjetas grandes y un chat más cómodo.
• Yala en el iPad: barra lateral, varias ventanas, atajos de teclado y widgets grandes. Y en el iPhone, Yala también gira a horizontal.
• Corregimos errores y pulimos detalles para que todo funcione mejor.
```

## Correcciones de esta versión (2026-10-13)

| Antes (borrador del 12-oct) | Ahora | Por qué |
|---|---|---|
| Sin exportación | Novedades: «Exporta gratis: todos tus datos, de cualquier período, en CSV o Excel». Hilo 5/: «exportar todos tus datos es gratis» | La política 2.1 (PR #469, D3) la hace gratis. Medido: `exportExtendedPeriods` ya no existe en `Yala/` |
| Hilo 3/: «te la pide y la olvida» | «te la pide y no la guarda» | Es la misma frase de las Novedades: una sola promesa, dicha igual |
| — | Sin cambios: ni Modo Nube, ni el conector de Claude, ni «iCloud», ni «no almacenamos nada en servidores» | Revisado frase a frase: el borrador ya no los tenía |

> Revisión anterior contra `BRAND-VOICE.md` (2026-10-12, de Lola): fuera «al toque» (§2.3) y «más fácil» (§8);
> «pantalla» → «hoja»; cierre en primera persona.
