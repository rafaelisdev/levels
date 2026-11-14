import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { ImageResponse } from "next/og";
import { site } from "@/lib/site";

export const alt = "Levels: a volume slider for every Mac app";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default async function OpenGraphImage() {
  const [semibold, medium, art] = await Promise.all([
    readFile(join(process.cwd(), "node_modules/@fontsource/inter-tight/files/inter-tight-latin-600-normal.woff")),
    readFile(join(process.cwd(), "node_modules/@fontsource/inter-tight/files/inter-tight-latin-500-normal.woff")),
    readFile(join(process.cwd(), "public/renders/hero-og.png")),
  ]);
  const artSrc = `data:image/png;base64,${art.toString("base64")}`;

  const lines = [30, 60, 90];
  const knobs = [[30, 76], [60, 36], [90, 58]];

  return new ImageResponse(
    (
      <div style={{ width: "100%", height: "100%", display: "flex", background: "#fff", fontFamily: "Inter Tight", position: "relative" }}>
        <div style={{ position: "absolute", inset: 24, border: "1px solid #ebebeb", borderRadius: 6, display: "flex" }} />
        <div style={{ display: "flex", flexDirection: "column", justifyContent: "center", padding: "0 0 0 84px", width: 600 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
            <svg width="44" height="44" viewBox="0 0 120 120">
              {lines.map((x) => <line key={x} x1={x} y1={20} x2={x} y2={100} stroke="#0a0a0a" strokeWidth={7} strokeLinecap="round" />)}
              {knobs.map(([x, y]) => <circle key={x} cx={x} cy={y} r={12.5} fill="#0a0a0a" stroke="#fff" strokeWidth={7} />)}
            </svg>
            <span style={{ fontSize: 40, fontWeight: 600, letterSpacing: "-0.05em", color: "#0a0a0a" }}>Levels</span>
          </div>
          <div style={{ fontSize: 64, fontWeight: 600, letterSpacing: "-0.05em", lineHeight: 1.02, color: "#0a0a0a", marginTop: 36 }}>
            A volume slider for every Mac app.
          </div>
          <div style={{ display: "flex", marginTop: 36, padding: "14px 18px", border: "1px solid #dedede", borderRadius: 6, background: "#fafafa", fontSize: 24, fontWeight: 500, color: "#0a0a0a" }}>
            <span style={{ color: "#a3a3a3", marginRight: 12 }}>$</span>{site.brew}
          </div>
        </div>
        <img src={artSrc} width={620} height={388} style={{ position: "absolute", right: 0, top: 120 }} alt="" />
      </div>
    ),
    {
      ...size,
      fonts: [
        { name: "Inter Tight", data: semibold, weight: 600, style: "normal" },
        { name: "Inter Tight", data: medium, weight: 500, style: "normal" },
      ],
    },
  );
}
