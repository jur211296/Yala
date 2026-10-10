---
id: transaction-service-bulk-block-is-dead-code
status: backlog
priority: very-low
area: "arquitectura, tech-debt"
created: 2026-09-08
source: barrido del patrón de bulk-update-account-leaves-converted-amount-stale (2026-09-08)
updated: 2026-10-08
---

# El bloque bulk de `TransactionService` es una copia paralela muerta de la del ViewModel

## Qué pasa

Al arreglar `bulk-update-account-leaves-converted-amount-stale` se midió el alcance real, y es mayor
que el que decía aquel ticket. No había un método huérfano: hay **dos implementaciones completas y
paralelas** del bloque de edición masiva.

`BulkEditSheet` —la única pantalla que hace edición masiva de transacciones— llama a
`RecordsViewModel` para **las seis** operaciones. Los seis gemelos de `TransactionService` no los
llama nadie:

| Operación | Ruta viva | Copia en el servicio |
|---|---|---|
| `bulkUpdateAccount` | `RecordsViewModel:510` | **borrada el 2026-09-08** (tenía dos bugs) |
| `bulkUpdateSubcategory` | `RecordsViewModel:533` | `TransactionService`, sin llamador |
| `bulkAddTags` | `RecordsViewModel:557` | `TransactionService`, sin llamador |
| `bulkRemoveTags` | `RecordsViewModel:593` | `TransactionService`, sin llamador |
| `bulkUpdateNote` | `RecordsViewModel:635` | `TransactionService`, sin llamador |
| `bulkUpdateAmount` | `RecordsViewModel:666` | `TransactionService`, llamado **solo por su test** |

Medido con `git log -S` sobre todas las ramas: ninguno tuvo jamás un llamador de producción. Nacieron
en el refactor C.3 (`461cc0ea`, 2026-01-29) para "estandarizar operaciones", y la migración de la UI
no llegó a hacerse.

## Por qué importa aunque sea código muerto

**Porque ya divergió una vez, en silencio y por el peor sitio.** Un mes después del refactor,
`2eb7acc6` arregló la integridad del bulk edit **en el ViewModel** y la copia del servicio se quedó
atrás. El resultado fue `bulkUpdateAccount` con dos daños que la ruta viva no tenía: no recomputaba
las derivadas de divisa y no bloqueaba transferencias. Nadie lo notó en los **6 meses y medio** que
van de aquella divergencia (23-feb) a hoy, porque el código muerto no falla: espera.

Los cinco que quedan son fieles a la ruta viva **en integridad de datos** (comparados uno a uno el
2026-09-08), que es lo que importa para el bug de este ticket. En otra cosa ya divergen los cinco: los
del servicio refrescan `WidgetDataCache` y los seis del ViewModel no. El riesgo no es que estén mal
ahora, es que el próximo arreglo del ViewModel vuelva a dejarlos atrás.

## Opciones

1. **Borrar los cinco** (y con ellos el test de `bulkUpdateAmount`, que es lo único que los ejercita).
   El más limpio — pero **no deja «lo que sí se usa», y conviene saberlo antes de elegir**: medido, los
   únicos usos vivos del servicio en todo el repo son `setContext` y `create` (`ChatAssistantViewModel`
   y `AppBootstrapper`). `save`, `delete` y `deleteMultiple` tampoco los llama nadie, así que borrar
   los cinco bulk deja **tres métodos muertos más** y el ticket real es mayor que su título.
2. **Migrar la UI al servicio y borrar los del ViewModel.** Es la intención original del refactor C.3,
   pero los del ViewModel tienen hoy la lógica buena y son los que están probados: la migración habría
   que hacerla en esa dirección, no en la contraria. Más caro y sin beneficio visible para el usuario.
3. **Dejarlo y documentarlo.** Es lo que hay hoy, y ya se cobró un ticket.

## Criterio de hecho (AC)

- [ ] Elegida una de las tres, con el motivo escrito.
- [ ] Si se borra: comprobar que ningún test ni source-scan depende de esos símbolos —
      `TransactionServiceTests` ejercita `bulkUpdateAmount` y habría que decidir si su caso de
      coherencia del grupo `money` se muda a la ruta viva (donde ya vive el de la cuenta, en
      `RecordsViewModelBulkAccountCurrencyTests`) o se pierde.

## Medido en 2.1 (triage 2026-10-08)

- Los cinco siguen en `TransactionService.swift` (`:146-245`) y ninguno tiene llamador de producción; `bulkUpdateAmount` solo lo usa su test. El fichero no tiene commits tras `48120f915` (el que borró `bulkUpdateAccount`).

Triage 2026-10-08: abierto · low → very-low · siguen los cinco métodos muertos; es deuda técnica sin efecto para el usuario mientras nadie los llame.
