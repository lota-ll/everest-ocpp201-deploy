#!/bin/bash
# ============================================================================
# EVerest OCPP 2.0.1 Deployment Script for Cyber Range
# Сервер EVerest: 172.16.0.60
# Підключення до CitrineOS: 192.168.20.20:8081
# ============================================================================

set -e

echo "=============================================="
echo "EVerest OCPP 2.0.1 Deployment Script"
echo "=============================================="

# Default values
CSMS_IP="${CSMS_IP:-192.168.20.20}"
CSMS_PORT="${CSMS_PORT:-8081}"
CHARGE_POINT_ID="${CHARGE_POINT_ID:-cp002}"
SECURITY_PROFILE="${SECURITY_PROFILE:-1}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --csms-ip)
            CSMS_IP="$2"
            shift 2
            ;;
        --csms-port)
            CSMS_PORT="$2"
            shift 2
            ;;
        --cp-id)
            CHARGE_POINT_ID="$2"
            shift 2
            ;;
        --security-profile)
            SECURITY_PROFILE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --csms-ip IP          IP адреса CitrineOS CSMS (default: 192.168.20.20)"
            echo "  --csms-port PORT      Порт OCPP 2.0.1 (default: 8081)"
            echo "  --cp-id ID            ChargePointId (default: cp002)"
            echo "  --security-profile N  Security Profile 1-3 (default: 1)"
            echo "  -h, --help            Показати цю довідку"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Update .env file
echo ""
echo "[1/6] Оновлення конфігурації..."
cat > .env << EOF
# EVerest OCPP 2.0.1 Environment Variables
EVEREST_IMAGE_TAG=0.0.23
EVEREST_TARGET_URL=ws://${CSMS_IP}:${CSMS_PORT}/${CHARGE_POINT_ID}
CHARGE_POINT_ID=${CHARGE_POINT_ID}
SECURITY_PROFILE=${SECURITY_PROFILE}
OCPP_VERSION=two
EOF
echo "✅ Конфігурацію оновлено"
echo "   CSMS URL: ws://${CSMS_IP}:${CSMS_PORT}/${CHARGE_POINT_ID}"
echo "   ChargePointId: ${CHARGE_POINT_ID}"
echo "   Security Profile: ${SECURITY_PROFILE}"

# Check Docker
echo ""
echo "[2/6] Перевірка Docker..."
if ! command -v docker &> /dev/null; then
    echo "⚠️  Docker не встановлено. Встановлюю..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo apt install -y docker-compose-plugin
    sudo usermod -aG docker $USER
    echo ""
    echo "❗ Docker встановлено. Будь ласка:"
    echo "   1. Вийдіть з сесії: exit"
    echo "   2. Зайдіть знову"
    echo "   3. Запустіть цей скрипт повторно"
    exit 0
fi
echo "✅ Docker встановлено"

# Check connection to CitrineOS
echo ""
echo "[3/6] Перевірка з'єднання з CitrineOS (${CSMS_IP}:${CSMS_PORT})..."
if nc -zw3 ${CSMS_IP} ${CSMS_PORT} 2>/dev/null; then
    echo "✅ CitrineOS OCPP 2.0.1 endpoint доступний"
else
    echo "⚠️  Не вдається з'єднатися з CitrineOS на ${CSMS_IP}:${CSMS_PORT}"
    echo "   Перевірте:"
    echo "   - Чи запущено CitrineOS на сервері ${CSMS_IP}"
    echo "   - Чи відкрито порт ${CSMS_PORT} для OCPP 2.0.1"
    echo "   - Чи є мережеве з'єднання між серверами"
    echo ""
    echo "   ВАЖЛИВО: CitrineOS використовує різні порти для різних версій OCPP:"
    echo "   - Порт 8092 для OCPP 1.6"
    echo "   - Порт 8081 для OCPP 2.0.1"
    read -p "   Продовжити все одно? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check files
echo ""
echo "[4/6] Перевірка файлів..."
MISSING=0
for file in docker-compose.yml start.sh .env; do
    if [ ! -f "$file" ]; then
        echo "❌ $file не знайдено!"
        MISSING=1
    fi
done
if [ $MISSING -eq 1 ]; then
    echo "❌ Деякі файли відсутні. Перевірте директорію."
    exit 1
fi
echo "✅ Всі файли на місці"

# Set permissions
echo ""
echo "[5/6] Встановлення прав доступу..."
chmod +x start.sh
echo "✅ Права встановлено"

# Start EVerest
echo ""
echo "[6/6] Запуск EVerest з OCPP 2.0.1..."
docker compose up -d --build

# Wait for startup
echo ""
echo "Очікування запуску контейнерів (60 секунд для OCPP 2.0.1)..."
sleep 60

# Status
echo ""
echo "=============================================="
echo "Статус контейнерів:"
echo "=============================================="
docker compose ps
echo ""

# Check manager logs
echo "=============================================="
echo "Логи EVerest Manager (останні 30 рядків):"
echo "=============================================="
docker logs everest-manager-201 --tail 30 2>&1 || true
echo ""

echo "=============================================="
echo "✅ РОЗГОРТАННЯ OCPP 2.0.1 ЗАВЕРШЕНО!"
echo "=============================================="
echo ""
echo "Доступні сервіси:"
echo "  • EVerest UI:    http://172.16.0.60:1881/ui/"
echo "  • NodeRed:       http://172.16.0.60:1881/"
echo "  • OCPP Logs:     http://172.16.0.60:8889/"
echo ""
echo "Налаштування підключення:"
echo "  • ChargePointId: ${CHARGE_POINT_ID}"
echo "  • CSMS URL:      ws://${CSMS_IP}:${CSMS_PORT}/${CHARGE_POINT_ID}"
echo "  • Протокол:      OCPP 2.0.1"
echo "  • Security:      Profile ${SECURITY_PROFILE}"
echo ""
echo "Корисні команди:"
echo "  docker compose logs -f manager   # Логи EVerest"
echo "  docker compose down              # Зупинити"
echo "  docker compose up -d             # Запустити"
echo ""
echo "Відмінності від OCPP 1.6:"
echo "  • Device Model замість JSON конфігу"
echo "  • Нові повідомлення (BootNotification, TransactionEvent, etc.)"
echo "  • Security Profiles для автентифікації"
echo "  • Порт CSMS: 8081 (замість 8092 для OCPP 1.6)"
echo ""
