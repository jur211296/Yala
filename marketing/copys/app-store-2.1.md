# Yala 2.1 — Textos de la App Store (es, LatAm neutro)

> **Borrador. Nada de esto se ha subido a App Store Connect.**
> Fuente: `~/Claude/lola-borradores/2.1/app-store-2.1.md` (2026-10-12), corregido el 2026-10-13 con el
> criterio de copy de 2.1 (PR #469). Hechos: [`../funcionalidades/`](../funcionalidades/). Tono: `docs/planning/BRAND-VOICE.md`.
> **Fuera a propósito:** la cuenta en la nube (Modo Nube) y el conector de Claude.
> **Grupos (card i6tj):** la política y los términos ya dicen que Grupos vive en los servidores de Yala.
> Lo corrigió el PR #469, mergeado el 2026-10-12. Falta el despliegue en Vercel (paso de Lola en ese PR):
> la línea de Grupos se publica cuando `yala-app.pe/privacy` muestre «Octubre 2026».
> Los conteos se midieron con Python (`len`, caracteres Unicode).

## Novedades (What's New) — 1183/4000

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

## Texto promocional — ≤170 (se cambia sin versión nueva)

Opción A (156/170):
```
Nuevo: Yala en el iPad. Dicta tus gastos y confírmalos en la misma hoja, comparte varias capturas a la vez y deja que Yala lea tus estados de cuenta en PDF.
```
Opción B (143/170):
```
Yala ahora también en el iPad 🎉 Anota por voz, comparte varias capturas a la vez y mira cuánto te dio o te quitó el tipo de cambio en tu Panel.
```

## Subtítulo — ≤30

- Recomendado: `Gastos con IA, voz y grupos` (27/30).
- Alternativa: `Tus gastos con IA, voz y foto` (29/30), si Grupos tiene que esperar al despliegue de la política.
- El subtítulo vivo en es **no está en el repo**: se confirma con `asc metadata pull` antes de cambiarlo.

## Keywords — ≤100 (98/100)

```
finanzas,presupuesto,dinero,ahorro,dividir,cuentas,recibos,flujo de caja,divisas,deudas,viaje,ipad
```
Sin repetir palabras del nombre ni del subtítulo, y sin espacios tras las comas. «iCloud» se queda fuera: Grupos no vive ahí.

## Descripción: **hay que actualizarla**

La vigente es `App Store/metadata/description-es.md`, anterior a 2.0. Qué falla en ella:

- **Es falso hoy:**
  - «no almacenamos nada en servidores»: Grupos y la IA pasan por servidores.
  - Usa «45+ divisas» y «más de 50» en el mismo texto. Se dice **«más de 50 divisas»** (`CurrencyCode`, 54).
- **Falta:** Grupos (ya sin la etiqueta beta), Yala IA, el iPad, el PDF de estados de cuenta, varias capturas a la vez y la exportación gratis.
- **Choca con BRAND-VOICE:**
  - «nunca fue tan fácil» y «Sin complicaciones» (§8 «Es fácil»).
  - «transacción»: usar «gasto o ingreso» (§8).
  - «Insights»: es anglicismo (§2.2), usar «Análisis con IA».
  - «Multi-cuenta»: usar «Varias cuentas».

**Bloque de privacidad propuesto**, sin hablar de la cuenta en la nube:

> PRIVACIDAD: No nos conectamos a tus bancos ni vendemos tus datos. Tú decides qué compartes con Yala.

Cuadra con la política 2.1: «No los vendemos ni los usamos para publicidad». Si algún día chocan, manda la política.

**Bullets nuevos:**
- «Yala en el iPad: barra lateral, varias ventanas, atajos de teclado y widgets grandes.»
- «Estados de cuenta en PDF: Yala los lee página por página, aunque tengan contraseña.»
- «Grupos: comparte gastos con tu gente, mira cuánto te toca y manda el resumen del viaje en una imagen. Tus grupos viven en la nube de Yala, así todos ven lo mismo.» (cuando la política esté desplegada)
- «Yala IA: pregúntale por tu dinero y pídele que anote tus gastos.» (sigue siendo Pro)
- «Exporta todos tus datos gratis, de cualquier período, en CSV o Excel.»
- «Más de 50 divisas, con tipo de cambio y el efecto que tiene en tu Panel.»

La prueba gratis de 5 notas de voz y 5 fotos sigue en `qa`: no se anuncia hasta que pase.

## Correcciones de esta versión (2026-10-13)

| Antes (borrador del 12-oct) | Ahora | Por qué |
|---|---|---|
| Novedades sin exportación (1110/4000) | Bullet «Exporta gratis…» (1183/4000) | PR #469 (D3): exportar es gratis en todos los períodos |
| Grupos «bloqueado: la política dice iCloud» | La política ya está corregida en `2.1` y falta desplegarla | PR #469, mergeado el 2026-10-12 |
| Bullet de Grupos sin decir dónde viven | «Tus grupos viven en la nube de Yala» | Política 2.1: Grupos vive en servidores de Yala, no en iCloud |
| Bullets sin divisas ni exportación | Añadidos «Más de 50 divisas…» y «Exporta…» | Criterio de copy 2.1 |
| Privacidad: «No nos conectamos a bancos» | «No nos conectamos a **tus** bancos» | Así queda claro que se habla de las cuentas del usuario |
| «Modo Nube» y «conector MCP» nombrados en la cabecera | «la cuenta en la nube (Modo Nube)» y «el conector de Claude», solo como lo que queda fuera | Es una nota interna; nada de eso entra en el copy |
