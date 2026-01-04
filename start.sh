#!/bin/bash
set -e

echo "=============================================="
echo "EVerest OCPP 2.0.1 Startup (Hunter Fix)"
echo "=============================================="

# --- 1. ОЧИЩЕННЯ (Обов'язково!) ---
echo "[1/5] Cleaning up old databases..."
rm -f /ext/dist/share/everest/modules/OCPP201/device_model_storage.db
rm -rf /tmp/everest_ocpp_storage

# --- 2. ЗАЛЕЖНОСТІ ---
echo "[2/5] Installing dependencies..."
apt-get update -qq && apt-get install -qq -y sqlite3 http-server grep > /dev/null 2>&1 || true

# --- 3. СЕРТИФІКАТИ ---
echo "[3/5] Setting up PKI..."
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

# --- 4. ПОШУК І ЗАМІНА КОНФІГУРАЦІЇ ---
echo "[4/5] Hunting for configuration files..."
TARGET_URL="${EVEREST_TARGET_URL}"
# Видаляємо ws:// з початку для чистоти, якщо треба, але краще передати як є
TARGET_ID="${CHARGE_POINT_ID:-cp002}"
SEARCH_DIR="/ext/dist/share/everest/modules/OCPP201"

echo "   -> Target URL: $TARGET_URL"
echo "   -> Target ID:  $TARGET_ID"

# Шукаємо файл, який містить 'localhost:9000'
CONF_FILE=$(grep -lR "localhost:9000" "$SEARCH_DIR" | head -n 1)

if [ -z "$CONF_FILE" ]; then
    echo "⚠️ WARNING: Could not find config file containing 'localhost:9000'!"
    echo "   Running generic replace on all JSONs..."
    find "$SEARCH_DIR" -name "*.json" -print0 | xargs -0 sed -i "s|ws://localhost:9000/cp001|$TARGET_URL|g"
else
    echo "✅ FOUND CONFIG FILE: $CONF_FILE"
    echo "   Old content:"
    grep "localhost:9000" "$CONF_FILE" || true
    
    # Замінюємо URL (використовуємо | як розділювач, щоб не конфліктувати зі слешами в URL)
    sed -i "s|ws://localhost:9000/cp001|$TARGET_URL|g" "$CONF_FILE"
    
    # Замінюємо ID (cp001 -> cp002)
    sed -i "s/\"value\": \"CP001\"/\"value\": \"$TARGET_ID\"/gI" "$CONF_FILE"
    sed -i "s/cp001/$TARGET_ID/gI" "$CONF_FILE"
    
    echo "   New content (verification):"
    grep "$TARGET_ID" "$CONF_FILE" || true
fi

# --- 5. ЗАПУСК ---
echo "[5/5] Starting EVerest Manager..."
exec /ext/dist/bin/manager --config config-sil-ocpp201
