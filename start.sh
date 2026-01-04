#!/bin/bash
# ============================================================================
# EVerest Start Script for OCPP 2.0.1 (FIXED)
# Cleans DB to prevent integrity errors and injects config into JSON templates
# ============================================================================

set -e

echo "=============================================="
echo "EVerest OCPP 2.0.1 Startup (Cyber Range)"
echo "=============================================="
echo "ChargePointId: ${CHARGE_POINT_ID:-cp002}"
echo "CSMS URL: ${EVEREST_TARGET_URL}"
echo "Security Profile: ${SECURITY_PROFILE:-1}"
echo "=============================================="

# 1. Clean up potential locking or corrupted files
# Це вирішує помилку "Integrity check ... failed"
echo "Cleaning up old databases..."
rm -f /ext/dist/share/everest/modules/OCPP201/device_model_storage.db
rm -rf /tmp/everest_ocpp_storage

# Create directories
mkdir -p /tmp/everest_ocpp_logs
mkdir -p /tmp/everest-logs

# Install tools
echo "Installing dependencies..."
apt-get update -qq 
apt-get install -qq -y sqlite3 http-server > /dev/null 2>&1 || true

# Start log server
http-server /tmp/everest_ocpp_logs -p 8888 &

# ============================================================================
# Setup PKI Certificates
# ============================================================================
echo "Setting up PKI certificates..."
CERT_DIR="/ext/dist/etc/everest/certs"
# Ensure directories exist
mkdir -p ${CERT_DIR}/ca/{csms,cso,mf,mo,v2g}
mkdir -p ${CERT_DIR}/client/{csms,cso}

# Generate generic Self-Signed CA if missing
if [ ! -f "${CERT_DIR}/ca/csms/CSMS_ROOT_CA.pem" ]; then
    echo "Generating fresh certificates..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.key \
        -out ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.pem \
        -subj "/CN=CyberRange CSMS CA/O=CyberRange/C=UA" 2>/dev/null
    
    # Distribute CA (Hack for testing environment to satisfy all roles)
    cp ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.pem ${CERT_DIR}/ca/cso/CPO_SUB_CA1.pem
    cp ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.pem ${CERT_DIR}/ca/cso/CPO_SUB_CA2.pem
    cp ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.pem ${CERT_DIR}/ca/mf/MF_ROOT_CA.pem
    cp ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.pem ${CERT_DIR}/ca/mo/MO_ROOT_CA.pem
    cp ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.pem ${CERT_DIR}/ca/v2g/V2G_ROOT_CA.pem # Fixes 'Failed to read cert_info'

    # Generate Client Cert
    openssl req -nodes -newkey rsa:2048 \
        -keyout ${CERT_DIR}/client/csms/CSMS_LEAF.key \
        -out ${CERT_DIR}/client/csms/CSMS_LEAF.csr \
        -subj "/CN=${CHARGE_POINT_ID:-cp002}/O=CyberRange/C=UA" 2>/dev/null
    
    openssl x509 -req -days 365 \
        -in ${CERT_DIR}/client/csms/CSMS_LEAF.csr \
        -CA ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.pem \
        -CAkey ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.key \
        -CAcreateserial \
        -out ${CERT_DIR}/client/csms/CSMS_LEAF.pem 2>/dev/null
        
    cat ${CERT_DIR}/client/csms/CSMS_LEAF.pem ${CERT_DIR}/ca/csms/CSMS_ROOT_CA.pem > \
        ${CERT_DIR}/client/csms/CPO_CERT_CHAIN.pem

    # Copy to SECC (required for ISO15118 module)
    cp ${CERT_DIR}/client/csms/CSMS_LEAF.key ${CERT_DIR}/client/cso/SECC_LEAF.key
    cp ${CERT_DIR}/client/csms/CPO_CERT_CHAIN.pem ${CERT_DIR}/client/cso/CPO_CERT_CHAIN.pem
fi

# ============================================================================
# Configure Device Model (JSON Injection)
# ============================================================================
echo "Configuring Device Model templates..."

# Path to the SOURCE configuration file that generates the DB
# EVerest uses this file to populate the DB on first run
CONFIG_PATH="/ext/dist/share/everest/modules/OCPP201/component_config/standardized/InternalCtrlr.json"

# We use sed to inject the CSMS URL directly into the JSON template
# This is necessary because we deleted the DB, so we can't use sqlite3 yet.
if [ -f "$CONFIG_PATH" ]; then
    # Create a safe escaped version of the URL for sed
    SAFE_URL=$(echo "${EVEREST_TARGET_URL}" | sed 's/\//\\\//g')
    
    # Replace the default localhost URL with our target
    # Looking for pattern: "ocppCsmsUrl": "..."
    sed -i "s/\"ocppCsmsUrl\": \".*\"/\"ocppCsmsUrl\": \"$SAFE_URL\"/" "$CONFIG_PATH"
    
    # Inject ChargePointId
    sed -i "s/\"value\": \"CP001\"/\"value\": \"${CHARGE_POINT_ID:-cp002}\"/" "$CONFIG_PATH"
    
    echo "✓ Injected configuration into InternalCtrlr.json"
else
    echo "⚠ Warning: Config template not found at $CONFIG_PATH"
fi

# ============================================================================
# Start EVerest
# ============================================================================
echo "Starting EVerest Manager..."

# We use the standard demo config which works well with the default image
# We explicitly set the config to ensure consistency
exec /ext/dist/bin/manager --config config-sil-ocpp201-pnc
