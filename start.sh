#!/bin/bash
set -e

echo "=============================================="
echo "EVerest OCPP 2.0.1 Startup (SQL FIX)"
echo "=============================================="

# --- 1. ОЧИЩЕННЯ (Критично важливо!) ---
echo "[1/4] Cleaning up old databases..."
rm -f /ext/dist/share/everest/modules/OCPP201/device_model_storage.db
rm -rf /tmp/everest_ocpp_storage

# --- 2. ЗАЛЕЖНОСТІ ---
echo "[2/4] Installing dependencies..."
apt-get update -qq && apt-get install -qq -y sqlite3 http-server grep sed > /dev/null 2>&1 || true

# --- 3. СЕРТИФІКАТИ ---
echo "[3/4] Setting up PKI..."
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

# --- 4. АГРЕСИВНА ЗАМІНА КОНФІГУРАЦІЇ ---
echo "[4/4] Patching configuration files..."

TARGET_URL="${EVEREST_TARGET_URL}"
TARGET_ID="${CHARGE_POINT_ID:-cp002}"
SEARCH_DIR="/ext/dist/share/everest/modules/OCPP201"

echo "   -> Target URL: $TARGET_URL"
echo "   -> Target ID:  $TARGET_ID"

# ШУКАЄМО ВСІ МОЖЛИВІ ФАЙЛИ КОНФІГУРАЦІЇ (.json ТА .sql)
# Знаходимо файли, що містять localhost або cp001 (незалежно від регістру)
FILES_TO_PATCH=$(grep -rlE "localhost|cp001|CP001" "$SEARCH_DIR" || true)

# Якщо grep нічого не знайшов, беремо всі json та sql файли примусово
if [ -z "$FILES_TO_PATCH" ]; then
    echo "⚠️  Hard search mode activated..."
    FILES_TO_PATCH=$(find "$SEARCH_DIR" -name "*.json" -o -name "*.sql")
fi

for FILE in $FILES_TO_PATCH; do
    echo "🔧 Patching: $FILE"
    
    # 1. Заміна URL (видаляємо старий localhost незалежно від порту та шляху)
    # Шукаємо ws://localhost.... і замінюємо на наш URL
    sed -i "s|ws://localhost:[0-9]*/[a-zA-Z0-9_]*|$TARGET_URL|g" "$FILE"
    
    # На випадок якщо URL записаний інакше, пряма заміна найпоширенішого варіанту
    sed -i "s|ws://localhost:9000/cp001|$TARGET_URL|g" "$FILE"
    sed -i "s|ws://localhost:9000/CP001|$TARGET_URL|g" "$FILE"
    
    # 2. Заміна ID
    sed -i "s|CP001|$TARGET_ID|g" "$FILE"
    sed -i "s|cp001|$TARGET_ID|g" "$FILE"
done

echo "✓ Configuration patched."

# --- 5. ЗАПУСК ---
echo "Starting EVerest Manager..."
exec /ext/dist/bin/manager --config config-sil-ocpp201
