---
name: git-bloqueado-por-licencia-de-xcode
description: Tras actualizar Xcode, `/usr/bin/git` y `/usr/bin/python3` fallan con «You have not agreed to the Xcode license agreements». El binario REAL del toolchain no comprueba la licencia y desbloquea la sesión sin sudo.
metadata:
  type: reference
---

Si a mitad de sesión `git` empieza a contestar **«You have not agreed to the Xcode license
agreements. Please run 'sudo xcodebuild -license'»**, no es el repo ni los hooks: **Xcode se
actualizó** y los shims de `/usr/bin` se niegan a correr hasta que alguien acepte la licencia nueva.

**Cómo se confirma en dos comandos** (y conviene confirmarlo, no suponerlo):

```bash
xcodebuild -version                                       # la versión instalada AHORA
defaults read /Library/Preferences/com.apple.dt.Xcode \
  IDEXcodeVersionForAgreedToGMLicense                     # la versión cuya licencia se aceptó
```

Si no coinciden, es esto. El 2026-09-22 pasó a mitad de una sesión autónoma: instalada **27.0**,
aceptada **26.3**. Los builds de la primera mitad de la sesión habían corrido con la 26.x.

**La salida que NO necesita a Jürgen ni `sudo`:** el shim de `/usr/bin` es el que comprueba la
licencia; el binario del toolchain no.

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/git -C <repo> status
```

Medido: `status`, `add`, `commit` (con los hooks del repo corriendo) y `push` funcionan igual. Es el
mismo git, sin el guardián delante. `gh` también sirve para lo que va por la API, con `--repo
owner/nombre` para que no intente leer el repo local — sin ese flag, `gh pr checks` llama a `git` y
hereda el bloqueo.

**Qué NO arregla:** `xcodebuild` de verdad (build y tests) sí queda bloqueado, así que un gate no se
puede correr hasta que la licencia se acepte. Si el gate ya estaba sellado antes de la actualización,
**su sello sigue siendo válido para ESE árbol pero se midió con el Xcode anterior** — dilo al
entregar en vez de callarlo.

**Y lo que hay que decirle a Jürgen**, porque sí necesita su contraseña: `sudo xcodebuild -license
accept` en una Terminal. Una vez.

**Corolario que ya estaba escrito y ahora tiene su caso:** el `CLAUDE.md` avisa de que una hipótesis
de la Lista Negra caduca si cambia la versión de Xcode. Aquí cambió **a mitad de sesión**, así que
cualquier medición de esta sesión anterior a la actualización se hizo en otro entorno que el de
después. Relacionado: [[feedback_mis_mediciones_fallan_por_el_filtro]].
