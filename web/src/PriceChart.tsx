import { useEffect, useRef } from "react";
import uPlot from "uplot";

export type Series = { good: string; points: { ts: number; ask: number }[] };

const GOODS = ["wood", "fish", "iron"];
const cssVar = (name: string) => getComputedStyle(document.documentElement).getPropertyValue(name).trim();

/** Ask price per good over time. A data table below is the accessible alternative. */
export function PriceChart({ series, xLabel = "time", yLabel = "ask (C)" }: { series: Series[]; xLabel?: "time" | "day"; yLabel?: string }) {
  const box = useRef<HTMLDivElement>(null);
  const plot = useRef<uPlot | null>(null);

  const xs = [...new Set(series.flatMap((s) => s.points.map((p) => p.ts)))].sort((a, b) => a - b);
  const data: uPlot.AlignedData = [
    xs,
    ...GOODS.map((g) => {
      const m = new Map((series.find((s) => s.good === g)?.points ?? []).map((p) => [p.ts, p.ask]));
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
        { stroke: cssVar("--muted"), grid: { stroke: cssVar("--border") }, label: xLabel === "day" ? "day" : undefined },
        { stroke: cssVar("--muted"), grid: { stroke: cssVar("--border") }, label: yLabel },
      ],
      series: [{}, ...GOODS.map((g) => ({ label: g, stroke: cssVar(`--${g}`), width: 2, spanGaps: true }))],
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
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [xLabel, yLabel]);

  useEffect(() => {
    plot.current?.setData(data);
  });

  const last = (g: string) => series.find((s) => s.good === g)?.points.at(-1)?.ask;

  return (
    <div>
      <div className="legend" aria-hidden>
        {GOODS.map((g) => (
          <span key={g}>
            <i style={{ background: `var(--${g})` }} />
            {g}
          </span>
        ))}
      </div>
      <div ref={box} className="chart" role="img" aria-label="Ask price per good over time" />
      <table className="sr-only">
        <caption>Latest ask prices</caption>
        <tbody>
          {GOODS.map((g) => (
            <tr key={g}>
              <th scope="row">{g}</th>
              <td>{last(g) ?? "no data"} C</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
