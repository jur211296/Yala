# Lote 2.2: ícono Liquid Glass con Icon Composer y subida de dSYM a Sentry en cada build

Base: origin/2.2 en jur211296/Yala. Una sola sesión, un PR contra 2.2 y un cierre. Cards:
1. «Ícono Liquid Glass de Yala con Icon Composer»: arma el ícono por capas (claro, oscuro, tintado y transparente) a partir del ícono actual, sin cambiar la marca, e intégralo en Yala y en Yala Dev. Pon capturas de las cuatro variantes en el PR.
2. «Sentry: token con escritura para resolver YALA-IOS-2 y subir los dSYM de cada build»: usa el token de Sentry con escritura que ya está en el entorno de la Mini o en Secrets.xcconfig (si no está, déjalo anotado en la card y sigue). Agrega el paso de subida de dSYM al archivado y marca YALA-IOS-2 como resuelto.
Mueve las cards a «in qa» con guion.

Termina con /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

**Ícono**
1. **Capas sacadas del PNG actual, sin redibujar.** Fondo degradado (ajustado por mínimos cuadrados: #7C7DF2 → #4F47E5 en diagonal), «yala» blanca, estrella cian y barra rosa, separadas por color con su alfa de borde. Recomponerlas da el PNG original con error ≤ 4/255. Así la marca no cambia.
2. **Dos grupos de cristal**: la estrella sola (sombra de su color) y palabra + barra (sombra neutra). Glass encendido y translucidez 0,3.
3. **Oscuro con índigo profundo** (#333185 → #1A1655), no el negro por defecto de iOS: conserva la marca.
4. **Tintado: estrella y barra en blanco**; con su color, la barra rosa casi desaparecía en tintado oscuro. Transparente: lo genera el sistema.
5. **`Yala/Resources/AppIcon.icon` con el mismo nombre que el ícono de catálogo**: Xcode usa el `.icon`. Yala y Yala Dev son el mismo target (Debug-Dev/Release-Dev), así que basta uno. `AppIcon.appiconset` se queda como respaldo y los alternativos (Light, Neon, Dark) no se tocan: el encargo es el ícono principal.
6. **Capturas** con `ictool` (el renderizador de Icon Composer) de las seis variantes + el ícono en la pantalla de inicio del simulador.

**Sentry**
7. **El token no está** ni en el Llavero (`sentry-yala`/`jur`) ni en `Secrets.xcconfig` ni en el entorno. El bot dueño confirmó: no se pasa por chat; el paso lee el Llavero y nunca se escribe en el repo. YALA-IOS-2 queda sin resolver, anotado en la card y en «Necesita de ti» sin BLOQUEANTE.
8. **El paso va como post-action «Archive» del scheme `Yala`**, no como fase de build: corre fuera del sandbox de scripts, recibe `ARCHIVE_DSYMS_PATH` (app, widgets y share) y sirve para cualquier sesión que archive. Lo llama `scripts/sentry-subir-dsym.sh`, que también se corre a mano sobre un archivado o un zip de dSYM (el de 2.2 (7) está guardado en entregas).
9. **Sin token o sin sentry-cli, el archivado no se rompe**: avisa y deja el motivo en `<archivo>-sentry-dsym.log` junto al archivado. A mano, el fallo sale con 1.
10. **sentry-cli instalado en la Mini con Homebrew** (`getsentry/tools/sentry-cli`, 3.8.2): es la herramienta oficial; sin ella no hay subida.
11. El cambio ajeno sin commitear del árbol principal toca la parte de tests de `Yala.xcscheme`; el mío, la de archivado: no chocan.

**Cambio sobre el Paso 0 (2026-11-04, a mitad de sesión):** Jürgen guardó el token con escritura en el Llavero (`sentry-yala`/`jur`). Con él:
- YALA-IOS-2 resuelto **en la release `com.jurgenschmidt.yala@2.2+6`**, la primera que trae el arreglo del congelamiento (el merge del arreglo es ancestro del bump a 6). Si vuelve a salir en 2.2 (6) o después, Sentry lo reabre.
- dSYM de 2.2 (7) (el build de TestFlight, guardados en entregas) subidos a mano: UUID de Yala `625D29AB-…` visible en Sentry.

## Resultado
- Ícono: `Yala/Resources/AppIcon.icon` (3 capas, 2 grupos). Build `Yala` y `Yala Dev` ✓; el archivado Release lleva la pila de capas (`IconImageStack`); en la pantalla de inicio del simulador sale el ícono nuevo. Capturas en `qa/evidencia-icono-liquid-glass-20261104/`.
- dSYM: archivado de prueba de `Yala` Release ✓ y el post-action subió solo sus 3 dSYM (UUID de Yala `6D7A7827-…` = el del binario). Sin dSYM, sale 0 y lo deja escrito en el registro; a mano, una ruta que no existe sale 2.
