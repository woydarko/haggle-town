import { useEffect, useState } from "react";
import { api, type Config, type Feed, type Market } from "../api.ts";

/** failed: the last poll failed. With data still null that is the error state; with data present the numbers are stale. */
export type Live = { market: Market[] | null; prevMarket: Market[] | null; feed: Feed | null; config: Config | null; failed: boolean; at: number | null };

/** Polls the public API every 10 s. A failed call keeps the last good value. */
export function useLive(): Live {
  const [live, setLive] = useState<Live>({ market: null, prevMarket: null, feed: null, config: null, failed: false, at: null });
  useEffect(() => {
    let alive = true;
    api.config().then((config) => alive && setLive((p) => ({ ...p, config }))).catch(() => undefined);
    const load = async () => {
      try {
        const [market, feed] = await Promise.all([api.market(), api.feed()]);
        if (alive) setLive((p) => ({ ...p, prevMarket: p.market, market, feed, failed: false, at: Date.now() }));
      } catch {
        if (alive) setLive((p) => ({ ...p, failed: true }));
      }
    };
    load();
    const id = setInterval(load, 10_000);
    return () => {
      alive = false;
      clearInterval(id);
    };
  }, []);
  return live;
}
