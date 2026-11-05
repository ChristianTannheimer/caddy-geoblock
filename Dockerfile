FROM caddy:builder AS builder

# Die beiden letzten --with-Zeilen heben Abhaengigkeiten auf eine
# Mindestversion an (CVE-Fixes, bevor Caddy selbst nachzieht).
# Go nimmt automatisch eine neuere Version, wenn Caddy sie verlangt.
# Kann entfernt werden, sobald Caddy mindestens diese Versionen mitbringt.
#   go-jose/v4 >= 4.1.6   GHSA-mgcc-cww5-fp2q
#   x/net      >= 0.62.0  GO-2026-6860, GO-2026-6866
RUN xcaddy build \
    --with github.com/porech/caddy-maxmind-geolocation \
    --with github.com/caddy-dns/desec \
    --with github.com/go-jose/go-jose/v4@v4.1.6 \
    --with golang.org/x/net@v0.62.0

FROM caddy:latest
LABEL org.opencontainers.image.source="https://github.com/christiantannheimer/caddy-geoblock"
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
