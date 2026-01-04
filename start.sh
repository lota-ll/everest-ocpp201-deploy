#!/bin/bash
# ============================================================================
# EVerest Start Script for OCPP 2.0.1
# Includes PKI certificate setup for Security Profile 1
# ============================================================================

set -e

echo "=============================================="
echo "EVerest OCPP 2.0.1 Startup"
echo "=============================================="
echo "ChargePointId: ${CHARGE_POINT_ID:-cp002}"
echo "CSMS URL: ${EVEREST_TARGET_URL}"
echo "Security Profile: ${SECURITY_PROFILE:-1}"
echo "=============================================="

# Run standard entrypoint
/entrypoint.sh

# Create directories
mkdir -p /tmp/everest_ocpp_logs
mkdir -p /tmp/everest-logs

# Install required packages
echo "Installing required packages..."
apt-get update -qq 
apt-get install -qq -y sqlite3 > /dev/null 2>&1 || true

# Install and start http-server for logs
npm i -g http-server 2>/dev/null || true
http-server /tmp/everest_ocpp_logs -p 8888 &

# Wait for initialization
sleep 2

# ============================================================================
# Setup PKI Certificates (Required for OCPP 2.0.1)
# ============================================================================
echo ""
echo "Setting up PKI certificates..."

CERT_DIR="/ext/dist/etc/everest/certs"

# Create certificate directories if they don't exist
mkdir -p ${CERT_DIR}/ca/csms
mkdir -p ${CERT_DIR}/ca/cso
mkdir -p ${CERT_DIR}/ca/mf
mkdir -p ${CERT_DIR}/ca/mo
mkdir -p ${CERT_DIR}/ca/v2g
mkdir -p ${CERT_DIR}/client/csms
mkdir -p ${CERT_DIR}/client/cso

# Generate a simple self-signed CA if certificates don't exist
if [ ! -f "${CERT_DIR}/ca/csms/CSMS_ROOT_CA.pem" ]; then
    echo "Generating self-signed certificates..."
    
    # Generate CSMS Root CA
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.key \
        -out ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.pem \
        -subj "/CN=CyberRange CSMS CA/O=CyberRange/C=UA" 2>/dev/null || true
    
    # Copy to other CA directories (simplified setup)
    cp ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.pem ${CERT_DIR}/ca/cso/CPO_SUB_CA1.pem 2>/dev/null || true
    cp ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.pem ${CERT_DIR}/ca/cso/CPO_SUB_CA2.pem 2>/dev/null || true
    cp ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.pem ${CERT_DIR}/ca/mf/MF_ROOT_CA.pem 2>/dev/null || true
    cp ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.pem ${CERT_DIR}/ca/mo/MO_ROOT_CA.pem 2>/dev/null || true
    cp ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.pem ${CERT_DIR}/ca/v2g/V2G_ROOT_CA.pem 2>/dev/null || true
    
    # Generate client certificate
    openssl req -nodes -newkey rsa:2048 \
        -keyout ${CERT_DIR}/client/csms/CSMS_LEAF.key \
        -out ${CERT_DIR}/client/csms/CSMS_LEAF.csr \
        -subj "/CN=${CHARGE_POINT_ID:-cp002}/O=CyberRange/C=UA" 2>/dev/null || true
    
    openssl x509 -req -days 365 \
        -in ${CERT_DIR}/client/csms/CSMS_LEAF.csr \
        -CA ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.pem \
        -CAkey ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.key \
        -CAcreateserial \
        -out ${CERT_DIR}/client/csms/CSMS_LEAF.pem 2>/dev/null || true
    
    # Create chain
    cat ${CERT_DIR}/client/csms/CSMS_LEAF.pem ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.pem > \
        ${CERT_DIR}/client/csms/CPO_CERT_CHAIN.pem 2>/dev/null || true
    
    cp ${CERT_DIR}/client/csms/CSMS_LEAF.key ${CERT_DIR}/client/cso/SECC_LEAF.key 2>/dev/null || true
    cp ${CERT_DIR}/client/csms/CPO_CERT_CHAIN.pem ${CERT_DIR}/client/cso/CPO_CERT_CHAIN.pem 2>/dev/null || true
    
    echo "✓ Certificates generated"
else
    echo "✓ Certificates already exist"
fi

# ============================================================================
# Configure Device Model
# ============================================================================
echo ""
echo "Configuring Device Model..."

DEVICE_MODEL_DB="/ext/dist/share/everest/modules/OCPP201/device_model_storage.db"

# Network Connection Profile JSON
NETWORK_PROFILE='[{"configurationSlot": 1, "connectionData": {"messageTimeout": 30, "ocppCsmsUrl": "'${EVEREST_TARGET_URL}'", "ocppInterface": "Wired0", "ocppTransport": "JSON", "ocppVersion": "OCPP20", "securityProfile": '${SECURITY_PROFILE:-1}'}}]'

if [ -f "$DEVICE_MODEL_DB" ]; then
    echo "Updating Device Model database..."
    
    # Update NetworkConnectionProfiles
    sqlite3 "$DEVICE_MODEL_DB" \
        "UPDATE VARIABLE_ATTRIBUTE 
        SET value = '${NETWORK_PROFILE}' 
        WHERE variable_Id IN (
            SELECT id FROM VARIABLE 
            WHERE name = 'NetworkConnectionProfiles'
        );" 2>/dev/null && echo "✓ NetworkConnectionProfiles updated" || echo "⚠ NetworkConnectionProfiles update skipped"
    
    # Update ChargePointId
    sqlite3 "$DEVICE_MODEL_DB" \
        "UPDATE VARIABLE_ATTRIBUTE 
        SET value = '${CHARGE_POINT_ID:-cp002}' 
        WHERE variable_Id IN (
            SELECT id FROM VARIABLE 
            WHERE name = 'ChargePointId'
        );" 2>/dev/null && echo "✓ ChargePointId updated" || echo "⚠ ChargePointId update skipped"
    
    echo ""
    echo "Device Model configured for:"
    echo "  CSMS URL: ${EVEREST_TARGET_URL}"
    echo "  ChargePointId: ${CHARGE_POINT_ID:-cp002}"
else
    echo "⚠ Device Model database not found (will be initialized on first run)"
fi

# ============================================================================
# Start EVerest
# ============================================================================
echo ""
echo "=============================================="
echo "Starting EVerest Manager with OCPP 2.0.1"
echo "=============================================="

# Find and run the appropriate script
if [ -f "/ext/build/run-scripts/run-sil-ocpp201-pnc.sh" ]; then
    echo "Using: run-sil-ocpp201-pnc.sh"
    chmod +x /ext/build/run-scripts/run-sil-ocpp201-pnc.sh
    exec /ext/build/run-scripts/run-sil-ocpp201-pnc.sh
elif [ -f "/ext/build/run-scripts/run-sil-ocpp201.sh" ]; then
    echo "Using: run-sil-ocpp201.sh"
    chmod +x /ext/build/run-scripts/run-sil-ocpp201.sh
    exec /ext/build/run-scripts/run-sil-ocpp201.sh
else
    echo "No standard run script found!"
    echo "Available run scripts:"
    ls -la /ext/build/run-scripts/ 2>/dev/null || echo "Directory not found"
    echo ""
    echo "Trying direct manager start..."
    exec /ext/dist/bin/manager --config config-sil-ocpp201-pnc
fi
