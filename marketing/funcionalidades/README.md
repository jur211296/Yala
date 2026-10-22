# Funcionalidades 2.1 — una ficha por función

> Fuente: `~/Claude/lola-borradores/2.1/funcionalidades-2.1.md` (investigación del 2026-10-12 sobre `origin/2.1`).
> La ficha 09 es nueva: sale de la política 2.1 (PR #469).
> Tono: `docs/planning/BRAND-VOICE.md`. Handle de X recomendado: **@yalaapp** (sin reclamar). Enlace: `https://apps.apple.com/app/id6758253109`.

**Antes de anunciar algo como «nuevo»:** Apple Pay, compartir imagen y la voz ya estaban en 2.0.4. Lo nuevo en 2.1 es *cómo* se usan, y así se cuenta.

| # | Función | Formato | Dónde se graba |
|---|---|---|---|
| 1 | [Registro por voz: hablas y confirmas en la misma hoja](01-voz-en-una-hoja.md) | IG Reel · X video corto | El Simulador sirve (usa el micrófono de la Mac), pero la IA necesita el gateway y el consentimiento de IA |
| 2 | [Compartir capturas desde Fotos o WhatsApp, varias de una vez](02-varias-capturas.md) | IG Reel · X video | Desde Fotos sirve el Simulador (el PR #456 se probó ahí) |
| 3 | [Estados de cuenta en PDF, página por página, incluso con contraseña](03-pdf-estado-de-cuenta.md) | IG Reel o carrusel (antes y después) · X video | Simulador, con un PDF de prueba sin datos reales |
| 4 | [Apple Pay: tus pagos con el iPhone llegan solos a Yala](04-apple-pay.md) | IG Reel · X video + post de texto | La guía se graba en el Simulador |
| 5 | [Grupos: tu parte clara, el reparto en una frase y el resumen del viaje en imagen](05-grupos.md) | IG carrusel (la imagen del resumen luce mucho) + Reel · X imagen + hilo | Simulador con datos sembrados |
| 6 | [Panel y Yala IA rediseñados](06-panel-y-yala-ia.md) | IG Reel o carrusel · X video | Simulador |
| 7 | [Monedas: qué te dio o te quitó el tipo de cambio](07-tipo-de-cambio.md) | IG carrusel · X post con captura | Simulador |
| 8 | [Yala en el iPad, y el iPhone en horizontal](08-ipad-y-horizontal.md) | IG carrusel · X video corto | Simulador de iPad |
| 9 | [Exporta todos tus datos gratis, de cualquier período](09-exportar-gratis.md) | IG carrusel (lámina de cierre) · X post con captura | Simulador |

## Fuera de lo público

Aunque existen en el código, no se anuncian:

- **La cuenta en la nube (Modo Nube)**: el criterio de copy de 2.1 la deja fuera de toda pieza pública.
- **El conector de Yala para Claude**: solo funciona contra staging.
- **Widgets y Siri tras salir de la app** (PR #457): es una mejora interna, no un tema para redes.
- **La prueba gratis de 5 notas de voz y 5 fotos**: el ticket sigue en `qa`; no se anuncia hasta que pase.
