---
id: gate-never-reads-test-file-warnings
status: backlog
priority: low
area: "qa, gate"
created: 2026-09-10
source: "cierre de `beacon-routes-only-never-blocks`, 2026-09-10"
updated: 2026-10-08
---

# El gate no mira los warnings de los ficheros de test, y los de la app los lee de un build incremental

## El síntoma

El paso 1 de `/gate` pide «cero warnings NUEVOS en los archivos tocados». Dos huecos hacen que ese
criterio salga verde sin haberse medido:

1. **Los ficheros de test no los mira ningún paso.** El `build` del paso 1 no compila `YalaTests`, y el
   grep del paso 2 (`Test run with|Test Suite|Test Case|Executed|passed|failed|error:`) filtra fuera toda
   línea `warning:`. Un warning en un test tocado no aparece en el informe.
2. **El paso 1 lee un build incremental.** Un fichero que no se recompila en esa corrida no vuelve a
   imprimir sus warnings. Si se compiló por última vez en una corrida anterior de la sesión, el gate lo da
   limpio aunque no lo esté.

## Lo medido (2026-09-10, sesión del paso 6)

- `xcodebuild -scheme Yala build` y `-scheme "Yala Dev" build`: **0 líneas** del target `YalaTests` en los
  dos logs. El `test` de la suite unit sí lo compila (614 líneas).
- El grep del paso 2 sobre un log unit con warnings de test deja pasar **0** de ellos.
- Dos warnings de ficheros de test tocados habrían llegado al commit: una llamada `@MainActor` desde un
  closure `@Sendable` en `CloudIdentityDiscoveryTests.swift` —en modo Swift 6 es un error— y una variable
  muerta en `WelcomeSignInVerbTests.swift`. No estaban en el log de la suite que tomé como final, porque
  ahí esos ficheros no se recompilaron; salieron al unir todos los logs de la sesión.
- Esa unión trae ruido que hay que descartar a mano: cuatro warnings más eran de mutantes (una variable
  que el mutante deja sin usar), no del árbol.

## Qué tiene que dar el arreglo

Que «cero warnings nuevos» cubra también los ficheros de test tocados y se mida sobre una compilación
que los incluya de verdad. Dos piezas, a decidir cómo:

- **Leer los warnings del paso 2**: grep de `warning:` en el log del `test`, filtrado por los ficheros
  del alcance.
- **Forzar que los ficheros del alcance se compilen en la corrida que se lee**: `touch` de sus `.swift`
  antes del build y del test. Un `clean build` también sirve, pero cuesta varios minutos por scheme.

Fuera de alcance: los warnings preexistentes de otros ficheros, que el gate ya declara no bloqueantes.

## Medido en 2.1 (triage 2026-10-08)

- `/gate` §1 (`.claude/commands/gate.md:24-27`) sigue siendo un `build` incremental sin `touch` ni `clean`. El target `build` del scheme no compila `YalaTests`.
- `/gate` §2 (`:37-42`) sigue filtrando con `grep -E "(Test run with|Test Suite|Test Case|Executed|passed|failed|error:)"`, sin `warning:`.
- Los dos commits del fichero desde el 10-sep (`c7fa850fe`, `a4454b8e2`) tocan la medición de XCUITest y la cola del simulador, no esto.

Triage 2026-10-08: abierto · medium → low · el §2 del gate sigue filtrando fuera `warning:` (`gate.md:41`) y el §1 sigue leyendo un build incremental; es tooling, y un warning de test no llega al usuario.
