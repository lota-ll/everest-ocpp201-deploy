#!/bin/bash
set -e

echo "=============================================="
echo "EVerest OCPP 2.0.1 Startup (Standard Config)"
echo "=============================================="

# --- 1. CLEANUP (Вирішення проблеми Integrity Check) ---
# Документація передбачає, що структура БД залежить від конфігу.
# Видаляємо стару БД, щоб EVerest створив нову під поточний конфіг.
echo "[1/4] Cleaning up old databases..."
rm -f /ext/dist/share/everest/modules/OCPP201/device_model_storage.db
rm -rf /tmp/everest_ocpp_storage

# --- 2. DEPENDENCIES ---
echo "[2/4] Installing dependencies..."
apt-get update -qq 
apt-get install -qq -y sqlite3 http-server > /dev/null 2>&1 || true

# --- 3. CERTIFICATES (Вирішення проблеми ISO15118) ---
# Згідно з everest-core, модуль Josev/ISO15118 вимагає сертифікати.
echo "[3/4] Setting up basic PKI..."
CERT_DIR="/ext/dist/etc/everest/certs"
mkdir -p ${CERT_DIR}/ca/{csms,cso,mf,mo,v2g}
mkdir -p ${CERT_DIR}/client/{csms,cso}

# Генеруємо заглушку CA, щоб модуль ISO15118 не падав при старті
if [ ! -f "${CERT_DIR}/ca/csms/CSMS_ROOT_CA.pem" ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.key \
        -out ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.pem \
        -subj "/CN=CyberRange CSMS CA/O=CyberRange/C=UA" 2>/dev/null
    
    # Копіюємо для всіх ролей (V2G, MO, MF)
    for dir in cso mf mo v2g; do
        cp ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.pem ${CERT_DIR}/ca/${dir}/ || true
    done
fi

# --- 4. CONFIG INJECTION ---
echo "[4/4] Injecting configuration..."
CONFIG_PATH="/ext/dist/share/everest/modules/OCPP201/component_config/standardized/InternalCtrlr.json"

if [ -f "$CONFIG_PATH" ]; then
    SAFE_URL=$(echo "${EVEREST_TARGET_URL}" | sed 's/\//\\\//g')
    sed -i "s/\"ocppCsmsUrl\": \".*\"/\"ocppCsmsUrl\": \"$SAFE_URL\"/" "$CONFIG_PATH"
    sed -i "s/\"value\": \"CP001\"/\"value\": \"${CHARGE_POINT_ID:-cp002}\"/" "$CONFIG_PATH"
fi

# --- START ---
echo "Starting EVerest Manager..."
# Використовуємо стабільний конфіг без PnC, щоб уникнути складних помилок сертифікатів
exec /ext/dist/bin/manager --config config-sil-ocpp201
