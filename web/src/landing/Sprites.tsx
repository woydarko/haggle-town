// 16x16 pixel sprites of the game's goods and tools. Tool colors are taken from the in-game models.
const PAL: Record<string, string> = {
  k: "#2B2118", // outline (ink)
  R: "#D93A2B", H: "#E8D29A", D: "#3A3A3A", // axe: red head, pale handle, dark grip
  S: "#5E7A8C", P: "#7A4A1E", // pickaxe: slate head, brown handle
  M: "#7A1F2B", C: "#C9A46A", B: "#333333", // rod: maroon shaft, cork grip, reel
  W: "#A8661C", w: "#8A5216", T: "#E2C08A", t: "#A8661C", // log
  F: "#1E7A78", f: "#6FB3AE", // fish
  G: "#6B7885", g: "#4F5D6B", c: "#8FD3FF", // ore rock + crystal
};

const SPRITES = {
  axe: ["..........kk....", ".....kkkkkHHk...", "....kRRRRkHHk...", "...kRRRRRkHHk...", "...kRRRRRkHHk...", "....kRRRRkHHk...", ".....kkkkkHHk...", ".........kHHk...", ".........kHHk...", ".........kHHk...", ".........kDDk...", ".........kDDk...", ".........kDDk...", ".........kDDk...", "..........kk....", "................"],
  pickaxe: ["................", "..kk........kk..", ".kSSk......kSSk.", ".kSSSkkkkkkSSSk.", "..kSSSSSSSSSSk..", "...kkkkPPkkkk...", "......kPPk......", "......kPPk......", "......kPPk......", "......kPPk......", "......kPPk......", "......kPPk......", "......kPPk......", "......kPPk......", ".......kk.......", "................"],
  rod: ["..............kk", ".............kMk", "............kMk.", "...........kMk..", "..........kMk...", ".........kMk....", "........kMk.....", ".......kMk......", "......kCk.......", ".....kCCk.......", "....kCCk.kk.....", "...kCCk.kBBk....", "..kCCk..kBBk....", ".kCCk....kk.....", ".kkk............", "................"],
  wood: ["................", "................", "................", "................", "..kkkkkkkkkkk...", ".kWWwWWWWwWWkkk.", ".kWWWWwWWWWkTTTk", ".kwWWWWWWwWkTtTk", ".kWWWwWWWWWkTTTk", ".kWWWWWWwWWWkkk.", "..kkkkkkkkkkk...", "................", "................", "................", "................", "................"],
  fish: ["................", "................", "................", "....kkkkkk......", "..kkFFFFFFkk..kk", ".kFFFFFFFFFkkkFk", "kFkFFFFFFFFFFFFk", "kFFFFFFFFFFFkkFk", ".kffffffffffk.kk", "..kkffffffkk....", "....kkkkkk......", "................", "................", "................", "................", "................"],
  ore: ["................", "................", "................", "................", ".....kkkkk......", "....kGGGGGk.....", "...kGGgGGGGkk...", "..kGGGGGGcGGGk..", ".kGGgGGGcccGGGk.", ".kGGGGGGGcGgGGk.", ".kgGGGGGGGGGGgk.", "..kkkkkkkkkkkk..", "................", "................", "................", "................"],
} as const;

export type SpriteName = keyof typeof SPRITES;

export function Sprite({ name, size = 40 }: { name: SpriteName; size?: number }) {
  return (
    <svg className="sprite" width={size} height={size} viewBox="0 0 16 16" shapeRendering="crispEdges" aria-hidden="true">
      {SPRITES[name].flatMap((row, y) =>
        [...row].map((ch, x) => (PAL[ch] ? <rect key={`${x}-${y}`} x={x} y={y} width={1} height={1} fill={PAL[ch]} /> : null)),
      )}
    </svg>
  );
}
