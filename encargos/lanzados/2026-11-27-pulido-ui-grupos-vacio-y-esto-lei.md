Yala
# Pulido: botones de registro arriba en Grupos y Personas sin gastos, y «Esto leí» en grande con fondo de card y deslizar para rechazar o eliminar
---
toca: Yala/App/Views/Groups/GroupRecordsView.swift,Yala/App/Views/Voice/MultiDraftReviewList.swift,Yala/App/Views/Voice/VoiceDraftReviewCard.swift,Yala/App/Views/Image/ImageSelectionView.swift,Yala/App/Views/Image/ImageEntrySheetHeight.swift,Yala/App/Logic/PulidoGruposVacioEstoLei/,Yala/Resources/de.lproj/PulidoGruposVacioEstoLei.strings,Yala/Resources/en-GB.lproj/PulidoGruposVacioEstoLei.strings,Yala/Resources/en.lproj/PulidoGruposVacioEstoLei.strings,Yala/Resources/es-419.lproj/PulidoGruposVacioEstoLei.strings,Yala/Resources/es-AR.lproj/PulidoGruposVacioEstoLei.strings,Yala/Resources/es-ES.lproj/PulidoGruposVacioEstoLei.strings,Yala/Resources/es.lproj/PulidoGruposVacioEstoLei.strings,Yala/Resources/fr.lproj/PulidoGruposVacioEstoLei.strings,Yala/Resources/it.lproj/PulidoGruposVacioEstoLei.strings,Yala/Resources/ja.lproj/PulidoGruposVacioEstoLei.strings,Yala/Resources/nl.lproj/PulidoGruposVacioEstoLei.strings,Yala/Resources/pl.lproj/PulidoGruposVacioEstoLei.strings,Yala/Resources/pt-BR.lproj/PulidoGruposVacioEstoLei.strings,Yala/Resources/pt-PT.lproj/PulidoGruposVacioEstoLei.strings,Yala/Resources/pt.lproj/PulidoGruposVacioEstoLei.strings,Yala/Resources/zh-Hans.lproj/PulidoGruposVacioEstoLei.strings,YalaTests/PulidoGruposVacioEstoLei/,YalaUITests/PulidoGruposVacioEstoLei/,tickets/backlog/2026-11-27-pulido-ui-grupos-vacio-y-esto-lei.md,tickets/done/2026-11-27-pulido-ui-grupos-vacio-y-esto-lei.md
modelo: opus
esfuerzo: medium
cierre: cierra-sola
release: no
pruebas-ui: si
depende: Yala/trabas-flujo-proyeccion-y-convertir-a-compartido
---

Decisión de Jürgen (27-nov, Lima; t2011u): «En Grupos/Personas sin gastos, la fila de botones (Nuevo gasto, Voz, Foto, Yala IA) sube justo debajo de los chips y solo queda centrado Sin gastos; en Esto leí (presentación large), las tarjetas llevan fondo de card como en Panel y gesto de deslizar para rechazar o eliminar». Espera a «Trabas: proyección inteligente…», que también toca `ImageSelectionView.swift`.

## Contexto
- Cards del tablero de Yala 2.3: «Grupos y Personas sin gastos: anclar botones de registro arriba debajo de los chips» y «Esto leí en modo grande: fondo de card como en Panel y deslizar para rechazar o eliminar». Al terminar, muévelas a «in qa» con nota del PR.
- Capturas de referencia de Jürgen (en Mini y Max): `~/Claude/flota/referencias/pulido-grupos-y-esto-lei/grupo-sin-gastos-hueco.png` (el hueco: los botones quedan centrados junto a «Sin gastos») y `~/Claude/flota/referencias/pulido-grupos-y-esto-lei/esto-lei-large-plano.png` (las tarjetas de «Esto leí» en grande, planas sobre el fondo).
- «Esto leí» con varias lecturas a revisar se presenta solo en `.large` (`ImageEntrySheetHeight.swift`, `showsSeveralToReview`); la lista es `MultiDraftReviewList.swift` con `VoiceDraftReviewCard.swift`, y la hoja de foto es `ImageSelectionView.swift`. Confírmalo al abrir; si la vista real vive en otro archivo fuera de `toca:`, no lo toques: anótalo.
- El fondo estándar de card del Panel es `CardBackgroundView` (`Yala/App/Views/Panel/DisenoTarjeta/CardFaceComponents.swift`): úsalo tal cual, **sin editarlo** (lo toca otra sesión en paralelo).

