# Shush 🎙️

A browser-based mic volume monitor that barks at you when you talk too loudly.

Built because the author keeps speaking too loudly during calls. The page listens to your microphone, shows your dB level in real time, and plays a dog bark (or any sound you pick) when you exceed a threshold. Zero install, zero backend — just open it in a browser.

## Features

- **Real-time dB meter** with peak / average / warning count
- **Configurable threshold** for loud and quiet warnings
- **11 built-in dog bark sounds** + bring-your-own custom audio
- **Volume up to 1000% (10x)** with a compressor/limiter so it stays clear, not distorted
- **Rolling 60-second timeline** of your speech
- **IndexedDB log** of every warning with hourly histogram for today
- **Streak counter** — how many days in a row you stayed under your daily goal
- **Escalating warnings (L1–L4)** — quiet beep → dog bark → flash → text-to-speech "小聲一點"
- **Schedule** — auto-start/stop in a configurable time window (e.g. 09:00–18:00, weekdays only)
- **System notifications** when the tab is in the background
- **Wake Lock** to stop the screen from sleeping while monitoring
- **Background detection** — silent keep-alive audio path prevents browser tab throttling
- **MP3 recording** via `MediaRecorder` + in-browser re-encoding with [lamejs](https://github.com/zhuker/lamejs)
- **PWA-installable** so you can run it as a standalone desktop app
- **Hotkeys**: `Ctrl+Shift+M` pause/resume, `Ctrl+R` start recording, `Ctrl+K` stop recording
- **CSV export** of your warning log

## Quick start

### Option A — local dev server (Node)

```bash
node server.js
# opens http://localhost:5173/
```

### Option B — Docker (recommended for deployment)

```bash
./start.sh              # build + run on port 8080
./start.sh -p 9000      # different host port
./start.sh --logs       # follow logs
./start.sh stop         # tear down
./start.sh restart      # rebuild + restart
```

Then point a reverse proxy (nginx / Caddy / Traefik) at the container and put it behind HTTPS. Mic / Wake Lock / notifications / PWA install all require HTTPS (or `localhost`).

## Deploying behind your own domain

See [DEPLOYMENT.md](DEPLOYMENT.md) for the full step-by-step. TL;DR:

```
phone / laptop  →  Cloudflare (HTTPS)  →  your nginx  →  shush container
```

`./deploy.sh -h user@server -p /opt/shush` rsyncs the project to a remote box, then `ssh`s in and runs `start.sh restart` to rebuild + restart the container.

## How the audio pipeline works

```
mic → MediaStreamSource ─┬─→ AnalyserNode (live dB metering)
                         ├─→ keepAlive gain (≈0, prevents background throttling)
                         └─→ (recording path: MediaRecorder → webm → decodeAudioData → lamejs → MP3)
```

The analysis loop runs on a 50 ms `setInterval` instead of `requestAnimationFrame` so that the throttling that browsers apply to hidden tabs is gentler. The keep-alive gain path makes the tab look "audible" to the browser, which keeps the timers running at full speed in the background. For best results, install as a PWA — PWA windows aren't subject to tab throttling at all.

## File layout

```
.
├── index.html              # the whole app (HTML + CSS + JS)
├── server.js               # tiny static dev server
├── start.sh                # Docker startup helper
├── Dockerfile              # nginx:alpine static-serving image
├── docker-compose.yml      # compose service definition
├── nginx.conf              # nginx config (gzip, cache headers, SW no-cache)
├── manifest.json           # PWA manifest
├── sw.js                   # service worker (cache-first)
├── icon-{192,512}.svg      # PWA icons
├── sounds/                 # 11 free dog bark mp3s from Mixkit
└── vendor/lame.min.js      # lamejs MP3 encoder (vendored)
```

All settings, the warning log, and the streak counter live in the **browser** (`localStorage` + `IndexedDB`). Nothing is sent off-device. If you want cross-device sync, you'll need to add a backend.

## Known limitations

- iOS Safari does not support Wake Lock or PWA notifications outside of an installed PWA
- Browser tab throttling kicks in even with the keep-alive path; install as a PWA for fully reliable background detection
- Custom audio files for warnings live on the device only — they aren't persisted across sessions
- Bringing your own mic stream from `file://` will not work for audio files; use the bundled dev server or Docker

## License

MIT
