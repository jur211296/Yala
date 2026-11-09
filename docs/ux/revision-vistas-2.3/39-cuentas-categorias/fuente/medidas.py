"""Lo medido en el simulador (9-nov-2026) y las notas de texto grande, para paginas.py."""

EFIC_MED = [
    ("Abrir Ajustes › Cuentas sin registros (semilla «sin-registros», 2 cuentas)",
     "32 ms de mediana (31,6-32,8; la primera, 86)",
     "Marca <code>PERF ajustes-cuentas</code> de la app (<code>LoadTimeMarks</code>: empieza y acaba en el <code>onAppear</code> de la lista, "
     "alrededor de <code>setContext</code>, que lee cuentas y todos los registros), leída del registro del simulador. 7 aperturas seguidas en el mismo arranque."),
    ("Lo mismo con dos años de registros (semilla «realista»)",
     "113 ms de mediana (110,9-114,8; la primera, 154)", "Igual: 7 aperturas."),
    ("Lo mismo con diez años de registros (semilla «pesado»)",
     "447 ms de mediana (442,7-447,9; la primera, 495)",
     "Igual: 7 aperturas. Crece con el número de registros, no con el de cuentas (son 2 en las tres semillas): la lista lee todos los registros para calcular saldos, en el hilo principal."),
    ("Abrir el formulario de una cuenta, Categorías, Etiquetas o Moneda", "sin medir",
     "No tienen marca de carga."),
]

AX_CAP = {
    "ax-c01-lista-cuentas-free.jpg": "Cuentas: sin nombres (problema 8).",
    "ax-c03-form-tarjeta.jpg": "Ficha de la tarjeta: los tipos se parten bien.",
    "ax-c04-acciones-antes.jpg": "«Acciones», aún más abajo (problema 1).",
    "ax-c09-saldo-escrito.jpg": "Saldo: el signo no crece; el teclado tapa (problema 4).",
    "ax-k01-categorias.jpg": "Categorías: parte bien «Entreteni-miento».",
    "ax-k03-detalle-alimentacion.jpg": "Una categoría: bien.",
    "ax-k06-nueva-categoria.jpg": "Nueva categoría con el teclado.",
    "ax-e01-etiquetas.jpg": "Etiquetas: 4 de 5 (problema 8).",
    "ax-e03-editar-etiqueta.jpg": "Etiqueta: «Seleccionado: #5E5CE6» (problema 7).",
    "ax-d01-divisas.jpg": "Moneda y tipo de cambio: bien.",
}
AX_NOTE = ('<p class="sub">Lo que falla con texto grande va al problema 8 (Cuentas sin nombres, Etiquetas sin su última fila). '
           'Además: el selector de signo («A favor / Consumido», «Positivo / Negativo») no crece con el texto, y en la ficha de la '
           'cuenta «Acciones» queda todavía más lejos. Categorías, subcategorías y Moneda parten bien los textos largos.</p>')
