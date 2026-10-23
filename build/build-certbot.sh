#!/usr/bin/env bash
# Builds a standalone certbot (PyInstaller, onedir) inside a manylinux2014
# container, so it runs on old glibc (CentOS 7 / CloudLinux 7 and newer).
#   docker run --rm -v "$PWD:/io" quay.io/pypa/manylinux2014_x86_64 /io/build/build-certbot.sh
set -euo pipefail

ARCH="$(uname -m)"
# manylinux's own Pythons are static; PyInstaller needs a shared libpython,
# so use python-build-standalone (also built against glibc 2.17).
PBS_TAG="${PBS_TAG:-20261021}"
PBS_PY="${PBS_PY:-3.12.15}"
OUT=/io/dist
CERTBOT_VERSION="${CERTBOT_VERSION:-}"

cd /tmp
curl -fsSL "https://github.com/astral-sh/python-build-standalone/releases/download/$PBS_TAG/cpython-$PBS_PY%2B$PBS_TAG-$ARCH-unknown-linux-gnu-install_only.tar.gz" | tar xz
python/bin/python3 -m venv venv
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
