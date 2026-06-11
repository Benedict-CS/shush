# Deploying Shush to your own server (mobile-ready)

Shush is a pure static web app. The deployment chain is:

```
phone / laptop  →  Cloudflare (HTTPS + DNS)  →  your nginx (reverse proxy)  →  shush docker container
```

You **need HTTPS** for microphone access, Notifications, Wake Lock and PWA install on mobile. Cloudflare provides this for free.

---

## One-time prep on your server

1. Install Docker + Docker Compose
2. Choose a host port (default `8080`). It does NOT need to be public — your reverse proxy will forward to it on the loopback interface.
3. Clone or copy the project:
   ```bash
   git clone https://github.com/Benedict-CS/shush.git
   cd shush
   ```

## Build + run the container

```bash
./start.sh                 # build + run on port 8080
./start.sh -p 9000         # different host port
./start.sh --logs          # follow logs after start
./start.sh stop            # tear down
./start.sh restart         # rebuild + restart
```

Verify locally on the server:
```bash
curl -I http://localhost:8080/
# HTTP/1.1 200 OK
```

## Reverse proxy (nginx example)

Add a server block in your existing nginx config (e.g. `/etc/nginx/sites-available/shush`):

```nginx
server {
    listen 443 ssl http2;
    server_name shush.your-domain.com;

    # SSL: use Cloudflare Origin Cert (15 yr) or Let's Encrypt
    ssl_certificate     /etc/ssl/cloudflare/origin.crt;
    ssl_certificate_key /etc/ssl/cloudflare/origin.key;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/shush /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

## Cloudflare DNS

1. **DNS tab** → add an `A` record:
   - Name: `shush`
   - IPv4: your home/server public IP
   - Proxy status: **Proxied** (orange cloud, for free HTTPS + CDN)
2. **SSL/TLS tab** → Overview → set encryption mode to **Full (strict)** if you used Origin Cert, or **Full** if you used Let's Encrypt
3. **SSL/TLS → Origin Server** → "Create Certificate" (15-year cert), save to your server as the paths in the nginx block above

## Verify on your phone

1. Open `https://shush.your-domain.com/` in Chrome (Android) or Safari (iOS)
2. The browser should prompt for microphone permission — allow it
3. Should see the live dB meter respond when you speak
4. **Install as PWA:**
   - **Android Chrome**: tap the menu → "Install app" or look for the install icon in the address bar
   - **iOS Safari**: tap the share icon → "Add to Home Screen"
5. Now the icon on your home screen launches Shush as a standalone app — no browser chrome, no tab throttling, mic + notifications all work in background

## Updating

Push to GitHub, then on the server:

```bash
cd /path/to/shush
git pull
./start.sh restart
```

If you have a CI pipeline, point it at this directory.

## Troubleshooting

- **Mic permission denied on mobile**: must be HTTPS. Plain IP or `http://` will not work on mobile browsers.
- **Service worker old version stuck**: open Chrome DevTools → Application → Service Workers → Unregister, then hard-refresh (Ctrl+Shift+R).
- **PWA install button never appears**: only fires on Chrome/Edge/Brave. iOS Safari users install via the share menu manually (the page has an iOS-specific instruction button).
- **Audio recording silent on mobile**: same as desktop — confirm the right mic is selected in the device dropdown after granting permission.
