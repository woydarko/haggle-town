import { useEffect, useRef } from "react";
import uPlot from "uplot";
import { CATEGORIES, CATEGORY_NAME, ITEMS, tierColor, type Category } from "./items.ts";

export type Series = { key: string; label: string; color: string; points: { ts: number; ask: number }[] };

const cssVar = (value: string) => {
  const m = /^var\((--[\w-]+)\)$/.exec(value);
  return m ? getComputedStyle(document.documentElement).getPropertyValue(m[1]).trim() : value;
};

/** One line per series (e.g. the four items of a category). A data table below is the accessible alternative. */
export function PriceChart({ series, xLabel = "time", yLabel = "ask (C)" }: { series: Series[]; xLabel?: "time" | "day"; yLabel?: string }) {
  const box = useRef<HTMLDivElement>(null);
  const plot = useRef<uPlot | null>(null);
  const shape = series.map((s) => s.key).join(",");

  const xs = [...new Set(series.flatMap((s) => s.points.map((p) => p.ts)))].sort((a, b) => a - b);
  const data: uPlot.AlignedData = [
    xs,
    ...series.map((s) => {
      const m = new Map(s.points.map((p) => [p.ts, p.ask]));
      return xs.map((x) => m.get(x) ?? null);
    }),
  ];

  useEffect(() => {
    if (!box.current) return;
    const opts: uPlot.Options = {
      width: box.current.clientWidth,
      height: 260,
      scales: { x: { time: xLabel === "time" } },
      axes: [
        { stroke: cssVar("var(--muted)"), grid: { stroke: cssVar("var(--border)") }, label: xLabel === "day" ? "day" : undefined },
        { stroke: cssVar("var(--muted)"), grid: { stroke: cssVar("var(--border)") }, label: yLabel },
      ],
      series: [{}, ...series.map((s) => ({ label: s.label, stroke: cssVar(s.color), width: 2, spanGaps: true }))],
      legend: { show: false },
    };
    plot.current = new uPlot(opts, data, box.current);
    const onResize = () => box.current && plot.current?.setSize({ width: box.current.clientWidth, height: 260 });
    window.addEventListener("resize", onResize);
    return () => {
      window.removeEventListener("resize", onResize);
      plot.current?.destroy();
      plot.current = null;
    };
    // Rebuilt when the set of lines changes (category switch); data updates go through setData below.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [xLabel, yLabel, shape]);

  useEffect(() => {
    plot.current?.setData(data);
  });

  return (
    <div>
      <div className="legend" aria-hidden>
        {series.map((s) => (
          <span key={s.key}>
            <i style={{ background: s.color }} />
            {s.label}
          </span>
        ))}
      </div>
      <div ref={box} className="chart" role="img" aria-label={`${yLabel} over ${xLabel}`} />
      <table className="sr-only">
        <caption>Latest values</caption>
        <tbody>
          {series.map((s) => (
            <tr key={s.key}>
              <th scope="row">{s.label}</th>
              <td>{s.points.at(-1)?.ask ?? "no data"}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

/** Chips to pick which category's four items a chart shows. */
export function CategoryChips({ value, onChange }: { value: Category; onChange: (c: Category) => void }) {
  return (
    <>
      {CATEGORIES.map((c) => (
        <button key={c} className="chip" aria-pressed={value === c} onClick={() => onChange(c)}>
          {CATEGORY_NAME[c]}
        </button>
      ))}
    </>
  );
}

/** The four series of a category, colored by tier, from a per-item points lookup. */
export const categorySeries = (category: Category, pointsOf: (item: string) => { ts: number; ask: number }[]): Series[] =>
  ITEMS.filter((i) => i.category === category).map((i) => ({ key: i.id, label: i.name, color: tierColor(i.tier), points: pointsOf(i.id) }));
