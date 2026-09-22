---
id: xcode-project-config-json-format-when-27-2-stable
status: backlog
priority: very-low
area: "tooling, xcode"
created: 2026-09-20
source: "Apple docs (Beta) vía Dan — Jürgen 2026-09-20; captura Frank"
---

# Adoptar el formato JSON del project config de Xcode 27.2+

## Qué es

Apple documenta (Beta) **Updating your Xcode project configuration file format** para **Xcode 27.2+**: el project config pasa a un formato JSON más legible y pensado para que agentes de código lo editen con menos dolor que el `pbxproj` clásico.

## Por qué importa a Yala

Hoy el project file es frágil para diffs y para Claude/agentes. Cuando el toolchain estable lo permita, migrar reduce fricción en PRs de proyecto y en encargos que tocan targets/capabilities.

## Qué no hacer ahora

- **No atacar en beta.** Prioridad very-low; solo cuando Yala esté en **Xcode 27.2+ estable** o Jürgen diga go.
- No es rewrite de app ni cambio de producto.

## Criterio de listo (cuando se ataque)

- [ ] Toolchain 27.2+ estable en la Mini / CI
- [ ] Migración del project config al formato JSON documentado por Apple
- [ ] Build + tests verdes; diff de proyecto revisable
- [ ] Nota breve en docs de tooling / inbox si aplica

## Referencia

Apple Developer Documentation (Beta): *Updating your Xcode project configuration file format* — Xcode 27.2+.
