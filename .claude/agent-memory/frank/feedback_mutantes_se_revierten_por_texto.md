---
name: mutantes-se-revierten-por-texto
description: Un mutante se quita con el reemplazo inverso, nunca con git checkout del fichero: el fichero lleva el trabajo de la sesión sin commitear
metadata:
  type: feedback
---

Al poner mutantes a mano sobre ficheros con cambios sin commitear, **se revierten con el reemplazo inverso** (el mismo
script con `a` y `b` cambiados) y se comprueba con `cmp` contra la copia medida o con un `grep` del texto original. Nunca
con `git checkout -- <fichero>`: devuelve el fichero a HEAD y se lleva todo el trabajo de la sesión.

**Why:** 27-nov-2026, lote 7 de eficiencia: escribí un comando de mutantes que acababa en `git checkout -- PanelViewModel.swift`
«para limpiar»; lo vi a tiempo y lo paré con TaskStop antes de que llegara a esa línea. Habría borrado ~80 líneas del Panel.

**How to apply:** en cualquier tanda de mutantes (gate, revisión), el paso de deshacer va aparte, después de leer el
resultado, y con verificación de que el árbol vuelve a ser el medido.
