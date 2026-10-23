#!/usr/bin/env bash
# Builds a standalone certbot (PyInstaller, onedir) inside a manylinux2014
# container, so it runs on old glibc (CentOS 7 / CloudLinux 7 and newer).
#   docker run --rm -v "$PWD:/io" quay.io/pypa/manylinux2014_x86_64 /io/build/build-certbot.sh
set -euo pipefail

PY=/opt/python/cp312-cp312/bin/python
ARCH="$(uname -m)"
OUT=/io/dist
CERTBOT_VERSION="${CERTBOT_VERSION:-}"

cd /tmp
"$PY" -m venv venv
venv/bin/pip install -q --upgrade pip
venv/bin/pip install -q "certbot${CERTBOT_VERSION:+==$CERTBOT_VERSION}" pyinstaller

printf 'import sys\nfrom certbot.main import main\nsys.exit(main())\n' >entry.py
venv/bin/pyinstaller -y --log-level WARN --onedir --name certbot \
  --collect-all certbot --collect-all acme --recursive-copy-metadata certbot \
  entry.py

# Smoke test: runs and finds its plugins.
dist/certbot/certbot --version
dist/certbot/certbot --config-dir /tmp/c --work-dir /tmp/w --logs-dir /tmp/l plugins | grep -q webroot

mkdir -p "$OUT"
tar -C dist -czf "$OUT/certbot-linux-$ARCH.tar.gz" certbot
(cd "$OUT" && sha256sum "certbot-linux-$ARCH.tar.gz" >"certbot-linux-$ARCH.tar.gz.sha256")
ls -lh "$OUT"
