"use client";

import { useState, type CSSProperties, type ReactNode } from "react";
import { LevelsMark } from "./LevelsMark";

/*
 * A working copy of the real Levels panel (Sources/Levels/MixerPanel.swift):
 * same layout, sizes, translucent material and slider style. App icons are
 * generic so no third-party brands appear.
 */

type DemoApp = { id: string; name: string; bg: string; glyph: ReactNode; v: number; playing: boolean; muted: boolean };

const g = { fill: "none", stroke: "#fff", strokeWidth: 1.9, strokeLinecap: "round", strokeLinejoin: "round" } as const;

const ACTIVE: DemoApp[] = [
  { id: "music", name: "Music", v: 72, playing: true, muted: false, bg: "linear-gradient(180deg,#ff7a6b,#f2385a)",
    glyph: <><path d="M9 17V6l9-2v11" {...g} /><circle cx="6.5" cy="17" r="2.5" {...g} /><circle cx="15.5" cy="15" r="2.5" {...g} /></> },
  { id: "call", name: "Video call", v: 100, playing: true, muted: false, bg: "linear-gradient(180deg,#5fe27a,#1fb44a)",
    glyph: <><rect x="3" y="7" width="12" height="10" rx="2" {...g} /><path d="m15 11 6-3v8l-6-3z" {...g} /></> },
  { id: "browser", name: "Browser", v: 35, playing: false, muted: false, bg: "linear-gradient(180deg,#6cc4ff,#1b7cf2)",
    glyph: <><circle cx="12" cy="12" r="8" {...g} /><path d="M4 12h16M12 4c2.6 2.6 2.6 13.4 0 16M12 4c-2.6 2.6-2.6 13.4 0 16" {...g} /></> },
  { id: "game", name: "Game", v: 100, playing: true, muted: true, bg: "linear-gradient(180deg,#b28cff,#7a4bf0)",
    glyph: <><rect x="3" y="8" width="18" height="9" rx="4" {...g} /><path d="M8 11v3M6.5 12.5h3" {...g} /><circle cx="16" cy="11.5" r=".9" fill="#fff" /><circle cx="18" cy="13.5" r=".9" fill="#fff" /></> },
];

const OTHERS: DemoApp[] = [
  { id: "chat", name: "Chat", v: 100, playing: false, muted: false, bg: "linear-gradient(180deg,#ffd45c,#f5a623)",
    glyph: <path d="M5 6h14v9H9l-4 3z" {...g} /> },
  { id: "editor", name: "Editor", v: 100, playing: false, muted: false, bg: "linear-gradient(180deg,#8e9aaf,#5b6577)",
    glyph: <path d="m14 5 5 5-9 9H5v-5z" {...g} /> },
];

function Slider({ value, muted, label, onChange }: { value: number; muted?: boolean; label: string; onChange: (v: number) => void }) {
  return (
    <input
      type="range" min={0} max={100} value={value} aria-label={label}
      className={`lv-range${muted ? " is-muted" : ""}`}
      style={{ "--v": `${value}%` } as CSSProperties}
      onChange={(e) => onChange(Number(e.target.value))}
    />
  );
}

function Speaker({ level }: { level: number }) {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M4 9h3l5-4v14l-5-4H4z" fill="currentColor" />
      {level === 0 && <path d="m16 9 5 6M21 9l-5 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />}
      {level > 0 && <path d="M15.5 9.5a3.5 3.5 0 0 1 0 5" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />}
      {level > 33 && <path d="M18 7a7 7 0 0 1 0 10" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />}
      {level > 66 && <path d="M20.5 4.5a10.5 10.5 0 0 1 0 15" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />}
    </svg>
  );
}

function Row({ app, onChange }: { app: DemoApp; onChange: (patch: Partial<DemoApp>) => void }) {
  const shown = app.muted ? 0 : app.v;
  return (
    <div className="lv-row">
      <button
        className="lv-icon" aria-pressed={app.muted}
        aria-label={`${app.muted ? "Unmute" : "Mute"} ${app.name}`} title={app.muted ? "Unmute" : "Mute"}
        onClick={() => onChange({ muted: !app.muted })}
      >
        <span className="lv-tile" style={{ background: app.bg }}>
          <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true">{app.glyph}</svg>
        </span>
        {app.muted && (
          <span className="lv-badge" aria-hidden="true">
            <svg width="8" height="8" viewBox="0 0 24 24"><path d="M3 9h3l5-4v14l-5-4H3z" fill="#fff" /><path d="m15 9 6 6M21 9l-6 6" stroke="#fff" strokeWidth="2.6" strokeLinecap="round" /></svg>
          </span>
        )}
      </button>
      <div className="lv-row-body">
        <div className="lv-row-top">
          <span className="lv-name">{app.name}</span>
          {app.playing && !app.muted && <span className="lv-bars" aria-hidden="true"><i /><i /><i /></span>}
          <span className="lv-pct">{shown}%</span>
        </div>
        <Slider value={app.v} muted={app.muted} label={`${app.name} volume`} onChange={(v) => onChange({ v, muted: v > 0 ? false : app.muted })} />
      </div>
    </div>
  );
}

