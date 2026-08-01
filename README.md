# caddy-geoblock

Ein Caddy-Image mit eingebautem [caddy-maxmind-geolocation](https://github.com/porech/caddy-maxmind-geolocation)-Plugin, gebaut mit `xcaddy` und veröffentlicht in der GitHub Container Registry.

## Warum ein eigenes Image?

Caddy kompiliert Plugins fest ins Binary — es gibt keinen Laufzeit-Mechanismus zum Nachladen. Das offizielle `caddy`-Image enthält ausschließlich die Standardmodule. Sobald man ein Nicht-Standard-Modul wie den MaxMind-Geofilter braucht, führt kein Weg an einem selbst gebauten Binary vorbei.

## Enthaltene Plugins

| Plugin | Zweck |
|---|---|
| `porech/caddy-maxmind-geolocation` | Request-Matcher nach Herkunftsland auf Basis einer GeoLite2-Datenbank |

## Verwendung

```yaml
services:
  caddy:
    image: ghcr.io/christiantannheimer/caddy-geoblock:latest
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./caddy/Caddyfile:/etc/caddy/Caddyfile
      - ./geo-db:/geo-db:ro
      - caddy_data:/data
      - caddy_config:/config

volumes:
  caddy_data:
  caddy_config:
```

Beispiel-Caddyfile:

```caddyfile
example.org {
    @blocked not maxmind_geolocation {
        db_path /geo-db/GeoLite2-Country.mmdb
        allow_countries AT DE CH
    }
    respond @blocked 403

    reverse_proxy backend:8080
}
```

### GeoLite2-Datenbank

Das Plugin bringt keine Datenbank mit. Am einfachsten hält man sie mit `maxmindinc/geoipupdate` aktuell (kostenloser MaxMind-Account erforderlich):

```yaml
  geoipupdate:
    image: maxmindinc/geoipupdate
    restart: unless-stopped
    environment:
      - GEOIPUPDATE_ACCOUNT_ID=${MAXMIND_ACCOUNT_ID}
      - GEOIPUPDATE_LICENSE_KEY=${MAXMIND_LICENSE_KEY}
      - GEOIPUPDATE_EDITION_IDS=GeoLite2-Country
      - GEOIPUPDATE_FREQUENCY=72
    volumes:
      - ./geo-db:/usr/share/GeoIP
```

## Tags

| Tag | Bedeutung |
|---|---|
| `latest` | jeweils aktueller Build |
| `v2.x.y-mm-<sha>` | Caddy-Release plus Kurz-SHA des Plugin-Commits |

Für reproduzierbare Deployments den versionierten Tag verwenden. `latest` eignet sich für automatische Updates via Watchtower.

## Automatischer Build

Ein GitHub-Actions-Workflow prüft täglich das aktuelle Caddy-Release und den neuesten Commit des MaxMind-Plugins. Existiert für diese Kombination bereits ein Image in GHCR, endet der Lauf ohne Build. Andernfalls wird neu gebaut und gepusht.

Zusätzlich läuft der Workflow bei jedem Push auf `main` sowie manuell über *Actions → Run workflow*.

> **Hinweis:** GitHub deaktiviert geplante Workflows in Repositories, die 60 Tage lang keine Aktivität hatten. Kommt eine entsprechende E-Mail, genügt ein Klick auf *Enable workflow*.

## Achtung: ACME-Validierung

Der Geofilter greift auf allen Ports, für die er im Caddyfile definiert ist. Umfasst das Port 80, schlagen HTTP-01-Challenges fehl — die Validierungsserver von Let's Encrypt kommen unter anderem aus den USA und Irland. Entweder den Filter auf die jeweiligen vHosts beschränken oder auf DNS-01 wechseln (dann ist ein zusätzliches DNS-Provider-Plugin nötig).

## Lokal bauen

```bash
docker build -t caddy-geoblock .
```

## Lizenz

MIT — siehe [LICENSE](LICENSE).

Caddy steht unter Apache-2.0, `caddy-maxmind-geolocation` unter der Lizenz des jeweiligen Upstream-Projekts. GeoLite2-Daten unterliegen den MaxMind-Nutzungsbedingungen.
