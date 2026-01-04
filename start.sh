#!/bin/bash
set -e

echo "=============================================="
echo "EVerest OCPP 2.0.1 Startup (FINAL FIX)"
echo "=============================================="

# --- 1. ОЧИЩЕННЯ БАЗИ ДАНИХ ---
# Ми видаляємо базу, щоб вона створилася заново з вже виправлених нами файлів
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

# --- 4. ПОШУК І ЗАМІНА (URL + CP ID) ---
echo "[4/4] Patching configuration files..."

# Ваші змінні з .env
TARGET_URL="${EVEREST_TARGET_URL}"
TARGET_ID="${CHARGE_POINT_ID:-cp002}"
SEARCH_DIR="/ext/dist/share/everest/modules/OCPP201"

echo "Targeting: URL=$TARGET_URL | ID=$TARGET_ID"

# КРОК А: Знаходимо всі файли, що містять 'localhost:9000' (це точно старий конфиг)
# grep -r (рекурсивно) -l (тільки імена файлів)
FILES_TO_PATCH=$(grep -rl "localhost:9000" "$SEARCH_DIR")

if [ -z "$FILES_TO_PATCH" ]; then
    echo "⚠️ WARNING: No files containing 'localhost:9000' found."
    echo "Attempting blind patch on generic JSONs..."
    FILES_TO_PATCH=$(find "$SEARCH_DIR" -name "*.json")
fi

# КРОК Б: Проходимось по кожному знайденому файлу і міняємо дані
for FILE in $FILES_TO_PATCH; do
    echo "🔧 Patching file: $FILE"
    
    # 1. Заміна URL (використовуємо | як розділювач, щоб не ламалось об http://)
    sed -i "s|ws://localhost:9000/cp001|$TARGET_URL|g" "$FILE"
    
    # 2. Заміна ID (замінюємо CP001 на ваш cp002)
    # Замінюємо "CP001" (великими)
    sed -i "s|CP001|$TARGET_ID|g" "$FILE"
    # Замінюємо "cp001" (маленькими - часто буває в URL шляху)
    sed -i "s|cp001|$TARGET_ID|g" "$FILE"
done

echo "✓ Configuration patched."

# --- 5. ЗАПУСК ---
echo "Starting EVerest Manager..."
exec /ext/dist/bin/manager --config config-sil-ocpp201
