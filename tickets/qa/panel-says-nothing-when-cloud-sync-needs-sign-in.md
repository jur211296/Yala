---
id: panel-says-nothing-when-cloud-sync-needs-sign-in
status: qa
priority: high
area: panel, cloud-sync
created: 2026-10-28
updated: 2026-10-28
source: card pz4v del tablero (Jürgen, 2.º iPhone, 2026-10-28 ~06:10)
---

# Sin sesión de nube el Panel se ve vacío y no avisa

## Qué pasaba

Con la sesión de la nube caducada y 5 006 cambios sin subir, el Panel se veía tranquilo —saldo en cero, «Aún no tienes
registros», Primeros pasos 0 de 7— y nada decía que algo iba mal. El único aviso estaba en Ajustes › «Dónde viven tus
datos»: «Inicia sesión para subir 5,006 cambios» con su botón.

## Hecho (2026-10-28)

El Panel enseña arriba, fijo y fuera de la cola «1 de N», el mismo aviso: «Inicia sesión para subir N cambios» y «Lo que
ves aquí puede no estar al día con tu cuenta», con el botón «Iniciar sesión». Sale exactamente cuando sale la tarjeta de
Ajustes (`CloudMigrationController.syncNeedsSignIn`), con el canal estable y nunca a la vez que el aviso del attest. El
botón abre «Dónde viven tus datos» y arranca ahí el inicio de sesión, que es donde se presentan los errores. Sin X:
desaparece al volver a entrar. Decisiones D1-D5 del Paso 0 del encargo `2026-10-28-sesion-nube-panel-welcome`.

Tests: `SyncSignInBannerLogicTests` (tabla de la decisión y cableado del Panel y de Ajustes).

## Device-QA (iPhone de QA)

No se puede montar en el simulador: hace falta una sesión de la nube real que caduque.

1. En un iPhone con Yala en la nube, deja la sesión caducada (el caso del 28-oct: el teléfono que cerró sesión en el otro
   aparato, o esperar a que Ajustes › «Dónde viven tus datos» diga «Inicia sesión para subir…»).
2. Abre el Panel: arriba sale «Inicia sesión para subir N cambios» con el botón «Iniciar sesión».
3. Toca el botón: se abre «Dónde viven tus datos» y sale directamente el inicio de sesión de tu cuenta.
4. Entra con la MISMA cuenta: el aviso desaparece del Panel y los cambios empiezan a subir.
