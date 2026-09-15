---
name: la-poblacion-de-un-bug-se-mide-antes-de-arreglarlo
description: "Antes de cerrar un hueco en código, mide a cuánta gente alcanza — hay CUATRO fuentes en este repo y las cuatro son baratas; el 14-sep la respuesta fue cero y el arreglo habría tenido coste real contra beneficio nulo"
metadata:
  type: feedback
---

**Antes de escribir el arreglo de un hueco, mide su POBLACIÓN.** En este repo hay cuatro fuentes
independientes y ninguna cuesta más de un comando:

1. **Telemetría propia** (Analytics Engine, dataset `yala_metrics`, retención **90 días**). Casi todo
   camino de alta o de conversión emite su evento: `MetricsService.localRegistrationCompleted(mode:)`
   distingue `initial`, `groupsOrganizer`, `groupInvite`. Y **`MetricsService.start()` corre
   incondicional en el cold launch** —sin opt-in ni consentimiento, solo lo apaga `-uitest`—, así que
   la ausencia de eventos es un dato, no un hueco de instrumentación. El acceso está en
   [[reference-cloudflare-analytics-token]]. Control negativo y positivo **siempre**: un `detail`
   inexistente tiene que dar 0, y el censo sin filtro tiene que devolver filas con fechas.
2. **El backend** (Supabase `yala-modo-nube-production`). Un alta de Grupos deja identidad: si
   `auth.users` está en 0, no hubo alta. El MCP entra como rol `postgres` ⇒ RLS no oculta nada; el
   control positivo es contar migraciones y tablas en la misma consulta.
3. **El universo de exposición, con `asc`** — y esta es la que se me olvida. `asc versions list` dice
   qué sirve la App Store **de verdad** (el 14-sep: 2.0.4, de julio), `asc builds list` qué subió a
   TestFlight y cuándo, y `asc testflight testers list` **cuánta gente hay** (eran 3). Un camino que
   solo viajó en TestFlight tiene un universo de un puñado de personas, y eso cambia la prioridad de
   cualquier ticket.
4. **¿Ha corrido ese código alguna vez?** `git show <commit-del-build>:<fichero>` contra los commits
   de bump de `CURRENT_PROJECT_VERSION`. El 14-sep ningún build distribuido contenía el tipo entero
   que el bug necesitaba para dispararse.

**Why:** el 2026-09-14 el ticket `remote-wipe-axis-misses-groups-only-installs-before-the-mount-mark`
pedía cerrar un hueco real —a un teléfono prestado se le vaciaban los datos por orden de otro— y
ofrecía como alternativa medir la población. Salió **cero por las cuatro vías**. Y el arreglo no era
gratis: las señales candidatas derivaban el eje de una AUSENCIA, que **falla ABIERTO** y le esconde
las cuentas a alguien con su vida personal entera cuando el store tarda en montar. Coste real contra
beneficio nulo. Jürgen zanjó el fork: se cierra con el número.

**How to apply:**

- Un ticket que diga «esta población sigue afectada» es una **afirmación verificable**, igual que una
  coordenada. Mídela antes de diseñar nada.
- Cuando cierres por población, **deja escrito qué la reabriría**, y si se puede, como TEST. Aquí la
  celda necesitaba la marca del eje ausente, y hoy toda alta solo-grupos la escribe en el acto: un
  test fija esa premisa con censo, así que un alta nueva rompe el test en vez de repoblar en silencio.
  Sin eso, «población cero» caduca sin avisar y nadie se entera.
- **Población cero no es lo mismo que mecanismo inexistente.** El hueco de código sigue descrito en su
  docblock, con las mediciones y su fecha. El ticket va a `done` (cumple su criterio de aceptación),
  no a `discarded`: no se refutó nada.

Relacionado: [[feedback-el-predicado-del-ticket-no-es-el-criterio]],
[[feedback-la-premisa-del-encargo-tambien-se-mide]], [[project-poblacion-cero-del-eje-de-vaciado]].
