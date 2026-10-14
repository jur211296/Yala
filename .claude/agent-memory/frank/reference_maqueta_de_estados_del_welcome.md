---
name: maqueta-de-estados-del-welcome
description: Cómo pintar en el simulador los estados del Welcome que dependen de iCloud, Apple/Google o el backend (restaurar, entrar en la nube, aviso tardío) sin que el cover se caiga
metadata:
  type: reference
---

Receta medida el 2026-10-14 (auditoría UX 2.2, lote 6; parche en
`~/Claude/entregas/Yala--auditoria-ux-2-2-lote-6-datos-previos-nube/maquetas-lote-6.patch`):

- Un `Mock6.swift` con `-mock6 <id>` (y `-mockv N` para variantes) que fuerza el `@State` inicial de cada vista
  (`state`, `phase`, `finale`) y un `.task` en `ContentView` que, a los 3 s, enciende la presentación real
  (`showWelcomeRestore`, `showWelcomeCloudSignIn`, `lateICloudNotice`…). El proyecto usa carpetas sincronizadas: el
  fichero nuevo entra solo, pero **la primera compilación tras crearlo no lo ve si ya estaba en marcha**.
- **El cover de entrar en la nube se cae si lo pides sobre la app** (`-uitest-skip-onboarding`): a los ~6-10 s vuelve
  el Hero. Lánzalo SIN saltar el onboarding y, como hace el chooser, cierra antes el flujo del Welcome
  (`showWelcomeFlow = false`, 1 s, y el cover). Restaurar y el aviso tardío sí aguantan sobre la app.
- La fase `.wiping` del aviso tardío ejecuta el borrado de verdad (en el store de uitest falla y salta a `.failed`):
  no se puede capturar forzándola.
- Las pantallas finales de «Yala completo» se conducen a mano (Más › Activar) con `-uitest-group-invite`: presentar
  su hoja desde la maqueta deja el Hero encima.
- Separar maqueta de arreglo: copia los ficheros enteros a un directorio aparte ANTES de revertir los trozos de
  maqueta; el parche se reconstruye después con `git diff` contra el commit.

Relacionado: [[maqueta-de-variantes-por-xcuitest]], [[auditoria-ux-lote-propone-no-implementa]].
