#!/bin/bash
set -e

echo "=============================================="
echo "EVerest OCPP 2.0.1 Startup (ESCAPED FIX)"
echo "=============================================="

# --- 1. CLEANUP ---
echo "[1/5] Cleaning up old databases..."
rm -f /ext/dist/share/everest/modules/OCPP201/device_model_storage.db
rm -rf /tmp/everest_ocpp_storage

# --- 2. DEPENDENCIES ---
echo "[2/5] Installing dependencies..."
apt-get update -qq && apt-get install -qq -y sqlite3 http-server grep sed > /dev/null 2>&1 || true

# --- 3. CERTS ---
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

# --- 4. PATCHING CONFIGURATION ---
echo "[4/5] Patching configuration files..."

TARGET_ID="${CHARGE_POINT_ID:-cp002}"
SEARCH_DIR="/ext/dist/share/everest/modules/OCPP201"

# Витягуємо IP:PORT з вашої змінної EVEREST_TARGET_URL (наприклад, 192.168.20.20:8081)
# Це дозволяє замінити localhost:9000 незалежно від протоколу (ws/wss) і слешів
NEW_HOST_PORT=$(echo $EVEREST_TARGET_URL | sed -e 's|^[^/]*//||' -e 's|/.*$||')

echo "   -> Replacing 'localhost:9000' with '$NEW_HOST_PORT'"
echo "   -> Replacing 'CP001' with '$TARGET_ID'"

# Шукаємо файли (JSON і SQL)
FILES=$(grep -rlE "localhost|cp001|CP001" "$SEARCH_DIR" || true)

if [ -z "$FILES" ]; then
    # Fallback search
    FILES=$(find "$SEARCH_DIR" -name "*.json" -o -name "*.sql")
fi

for FILE in $FILES; do
    echo "🔧 Processing: $FILE"
    
    # 1. ЗАМІНА HOST:PORT (Найважливіше!)
    # Міняємо localhost:9000 на ваш IP:PORT. Це ігнорує проблему екранованих слешів \/
    sed -i "s|localhost:9000|$NEW_HOST_PORT|g" "$FILE"
    
    # 2. ЗАМІНА ID
    sed -i "s|CP001|$TARGET_ID|g" "$FILE"
    sed -i "s|cp001|$TARGET_ID|g" "$FILE"
done

# --- 5. VERIFICATION (Щоб ви бачили правду в логах) ---
echo "[5/5] verifying patches..."
echo "Searching for remaining 'localhost' (Should be empty):"
grep -r "localhost:9000" "$SEARCH_DIR" || echo "✅ CLEAN! No localhost found."

echo "Searching for new IP ($NEW_HOST_PORT) (Should find files):"
grep -r "$NEW_HOST_PORT" "$SEARCH_DIR" | head -n 3 || echo "⚠️ Warning: New IP not found (Check logs)"

echo "Starting EVerest Manager..."
exec /ext/dist/bin/manager --config config-sil-ocpp201
