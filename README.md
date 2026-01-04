# EVerest OCPP 2.0.1 для Кіберполігону

**ChargePointId:** cp002  
**Протокол:** OCPP 2.0.1  
**Сервер EVerest:** 172.16.0.60  
**Сервер CitrineOS:** 192.168.20.20  

---

## 📋 Зміст

- [Відмінності від OCPP 1.6](#-відмінності-від-ocpp-16)
- [Структура файлів](#-структура-файлів)
- [Швидкий старт](#-швидкий-старт)
- [Ручне розгортання](#-ручне-розгортання)
- [Налаштування CitrineOS для OCPP 2.0.1](#-налаштування-citrineos-для-ocpp-201)
- [Мережева конфігурація](#-мережева-конфігурація)
- [Device Model (OCPP 2.0.1)](#-device-model-ocpp-201)
- [Використання EVerest UI](#-використання-everest-ui)
- [Вирішення проблем](#-вирішення-проблем)
- [Корисні команди](#-корисні-команди)

---

## 🔄 Відмінності від OCPP 1.6

| Характеристика | OCPP 1.6 | OCPP 2.0.1 |
|----------------|----------|------------|
| **Модуль EVerest** | `OCPP` | `OCPP201` |
| **Конфігурація** | JSON файл (`config-docker.json`) | Device Model (SQLite + JSON configs) |
| **Порт CitrineOS** | 8092 | 8081 |
| **ChargePointId** | `CentralSystemURI` | `NetworkConnectionProfiles` |
| **Повідомлення** | `BootNotification`, `StartTransaction` | `BootNotification`, `TransactionEvent` |
| **Авторизація** | `Authorize.req` | `AuthorizeRequest` з IDTOKEN |
| **Security** | Опціонально | Security Profiles 1-3 |

### Нові можливості OCPP 2.0.1:
- **Device Model** - структурована модель даних зарядної станції
- **Security Profiles** - обов'язкова автентифікація
- **Transaction Events** - детальніше логування транзакцій
- **Cost Messages** - підтримка тарифікації
- **ISO 15118** - повна підтримка Plug & Charge

---

## 📁 Структура файлів

```
everest-ocpp201-deploy/
├── docker-compose.yml        # Docker Compose конфігурація
├── start.sh                  # Скрипт запуску з налаштуванням сертифікатів та Device Model
├── .env                      # Змінні середовища
├── deploy.sh                 # Скрипт автоматичного розгортання
├── citrineos/                # Інструкції для CitrineOS
│   └── README.md
├── README.md                 # Цей файл
├── LICENSE                   # Apache 2.0
└── .gitignore
```

**Примітка:** Ця версія використовує стандартний Docker образ EVerest demo без кастомних конфігурацій. Скрипт `start.sh` автоматично:
- Генерує self-signed сертифікати для Security Profile 1
- Налаштовує Device Model з вашим CSMS URL
- Запускає EVerest з OCPP 2.0.1

---

## 🚀 Швидкий старт

### Крок 1: Клонування репозиторію

```bash
# На сервері 172.16.0.60
git clone https://github.com/YOUR_USERNAME/everest-ocpp201-deploy.git
cd everest-ocpp201-deploy
```

### Крок 2: Запуск скрипта розгортання

```bash
chmod +x deploy.sh
./deploy.sh
```

### Крок 3: Перевірка підключення

1. **EVerest UI:** http://172.16.0.60:1881/ui/
2. **CitrineOS UI:** http://192.168.20.20:3000/

В CitrineOS UI повинна з'явитись станція `cp002` з протоколом OCPP 2.0.1.

---

## 🔧 Ручне розгортання

### 1. Встановіть Docker (якщо не встановлено)

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo apt install -y docker-compose-plugin
sudo usermod -aG docker $USER
# Вийдіть та зайдіть знову
```

### 2. Налаштуйте параметри

Відредагуйте файл `.env`:

```bash
# CitrineOS CSMS URL для OCPP 2.0.1
EVEREST_TARGET_URL=ws://192.168.20.20:8081/cp002

# ChargePointId
CHARGE_POINT_ID=cp002

# Security Profile (1-3)
SECURITY_PROFILE=1
```

### 3. Перевірте з'єднання з CitrineOS

```bash
# OCPP 2.0.1 порт
nc -zv 192.168.20.20 8081

# Або через curl (має повернути "Upgrade Required")
curl -v http://192.168.20.20:8081
```

### 4. Запустіть EVerest

```bash
chmod +x start.sh
docker compose up -d --build
```

### 5. Перевірте логи

```bash
# Всі контейнери
docker compose ps

# Логи manager
docker compose logs -f manager
```

---

## 🔌 Налаштування CitrineOS для OCPP 2.0.1

### Важливі відмінності конфігурації CitrineOS

CitrineOS підтримує обидва протоколи на різних портах:

| Протокол | Порт | WebSocket path |
|----------|------|----------------|
| OCPP 1.6 | 8092 | `/CP001` |
| OCPP 2.0.1 | 8081 | `/cp002` |

### Перевірка конфігурації CitrineOS

Переконайтеся, що в `config.json` CitrineOS:

```json
{
  "websocket": {
    "ocpp16": {
      "port": 8092,
      "allowUnknownChargingStations": true
    },
    "ocpp201": {
      "port": 8081,
      "allowUnknownChargingStations": true
    }
  }
}
```

### Реєстрація станції в CitrineOS (опціонально)

Якщо `allowUnknownChargingStations: false`, зареєструйте станцію:

```bash
# Через API CitrineOS
curl -X POST http://192.168.20.20:3000/api/charging-stations \
  -H "Content-Type: application/json" \
  -d '{
    "id": "cp002",
    "ocppVersion": "2.0.1",
    "securityProfile": 1
  }'
```

---

## 🌐 Мережева конфігурація

### Порти EVerest (172.16.0.60)

| Порт | Призначення | Примітка |
|------|-------------|----------|
| 1881 | NodeRed UI / EVerest Simulator UI | Змінено з 1880 щоб не конфліктував з 1.6 |
| 8889 | OCPP Logs viewer | Змінено з 8888 |

### Порти CitrineOS (192.168.20.20)

| Порт | Призначення |
|------|-------------|
| 8081 | OCPP 2.0.1 WebSocket |
| 8092 | OCPP 1.6 WebSocket |
| 3000 | CitrineOS UI |

### Фаєрвол на CitrineOS

```bash
# На сервері 192.168.20.20
sudo ufw allow from 172.16.0.60 to any port 8081
```

---

## 📊 Device Model (OCPP 2.0.1)

### Що таке Device Model?

Device Model - це структурована база даних, яка описує всі компоненти та змінні зарядної станції згідно з OCPP 2.0.1. Замість простого JSON конфігу (як в OCPP 1.6), тут використовується SQLite база даних.

### Структура Device Model

```
/ext/dist/share/everest/modules/OCPP201/
├── device_model_storage.db     # SQLite база даних
└── component_config/
    ├── standardized/           # Стандартні компоненти OCPP
    │   ├── InternalCtrlr.json  # ChargePointId, NetworkConnectionProfiles
    │   ├── OCPPCommCtrlr.json  # OCPP комунікація
    │   ├── AuthCtrlr.json      # Авторизація
    │   └── ...
    └── custom/                 # Кастомні компоненти
        ├── EVSE_1.json
        ├── EVSE_2.json
        └── Connector_*.json
```

### Ключові змінні Device Model

| Компонент | Змінна | Опис |
|-----------|--------|------|
| `InternalCtrlr` | `ChargePointId` | Ідентифікатор станції |
| `InternalCtrlr` | `NetworkConnectionProfiles` | Налаштування підключення до CSMS |
| `OCPPCommCtrlr` | `HeartbeatInterval` | Інтервал heartbeat |
| `AuthCtrlr` | `LocalAuthorizeOffline` | Офлайн авторизація |

### Оновлення NetworkConnectionProfiles

Скрипт `start.sh` автоматично оновлює `NetworkConnectionProfiles`:

```sql
UPDATE VARIABLE_ATTRIBUTE 
SET value = '[{
  "configurationSlot": 1, 
  "connectionData": {
    "messageTimeout": 30, 
    "ocppCsmsUrl": "ws://192.168.20.20:8081/cp002", 
    "ocppInterface": "Wired0", 
    "ocppTransport": "JSON", 
    "ocppVersion": "OCPP20", 
    "securityProfile": 1
  }
}]' 
WHERE variable_Id IN (
  SELECT id FROM VARIABLE WHERE name = 'NetworkConnectionProfiles'
);
```

---

## 🔌 Використання EVerest UI

1. Відкрийте http://172.16.0.60:1881/ui/
2. Симулятор зарядної станції з 2 конекторами
3. Доступні дії:
   - **Plug** — підключити EV
   - **Unplug** — відключити EV
   - **Start Charging** — почати зарядку
   - **Stop Charging** — зупинити зарядку

### Перегляд OCPP 2.0.1 логів

Відкрийте http://172.16.0.60:8889/ для перегляду OCPP повідомлень.

---

## 🛠️ Вирішення проблем

### Помилка "Failed to read cert_info! Not Accepted"

Ця помилка виникає коли ISO 15118 модуль не може прочитати сертифікати.

**Рішення:** Скрипт `start.sh` автоматично генерує self-signed сертифікати. Якщо помилка все ще виникає:

```bash
# Перезапустіть з очищенням
docker compose down
docker compose up -d

# Перевірте логи
docker logs everest-manager-201 | grep -i cert
```

### EVerest не підключається до CitrineOS

1. **Перевірте порт OCPP 2.0.1:**
   ```bash
   nc -zv 192.168.20.20 8081  # НЕ 8092!
   ```

2. **Перевірте логи CitrineOS:**
   ```bash
   docker logs citrine-core | grep -i "ocpp201\|8081\|cp002"
   ```

3. **Перевірте Device Model:**
   ```bash
   docker exec -it everest-manager-201 \
     sqlite3 /ext/dist/share/everest/modules/OCPP201/device_model_storage.db \
     "SELECT value FROM VARIABLE_ATTRIBUTE WHERE variable_Id IN (SELECT id FROM VARIABLE WHERE name='NetworkConnectionProfiles');"
   ```

### Помилка "Connection refused"

CitrineOS може не слухати на порту 8081. Перевірте конфігурацію:

```bash
# На сервері CitrineOS
docker exec -it citrine-core cat /app/config.json | grep -A5 "ocpp201"
```

### Помилка Device Model ініціалізації

```bash
# Перезапустіть з очищенням бази
docker compose down
docker volume rm everest-ocpp201-deploy_device_model || true
docker compose up -d --build
```

### Станція не з'являється в CitrineOS UI

1. Перевірте що ChargePointId співпадає
2. Перевірте Security Profile
3. Перегляньте OCPP логи на предмет BootNotification

---

## ⚙️ Корисні команди

```bash
# Статус контейнерів
docker compose ps

# Логи в реальному часі
docker compose logs -f

# Логи конкретного контейнера
docker compose logs -f manager

# Перезапуск
docker compose restart

# Зупинити
docker compose down

# Запустити
docker compose up -d

# Повна перебудова
docker compose down
docker compose up -d --build

# Перегляд Device Model бази
docker exec -it everest-manager-201 \
  sqlite3 /ext/dist/share/everest/modules/OCPP201/device_model_storage.db \
  ".tables"

# Перегляд NetworkConnectionProfiles
docker exec -it everest-manager-201 \
  sqlite3 /ext/dist/share/everest/modules/OCPP201/device_model_storage.db \
  "SELECT * FROM VARIABLE WHERE name LIKE '%Network%';"
```

---

## 📊 Очікуваний результат

Після успішного розгортання:

1. В **CitrineOS UI** (http://192.168.20.20:3000/):
   - З'явиться станція `cp002`
   - Протокол: OCPP 2.0.1
   - Статус: Online
   - 2 конектори

2. В **EVerest UI** (http://172.16.0.60:1881/ui/):
   - Симулятор зарядної станції
   - Можливість симулювати plug/unplug
   - Можливість запускати/зупиняти зарядку

3. В **OCPP Logs** (http://172.16.0.60:8889/):
   - BootNotificationRequest/Response
   - StatusNotificationRequest
   - TransactionEventRequest (замість StartTransaction)
   - HeartbeatRequest/Response

---

## 🔗 Запуск обох версій OCPP одночасно

Для кіберполігону можна запустити обидві версії OCPP паралельно:

| Сервер | OCPP 1.6 | OCPP 2.0.1 |
|--------|----------|------------|
| **IP** | 172.16.0.40 | 172.16.0.60 |
| **ChargePointId** | CP001 | cp002 |
| **NodeRed UI** | :1880 | :1881 |
| **OCPP Logs** | :8888 | :8889 |
| **CSMS Port** | 8092 | 8081 |

---

## 📚 Додаткові ресурси

- [EVerest Documentation](https://everest.github.io/)
- [EVerest Demo Repository](https://github.com/EVerest/everest-demo)
- [libocpp OCPP 2.0.1](https://github.com/EVerest/libocpp)
- [CitrineOS Documentation](https://citrineos.github.io/)
- [OCPP 2.0.1 Specification](https://openchargealliance.org/)

---

## 📝 Ліцензія

Apache 2.0 - див. файл LICENSE
