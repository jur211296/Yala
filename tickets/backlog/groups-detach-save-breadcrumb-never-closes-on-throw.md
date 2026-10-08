---
id: groups-detach-save-breadcrumb-never-closes-on-throw
status: backlog
priority: very-low
area: "modo-nube, groups, settings"
created: 2026-09-11
updated: 2026-10-08
source: "review adversarial de `detach-failure-looks-like-success` (tres lentes)"
---

# Un cabo del desasociar: el breadcrumb que no cierra cuando el borrado lanza

## (1) `SaveBreadcrumb.willSave` sin su `didSave` cuando el borrado lanza

`CloudSessionSignOut.purgeGroupsDomainForDetach` abre el breadcrumb y, si el borrado lanza, ya no lo
cierra: propaga. Era igual antes del arreglo (el `catch` tampoco lo cerraba), pero ahora el throw sale
del método y el par queda desbalanceado también para quien lo reciba. Mirar si `SaveBreadcrumb` tiene
una forma de cerrar en fallo, y si no, si merece tenerla — hay más sitios con la misma forma.

## (2) ~~Un cierre de sesión en curso deja el desasociar mudo~~ — HECHO el 2026-09-11

Se cerró dentro de `detach-failure-looks-like-success`: `.busy` tiene motivo propio (`detachBusy`) con
su copy en los 16 idiomas, y su aviso **no** llama a `acknowledgeBlocked()` — la fase la puso el gesto
ajeno, y soltarla le borraba además el `blockedExit`, dejando inertes los dos botones del aviso del
Perfil. Queda solo el cabo (1).

---

Se dejó como ticket propio y no dentro de aquél porque el breadcrumb es de otra familia: hay más sitios
con la misma forma y merecen mirarse juntos.

## Medido en 2.1 (triage 2026-10-08)

- `CloudSessionSignOut.purgeGroupsDomainForDetach` sigue abriendo `SaveBreadcrumb.willSave` y llamando a `didSave` solo si el borrado no lanza.
- `SaveBreadcrumb` sigue sin forma de cerrar en fallo: solo `willSave`, `didSave` y `deferred`. Es una línea de log de diagnóstico; un `SAVE` sin `SAVED` puede leerse como un crash en ese sitio.

Triage 2026-10-08: abierto · low → very-low · el par de breadcrumbs sigue desbalanceado al lanzar, pero solo afecta a cómo se lee un log de diagnóstico.
