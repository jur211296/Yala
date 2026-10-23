# Dejar la versión 2.1 de Yala lista para enviar a revisión en App Store Connect, sin enviarla

## Contexto
Jürgen dio 2.1 por lista para la App Store el 21-oct. El QA guiado (PR #563) pasó completo, y el TestFlight 2.1 (20) es válido y ya está asignado a la versión 2.1 (PR #578). Hay una card en el board, «Checklist de envío de 2.1 a App Store, verificada contra el código», en in qa. Úsala como guía. Lola es quien pulsa «Enviar a revisión», así que esta sesión deja todo listo y NO envía.

## Qué se pide
1. En App Store Connect (con la API o el navegador, como se haya hecho antes), versión iOS 2.1:
   - Confirmar que el build 20 está seleccionado.
   - Revisar que estén completos los textos de novedades, la descripción, las palabras clave, las capturas, App Privacy, la información de revisión (cuenta demo y notas), la clasificación por edad, el cumplimiento de exportación y el precio. Usar la ficha que ya existe en marketing/ y en el repo.
   - Completar lo que falte con el material de marketing/ y la biblioteca ya aprobada. Nunca escribir «OpenAI» ni «gratis» para los Grupos.
   - Revisar que las políticas y los términos estén publicados en producción (yala-app.pe), porque es requisito antes de enviar.
2. Dejar la versión en estado «Lista para enviar», con el botón de enviar a revisión habilitado.
3. Mover la card de la checklist con una nota de lo verificado y dejar una card asignada a lola: «Enviar 2.1 a revisión en App Store Connect».

## Qué NO hay que tocar
- No pulsar «Enviar a revisión» ni «Publicar».
- No subir builds nuevos ni tocar código o ramas de la app.
- No usar el simulador ni los iPhone o iPad reales de Jürgen.
- No tocar los archivos sin commitear de Jürgen en ~/Yala.
- Si falta algo que solo Jürgen puede decidir o hacer (un texto legal, un pago o un acuerdo pendiente), anotarlo claramente y cerrar igual.

## Cómo se sabe que está bien
La versión 2.1 aparece en ASC con el build 20, sin avisos de campos faltantes, y lista para que Lola la envíe. La card de Lola está creada. Al terminar, /cerrar-total.

## Paso 0 (Lola, 2026-10-21, sin nadie delante: decisiones asumidas)

- **Herramienta:** `asc` (API), como en las releases anteriores; el navegador solo para lo que la API no lee.
- **en-GB sin novedades ni texto promocional:** se rellena con el texto ya aprobado de en-US. No lleva rasgos de inglés americano, así que va idéntico.
- **Notas para el revisor:** desde el borrador verificado de `docs/RELEASE-CHECKLIST-2.1.md` §5.7, con las rutas ajustadas a las etiquetas reales de la app. Sin enlace a un grupo de prueba: crearlo pide una cuenta de Jürgen en su iPhone, fuera de alcance.
- **Imagen promocional de las suscripciones:** no se sube. Es un aviso opcional y no bloquea.
- **Card de la checklist:** a `done`. Su único paso pendiente era el envío, que pasa a la card nueva de Lola.

## Resultado

- Versión 2.1 en `PREPARE_FOR_SUBMISSION` con el build 20. `asc validate`: 0 errores y 0 bloqueantes. `asc review doctor`: «No submission blockers detected».
- Completado: novedades y texto promocional de en-GB; notas para el revisor (`marketing/App Store/review-notes-2.1.md`).
- Verificado: textos en los 13 idiomas sin «OpenAI» ni «gratis» para Grupos; capturas de iPhone 6,9" e iPad 13" en los 13; suscripciones APPROVED; `/privacy` y `/terms` en producción con fecha de octubre de 2026.
- No verificado hoy: App Privacy (la API no lo expone y ASC en el navegador pedía login). Vale la medición de Frank del 19-oct.
- Tablero: checklist `d0ui` → done; nueva `tablero-enviar-2-1-a-revision-en-app-store-conne-4upo`, asignada a lola.
