---
id: 2026-11-14-bugs-entrada-lote-1
status: done
priority: high
area: "welcome, restore, cloud-adopt, groups-invite"
created: 2026-11-14
updated: 2026-11-14
card: tablero-conectar-con-la-cuenta-tarda-2250-s-sin-g8un
source: "recorrido de la bienvenida (13-nov) y barrido del iPhone 14 (14-nov)"
---

# Bugs de entrada y recuperación de 2.3, lote 1

Cinco cards del backlog de 2.3. Probado en el iPhone 14 con Yala Dev contra staging.

## 1 · «Conectar con la cuenta tarda 22–50 s» (card g8un)

**Medido** (iPhone 14, cuenta jur211296 de staging, 7.221 filas, traza temporal por paso): 55 s desde «Cargar mis datos y
entrar» hasta «¡Tu cuenta está lista!». 41 s eran la lectura de la cuenta en 15 páginas de 500 filas, y cada página
costaba ~2,5 s **aunque viniera vacía**; otros 10 s, los dos Merkle. La barra sí avanzaba (22 % → 80 %): el «0 % y
salta a lista» del recorrido era de un build anterior a la card jxbp.

**Causa:** el gateway responde `/sync/pull` y `/sync/merkle` consultando las ~22 tablas una detrás de otra.

**Arreglo:**
- App: la lectura pide páginas de 1.000 (el máximo del servidor) y el Merkle de la barra va en paralelo con ella.
  Medido: **55 s → 32 s**, sin desplegar nada.
- Gateway: las consultas por tabla van en paralelo en `/sync/pull` y `/sync/merkle` (misma respuesta). Pendiente de
  desplegar; con él cada página debería bajar de ~2,7 s a una fracción.

## 2 · «Recuperar desde iCloud: un solo "Continuar"» (card lwv1)

Con «Traer mis datos» elegido en «Ya tienes datos en tu iCloud», tras reabrir Yala «¡Qué bien volver a verte!» enseña un
solo «Continuar», sin «Empezar desde cero» ni flecha atrás. La elección se guarda en disco (`RestoreBringChoiceStore`)
porque hay un relanzamiento en medio. Desde «Restaurar desde iCloud» (puerta de Grupos) la pregunta sigue: ahí la persona
no eligió nada antes. Probado en el iPhone 14.

## 3 · «El resumen dice 63 categorías y dos pantallas después 65» (card iio7)

La sonda de iCloud cuenta las categorías de fábrica repetidas una vez (card k15r); el resumen del teléfono las contaba
fila a fila antes de que el deduplicador las fundiera. Ahora el teléfono cuenta con la misma clave
(`SubcategoryDedupLogic.visibleCount`). En el iPhone 14: 62 en la puerta y 62 en «¡Qué bien volver a verte!».

## 4 · «Con datos en iCloud, entrar con Google o Apple no menciona esos datos» (card uzfd)

Es una pregunta de producto, sin código en este lote. Ver la resolución de Jürgen en el PR.

## 5 · «El aviso de enlace no válido queda debajo de "Unirme al grupo"» (card b72m)

El scroll se anclaba en «Pegar» y el aviso va debajo. Ahora se ancla al final del bloque, después del aviso, y se lleva a
la vista también cuando aparece. En el iPhone 14, con 4 líneas en el campo y el teclado abierto, el aviso se lee entero.

## Tests

- `YalaTests/BugsEntradaLote1/BugsEntradaLote1Tests.swift`: lógica y cableado de las cards 1, 2 y 3.
- `YalaUITests/Flows/InviteRecoveryPasteVisibleUITests.swift#test_longInvalidLinkWithKeyboard_invalidLinkNoticeIsAboveJoin`.
- `gateway/test/sync.parallelFanout.test.ts` (con el handler en serie, 2 rojos).
