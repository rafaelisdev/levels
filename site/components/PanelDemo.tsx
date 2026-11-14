"use client";

import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from "react";
import { LevelsMark } from "./LevelsMark";

/*
 * A working copy of the real Levels panel (Sources/Levels/MixerPanel.swift and
 * OutputsPage.swift): same layout, sizes, translucent material and slider style.
 * App icons and device names are generic so no third-party brands appear.
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

/* Outputs. `latency` is the device's own path in ms before any offset (example values). */

type OutputKind = "laptop" | "tv" | "headphones";
type DemoOutput = { id: string; name: string; kind: OutputKind; builtIn: boolean; latency: number };

const OUTPUTS: DemoOutput[] = [
  { id: "mac", name: "MacBook Pro Speakers", kind: "laptop", builtIn: true, latency: 28 },
  { id: "tv", name: "Living Room TV", kind: "tv", builtIn: false, latency: 70 },
  { id: "phones", name: "Headphones", kind: "headphones", builtIn: false, latency: 160 },
];
const DEFAULT_OUTPUT = "mac";
const OFFSET = { min: -200, max: 500 }; // MixerModel.offsetRange, in ms
const START_OFFSETS: Record<string, number> = { tv: 100, phones: 0 };

type SyncLine = { name: string; own: number; held: number };

/** What the engine reports: every playing output's own path, and how long it is held back to meet the slowest. */
function syncSummary(on: string[], offsets: Record<string, number>) {
  const own = OUTPUTS.filter((o) => on.includes(o.id))
    .map((o) => ({ name: o.name, own: Math.max(1, o.latency + (o.builtIn ? 0 : offsets[o.id] ?? 0)) }));
  const delay = Math.max(1, ...own.map((o) => o.own));
  return { delay, lines: own.map((o): SyncLine => ({ ...o, held: delay - o.own })) };
}

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

const Chevron = ({ size, dir }: { size: number; dir: "left" | "right" }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden="true">
    <path d={dir === "right" ? "m9 5 7 7-7 7" : "m15 5-7 7 7 7"} fill="none" stroke="currentColor" strokeWidth="3.4" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

function DeviceIcon({ kind, size = 12 }: { kind: OutputKind; size?: number }) {
  const s = { fill: "none", stroke: "currentColor", strokeWidth: 2, strokeLinecap: "round", strokeLinejoin: "round" } as const;
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden="true">
      {kind === "laptop" && <><rect x="4" y="5" width="16" height="11" rx="1.5" {...s} /><path d="M1.5 19.5h21" {...s} /></>}
      {kind === "tv" && <><rect x="2.5" y="4" width="19" height="13" rx="2" {...s} /><path d="M8 21h8" {...s} /></>}
      {kind === "headphones" && <><path d="M4 16v-4a8 8 0 0 1 16 0v4" {...s} /><rect x="2.8" y="13.5" width="5" height="7.5" rx="1.8" fill="currentColor" /><rect x="16.2" y="13.5" width="5" height="7.5" rx="1.8" fill="currentColor" /></>}
    </svg>
  );
}

function Check({ on }: { on: boolean }) {
  return (
    <svg className="lv-check" width="15" height="15" viewBox="0 0 24 24" aria-hidden="true">
      {on
        ? <><circle cx="12" cy="12" r="10.5" fill="currentColor" /><path d="m7.4 12.4 3.1 3.1 6.1-6.6" fill="none" stroke="#fff" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" /></>
        : <circle cx="12" cy="12" r="9.8" fill="none" stroke="currentColor" strokeWidth="1.6" />}
    </svg>
  );
}

/** The small macOS activity indicator. */
const Spinner = () => (
  <svg className="lv-spin" width="12" height="12" viewBox="0 0 24 24" aria-hidden="true">
    {Array.from({ length: 8 }, (_, i) => (
      <path key={i} d="M12 2.5v5" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" opacity={0.2 + (i / 7) * 0.8} transform={`rotate(${i * 45} 12 12)`} />
    ))}
  </svg>
);

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

