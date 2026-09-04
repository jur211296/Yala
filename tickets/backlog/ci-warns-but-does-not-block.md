---
id: ci-warns-but-does-not-block
status: backlog
priority: medium
area: platform
created: 2026-09-04
source: residuales de ci-verde-con-la-suite-en-rojo al cerrarlo (2026-09-04)
---

# El CI ya no miente, pero todavía no puede frenar una entrega defectuosa

`ci-verde-con-la-suite-en-rojo` se cerró con su alcance cumplido: los tests vuelven a ejecutarse, los
ocho rojos están arreglados, el aviso distingue «salió en rojo» de «ni llegó a correr», y el índice de
cobertura ya vigila el código del que dependen las áreas. **Lo que aquel ticket dejó explícitamente
fuera vive aquí**, para que no se pierda al archivarlo.

El estado de hoy es: el CI **avisa** pero no **frena**. Los tres pasos de test siguen siendo
informativos, así que un cambio que rompa la suite entra igual.

## Paso 3 — promover los unit a bloqueantes

Quitar los `continue-on-error: true` de los dos pasos de unit en `.github/workflows/qa.yml`.

**Coordenadas medidas el 2026-09-04:** los tres están en las líneas **201, 223 y 241**
(`unit_pure`, `unit_context`, `ui`). El ticket original citaba 175/197/215, que era el árbol
*anterior a su propio arreglo* — `815385b3` desplazó el fichero 26 líneas. Re-greppea antes de tocar:

```bash
grep -n 'continue-on-error: true' .github/workflows/qa.yml
```

**Prerequisito declarado y no resuelto:** el `EXC_BREAKPOINT` de SwiftData in-memory. Está escrito en
`qa.yml:126` y `:141` como el motivo de no bloquear. **Aviso honesto sobre su verificación:** es un
flaky de ~1 de cada N, así que **una corrida verde no lo refuta**. Ni el ticket original ni la
revisión del 2026-09-04 pudieron afirmar si sigue vivo. Quien retome esto necesita corridas repetidas,
no una.

Contexto útil que ya existe: la memoria del proyecto atribuye ese crash a acumulación de
`ModelContainer` in-memory (>~15 por proceso), con reuso por fichero como mitigación aplicada.
Confírmalo antes de darlo por bueno — es una hipótesis con fecha.

## Paso 4 — sacar la suite de UI del camino de cada push

Hoy cada cambio que toca código carga **1 h 14 min – 1 h 41 min** de servidor.

**Medido el 2026-09-04, y es el motivo de que no se haya hecho:** no existe ningún pase nocturno al
que mover la suite. Cero `schedule:` y cero `cron:` en los dos workflows del repo, sin crontab y sin
LaunchAgent. **Sacar la UI del push sin montar antes el nocturno la dejaría sin ninguna corrida
automática** — sería cambiar «lento» por «ciego», que es justo lo que costó tres semanas.

⇒ El orden no es negociable: primero el nocturno, después sacarla del push.

## Residuales menores

- **La carrera de `GroupsRetentionUITests` no está cerrada, solo tiene margen.** `uitest_ready`
  señala que el bootstrap y el seed terminaron, no que el cover esté presentado. Cerrarla de verdad
  exigiría que `markReady()` aguardase al cover, y eso haría esperar a *todos* los tests por algo que
  casi ninguno presenta. Es una decisión de diseño del harness, no un fix.
- **Cuatro áreas del índice se quedaron sin `lastVerified` nuevo a propósito**, porque dependen de
  suites que no se corrieron: `GroupsEmptyState`, `GroupExpenseSuccess`, `PaywallInboxAlertRouting` y
  cinco de `settings-profile-general`. Verificado el 2026-09-04: `groups-expense-form` y
  `settings-profile-general` siguen en `2026-08-11`.
- **Por qué `systemsetup` aplicaba la zona horaria 3 de cada 9 veces.** El mecanismo se retiró y se
  sustituyó por `TEST_RUNNER_TZ` a nivel de job, así que no molesta a nadie hoy; la causa quedó sin
  diagnosticar. Solo importa si algún día hace falta fijar la zona del *sistema* en CI.
- **Comprobar si el `TODO(@jur, 2026-07-15)` de `qa.yml` sigue vigente o ya caducó.**

## Dos cifras del ticket original que NO hay que reusar

Medidas el 2026-09-04 al verificarlo, ambas ilustraban bien una conclusión correcta con un número
equivocado:

- «`FABStackView.swift` no figuraba en los globs de **ninguna** área» es falso: ya estaba en cuatro
  (`groups-expense-form`, `image-settings-fab`, `smart-refinement-fab-stats`,
  `voice-settings-fab`). El arreglo real fue 4 → 14, no 0 → 14.
- El «30 áreas sin cubrir su código» no cuadra con la huella del commit que lo arregló: `7fcd8c1c`
  modificó los `codeGlobs` de **56** áreas.

La conclusión de fondo —el gate no corría lo que podía romperse— se sostiene. Las cifras, no.