export function PanelDemo() {
  const [apps, setApps] = useState(ACTIVE);
  const [others, setOthers] = useState(OTHERS);
  const [showOthers, setShowOthers] = useState(false);
  const [device, setDevice] = useState(64);
  const [deviceMuted, setDeviceMuted] = useState(false);
  const [login, setLogin] = useState(true);

  const patch = (list: "apps" | "others", id: string, p: Partial<DemoApp>) =>
    (list === "apps" ? setApps : setOthers)((all) => all.map((a) => (a.id === id ? { ...a, ...p } : a)));
  const resetAll = () => {
    setApps((all) => all.map((a) => ({ ...a, v: 100, muted: false })));
    setOthers((all) => all.map((a) => ({ ...a, v: 100, muted: false })));
  };
  const deviceShown = deviceMuted ? 0 : device;

  return (
    <div className="lv-stage" aria-label="Interactive preview of the Levels panel">
      <div className="lv-menubar" aria-hidden="true">
        <svg width="15" height="11" viewBox="0 0 24 18"><path d="M12 16.5 15 13a4.5 4.5 0 0 0-6 0zM5.5 9.6a9.5 9.5 0 0 1 13 0l-2 2.2a6.5 6.5 0 0 0-9 0zM1.5 5.5a15 15 0 0 1 21 0l-2 2.1a12 12 0 0 0-17 0z" fill="currentColor" /></svg>
        <span className="lv-item on"><LevelsMark size={13} color="rgba(0,0,0,.85)" ring="#d9dbe3" /></span>
        <span>Thu 9:41</span>
      </div>

      <div className="lv-panel">
        <div className="lv-head">
          <LevelsMark size={26} color="rgba(0,0,0,.85)" ring="#eeeef2" />
          <div>
            <div className="lv-title">Levels</div>
            <div className="lv-sub">Volume for every app</div>
          </div>
        </div>

        <div className="lv-card">
          <div className="lv-card-top">
            <svg width="14" height="11" viewBox="0 0 24 18" aria-hidden="true"><rect x="4" y="2" width="16" height="11" rx="1.5" fill="none" stroke="currentColor" strokeWidth="2" /><path d="M1 16h22" stroke="currentColor" strokeWidth="2" strokeLinecap="round" /></svg>
            <span className="lv-device">MacBook Pro Speakers</span>
            <span className="lv-pct">{deviceShown}%</span>
          </div>
          <div className="lv-card-controls">
            <button className="lv-mute" onClick={() => setDeviceMuted(!deviceMuted)} aria-label={deviceMuted ? "Unmute" : "Mute"} title={deviceMuted ? "Unmute" : "Mute"}>
              <Speaker level={deviceShown} />
            </button>
            <Slider value={device} muted={deviceMuted} label="Output device volume" onChange={(v) => { setDevice(v); if (v > 0) setDeviceMuted(false); }} />
          </div>
        </div>

        <div className="lv-label">Apps</div>
        {apps.map((a) => <Row key={a.id} app={a} onChange={(p) => patch("apps", a.id, p)} />)}

        <button className="lv-more" onClick={() => setShowOthers(!showOthers)} aria-expanded={showOthers}>
          <svg width="9" height="9" viewBox="0 0 24 24" style={{ transform: `rotate(${showOthers ? 90 : 0}deg)` }} aria-hidden="true"><path d="m9 5 7 7-7 7" fill="none" stroke="currentColor" strokeWidth="3.4" strokeLinecap="round" strokeLinejoin="round" /></svg>
          Other apps with sound <span className="lv-count">{others.length}</span>
        </button>
        {showOthers && others.map((a) => <Row key={a.id} app={a} onChange={(p) => patch("others", a.id, p)} />)}

        <div className="lv-divider" />
        <div className="lv-foot">
          <button className="lv-switch-row" role="switch" aria-checked={login} onClick={() => setLogin(!login)}>
            <span className={`lv-switch${login ? " on" : ""}`}><span /></span>
            Launch at login
          </button>
          <button className="lv-btn" onClick={resetAll} title="Set every app back to full volume">Reset</button>
          <button className="lv-btn" title="It’s a preview, Levels itself keeps running">Quit</button>
        </div>
      </div>
    </div>
  );
}