/** DelayTimeline in the app: each output's own delay (solid) plus how long Levels holds it back (light). */
function DelayBox({ delay, lines }: { delay: number; lines: SyncLine[] }) {
  return (
    <div className="lv-delay">
      <div className="lv-delay-head"><span>Delay</span><b>{Math.round(delay)} ms</b></div>
      {lines.map((l) => (
        <div key={l.name} className="lv-delay-row">
          <div className="lv-delay-top">
            <span className="lv-delay-name">{l.name}</span>
            <span className="lv-delay-tag">{l.held < 0.5 ? "slowest" : `waits ${Math.round(l.held)} ms`}</span>
          </div>
          <div className="lv-track">
            <i className="lv-own" style={{ width: `${(l.own / delay) * 100}%` }} />
            {l.held >= 0.5 && <i className="lv-held" />}
          </div>
        </div>
      ))}
    </div>
  );
}

/** A still crop of the Sync section, for the features grid. */
export function SyncPreview() {
  return (
    <div className="lv-mini" aria-label="The Sync section of the Levels Outputs page">
      <div className="lv-label">Sync</div>
      <DelayBox {...syncSummary(OUTPUTS.map((o) => o.id), START_OFFSETS)} />
    </div>
  );
}

const fmtOffset = (ms: number) => `${ms < 0 ? "-" : "+"}${Math.abs(ms)} ms`;

const clampOffset = (ms: number) => Math.min(OFFSET.max, Math.max(OFFSET.min, Math.round(ms)));

function OffsetRow({ output, value, update }: { output: DemoOutput; value: number; update: (f: (ms: number) => number) => void }) {
  const pct = ((value - OFFSET.min) / (OFFSET.max - OFFSET.min)) * 100;
  return (
    <div className="lv-offset">
      <div className="lv-offset-top">
        <span className="lv-out-icon"><DeviceIcon kind={output.kind} size={11} /></span>
        <span className="lv-out-name">{output.name}</span>
        <button className="lv-step" onClick={() => update((ms) => ms - 1)} aria-label={`${output.name}: 1 ms less`}>
          <svg width="9" height="9" viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14" stroke="currentColor" strokeWidth="4" strokeLinecap="round" /></svg>
        </button>
        <span className="lv-ms">{fmtOffset(value)}</span>
        <button className="lv-step" onClick={() => update((ms) => ms + 1)} aria-label={`${output.name}: 1 ms more`}>
          <svg width="9" height="9" viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14M12 5v14" stroke="currentColor" strokeWidth="4" strokeLinecap="round" /></svg>
        </button>
      </div>
      <input
        type="range" min={OFFSET.min} max={OFFSET.max} step={1} value={value}
        aria-label={`${output.name} offset`} aria-valuetext={fmtOffset(value)}
        className="lv-range" style={{ "--v": `${pct}%` } as CSSProperties}
        onChange={(e) => { const ms = Number(e.target.value); update(() => ms); }}
      />
    </div>
  );
}

type Page = "apps" | "outputs";