## Qué se pide
1. **Grupos y Personas sin gastos** (`GroupRecordsView.swift`): en el estado vacío, `quickActions` (Nuevo gasto, Voz, Foto, Yala IA) queda anclado arriba, justo debajo de los chips, igual que cuando hay gastos; solo `YalaEmptyState` («Sin gastos») queda centrado en el espacio que sobra. Vale para la sección de Grupos y la de Personas. Texto al máximo y girado sin que se monten.
2. **«Esto leí» en `.large`**: cada tarjeta lleva el fondo estándar de card como en el Panel (claro y oscuro), y se puede **deslizar** para rechazar (si es una lectura nueva) o eliminar (si ya estaba guardada), con el mismo resultado y confirmación que los botones actuales, y su alternativa de accesibilidad (acción de VoiceOver). Maneja bien la única tarjeta y la última: que la hoja se cierre o pase al estado correcto sin quedar vacía ni romper la altura. No cambies la presentación en otras alturas.
3. Pruebas: unitarias de la lógica que agregues (en `Yala/App/Logic/PulidoGruposVacioEstoLei/` si hace falta) y de interfaz del deslizar (rechazar, eliminar, única y última) y del vacío de Grupos y Personas.
- Textos nuevos solo en una tabla de strings propia (`PulidoGruposVacioEstoLei.strings`) en las 16 `.lproj`, con traducción real; nunca `Localizable.strings`.
- **Dispositivos:** en la Max puedes usar un segundo simulador además del de otra sesión; en la Mini, uno solo. Apaga y limpia los que enciendas. **iPhone 14** («iPhone de JURGEN», UDID `00008110-001A35A6267A401E`) por DeviceMCP con candado ADR-132 (hook `candado_dispositivo.py`): si está ocupado por otra sesión, **no reintentes en bucle**; sigue con el simulador u otra parte y vuelve a probar una sola vez más tarde; si sigue ocupado, anótalo en «Saltado o asumido sin preguntar». Antes comprueba con `xcrun devicectl device info lockState --device 00008110-001A35A6267A401E` que no esté bloqueado. No borres datos del iPhone salvo «Vaciar datos» o «Eliminar cuenta» dentro de Yala Dev cuando el encargo lo diga.
- Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final. Si una prueba falla 2 veces por timeout, anótala como inestable y sigue. Ninguna espera de más de 3 min sin escribir avance.
- Build iOS en pipeline serial: limpiar, `xcodebuild -jobs 2` sin simulador encendido, encender un simulador, probar y apagarlo. Antes de compilar mira la carga: si otra sesión compila en la misma máquina y la carga pasa los núcleos, espera en tramos cortos con aviso.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.

## Qué NO hay que tocar
- Nada fuera de `toca:`. Ni `CardBackgroundView`, ni `Yala/App/Views/Panel/`, ni `GroupExpenseFormView.swift`. Si hace falta, anótalo en «Saltado o asumido sin preguntar».
- Sin cambios de esquema de SwiftData, CloudKit ni Supabase.

## Cómo entregar
- Base 2.3, un PR, sin firma de IA en commits ni PR, con auto-merge activado; cierra sin quedarte esperando: los conflictos los relanza el vigía.
- Entrega final: artifact visual de Claude con capturas antes/después (claro y oscuro) del vacío de Grupos y de Personas y de «Esto leí» en grande, más el deslizar en acción (ADR-130 de casa); no Markdown, PDF ni documento de puro texto. Enlázalo en «Qué salió».
- Lo vital, según el modo fijado al arrancar: en semi preguntas y esperas con la sesión viva; en nocturno dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin mergear ni subir lo incompleto. Lo menor, con la opción recomendada, en «Decidido sin consultar».
- Cierre con `/cerrar-total` cuando el trabajo esté completo y el modo lo permita, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada», y el link del artifact. `BLOQUEANTE:` solo si algo de verdad no puede seguir sin Jürgen. Español neutro latinoamericano.

## Paso 0 — decisiones

*Modo semi. Las dos de producto las contestó Jürgen en la sesión (27-nov); el resto, con la recomendación.*

1. **Fondo de card en «Esto leí» grande** — el encargo apuntaba a `CardBackgroundView`, que es el degradado de las
   tarjetas de CUENTA. Jürgen: **el de los widgets del Panel** (`.thCard` + `theme.cardBorder`). `CardBackgroundView`
   no se usa ni se toca.
2. **Deslizar una fila ya guardada** — Jürgen: **borra el registro que creó**, con la misma pregunta que «Eliminar» de
   un registro (`RecordDeleteConfirmationText`). Lo de un grupo no se desliza (`RecordBulkActionLogic`).
3. **Deslizar una lectura nueva** = «Descartar» del editor y de la Bandeja (`DraftService.rejectDraft`, a Archivados),
   sin pregunta y con el aviso «Deshacer» de siempre (`DraftDiscardUndoNotice`).
4. **«En grande»** = la hoja se VE grande (borde de arriba ≤ 120 pt), no el detent elegido: la captura de Jürgen es la
   hoja parcial subida por el teclado, con fondo del sistema y la tarjeta del mismo gris. Ahí el fondo pasa a `.subtle`
   (`ImageEntrySheetHeightLogic.background`); a media altura nada cambia.
5. **El gesto**: reconocedor de UIKit que solo arranca en horizontal (como `HorizontalSwipeGesture`, para no quitarle el
   scroll), botón que asoma detrás, deslizamiento completo ejecuta. VoiceOver: acción personalizada en la tarjeta/fila.
6. **Última y única**: quitar la última fila cierra la hoja; si lo que queda ya está guardado, se cierra como al guardar.
7. **Grupos vacío**: la fila de botones arriba (bajo cabecera/chips) y «Sin gastos» centrado en el resto, en el mismo
   `GroupRecordsView` (sirve a Grupos y a Personas). Sin `ScrollView` nuevo: el título grande vive en el scroll de la
   rama con gastos y un scroll en el vacío lo fundiría.
8. **Textos**: se reusan «Descartar» y «Eliminar» existentes; si no hace falta texto nuevo, no se crea la tabla
   `PulidoGruposVacioEstoLei.strings`.
