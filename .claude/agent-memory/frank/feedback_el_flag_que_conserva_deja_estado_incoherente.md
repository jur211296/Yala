---
name: el-flag-que-conserva-deja-estado-incoherente
description: Partir un borrador destructivo con un flag «conserva las preferencias» deja puesto el estado DERIVADO de las filas borradas, y eso rompe la app por una vía silenciosa. El corte hay que escribirlo y enumerarlo.
metadata:
  type: feedback
---

**Cuando partas un borrador destructivo con un flag, «conservar las preferencias» y «conservar el estado
derivado de las filas» son dos cosas distintas, y solo la primera es la decisión de producto.** El corte
se escribe en una frase y se enumera; si no, el flag deja incoherencias que nadie ve hasta que muerden.

**Why:** el 2026-09-14, partiendo `DataWipeService.wipeAllUserData` con `resetsPreferences: Bool = true`
(decisión de Jürgen). La rama `false` conservaba el nombre y la divisa —correcto— y **también el
centinela `seedCategoriesExecuted`**. Un alta solo-grupos lo deja en `true` siempre, y
`seedCategoriesIfNeeded` sale por su flag guard **antes de mirar la base**: el seed del final del
onboarding pasaba a ser un no-op silencioso, así que la persona terminaba **sin ninguna categoría** — y
sin «Ajuste de saldo», con lo que el saldo inicial de su primera cuenta falla sin decir nada. Ninguna de
las tres decisiones de producto lo preveía, y el ticket tampoco.

Y no era uno: la lente de reglas encontró que la rama enumeraba **3 de ~10**. Faltaban los contadores
(`transactionsSavedCount` y su `pro.milestone.lastShown`), las huellas de drafts borrados, el barrido por
prefijo de dedup de notificaciones —cuyo `creditCardNotif_` SILENCIA el recordatorio de la cuenta
entrante—, los centinelas de migración de shortcutIDs, el estado del servicio de tipos de cambio (que
frena la recarga del histórico **30 días**) y la checklist de puesta en marcha.

**How to apply:**

- **El criterio, en una pregunta:** *¿esta key seguiría siendo verdad si el usuario no hubiera borrado
  nada?* Si no, se va en los DOS borrados; si describe a la persona (nombre, tema, toggles), se queda.
  Escríbelo en el docblock del parámetro: sin él, el siguiente que añada una key no sabrá dónde ponerla.
- **Enumera leyendo la función entera**, no la parte que te suena. Los ~114 `removeObject` de un barrido
  tienen secciones con nombre, y una de ellas ya se llama «derivados de los datos borrados».
- **Una sola lista, dos llamadores.** Los helpers extraídos (`reopenSeedGates`, `removeRowDerivedKeys`)
  los llama también la rama de siempre, que antes los enumeraba. Dos listas que «siempre van juntas»
  divergen en el commit siguiente, y aquí divergen hacia el lado que deja al usuario sin datos.
- **Mira también lo que está FUERA del bloque que el flag gatea.** `ProfileImageStorage.delete()` vivía
  cinco líneas por encima de `resetAllUserPreferences()`, así que el primer diseño borraba la foto de
  perfil mientras conservaba `userName`, `userAlias` y `userProfileIcon` — las cuatro son la misma
  sección del barrido.
- **Y no lo barras todo por simetría**: un reset «entero» (`AppRouter.resetAll()`,
  `DeferredIntentBuffer.clear()`) puede llevarse dentro cosas del dominio que el flag existe para
  conservar — ahí un `.navigateGroupDetail(groupID:)` de un grupo vivo. Mide el alcance de cada reset
  antes de invocarlo, incluso cuando te lo propone una lente de review.

Relacionado: [[feedback_mis_mediciones_fallan_por_el_filtro]] · [[feedback_prefiere_lo_limpio_a_lo_defensivo]] ·
[[feedback_la_correccion_de_la_lente_reintroduce_el_bug]]
