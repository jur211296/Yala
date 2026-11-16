---
id: onboarding-2-3-learn-to-record-courtesy-trial
status: qa
priority: high
area: onboarding
created: 2026-11-12
updated: 2026-11-12
source: tablero-bienvenida-2-3-paso-2-voz-foto-y-yala-ia-d1ab (docs/onboarding-2-3/SPEC.md, Y23-09)
qa-status: pending
qa-notes: el recorrido, la franja y el candado se ven en el simulador; leer la voz, la foto y la frase de Yala IA necesita red y App Attest de un iPhone, con una instalación nueva (vaciar Yala Dev), que esta sesión no podía hacer
---
# Bienvenida 2.3 · Paso 2 · Voz, foto y Yala IA con prueba de cortesía (Y23-09)

Entre una manera y otra, una pantalla con las cuatro (hecha / omitida / la que sigue), lo ya anotado y «Probar …» /
«Omitir». Voz (`VoiceRecordingView` de hoy): primero el aviso de IA de Yala y después el del micrófono de iOS. Foto
(`ImageSelectionView`): Cámara / Fotos / Archivo y «Usar el recibo de ejemplo». Yala IA (`ChatSheetView`): guía de foco
en «Apunta un gasto». Arriba de las tres, la franja «Prueba de cortesía: …, una vez gratis» con «Omitir».

Con cuenta Free, cada una funciona UNA vez dentro del tutorial (`FeatureGateService.enableSetupTrial`) y el registro se
guarda de verdad; al cerrar su pantalla vuelve el candado. Yala IA en la prueba sale como «apuntar»
(`forceIntent: .register`): solo lee la frase (`text.parse`, cubo `voice`, cupo de prueba de 5), así que el servidor no
necesita cambios — el plan Free no tiene cubo `chat` (`gateway/src/policy.ts`).

## Guion para el iPhone (Jürgen)

Montaje: iPhone 14 por cable, Yala Dev instalada desde esta rama, **cuenta sin Pro** y con red. Hace falta una
instalación nueva: Ajustes de Yala Dev › «Vaciar datos» o borrar y reinstalar Yala Dev.

1. Pasa el alta hasta el Panel. En el mazo toca «Crea tu primera cuenta» y crea una de efectivo en 0.
2. Toca «Aprender a registrar» › «Empezar a mano», guarda un gasto cualquiera y toca «Aceptar».
3. En «¡Tu primer registro!», toca «Probar con la voz». Debe salir primero «Yala lo apunta por ti»; acepta. Después,
   el aviso del micrófono de iOS; permítelo.
4. Arriba debe verse «Prueba de cortesía: la voz, una vez gratis». Di «Gasté 25 en el almuerzo», toca «Listo» y
   «Guardar». Cierra la hoja.
5. «Probar con una foto»: toca «Usar el recibo de ejemplo». Debe leer el recibo y dejarte «Guardar». Guarda y cierra.
6. «Probar con Yala IA»: si sale el permiso de Yala IA, acéptalo. Debe verse la franja y la guía sobre «Apunta un
   gasto». Tócala, escribe «Pagué 45 de luz», envía y toca «Guardar» en la tarjeta. Cierra.
7. «Ir a mi Panel»: la hoja «¿Borramos los de prueba?» debe traer los cuatro registros marcados. Toca «Conservarlos
   todos».
8. En el Panel, toca Voz, Foto y Yala IA: los tres deben pedir Yala Pro (vuelve el candado).

Si el paso 4, 5 o 6 muestra «Ya usaste tus notas de prueba» o un error de Pro, avísame con una captura.
