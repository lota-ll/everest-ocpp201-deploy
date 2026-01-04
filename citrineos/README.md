# Налаштування CitrineOS для OCPP 2.0.1

## Важливо!

CitrineOS використовує різні порти для різних версій OCPP:
- **Порт 8092** - OCPP 1.6
- **Порт 8081** - OCPP 2.0.1

## Приклад конфігурації CitrineOS

Переконайтеся, що ваш CitrineOS config.json містить налаштування для OCPP 2.0.1:

```json
{
  "websocket": {
    "ocpp16": {
      "port": 8092,
      "allowUnknownChargingStations": true
    },
    "ocpp201": {
      "port": 8081,
      "allowUnknownChargingStations": true,
      "securityProfile": 1
    }
  },
  "modules": {
    "certificates": {
      "enabled": false
    },
    "evdriver": {
      "enabled": true
    }
  }
}
```

## Перевірка готовності

```bash
# Перевірте, чи CitrineOS слухає на порту 8081
nc -zv 192.168.20.20 8081

# Перевірте логи CitrineOS
docker logs citrine-core | grep -i "ocpp201\|8081"
```

## Реєстрація станції (якщо потрібно)

Якщо `allowUnknownChargingStations: false`, зареєструйте станцію через API:

```bash
curl -X POST http://192.168.20.20:3000/api/charging-stations \
  -H "Content-Type: application/json" \
  -d '{
    "id": "cp002",
    "ocppVersion": "2.0.1",
    "securityProfile": 1
  }'
```
