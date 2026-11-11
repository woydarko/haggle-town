import { useEffect, useRef, useState } from "react";
import { CategoryChips, PriceChart, categorySeries } from "./PriceChart.tsx";
import type { Category } from "./items.ts";

type Week = { days: number; ticksPerDay: number; series: { tick: number; day: number; item: string; ask: number }[] };

const DURATION_MS = 60_000;
const reducedMotion = () => window.matchMedia("(prefers-reduced-motion: reduce)").matches;

/** Plays a simulated week (same pricing rules as the contract, no chain calls) in about a minute. */
export function FastForward() {
  const [week, setWeek] = useState<Week | null>(null);
  const [error, setError] = useState(false);
  const [shown, setShown] = useState(0); // ticks revealed
  const [playing, setPlaying] = useState(false);
  const [category, setCategory] = useState<Category>("fish");
  const raf = useRef(0);

  useEffect(() => {
    fetch("/sim/week.json")
      .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
      .then(setWeek)
      .catch(() => setError(true));
    return () => cancelAnimationFrame(raf.current);
  }, []);

  const total = week ? week.days * week.ticksPerDay : 0;

  const play = () => {
    if (!week) return;
    if (reducedMotion()) {
      setShown(total);
      return;
    }
    setPlaying(true);
    const start = performance.now();
    const step = (t: number) => {
      const p = Math.min(1, (t - start) / DURATION_MS);
      setShown(Math.max(1, Math.round(p * total)));
      if (p < 1) raf.current = requestAnimationFrame(step);
      else setPlaying(false);
    };
    raf.current = requestAnimationFrame(step);
  };

  const stepDay = (dir: 1 | -1) => week && setShown((s) => Math.min(total, Math.max(week.ticksPerDay, s + dir * week.ticksPerDay)));

  if (error) return <p style={{ color: "var(--error)" }}>Simulation file missing. Run the simulator, then reload.</p>;
  if (!week) return <p className="muted">Loading the simulation...</p>;

  const series = categorySeries(category, (item) =>
    week.series.filter((p) => p.item === item && p.tick < shown).map((p) => ({ ts: p.tick / week.ticksPerDay + 1, ask: p.ask })),
  );
  const day = shown ? Math.min(week.days, Math.floor((shown - 1) / week.ticksPerDay) + 1) : 0;

  return (
    <div>
      <div style={{ display: "flex", gap: "var(--s3)", alignItems: "center", flexWrap: "wrap", marginBottom: "var(--s3)" }}>
        <button className="primary" onClick={play} disabled={playing}>
          {playing ? "Simulating a week..." : shown ? "Replay the week" : "Fast-forward a week"}
        </button>
        {reducedMotion() && shown > 0 && (
          <>
            <button className="primary" onClick={() => stepDay(-1)}>Previous day</button>
            <button className="primary" onClick={() => stepDay(1)}>Next day</button>
          </>
        )}
        <span className="num" aria-live="polite">
          {shown ? `Day ${day} of ${week.days}` : `${week.days} days, 10 bot traders, no patches`}
        </span>
        <CategoryChips value={category} onChange={setCategory} />
      </div>
      {shown > 0 && <PriceChart series={series} xLabel="day" />}
    </div>
  );
}
