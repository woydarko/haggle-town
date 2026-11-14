import { useEffect, useState } from "react";
import { api, type Config, type Feed, type Market } from "../api.ts";

export type Live = { market: Market[] | null; feed: Feed | null; config: Config | null };

/** Polls the public API every 10 s. A failed call keeps the last good value (null until the first success). */
export function useLive(): Live {
  const [live, setLive] = useState<Live>({ market: null, feed: null, config: null });
  useEffect(() => {
    let alive = true;
    const put = (patch: Partial<Live>) => alive && setLive((p) => ({ ...p, ...patch }));
    api.config().then((config) => put({ config })).catch(() => undefined);
    const load = () => {
      api.market().then((market) => put({ market })).catch(() => undefined);
      api.feed().then((feed) => put({ feed })).catch(() => undefined);
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
