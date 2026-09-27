# Cerrar la sesión privada ya no borra lo local a mitad de una migración a la nube

## Contexto
Cola A autónoma (riesgo real): residual de PR #273 / `apple-id-change-boot-check-runs-before-the-migration-guard-can-see`. Ese PR ya protege la OFERTA del aviso de cambio de Apple ID con `migrationAtRest`. Queda el hueco: el cierre privado por Perfil (u otro camino que no sea esa oferta) no mira la migración y puede borrar lo local mientras sube.

Ticket: `tickets/backlog/private-sign-out-proceeds-with-a-migration-in-flight.md`
Rama base: 2.1 (ya lleva #273).

Horario Lima nocturno (21:00–6:00): elige la opción robusta / recomendada sin AskUserQuestion. Solo aparca en ticket propio si la decisión es demasiado irreversible para asumirla.

## Que se pide
- El escritor del cierre privado (no cada pantalla) se para con la migración fuera de reposo, reutilizando el mismo predicado `migrationAtRest` (u homólogo compartido) y un motivo propio en el aviso.
- Cubrir `CloudSessionSignOut` / `CloudSignOutFlowLogic` / caminos de Perfil y avisos que cierran sin pasar por la oferta automática.
- Test del escritor con migración en vuelo + control positivo en reposo.
- Mover el ticket en `tickets/` y actualizar `docs/TICKETS.md`.
- Gate, PR a 2.1, merge, board al día, `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Implementa de punta a punta sin pedir «¿Sigo?» ni parar por la regla de «>3 files → wait for approval». Sigue hasta gate / commit / PR / merge a 2.1 / board / `/cerrar-total`. No preguntes por continuar tras el plan.

## Que NO hay que tocar
- No reabrir ni reescribir el guard de la oferta automática de Apple ID salvo que haga falta compartir el predicado.
- No decidir ni implementar `apple-id-change-check-stays-off-after-a-failed-migration` (low, espera decisión de producto sin prisa).
- No marketing/. No datos de clinicas-dentales-bi. No prod Supabase.

## Como se sabe que esta bien
- Con migración en vuelo, cerrar por Perfil (u otro escritor privado) se para con aviso claro; en reposo, el cierre sigue igual.
- Tests verdes del escritor + controles.
- Ticket en done o qa según corresponda; PR mergeado a 2.1; `/cerrar-total` limpio.

## Paso 0

Decidido antes de escribir (sesión nocturna, auto-contestado):

1. **Un solo predicado.** El cierre usa `AppleIDChangeCloseLogic.migrationAtRest` tal cual. Lo que se comparte es la
   LECTURA de sus seis insumos (`MigrationRestReading.live`), que hoy vive dentro de `AppBootstrapper`: el guard de la
   oferta pasa a leerla de ahí, sin cambiar de comportamiento.
2. **Dónde para el escritor.** En `CloudSessionSignOut`, en dos sitios: al empezar el cierre (nada escrito aún) y pegado
   al arm del borrado, sin `await` entre la comprobación y el arm (cubre la migración que arranca durante la espera).
   No en cada pantalla.
3. **Qué celdas.** Las dos con sesión privada (`.privateOnly`, `.privateWithGroups`). Solo-grupos no: su store personal
   es el neutro vacío y no hay nada suyo que pueda estar subiendo. La nube tampoco: tiene su propio candado del motor.
4. **Motivos propios, dos.** `.migrationInFlight` (manda a «Dónde viven tus datos», que con la migración fuera de reposo
   se ve) y `.migrationUnreadable` (journal ilegible: esa fila puede estar oculta, así que dice «cierra y abre Yala»).
5. **Una migración FALLIDA también para el cierre.** Es lo que dice el predicado compartido; la salida es «Reintentar».
   Abrirlo es la decisión pendiente de `apple-id-change-check-stays-off-after-a-failed-migration`: se anota allí.
6. **Welcome.** La puerta de Grupos del Welcome usa el mismo escritor: lleva rama propia con un texto que no manda a
   Perfil (en el Welcome no existe).
7. **Test.** Override de la lectura en el coordinador (patrón `…Override` de los servicios), test del escritor con la
   migración en vuelo + control en reposo, tabla pura del motivo, y scans del orden en los dos sitios.

**Corregido tras la review (2026-09-27):** el punto 3 era falso —solo-grupos también puede migrar— y el cierre para en
las tres celdas por archivos. El punto 2 gana un tercer sitio: la entrada de `finalizeSessionExit`, por donde retoman los
cierres bloqueados sin pasar por el inicio.
