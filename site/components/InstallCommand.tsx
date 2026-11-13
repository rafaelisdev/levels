"use client";

import { useState } from "react";
import { site } from "@/lib/site";

const METHODS = [
  { id: "brew", label: "Homebrew", command: site.brew },
  { id: "curl", label: "curl", command: site.curl },
] as const;

export function InstallCommand() {
  const [method, setMethod] = useState<(typeof METHODS)[number]["id"]>("brew");
  const [copied, setCopied] = useState(false);
  const command = METHODS.find((m) => m.id === method)!.command;

  async function copy() {
    try {
      await navigator.clipboard.writeText(command);
    } catch {
      const area = document.createElement("textarea");
      area.value = command;
      document.body.appendChild(area);
      area.select();
      document.execCommand("copy");
      area.remove();
    }
    setCopied(true);
    setTimeout(() => setCopied(false), 1600);
  }

  return (
    <div className="cmd">
      <div className="cmd-tabs" role="tablist" aria-label="Install method">
        {METHODS.map((m) => (
          <button
            key={m.id}
            role="tab"
            className="cmd-tab"
            aria-selected={method === m.id}
            onClick={() => { setMethod(m.id); setCopied(false); }}
          >
            {m.label}
          </button>
        ))}
      </div>
      <div className="cmd-row" role="tabpanel">
        <code><span className="prompt">$</span>{command}</code>
        <button className="copy" onClick={copy} data-copied={copied} aria-live="polite">
          {copied ? "Copied" : "Copy"}
        </button>
      </div>
    </div>
  );
}
