#!/usr/bin/env bash
# Installs the pinned Helm release for linux-amd64, checksum verified.
set -euo pipefail
version=v4.3.0
sum=86584a54def73570558f66f5111cc53dfed56689637ae32c1201205d494f54fb
tmp=$(mktemp -d)
curl -fsSL -o "$tmp/h.tgz" "https://get.helm.sh/helm-$version-linux-amd64.tar.gz"
echo "$sum  $tmp/h.tgz" | sha256sum -c -
tar -xzf "$tmp/h.tgz" -C "$tmp"
sudo install "$tmp/linux-amd64/helm" /usr/local/bin/helm
helm version
