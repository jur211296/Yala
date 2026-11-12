# S12g · Estadísticas: cápsula del chip cortada al pulsar (glass)

**Card:** tablero-estadisticas-el-chip-activo-se-corta-arr-xl7q
**Prioridad:** high · **Cierre:** cierra-sola · **Versión:** 2.2
**Orden:** tras S12f (Nuevo registro); antes de S12d (Welcome)

## Qué hay que hacer
Dar espacio vertical al contenedor de chips (y revisar la píldora del período si aplica el mismo patrón) para que el efecto glass al pulsar pueda expandirse sin cortarse.

## Contexto (corrección de Jürgen 2026-10-27 ~20:44)
- **2026-10-27 ~21:22:** Jürgen confirma que en **Grupos** la animación de chips está perfecta; no tocar Grupos. El recorte del press/glass es de **Estadísticas** (y píldora de período si aplica).

- **En reposo se ve bien** — cápsula ordenada, no hay que “arreglar” el estado quieto.
- **Al poner el dedo** el glass quiere hincharse/expandirse y los límites del row lo cortan **arriba y abajo en recto**.
- Capturas de Jürgen en el chat (también en `~/Claude/entregas/Yala--chips-capsula-recorte/`): reposo OK; al press del chip de Tendencias el glow queda aplastado con bordes planos.
- El tirón/solape ya se corrigió en S12c (PR #656). Esto es solo el clip del press/glass.

## Qué se pide
1. Localizar el row de chips de pestaña (mismo sitio que S12c).
2. Ampliar altura / quitar clip / dar padding vertical al contenedor para que el glass del press dibuje cápsula completa (curvas arriba y abajo), no rectángulos truncados.
3. Misma revisión en la píldora del período si al press se corta igual.
4. Verificar en sim: reposo intacto + press en cada chip sin corte; vídeo/capturas después.
5. Terminar con `/cerrar-total`.

## Qué NO hay que tocar
- No cambiar el look en reposo si ya está bien.
- No reabrir tirón/solape salvo regresión.
- No barrer otras animaciones (S27c).
- **No tocar Grupos** (Jürgen 21:22: ahí está perfecta). Si el componente es compartido, el cambio debe quedar acotado a Estadísticas o con flag de pantalla.

## Cómo se sabe que está bien
- Reposo igual de limpio.
- Al press, el glass crece con libertad (cápsula completa, sin bordes planos arriba/abajo).
- Captura o vídeo después del press sin recorte.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Causa** (medida en el simulador, iPhone 17 Pro, iOS 27.0): el `ScrollView(.horizontal)` de la fila de chips de
   Estadísticas recorta su contenido a sus límites; el cristal `.regular.interactive()` del chip crece al pulsar y
   sale con bordes planos. Grupos lleva `.scrollClipDisabled()` en la misma fila y por eso allí se ve bien.
2. **Arreglo**: `.scrollClipDisabled()` en `DetailContainerView.navigationChipsBar`. No se toca `NavigationChipButton`
   (compartido) ni Grupos: el cambio queda acotado a Estadísticas, como pide el encargo. El reposo no cambia (la
   cápsula y el aire de `navigationChipsInset` siguen igual). El fundido hacia la barra vertical del Duo ya prevé
   carruseles sin recorte (su máscara se sale 10.000 pt por los lados).
3. **Píldora del período**: medida, no aplica. La píldora abre su menú al pulsar y las flechas dibujan el círculo
   entero. No se toca.
4. **Planificación y Reportes** tienen la misma fila sin `.scrollClipDisabled()`: otro objeto, fuera del encargo.
   Se anota en «Encontrado», no se toca.
