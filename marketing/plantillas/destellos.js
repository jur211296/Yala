// Pinta los destellos de cuatro puntas descritos en data-destellos="x,y,tamaño,color,giro,opacidad; …".
const TRAZO="M50 0 C54 36 64 46 100 50 C64 54 54 64 50 100 C46 64 36 54 0 50 C36 46 46 36 50 0 Z";
const COLOR={rosa:"#FF2D78",azul:"#6164EB",teal:"#3BD6F0",violeta:"#8B5CF6"};
document.querySelectorAll("[data-destellos]").forEach(l=>{
  l.dataset.destellos.split(";").map(s=>s.trim()).filter(Boolean).forEach(s=>{
    const [x,y,t,c,r,o]=s.split(",").map(v=>v.trim());const col=COLOR[c]||c;
    l.insertAdjacentHTML("beforeend",`<svg class="destello" viewBox="0 0 100 100" style="left:${x}px;top:${y}px;width:${t}px;height:${t}px;opacity:${o};transform:rotate(${r}deg);filter:drop-shadow(0 0 ${t*0.18}px ${col})"><path d="${TRAZO}" fill="${col}"/></svg>`);
  });
});
// Carrusel: con #3 en la URL solo se ve la lámina 3 (para exportarla); sin #, se ven todas.
const n=parseInt(location.hash.slice(1),10);
if(n){document.querySelectorAll(".lamina").forEach((l,i)=>{l.style.display=(i+1===n)?"":"none"});document.body.style.gap="0"}
