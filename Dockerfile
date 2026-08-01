FROM caddy:builder AS builder
RUN xcaddy build \
    --with github.com/porech/caddy-maxmind-geolocation

FROM caddy:latest
LABEL org.opencontainers.image.source="https://github.com/christiantannheimer/caddy-geoblock"
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
