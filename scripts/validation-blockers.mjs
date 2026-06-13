export const validationBlockerCodes = [
  "locked-session",
  "window-not-found",
  "no-ax-window",
  "computer-use-timeout",
  "remote-connection",
  "activation-failed",
  "black-capture",
  "flat-capture",
  "transparent-capture",
  "invalid-capture",
  "screen-recording-permission",
  "stale-bundle",
  "tool-layer-unknown",
];

const classifierRules = [
  {
    code: "locked-session",
    patterns: [/locked-session/i, /CGSSessionScreenIsLocked\s*=?\s*Yes/i, /macOS session is locked/i],
  },
  {
    code: "black-capture",
    patterns: [/black-capture/i, /near black/i, /all black/i],
  },
  {
    code: "flat-capture",
    patterns: [/flat-capture/i, /near-zero visual variance/i, /near[- ]flat/i, /near[- ]single[- ]color/i],
  },
  {
    code: "transparent-capture",
    patterns: [/transparent-capture/i, /mostly transparent/i],
  },
  {
    code: "invalid-capture",
    patterns: [/invalid-capture/i, /zero dimensions/i, /dimensions are too small/i, /unsupported PNG/i],
  },
  {
    code: "screen-recording-permission",
    patterns: [/Screen Recording permission/i, /not authorized.*screen/i, /TCC.*screen/i],
  },
  {
    code: "stale-bundle",
    patterns: [/stale-bundle/i, /older than source inputs/i, /stale app/i],
  },
  {
    code: "computer-use-timeout",
    patterns: [/timeoutReached/i, /Computer Use.*timeout/i, /timed out.*Computer Use/i],
  },
  {
    code: "remote-connection",
    patterns: [/remoteConnection/i, /remote connection/i],
  },
  {
    code: "no-ax-window",
    patterns: [/no AX window/i, /0 AX windows/i, /System Events.*0 windows/i],
  },
  {
    code: "window-not-found",
    patterns: [/cgWindowNotFound/i, /window-not-found/i, /No visible .*app window found/i, /timed out waiting for visible .* window/i],
  },
  {
    code: "activation-failed",
    patterns: [/activation error/i, /failed to activate/i, /activate.*failed/i],
  },
];

export function classifyValidationBlocker(input) {
  const text = String(input ?? "").trim();
  for (const code of validationBlockerCodes) {
    if (text.startsWith(`${code}:`)) {
      return code;
    }
  }
  for (const rule of classifierRules) {
    if (rule.patterns.some((pattern) => pattern.test(text))) {
      return rule.code;
    }
  }
  return "tool-layer-unknown";
}

export function formatValidationBlocker(input, fallback = "validation blocked") {
  const text = String(input ?? "").trim();
  const code = classifyValidationBlocker(text || fallback);
  if (text.startsWith(`${code}:`)) {
    return text;
  }
  return `${code}: ${text || fallback}`;
}
