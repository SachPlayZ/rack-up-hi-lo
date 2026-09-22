import type { CSSProperties } from "react";

const colors = [
  "#d7a83f",
  "#e8c932",
  "#2456a6",
  "#bd342e",
  "#653b82",
  "#e07f26",
  "#24794c",
  "#7d242a",
  "#171917",
  "#e8c932",
  "#2456a6",
  "#bd342e",
  "#653b82",
  "#e07f26",
  "#24794c",
  "#7d242a",
];

export function PoolBall({ number, rolling = false }: { number: number; rolling?: boolean }) {
  const safeNumber = number >= 1 && number <= 15 ? number : 0;
  const style = { "--ball-color": colors[safeNumber] } as CSSProperties;

  return (
    <div
      aria-label={rolling ? "Drawing the next ball" : safeNumber ? `Ball ${safeNumber}` : "Waiting for the opening ball"}
      className={`pool-ball${rolling ? " pool-ball--rolling" : ""}`}
      style={style}
    >
      <span className="pool-ball__number">{rolling ? "?" : safeNumber || "–"}</span>
    </div>
  );
}

