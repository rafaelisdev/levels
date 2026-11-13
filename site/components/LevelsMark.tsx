/** The Levels symbol from the brand board: three faders in a 120×120 viewBox. */
export function LevelsMark({ size = 22, color = "#0a0a0a", ring = "#ffffff" }: { size?: number; color?: string; ring?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 120 120" role="img" aria-label="Levels" style={{ display: "block", flex: "none" }}>
      {[30, 60, 90].map((x) => (
        <line key={x} x1={x} y1={20} x2={x} y2={100} stroke={color} strokeWidth={7} strokeLinecap="round" />
      ))}
      {[[30, 76], [60, 36], [90, 58]].map(([x, y]) => (
        <circle key={x} cx={x} cy={y} r={12.5} fill={color} stroke={ring} strokeWidth={7} />
      ))}
    </svg>
  );
}
