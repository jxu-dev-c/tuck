#!/usr/bin/env bash
# One-time: creates a self-signed "Tuck Dev" code-signing identity in your login keychain.
# A stable signature lets macOS remember Tuck's Accessibility / Screen Recording grants
# across rebuilds. macOS will ask for your password to trust the certificate.
set -euo pipefail

NAME="Tuck Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -p codesigning | grep -q "\"$NAME\""; then
  echo "\"$NAME\" already exists."
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

# Use the system LibreSSL so the .p12 format is one `security import` understands.
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$WORK/key.pem" -out "$WORK/cert.pem" -config "$WORK/cert.cnf"
/usr/bin/openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
  -out "$WORK/tuck.p12" -passout pass:tuck

security import "$WORK/tuck.p12" -k "$KEYCHAIN" -P tuck -T /usr/bin/codesign
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$WORK/cert.pem"

echo "Created \"$NAME\". Rebuild with scripts/build-app.sh."
