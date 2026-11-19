Yala
# Subir a TestFlight la build 5 de 2.3 con los PRs atascados, el Flujo de caja nuevo y el contraste del modo claro
---
toca: Yala.xcodeproj/project.pbxproj,tickets/backlog/2026-11-19-subir-testflight-2-3-build-5.md,tickets/done/2026-11-19-subir-testflight-2-3-build-5.md
esfuerzo: medium
cierre: cierra-sola
depende: Yala/mergear-prs-atascados-2-3,Yala/contraste-modo-claro-botones-blancos
---

Pedido de Jürgen (19-nov, 14:03 Lima): una nueva build en TestFlight, al grupo interno, cuando entren a 2.3 los PRs de las sesiones «mergear-prs-atascados-2-3» y «contraste-modo-claro-botones-blancos».

## Qué se pide
- Antes de nada, confirma con `gh pr list --base 2.3 --state open` y `gh pr view` que los PRs de esas dos sesiones están MERGED, y también el Flujo de caja nuevo (el PR del encargo flujo-aislados-promedio-y-detalle-mes, con auto merge). Si alguno sigue abierto, espera hasta 30 minutos revisando cada 5. Si sigue sin entrar, sale como `BLOQUEANTE:` con la lista de lo que falta. No subas una build sin ellos.
- Base `origin/2.3` al día y con el CI en verde. Si el último run de 2.3 no está verde, no subas: sale como `BLOQUEANTE:` con el link del run.
- Sube el número de build a 5 (la versión sigue en 2.3), archiva y sube a TestFlight igual que en las subidas anteriores de la 2.3, con los dSYM a Sentry si ya está el paso. Distribúyela al grupo interno.
- Notas de prueba en español neutro latinoamericano con lo nuevo desde la build 4, según lo mergeado: Pagos que se repiten como banner, Flujo de caja (aislados fuera en Promedio y Tendencia, detalle de línea con tooltip y selección de mes, no considerados por subcategoría, nueva hoja «Cálculo del monto», límites que se mueven cada mes, proyección futura solo con lo fijo y seguro), contraste del modo claro con borde y sombra, proyección inteligente, asistentes de grupo y de favorito, sin sugerencias de categoría bajo el monto y las correcciones de cuelgues de Sentry.
- No envíes a revisión de App Store: eso lo decide Jürgen.
- Puedes usar un segundo simulador en la Max además del de otra sesión, o el iPhone 14 por DeviceMCP. En la Mini, uno solo. No uses `-derivedDataPath /tmp/claude-*`.

## Cómo entregar
- Un PR con el cambio de build, sin firma de IA, contra 2.3. Deja el auto merge activado y no cierres hasta ver el PR dentro de 2.3. Si hay un conflicto o el CI falla, arréglalo tú. Si tras unos 45 minutos el CI sigue rojo por algo ajeno, cierra y anota el motivo.
- En «Qué salió», el número de build y el link de TestFlight o App Store Connect.
- Lo vital, según el modo fijado al arrancar: en semi preguntas y esperas con la sesión viva; en nocturno dejas un checkpoint recuperable y una card «Espera decisión». Si fallan credenciales o firmas, no las inventes: `BLOQUEANTE:`.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada».
