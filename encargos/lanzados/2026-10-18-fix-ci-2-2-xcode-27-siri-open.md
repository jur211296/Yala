# Arreglar el build de 2.2 en el CI (Siri «Abrir cuenta» y Xcode 27)

Base origin/2.2 y PR contra 2.2 (no 2.1). Card: «Arreglar el build de 2.2 en el CI: «Abrir cuenta» de Siri usa una API que solo existe en Xcode 27».

Desde el merge del PR #552 en 2.2 (commit ca61666), el job `tests` del CI falla en «Build for testing»: `SiriQueryIntents.swift:195: value of type 'some AssistantSchemas.SystemIntent' has no member 'open'` con Xcode 26.6. Run: https://github.com/jur211296/Yala/actions/runs/39185367867. No corre ningún test.

Qué hacer, lo más robusto:
1. Mira qué Xcode tiene disponible el runner del CI. La release de 2.1 se compila con Xcode 27.1. Si el runner tiene Xcode 27.x, pasa el CI de 2.2 a Xcode 27.1 (y sus simuladores iOS 27.0) y comprueba que todo compila y pasa. No cambies el CI de 2.1.
2. Si el runner no tiene Xcode 27, protege las APIs de iOS 27 con guards de compilador/SDK (`#if compiler(>=…)` o `canImport`, más `@available`) para que compile en 26.6 sin perder la función en 27. Busca todos los usos de APIs de iOS 27 que entraron con #552, no solo la línea 195.
3. Verifica en local con el Xcode que use el CI, y luego que el CI del PR quede en verde antes de dar por hecha la card (esta vez sí se espera el CI del propio PR, porque es lo que arregla).
4. git fetch y rebase sobre origin/2.2 justo antes de abrir el PR. Ticket con su card si encuentras algo más.
5. /barrido-qa y cierra con /cerrar-total.

Reglas de siempre: no toques los .ckdb, Yala.xcscheme ni encargos/pendientes/ de ~/Yala; no toques los tmux salud--, sat-lab--, clinicas-dentales-bi-- ni los Yala-- vivos; no nombres «OpenAI» en textos de la app.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos: el runner `macos-26` (imagen 20261013) solo trae Xcode 26.0.1–26.6. GitHub ofrece la imagen `xcode-27` (preview, macOS 27, issue actions/runner-images#14404) con Xcode 27.0 (default), 27.1 build 27A9275 (el mismo de esta Mac y la Mini) y 27.2 beta; su único runtime es iOS 27.0 y no trae iPhone 17 Pro, que `ci-simulador.sh` ya sabe crear por tipo + runtime.

**D1 · ¿Vía 1 (CI en Xcode 27.1) o vía 2 (guards de SDK)?** → Vía 1: `tests` y `ui` de `qa.yml` en 2.2 pasan a `runs-on: xcode-27` con Xcode 27.1.
Por qué: la release de 2.2 se compila con 27.1; un guard dejaría sin compilar en CI justo el código de iOS 27. Alternativa descartada: guards `#if compiler`, más código defensivo para un Xcode que nadie usa para subir.

**D2 · ¿Cómo se elige 27.1 en la imagen?** → `xcode-select` a `/Applications/Xcode_27.1.app` y comprobación del build 27A9275, en un script (`qa/scripts/ci-xcode.sh`) que usan los dos jobs.
Por qué: la ruta es la del README de la imagen y el paso falla con motivo si el build cambia. Alternativa descartada: `setup-xcode` con `27.1`; la app viene etiquetada «Release_Candidate» y no medí cómo la trata.

**D3 · ¿Se toca el job `ui` (nocturna)?** → Sí, igual que `tests`.
Por qué: compila el mismo código; un `workflow_dispatch` sobre 2.2 fallaría igual. 

**D4 · ¿Y la imagen es preview?** → Se acepta y se anota el riesgo (colas) en el PR.
Por qué: es la única imagen hospedada con Xcode 27; el CI propio de la Mini aún está en fase sombra.

**D5 · Simulador** → iPhone 17 Pro en iOS 27.0, creado por `ci-simulador.sh` sin cambios.
Por qué: el encargo pide iOS 27.0 y es el device de toda la casa.
