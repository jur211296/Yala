---
id: welcome-to-pro-still-lists-the-old-feature-names
status: done
priority: low
area: pro, copy
created: 2026-10-19
updated: 2026-10-22
source: lote decidido 2.2 · 06 — Yala Pro (encargo 2026-10-19-lote-decidido-2-2-06-yala-pro, PR #561)
---

# La bienvenida a Pro sigue listando las 7 funciones con los nombres viejos

## Qué pasa

`SubscriptionSuccessView` enumera las siete funciones con los textos de antes («Registro por voz ilimitado», «Escaneo de recibos e imágenes», «Iconos de app premium»…). Desde el lote 06 el paywall dice lo mismo con otras palabras («Apunta hablando», «Apunta con una foto», «Temas e iconos»), y «Registro por voz ilimitado» fue señalado en L17-2 porque sugiere que gratis hay un poco de voz (no hay nada).

## Contexto

La decisión L17-9 solo pidió quitar el brillo a la bienvenida y abrir la función al tocar «Comenzar»; la lista no se tocó.

## Pregunta para Jürgen

- A. Dejarla.
- B. Usar las mismas fichas de «Qué incluye Pro» del paywall. ← recomendada: una sola forma de decir qué incluye Pro.

## Hecho (2026-10-22, lote decidido 2.2 · 15)

Implementada la opción que eligió Jürgen. Red: `YalaTests/UXAudit22Decidido15Tests` y `YalaUITests/Flows/SettingsLote15UITests`.
