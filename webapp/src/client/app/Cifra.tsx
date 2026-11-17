/**
 * La cifra principal de una pantalla como el hero del Panel de la app (lote 5 de «Yala web como la app», decisión D5):
 * el rótulo claro arriba, el «?» que despliega de dónde sale la cifra y la cifra en grande sobre el fondo, sin tarjeta y
 * sin hueco antes del valor. Debajo, lo que la pantalla quiera añadir (entradas y salidas, la barra de Grupos…).
 *
 * Usa las mismas clases que el saldo del Panel (`.saldo`, `.ayuda`), así que se ve igual en las dos.
 */
import { useId, useState, type ReactNode } from "react";
import { CircleHelp } from "lucide-react";
import { texts } from "../i18n";

const t = texts();

export function CifraPrincipal({
  rotulo,
  explica,
  children,
  debajo,
  className,
}: {
  rotulo: string;
  /** El texto del «?»: de dónde sale la cifra. Más párrafos (avisos) van después, en gris. Sin texto, no hay «?». */
  explica?: string[];
  /** La cifra, normalmente un `Monto` con `tam="hero"`. */
  children: ReactNode;
  debajo?: ReactNode;
  className?: string;
}) {
  const [ayuda, setAyuda] = useState(false);
  const id = useId();
  return (
    <section className={`saldo${className ? ` ${className}` : ""}`} aria-labelledby={`${id}-t`}>
      <div className="saldo-l">
        <span className="cap" id={`${id}-t`}>
          {rotulo}
        </span>
        {explica && explica.length > 0 ? (
        <button
          type="button"
          className="ayuda"
          aria-expanded={ayuda}
          aria-controls={id}
          aria-label={t.app.porQueMonto}
          title={t.app.porQueMonto}
          onClick={() => setAyuda((v) => !v)}
        >
          <CircleHelp aria-hidden={true} focusable={false} />
        </button>
        ) : null}
      </div>
      <span className="big">{children}</span>
      {ayuda && explica ? (
        <div className="ayuda-t" id={id} role="note">
          {explica.map((p, i) => (
            <p key={i}>{p}</p>
          ))}
        </div>
      ) : null}
      {debajo}
    </section>
  );
}
