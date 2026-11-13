"use client";

import { useState, type CSSProperties, type ReactNode } from "react";
import { LevelsMark } from "./LevelsMark";

type Demo = { id: string; name: string; tone: string; glyph: ReactNode; v: number; playing: boolean; muted: boolean };

const stroke = { fill: "none", stroke: "#fff", strokeWidth: 1.8, strokeLinecap: "round", strokeLinejoin: "round" } as const;

const START: Demo[] = [
  { id: "music", name: "Music", tone: "#0a0a0a", v: 72, playing: true, muted: false,
    glyph: <><path d="M9 17V6l9-2v11" {...stroke} /><circle cx="6.5" cy="17" r="2.5" {...stroke} /><circle cx="15.5" cy="15" r="2.5" {...stroke} /></> },
  { id: "call", name: "Video call", tone: "#404040", v: 100, playing: true, muted: false,
    glyph: <><rect x="3" y="7" width="12" height="10" rx="2" {...stroke} /><path d="m15 11 6-3v8l-6-3z" {...stroke} /></> },
  { id: "browser", name: "Browser", tone: "#737373", v: 35, playing: false, muted: false,
    glyph: <><circle cx="12" cy="12" r="8" {...stroke} /><path d="M4 12h16M12 4c2.6 2.6 2.6 13.4 0 16M12 4c-2.6 2.6-2.6 13.4 0 16" {...stroke} /></> },
  { id: "game", name: "Game", tone: "#a3a3a3", v: 0, playing: true, muted: true,
    glyph: <><rect x="3" y="8" width="18" height="9" rx="4" {...stroke} /><path d="M8 11v3M6.5 12.5h3" {...stroke} /><circle cx="16" cy="11.5" r=".9" fill="#fff" /><circle cx="18" cy="13.5" r=".9" fill="#fff" /></> },
];

function Slider({ value, muted, label, onChange }: { value: number; muted?: boolean; label: string; onChange: (v: number) => void }) {
  return (
    <input
      type="range" min={0} max={100} value={value} aria-label={label}
      className={`range${muted ? " is-muted" : ""}`}
      style={{ "--v": `${value}%` } as CSSProperties}
      onChange={(e) => onChange(Number(e.target.value))}
    />
  );
}

/** A working replica of the Levels menu bar panel (sliders and mute are live). */
export function PanelDemo() {
  const [apps, setApps] = useState(START);
  const [device, setDevice] = useState(64);
  const update = (id: string, patch: Partial<Demo>) => setApps((all) => all.map((a) => (a.id === id ? { ...a, ...patch } : a)));

  return (
    <div className="stage" aria-label="Interactive preview of the Levels panel">
      <div className="menubar" aria-hidden="true">
        <span>Wi‑Fi</span>
        <span className="on"><LevelsMark size={14} ring="#e8e8e8" /></span>
        <span>Thu 9:41</span>
      </div>
      <div className="panel">
        <div className="panel-head">
          <LevelsMark size={24} />
          <div>
            <strong>Levels</strong>
            <span>Volume for every app</span>
          </div>
        </div>
        <div className="device">
          <div className="device-top"><span>MacBook Pro Speakers</span><span className="mono">{device}%</span></div>
          <Slider value={device} label="Output device volume" onChange={setDevice} />
        </div>
        <div className="label">APPS</div>
        {apps.map((a) => (
          <div className="app" key={a.id}>
            <button
              className="app-icon" style={{ background: a.tone }} aria-pressed={a.muted}
              aria-label={`${a.muted ? "Unmute" : "Mute"} ${a.name}`}
              onClick={() => update(a.id, { muted: !a.muted })}
            >
              <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true">{a.glyph}</svg>
            </button>
            <div>
              <div className="app-top">
                <span>{a.name}</span>
                {a.playing && !a.muted && <span className="bars" aria-hidden="true"><i /><i /><i /></span>}
                <span className="pct">{a.muted ? 0 : a.v}%</span>
              </div>
              <Slider
                value={a.v} muted={a.muted} label={`${a.name} volume`}
                onChange={(v) => update(a.id, { v, muted: v === 0 ? a.muted : false })}
              />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
