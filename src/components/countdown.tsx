"use client";

import { useEffect, useState } from "react";
import { secondsRemaining } from "@/lib/format";

export function Countdown({ deadline }: { deadline: bigint }) {
  const [now, setNow] = useState(0);

  useEffect(() => {
    const update = () => setNow(Date.now());
    update();
    const timer = window.setInterval(update, 250);
    return () => window.clearInterval(timer);
  }, []);

  const seconds = now ? secondsRemaining(deadline, now) : null;
  const display = seconds === null ? "—" : `0:${seconds.toString().padStart(2, "0")}`;

  return (
    <div className="countdown" aria-live="polite">
      {display}
      <small>{seconds === 0 ? "Bets closed" : "Betting left"}</small>
    </div>
  );
}

