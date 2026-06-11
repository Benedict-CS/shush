FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY index.html /usr/share/nginx/html/
COPY manifest.json /usr/share/nginx/html/
COPY sw.js /usr/share/nginx/html/
COPY icon-192.svg /usr/share/nginx/html/
COPY icon-512.svg /usr/share/nginx/html/
COPY sounds/ /usr/share/nginx/html/sounds/
COPY vendor/ /usr/share/nginx/html/vendor/

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD wget -qO- http://localhost/ >/dev/null 2>&1 || exit 1
