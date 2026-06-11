# CLAUDE.md

Guidance for Claude Code / any AI assistant working in this repo.

## What this is

`shush` is a **single-page, zero-backend, static web app** that listens to the microphone and warns the user when they speak too loudly. The entire app lives in `index.html` (HTML + CSS + JS in one file). All state — settings, warning log, streak — is stored client-side in `localStorage` and `IndexedDB`.

There is no API, no database, no build step. The "server" is either a tiny Node static-file helper (`server.js`) for development, or `nginx:alpine` in production (`Dockerfile` + `nginx.conf`).

## Tech inventory

- **Vanilla JS + Web Audio API.** No framework, no bundler.
- **Audio analysis** via `AnalyserNode` (time-domain RMS → dB).
- **MP3 recording** via `MediaRecorder` (capture) + `AudioContext.decodeAudioData` (decode webm/opus) + `lamejs` (re-encode to MP3). The vendored encoder lives at `vendor/lame.min.js`.
- **PWA** via `manifest.json` + `sw.js` (cache-first, SW itself is no-cache so updates roll out).
- **IndexedDB** for warning event log, `localStorage` for user prefs + streak state.
- **Background detection** strategy: `setInterval(50ms)` analysis loop + a near-silent passthrough gain into `audioCtx.destination` so browsers consider the tab "playing audio" and skip the aggressive timer throttling.

## File map

| Path | Purpose |
|---|---|
| `index.html` | The entire app. ~1450 lines. CSS at top, IIFE script at bottom. |
| `manifest.json` | PWA manifest. `name`, `short_name`, icons. |
| `sw.js` | Service worker. Cache-first for static assets; SW itself is never cached. |
| `icon-192.svg` / `icon-512.svg` | PWA icons. |
| `sounds/` | 11 free dog bark mp3s sourced from Mixkit (royalty-free). |
| `vendor/lame.min.js` | Vendored lamejs MP3 encoder (~156 KB). Do not modify. |
| `server.js` | Dev-only static server. Not shipped in the Docker image. |
| `Dockerfile` | `nginx:1.27-alpine`. Copies static assets into `/usr/share/nginx/html`. |
| `nginx.conf` | Gzip on, long cache for stable assets, SW + HTML are `no-cache`. |
| `docker-compose.yml` | Single service `shush`. Port via `${SHUSH_PORT:-8080}`. |
| `start.sh` | Convenience wrapper around `docker compose up -d --build`. |

## Mental model of `index.html`

It's a single IIFE. Read in this order:

1. **`els` object** — DOM refs collected up front from a list of IDs.
2. **State variables** — `audioCtx`, `mediaStream`, `analyser`, `sourceNode`, plus warning counters, peak/avg tracking, timeline buffer.
3. **UI helpers** — `setRangeLabel`, prefs save/load, collapsible section toggles.
4. **IndexedDB layer** — `openDb`, `logEvent`, `queryEvents`, `clearAllEvents`.
5. **Warning audio chain** — `MediaElementSource → DynamicsCompressor → GainNode → destination`. The compressor lets us push the gain up to 10× without clipping.
6. **Notifications + escalation manager** — keeps a rolling window of warning timestamps; level = count in window, capped at 4.
7. **Title + favicon** — dynamic updates so the tab shows the current dB.
8. **Timeline canvas** — `drawTimeline()` runs on its own `requestAnimationFrame` loop, separate from the analysis loop, and skips drawing when `document.hidden`.
9. **Histogram canvas** — drawn on demand from IndexedDB data.
10. **Streak logic** — re-evaluates any missed days when the page loads.
11. **Main analysis loop** — `setInterval(loop, 50)`. Reads `analyser`, derives dB, checks against loud + quiet thresholds with hold time / cooldown / VAD-less noise floor for quiet.
12. **Recording** — `MediaRecorder` for capture, async re-encode to MP3 on stop, fallback to webm if encoding fails.
13. **Wake Lock**, **schedule**, **hotkey**, **PWA install** — small modules near the bottom.

## Conventions and gotchas

- **Single file.** Resist the urge to split into modules. The whole point is "one file you can serve anywhere."
- **No build step.** No TypeScript, no JSX, no bundling. If you need a library, vendor it into `vendor/`.
- **Don't use `requestAnimationFrame` for analysis.** It's throttled to 1 fps in hidden tabs. The analysis loop must use `setInterval`. `rAF` is fine for canvas drawing because we skip drawing when hidden anyway.
- **`createMediaStreamSource` once.** Calling it twice on the same `MediaStream` makes the second source silent in some browsers. The recording path must tap from the **existing** `sourceNode` (or use `MediaRecorder` on the `MediaStream` directly, which is what we do now).
- **Keep-alive gain.** `sourceNode → keepAliveGain(0.0001) → destination` is required for background tabs. Don't remove it.
- **Service worker caching.** `sw.js` is itself `no-cache`. Static assets are long-cached. If you change `index.html`, the SW will pick it up on next reload because HTML is also `no-cache` from `nginx.conf`.
- **Prefs schema is forward-compatible.** `loadPrefs` only sets fields that exist in the loaded object. Adding a new pref doesn't break old saved configs.
- **MP3 encoding is async.** When the user clicks "Stop recording," the UI shows "🛠 處理 MP3 中..." while `decodeAudioData` + `lamejs` work. Don't block on it — the encode happens in `mediaRecorder.onstop`.
- **HTTPS required in production.** Mic, Notifications, Wake Lock, PWA install all require HTTPS or `localhost`. Plain `http://` over LAN IP will not work.

## Common tasks

### Add a new setting

1. Add the HTML row in the appropriate `settings-section`.
2. Add its ID to the list passed to `els` initialization at the top of the script.
3. Add it to `savePrefs()` and `loadPrefs()`.
4. Wire its event listener.

### Add a new sound effect

1. Drop the mp3 in `sounds/`.
2. Add an `<option value="sounds/your-file.mp3">label</option>` in the `#soundSelect` dropdown.
3. That's it — the existing audio-graph code handles loading and playback.

### Change the warning behavior

Look at `triggerWarning(currentDb)` and `currentEscalationLevel()`. Levels 1–4 map to: synth beep, full sound, sound × 2, sound + TTS. The body flash duration scales with level.

### Bump the service worker cache

Change `CACHE` in `sw.js` from `shush-v1` to `shush-v2`. Browsers will fetch the new SW, install it, and evict the old cache on activate.

## Deployment

Production target is **Docker + reverse proxy + Cloudflare**. The local nginx in the image listens on port 80; the user maps it to a host port (default 8080), then their existing reverse proxy points a domain at it. HTTPS terminates at Cloudflare (or at the reverse proxy with Cloudflare in front).

## What NOT to do

- Don't add a backend. The "zero backend" property is a feature.
- Don't introduce a framework. There is no scenario where adding React makes this better.
- Don't add telemetry / analytics. The data is sensitive (literal recordings of the user's voice).
- Don't change the dog bark sounds unless the user explicitly asks. They're part of the identity.
