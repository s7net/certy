# certy

Free SSL certificates (Let's Encrypt) on cPanel hosting with a single command — powered by `certbot`.

```bash
certy -d example.com --wildcard
```

- **No root required**: everything is installed into `~/bin` and `~/.certy`.
- **Bundled certbot**: a standalone certbot binary is built with GitHub Actions and published in Releases (no Python needed).
- **Always DNS validation (DNS-01)**: TXT records are added and removed automatically through cPanel's `uapi`, and shown in a clean table.
- **Automatic install into cPanel** and **automatic renewal** via cron.

## Install

On your cPanel host (Terminal or SSH):

```bash
curl -fsSL https://raw.githubusercontent.com/s7net/certy/main/install.sh | bash
```

If you have root access and want certbot installed from the OS package manager:

```bash
curl -fsSL https://raw.githubusercontent.com/s7net/certy/main/install.sh | bash -s -- --root
```

If neither `--root` nor `--user` is given, the installer asks.

## Usage

```bash
# Domain + wildcard (*.example.com)
certy -d example.com --wildcard

# Multiple domains, no wildcard
certy -d example.com -d www.example.com -d shop.example.com
certy -d example.com,www.example.com

# With an email for expiry notices
certy -d example.com -e me@example.com

# DNS not hosted on this cPanel (e.g. Cloudflare): print the records and wait
certy -d example.com --wildcard --manual
```

Sample output:

```
┌───┬──────────────────────────────┬──────┬─────┬─────────────────────────────────────────────┬────────┐
│ # │ Name                         │ Type │ TTL │ Value                                       │ Status │
├───┼──────────────────────────────┼──────┼─────┼─────────────────────────────────────────────┼────────┤
│ 1 │ _acme-challenge.example.com  │ TXT  │ 60  │ uOp7TmC-K4q0b3MHPLYs8e_awkEMTDmr0D8-pVMuir4 │ added  │
│ 2 │ _acme-challenge.example.com  │ TXT  │ 60  │ i1Ny4Oqr3at3FcgHzkVsqi_d4GBhKsuWADs-zs4V2-o │ added  │
└───┴──────────────────────────────┴──────┴─────┴─────────────────────────────────────────────┴────────┘
```

| Command | Description |
|---|---|
| `certy renew` | Renew all certificates (a daily cron job is added automatically) |
| `certy list` | List certificates |
| `certy cron` / `certy uninstall-cron` | Add / remove the renewal cron job |
| `certy update` | Update certy and certbot |

| Option | Description |
|---|---|
| `-d, --domain` | Domain to include (repeatable or comma separated) |
| `-w, --wildcard` | Also include `*.domain` for each domain |
| `-e, --email` | Let's Encrypt account email (remembered) |
| `--manual` | Don't touch DNS; only print the records table and wait |
| `--no-install` | Don't install the certificate into cPanel |
| `--staging` | Use the Let's Encrypt staging server |
| `--force` | Re-issue even if the current certificate is still valid |

Certificates are stored in `~/.certy/config/live/<domain>/` (`fullchain.pem`, `privkey.pem`, …).

`CERTY_DNS_TIMEOUT` (default 300 seconds) sets the maximum wait for DNS propagation.

## Building the certbot binary

The [`.github/workflows/release.yml`](.github/workflows/release.yml) workflow runs on every `v*` tag (or manually). It builds certbot with PyInstaller inside a `manylinux2014` container for `x86_64` and `aarch64` (compatible with CentOS 7 / CloudLinux and newer) and uploads it to the Release:

```bash
git tag v1.0.1 && git push origin v1.0.1
```

If the binary doesn't run on a server, the installer automatically falls back to installing certbot in a Python virtualenv.

## License

MIT
