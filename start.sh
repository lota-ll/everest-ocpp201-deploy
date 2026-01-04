#!/bin/bash
set -e

echo "=============================================="
echo "EVerest OCPP 2.0.1 Startup (Recursive Fix)"
echo "=============================================="

# --- 1. ОЧИЩЕННЯ (Обов'язково для застосування нового конфігу) ---
echo "[1/4] Cleaning up old databases..."
rm -f /ext/dist/share/everest/modules/OCPP201/device_model_storage.db
rm -rf /tmp/everest_ocpp_storage

# --- 2. ЗАЛЕЖНОСТІ ---
echo "[2/4] Installing dependencies..."
apt-get update -qq && apt-get install -qq -y sqlite3 http-server > /dev/null 2>&1 || true

# --- 3. СЕРТИФІКАТИ ---
echo "[3/4] Setting up basic PKI..."
CERT_DIR="/ext/dist/etc/everest/certs"
mkdir -p ${CERT_DIR}/ca/{csms,cso,mf,mo,v2g}
mkdir -p ${CERT_DIR}/client/{csms,cso}
if [ ! -f "${CERT_DIR}/ca/csms/CSMS_ROOT_CA.pem" ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.key \
        -out ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.pem \
        -subj "/CN=CyberRange CSMS CA/O=CyberRange/C=UA" 2>/dev/null
    for dir in cso mf mo v2g; do cp ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.pem ${CERT_DIR}/ca/${dir}/ || true; done
fi

# --- 4. ІН'ЄКЦІЯ КОНФІГУРАЦІЇ (ROBUST METHOD) ---
echo "[4/4] Injecting configuration..."
TARGET_URL="${EVEREST_TARGET_URL}"
TARGET_CP="${CHARGE_POINT_ID:-cp002}"
SEARCH_DIR="/ext/dist/share/everest/modules/OCPP201"

echo "Applying Config: URL=$TARGET_URL, ID=$TARGET_CP"

# Екрануємо URL для sed
ESCAPED_URL=$(echo "$TARGET_URL" | sed 's/\//\\\//g')

# 1. Знаходимо і замінюємо дефолтний localhost URL у ВСІХ json файлах
find "$SEARCH_DIR" -name "*.json" -print0 | xargs -0 sed -i "s|ws://localhost:9000/cp001|$TARGET_URL|g"
# На випадок іншого формату запису
find "$SEARCH_DIR" -name "*.json" -print0 | xargs -0 sed -i "s/\"ocppCsmsUrl\": \".*\"/\"ocppCsmsUrl\": \"$ESCAPED_URL\"/g"

# 2. Знаходимо і замінюємо дефолтний CP001 на ваш ID
find "$SEARCH_DIR" -name "*.json" -print0 | xargs -0 sed -i "s/\"value\": \"CP001\"/\"value\": \"$TARGET_CP\"/g"
find "$SEARCH_DIR" -name "*.json" -print0 | xargs -0 sed -i "s/\"value\": \"cp001\"/\"value\": \"$TARGET_CP\"/g"

echo "✓ Configuration patched successfully."

# --- START ---
echo "Starting EVerest Manager..."
exec /ext/dist/bin/manager --config config-sil-ocpp201
