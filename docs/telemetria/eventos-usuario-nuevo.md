# Eventos del usuario nuevo después del alta

Card «Telemetría del usuario nuevo después del alta» (2.3, aprobada el 12-nov). Sale de la revisión del usuario nuevo
(`docs/ux/revision-usuario-nuevo-2026-11/README.md`, §5 y §7.1): hasta ahora el embudo acababa en `alta.termina`, así
que no se podía medir el abandono después del alta ni comparar alternativas.

## Cómo viajan

Son eventos `use` del `POST /metrics` de siempre (`e = "use"`, `n` = el slug), con dos diferencias frente al «uno al día»
de las funciones (`Yala/Services/Metrics/MetricsUse.swift`):

- **Una vez por instalación.** Cada slug sale una sola vez en la vida de la instalación (`MetricsOnceLogic`; lo ya
  enviado se guarda en `metrics.onceEmitted`). «Vaciar datos» no lo borra; reinstalar sí, y la instalación nueva lleva
  otro `install` anónimo.
- **Los `primeros.*` solo llegan de instalaciones nuevas.** Hace falta que la instalación haya cerrado el alta
  (`alta.termina`) con una versión que ya los manda (marca `metrics.newUserAfterSignUp`). Sin eso, quien actualiza con
  años de datos mandaría «primer registro» en su próximo gasto. Los `alta.reabrir.*` no la piden: pasan antes del alta.

Privacidad: viaja el slug y nada más, igual que el resto de `use` (ni montos, ni nombres, ni textos), dentro de lo que
ya declara `PrivacyInfo.xcprivacy`. La app no tiene un ajuste para apagar la telemetría propia. Bajo `-uitest` y en los
tests no se apunta nada. El gateway no necesita cambios: acepta cualquier `n` que cumpla `[A-Za-z0-9_.-]{1,64}`.

## Los eventos

| Slug | Cuándo sale |
|---|---|
| `alta.reabrir.pide` | Aparece «Reabre Yala» en pleno alta: onboarding privado o restaurar de iCloud. No cuentan las otras salidas que piden reabrir (activar Yala completo, volver al neutro por un grupo, cerrar sesión) |
| `alta.reabrir.vuelve` | Al volver a abrir, el arranque retoma ese destino y el alta sigue. Si el teléfono vuelve a necesitar reabrir, no cuenta todavía |
| `primeros.registro` | Primer gasto o ingreso propio que se queda: Nuevo registro (sin transferencias), «Guardar» en Yala IA, o un borrador aprobado de uno en uno, desde su editor o en lote (voz, foto, Apple Pay, Siri, correo, pagar un pago planificado). No cuentan el saldo inicial, un CSV importado ni lo que llega de un grupo |
| `primeros.presupuesto` | Primer presupuesto que se queda |
| `primeros.pago` | Primer pago planificado que se queda |
| `primeros.cuenta2` | La persona crea una cuenta activa (formulario o paso 1 de Primeros pasos) y con ella tiene dos o más cuentas propias; si ya tenía dos, sale con la tercera. Las del onboarding (también el de activar Yala completo) y las de un CSV no cuentan |
| `primeros.pasos.ve` | Se ve la tarjeta de Primeros pasos en el Panel |
| `primeros.pasos.cuenta` · `.registrar` · `.presupuesto` · `.pagos` · `.grupo` · `.dinero` · `.inicio` | Ese paso del mazo queda hecho, por la persona o porque sus datos ya lo cumplen. Omitir un paso no emite |
| `primeros.pasos.completa` | Los siete pasos quedan hechos u omitidos |

### Lo que se borra como prueba no cuenta

El criterio de activación de la revisión excluye el registro marcado «Era de prueba». El primer registro, presupuesto o
pago no sale al guardarse, sino cuando se sabe que se queda (`Yala/Services/Metrics/MetricsNewUser.swift`):

1. Si su paso del mazo ya estaba hecho, no habrá pregunta y sale en el acto.
2. Si no, espera a que el paso se cierre. Sin «¿Era de prueba?», sale ahí. Con ella, espera la respuesta: «Guardarlo» lo
   emite; «Borrarlo, era de prueba» lo descarta, y el siguiente vuelve a ser el primero.
3. El tutorial de «Aprender a registrar» retiene el paso hasta su hoja final. Si tras la hoja no queda ningún registro
   propio, el primero no ha pasado todavía.
4. Lo que sigue esperando al arrancar Yala se emite: borrar solo pasa contestando, así que si iOS cerró la app con la
   pregunta en pantalla, el registro se quedó. El registro con el tutorial aún en marcha espera hasta 24 h: cerrar el
   tutorial con la X después de probar una manera lo deja abierto hasta que se retome, y sin ese plazo el primer
   registro de quien lo abandona no saldría nunca.
5. Una re-entrada (restaurar con todos los datos, retomar «solo grupos», adoptar una cuenta de la nube) retira la marca
   de usuario nuevo: sus datos ya existían.

## Qué se puede medir con ellos

Los criterios de la revisión (§5), con `blob5` (instalación) y la fecha de cada evento:

- **Abandono en el reinicio:** `alta.reabrir.pide` sin `alta.reabrir.vuelve` en 24 h. El camino lo dice
  `alta.camino.privada` o `alta.camino.restaurar` de la misma instalación.
- **Activación:** `alta.termina` y `primeros.registro` en 72 h.
- **Abandono temprano:** `alta.termina` sin `primeros.registro` a las 72 h.
- **Secundarios:** `primeros.presupuesto` y `primeros.pago` en 7 días; `primeros.cuenta2`.
- **Primeros pasos:** de `primeros.pasos.ve` a cada `primeros.pasos.*` y a `primeros.pasos.completa`.

```sql
-- Instalaciones distintas por evento del usuario nuevo, últimos 30 días.
SELECT blob2 AS evento, count(DISTINCT blob5) AS instalaciones
FROM yala_metrics
WHERE blob1 = 'use' AND (blob2 LIKE 'primeros.%' OR blob2 LIKE 'alta.reabrir.%')
  AND timestamp > NOW() - INTERVAL '30' DAY
GROUP BY evento ORDER BY instalaciones DESC;
```

El panel (`panel/`) les pone nombre (`NEW_USER_EVENTS` en `panel/src/labels.ts`) y los saca de «Lo que más se usa».
Todavía no tiene una sección propia para ellos.
