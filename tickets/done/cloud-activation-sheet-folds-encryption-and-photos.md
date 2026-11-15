---
id: cloud-activation-sheet-folds-encryption-and-photos
status: done
priority: medium
area: "cloud, settings, privacy"
created: 2026-11-12
updated: 2026-11-12
card: tablero-2-3-nube-cifrado-y-fotos-a-la-vista-al-a-1agd
source: "revisión 2.3 por vistas, zona 41 (nube y almacenamiento), problema 2 · decisión 52 de la discusión del 9-nov (opción H1)"
qa-status: passed
---

# Al activar la nube, el cifrado y las fotos quedaban plegados en «Ver los detalles»

La hoja «Antes de activar la nube» de Ajustes › Dónde viven tus datos enseñaba tres líneas y escondía tras «Ver los
detalles» lo que no se deshace solo: que no hay cifrado de extremo a extremo y que las fotos de los recibos no viajan.
Aceptar era tocar «Continuar con Apple» o «con Google», así que se podía aceptar sin haberlo visto.

## Hecho cuando

La hoja enseña de entrada, una línea cada uno, el cifrado, las fotos y «Exportar una copia antes», y «Ver los detalles»
desaparece. La bienvenida no se toca (H2 no se eligió).

## Resolución (2026-11-12)

- «Yala puede ver tus datos» dice ahora «Para darte soporte y funciones inteligentes. No hay cifrado de extremo a
  extremo.»
- Fila nueva: «Las fotos de tus recibos no viajan · Yala no las guarda ni las sube a tu cuenta.»
- «Exportar una copia antes» sigue a la vista, bajo «Tu entrada es tu Apple o tu Google».
- «Ver los detalles» y su texto legal desplegable se fueron, con sus tres textos en los 16 idiomas.
- **Sin cifra de fotos**, aunque la decisión la pedía («tienes 23»): medido en el código de 2.3, Yala no guarda fotos de
  recibos (ningún modelo tiene foto; se leen para crear el registro y se sueltan), así que no hay nada que contar.
  Jürgen eligió el 12-nov la fila sin cifra.
- El contrato del consentimiento no cambia de versión: los tres puntos siguen dichos, ahora a la vista.

Test: `PendingICloudWipeMigrationUITests#test_activationSheet_showsEncryptionPhotosAndExport_atFirstSight`, rojo con el
código anterior («La hoja sigue plegando el cifrado y las fotos tras "Ver los detalles"») y verde con el arreglo. Comprueba
además que las tres líneas quedan dentro de la hoja tal como abre y por encima de los botones de entrar.
