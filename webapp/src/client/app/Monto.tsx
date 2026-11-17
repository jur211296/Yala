/**
 * Una cifra como la dibuja la app (`AmountText`): el entero en letra redondeada y el símbolo de la divisa y los decimales
 * a la mitad y en gris. El texto es el mismo de `money()`, así que copiar, buscar y los lectores de pantalla no cambian.
 *
 * `tam`: «hero» es la cifra principal de una pantalla (el saldo del Panel); sin él, toma el tamaño de su contenedor.
 */
import { moneyParts } from "./format";

export function Monto({
  importe,
  divisa,
  signo,
  tam,
  className,
}: {
  importe: number | null | undefined;
  divisa: string | null | undefined;
  /** «+» delante de los positivos (los negativos llevan «−» siempre). */
  signo?: boolean;
  tam?: "hero";
  className?: string;
}) {
  const p = moneyParts(importe, divisa, { sign: signo });
  // «principal» y no «hero»: `.hero` ya es la tarjeta que la contiene (columna flexible).
  const cls = ["monto", tam === "hero" ? "principal" : "", className ?? ""].filter(Boolean).join(" ");
  if (!p) return <span className={cls}>—</span>;
  return (
    <span className={cls}>
      {p.signo ? <span className="m-i">{p.signo}</span> : null}
      {p.antes ? <span className="m-c">{p.antes}</span> : null}
      <span className="m-i">{p.entero}</span>
      {p.decimales ? <span className="m-d">{p.decimales}</span> : null}
      {p.despues ? <span className="m-c m-tras">{p.despues}</span> : null}
    </span>
  );
}