export function PanelDemo() {
  const [apps, setApps] = useState(ACTIVE);
  const [others, setOthers] = useState(OTHERS);
  const [showOthers, setShowOthers] = useState(false);
  const [device, setDevice] = useState(64);
  const [deviceMuted, setDeviceMuted] = useState(false);
  const [login, setLogin] = useState(true);

  const [on, setOn] = useState<string[]>([DEFAULT_OUTPUT, "tv"]);
  const [offsets, setOffsets] = useState(START_OFFSETS);
  const [busy, setBusy] = useState(false);

  // Page slide: the old page leaves while the new one comes in (same 0.2 s ease as the app).
  const [page, setPage] = useState<Page>("apps");
  const [leaving, setLeaving] = useState<Page | null>(null);
  const slideTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const busyTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  useEffect(() => () => { clearTimeout(slideTimer.current); clearTimeout(busyTimer.current); }, []);

  const go = (next: Page) => {
    if (next === page) return;
    setLeaving(page);
    setPage(next);
    clearTimeout(slideTimer.current);
    slideTimer.current = setTimeout(() => setLeaving(null), 220);
  };

  const patch = (list: "apps" | "others", id: string, p: Partial<DemoApp>) =>
    (list === "apps" ? setApps : setOthers)((all) => all.map((a) => (a.id === id ? { ...a, ...p } : a)));
  const resetAll = () => {
    setApps((all) => all.map((a) => ({ ...a, v: 100, muted: false })));
    setOthers((all) => all.map((a) => ({ ...a, v: 100, muted: false })));
  };
  const toggleOutput = (id: string) => {
    if (id === DEFAULT_OUTPUT) return; // the default output always plays
    setOn((all) => (all.includes(id) ? all.filter((x) => x !== id) : [...all, id]));
    setBusy(true);
    clearTimeout(busyTimer.current);
    busyTimer.current = setTimeout(() => setBusy(false), 700);
  };
  const deviceShown = deviceMuted ? 0 : device;
  const syncing = on.length >= 2;
  const adjustable = OUTPUTS.filter((o) => on.includes(o.id) && !o.builtIn);

  const appsPage = (
    <>
      <div className="lv-head">
        <LevelsMark size={26} color="rgba(0,0,0,.85)" ring="#eeeef2" />
        <div>
          <div className="lv-title">Levels</div>
          <div className="lv-sub">Volume for every app</div>
        </div>
      </div>

      <div className="lv-card">
        <div className="lv-card-top">
          <button className="lv-device-btn" onClick={() => go("outputs")} title="Choose outputs">
            <svg width="14" height="11" viewBox="0 0 24 18" aria-hidden="true"><rect x="4" y="2" width="16" height="11" rx="1.5" fill="none" stroke="currentColor" strokeWidth="2" /><path d="M1 16h22" stroke="currentColor" strokeWidth="2" strokeLinecap="round" /></svg>
            <span className="lv-device">MacBook Pro Speakers</span>
            {syncing && <span className="lv-plus">+{on.length - 1}</span>}
            <Chevron size={8} dir="right" />
          </button>
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
    </>
  );

  const outputsPage = (
    <div className="lv-outputs">
      <button className="lv-back" onClick={() => go("apps")} title="Back">
        <Chevron size={11} dir="left" />
        <span className="lv-back-title">Outputs</span>
        {busy && <span className="lv-busy"><Spinner />Lining up…</span>}
      </button>
      <p className="lv-note">Play on several outputs at once. Levels lines them up so they sound together.</p>

      <div className="lv-label lv-label-tight">Play on</div>
      {OUTPUTS.map((o) => {
        const isDefault = o.id === DEFAULT_OUTPUT;
        return (
          <button
            key={o.id} className="lv-out" role="checkbox" aria-checked={on.includes(o.id)} disabled={isDefault}
            title={isDefault ? "The default output always plays" : undefined} onClick={() => toggleOutput(o.id)}
          >
            <Check on={on.includes(o.id)} />
            <span className="lv-out-icon"><DeviceIcon kind={o.kind} /></span>
            <span className="lv-out-name">{o.name}</span>
            {isDefault && <span className="lv-tag">Default</span>}
          </button>
        );
      })}

      {syncing && adjustable.length > 0 && (
        <>
          <div className="lv-label">Sync</div>
          <DelayBox {...syncSummary(on, offsets)} />
          {adjustable.map((o) => (
            <OffsetRow key={o.id} output={o} value={offsets[o.id] ?? 0} update={(f) => setOffsets((all) => ({ ...all, [o.id]: clampOffset(f(all[o.id] ?? 0)) }))} />
          ))}
          <p className="lv-note lv-note-end">Play something with a clear beat and move a device until the echo is gone.</p>
        </>
      )}
    </div>
  );

  const render = (p: Page) => (p === "apps" ? appsPage : outputsPage);
  const forward = page === "outputs";

  return (
    <div className="lv-stage" aria-label="Interactive preview of the Levels panel">
      <div className="lv-menubar" aria-hidden="true">
        <svg width="15" height="11" viewBox="0 0 24 18"><path d="M12 16.5 15 13a4.5 4.5 0 0 0-6 0zM5.5 9.6a9.5 9.5 0 0 1 13 0l-2 2.2a6.5 6.5 0 0 0-9 0zM1.5 5.5a15 15 0 0 1 21 0l-2 2.1a12 12 0 0 0-17 0z" fill="currentColor" /></svg>
        <span className="lv-item on"><LevelsMark size={13} color="rgba(0,0,0,.85)" ring="#d9dbe3" /></span>
        <span>Thu 9:41</span>
      </div>

      <div className="lv-panel">
        {leaving && (
          <div className={`lv-page lv-leaving ${forward ? "to-left" : "to-right"}`} aria-hidden="true" inert>
            {render(leaving)}
          </div>
        )}
        <div key={page} className={`lv-page${leaving ? (forward ? " from-right" : " from-left") : ""}`}>
          {render(page)}
        </div>
      </div>
    </div>
  );
}
