# caddy-geoblock

Ein Caddy-Image mit eingebautem Geofilter ([caddy-maxmind-geolocation](https://github.com/porech/caddy-maxmind-geolocation)) und DNS-01-Unterstützung für [deSEC](https://desec.io) ([caddy-dns/desec](https://github.com/caddy-dns/desec)), gebaut mit `xcaddy` und veröffentlicht in der GitHub Container Registry.

## Warum ein eigenes Image?

Caddy kompiliert Plugins fest ins Binary — es gibt keinen Laufzeit-Mechanismus zum Nachladen. Das offizielle `caddy`-Image enthält ausschließlich die Standardmodule. Sobald man ein Nicht-Standard-Modul wie den MaxMind-Geofilter oder einen DNS-Provider braucht, führt kein Weg an einem selbst gebauten Binary vorbei.

## Enthaltene Plugins

| Plugin | Zweck |
|---|---|
| `porech/caddy-maxmind-geolocation` | Request-Matcher nach Herkunftsland auf Basis einer GeoLite2-Datenbank |
| `caddy-dns/desec` | DNS-01-Challenge über die deSEC-API, z. B. für Wildcard-Zertifikate und interne, nur per VPN erreichbare Dienste |

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
    environment:
      - DESEC_TOKEN=${DESEC_TOKEN:-}      # nur für DNS-01 nötig
    volumes:
      - ./caddy/Caddyfile:/etc/caddy/Caddyfile
      - ./geo-db:/geo-db:ro
      - caddy_data:/data
      - caddy_config:/config

volumes:
  caddy_data:
  caddy_config:
```

### Geofilter

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

### DNS-01-Challenge mit deSEC

Nötig, wenn Let's Encrypt den Server nicht per HTTP erreichen kann — etwa für interne Dienste, deren Namen auf eine VPN-Adresse zeigen — oder für Wildcard-Zertifikate.

Funktioniert mit jedem DNS-Anbieter, auch ohne API, über eine **delegierte Nachweis-Zone**. Beispiel für interne Dienste unter `*.intern.example.org`:

| Eintrag im DNS von `example.org` | Typ | Wert |
|---|---|---|
| `acme.intern` | NS | `ns1.desec.io` |
| `acme.intern` | NS | `ns2.desec.org` |
| `_acme-challenge.intern` | CNAME | `acme.intern.example.org` |
| `*.intern` | A | VPN-Adresse des Servers |

Bei deSEC ein Konto mit der Domain `acme.intern.example.org` (Managed DNS) anlegen und einen API-Token erzeugen. Caddy legt den Nachweis dann per API in dieser Zone ab:

```caddyfile
https://*.intern.example.org {
    tls {
        dns desec {
            token {$DESEC_TOKEN}
        }
        dns_challenge_override_domain acme.intern.example.org
    }

    @app host app.intern.example.org
    handle @app {
        reverse_proxy app:8080
    }
    handle {
        respond "Unbekannter Dienst" 404
    }
}
```

Die Erreichbarkeit der Dienste hängt dabei nur am DNS des Domaininhabers; deSEC wird ausschließlich zur Zertifikatsausstellung und -erneuerung gebraucht.

## Tags

| Tag | Bedeutung |
|---|---|
| `latest` | jeweils aktueller Build |
| `v2.x.y-mm-<sha>-ds-<sha>-df-<hash>` | Caddy-Release, Kurz-SHA der Plugin-Commits (MaxMind, deSEC) und Hash des Dockerfiles |

Für reproduzierbare Deployments den versionierten Tag verwenden. `latest` eignet sich für automatische Updates.

## Automatischer Build

Ein GitHub-Actions-Workflow prüft täglich das aktuelle Caddy-Release, die neuesten Commits beider Plugins und den Stand des Dockerfiles. Existiert für diese Kombination bereits ein Image in GHCR, endet der Lauf ohne Build. Andernfalls wird neu gebaut und gepusht. Änderungen am Dockerfile (z. B. ein zusätzliches Plugin) lösen dadurch zuverlässig einen Neubau aus.

Zusätzlich läuft der Workflow bei jedem Push auf `main` sowie manuell über *Actions → Run workflow*.

> **Hinweis:** GitHub deaktiviert geplante Workflows in Repositories, die 60 Tage lang keine Aktivität hatten. Kommt eine entsprechende E-Mail, genügt ein Klick auf *Enable workflow*.

## Achtung: ACME-Validierung und Geofilter

Der Geofilter greift auf allen Ports, für die er im Caddyfile definiert ist. Umfasst das Port 80, schlagen HTTP-01-Challenges fehl — die Validierungsserver von Let's Encrypt kommen unter anderem aus den USA und Irland. Entweder den Filter auf die jeweiligen vHosts beschränken oder für die betroffenen Domains auf DNS-01 mit deSEC wechseln (siehe oben).

## Lokal bauen

```bash
docker build -t caddy-geoblock .
```

## Lizenz

MIT — siehe [LICENSE](LICENSE).

Caddy steht unter Apache-2.0, `caddy-maxmind-geolocation` und `caddy-dns/desec` unter der Lizenz des jeweiligen Upstream-Projekts. GeoLite2-Daten unterliegen den MaxMind-Nutzungsbedingungen.