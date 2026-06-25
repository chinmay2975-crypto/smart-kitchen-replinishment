# 🏠 Smart Kitchen Automated Replenishment System

An end-to-end IoT solution that monitors kitchen container weights via ESP8266-based sensors and automatically places replenishment orders on Amazon when stock runs low.

## 📋 System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Client Layer                             │
│  ┌──────────────────────┐   ┌────────────────────────────┐  │
│  │  Flutter Mobile App   │   │  WiFi Provisioning Tool    │  │
│  │  (OTP auth, config,   │   │  (Python - USB-serial)     │  │
│  │   real-time status)   │   │                            │  │
│  └──────────┬───────────┘   └────────────┬───────────────┘  │
└─────────────┼────────────────────────────┼──────────────────┘
              │ HTTPS/REST                  │ USB Serial
┌─────────────┼────────────────────────────┼──────────────────┐
│             │                    ┌───────▼────────┐         │
│             │                    │  ESP8266 + HX711 │         │
│             │                    │  (per container) │         │
│             │                    └───────┬────────┘         │
│             │                            │ WiFi             │
│             ▼                            ▼                  │
│        ┌──────────────────────────────────────┐            │
│        │         Backend (Node.js/Express)     │            │
│        │                                      │            │
│        │  ┌────────────┐  ┌────────────────┐  │            │
│        │  │ Auth/REST  │  │ Ingestion API  │  │            │
│        │  │ API Module │  │ (device data)  │  │            │
│        │  └─────┬──────┘  └───────┬────────┘  │            │
│        │        │                 │            │            │
│        │  ┌─────▼─────────────────▼────────┐  │            │
│        │  │    Replenishment Engine        │  │            │
│        │  │  (threshold → cart → order)   │  │            │
│        │  └─────┬──────────────────┬───────┘  │            │
│        │        │                  │           │            │
│        │  ┌─────▼──────┐  ┌───────▼───────┐  │            │
│        │  │ Marketplace│  │ Notification  │  │            │
│        │  │ (Amazon)   │  │ (SMS/Email)   │  │            │
│        │  └────────────┘  └───────────────┘  │            │
│        └──────────────────┬──────────────────┘            │
│                           │                               │
│                    ┌──────▼──────┐                        │
│                    │  PostgreSQL  │                        │
│                    │  Database    │                        │
│                    └─────────────┘                        │
└───────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
ESP8266_API-main/              # Backend (Node.js)
├── index.js                   # Entry point - mounts all routes
├── package.json               # Dependencies
├── .env                       # Environment variables
├── ESP8266.ino                # IoT firmware (Arduino)
├── readme.md                  # This file
│
├── src/
│   ├── config/
│   │   ├── db.js              # PostgreSQL connection pool
│   │   └── init-db.js         # Database initialization script
│   │
│   ├── middleware/
│   │   └── auth.js            # JWT verification (device + user)
│   │
│   ├── routes/
│   │   ├── device.routes.js   # /provision, /send, /refresh, /devices
│   │   ├── auth.routes.js     # /api/auth/* (OTP, register, login)
│   │   ├── kitchen.routes.js  # /api/kitchens/* (CRUD)
│   │   ├── container.routes.js# /api/containers/* (CRUD)
│   │   ├── item.routes.js     # /api/items/*, SKU mappings
│   │   └── replenishment.routes.js  # /api/orders/*, /api/cart/*
│   │
│   ├── controllers/
│   │   ├── deviceController.js
│   │   ├── authController.js
│   │   ├── kitchenController.js
│   │   ├── containerController.js
│   │   ├── itemController.js
│   │   └── replenishmentController.js
│   │
│   ├── services/
│   │   ├── ingestionService.js      # Sensor data processing
│   │   ├── replenishmentEngine.js   # Threshold → cart → auto-order
│   │   ├── marketplaceService.js    # Amazon API integration
│   │   └── notificationService.js   # SMS/Email notifications
│   │
│   ├── utils/
│   │   ├── tokenUtils.js            # JWT generation
│   │   └── validators.js           # Input validation (Joi)
│   │
│   ├── models/
│   │   └── schema.sql              # Complete PostgreSQL schema
│   │
│   └── provisioning_tool/
│       ├── provisioner.py           # WiFi provisioning Python script
│       └── requirements.txt
│
Zone-IOT-main/                  # Flutter Mobile App
└── lib/
    ├── main.dart
    ├── config/
    │   └── api_config.dart
    ├── models/
    │   ├── user.dart
    │   ├── kitchen.dart
    │   ├── container.dart
    │   ├── item.dart
    │   └── order.dart
    ├── services/
    │   ├── api_service.dart
    │   └── auth_service.dart
    ├── providers/
    │   ├── auth_provider.dart
    │   ├── kitchen_provider.dart
    │   └── container_provider.dart
    ├── screens/
    │   ├── auth/
    │   │   ├── login_screen.dart
    │   │   ├── otp_screen.dart
    │   │   └── register_screen.dart
    │   ├── kitchen/
    │   │   ├── kitchen_list_screen.dart
    │   │   └── kitchen_detail_screen.dart
    │   └── dashboard/
    │       └── dashboard_screen.dart
    └── widgets/
        └── container_status_card.dart
```

## 🚀 Getting Started

### 1. Database Setup
```bash
# Create PostgreSQL database
psql -U postgres -c "CREATE DATABASE smart_kitchen;"

# Run schema
psql -U postgres -d smart_kitchen -f src/models/schema.sql

# Or use the automated script
npm run db:init
```

### 2. Backend Setup
```bash
# Install dependencies
npm install

# Configure .env with your settings
# Edit .env file with DB credentials, JWT secrets, etc.

# Start server
npm start
# Server runs on http://localhost:3000
```

### 3. Flutter App Setup
```bash
cd Zone-IOT-main
flutter pub get
flutter run
```

### 4. ESP8266 Firmware
Open `ESP8266.ino` in Arduino IDE:
- Install ESP8266 board package
- Install libraries: ESP8266WiFi, ESP8266HTTPClient, ArduinoJson
- Update server URL in the code
- Upload to ESP8266

### 5. WiFi Provisioning
```bash
# Install Python dependencies
pip install -r src/provisioning_tool/requirements.txt

# Interactive mode
python src/provisioning_tool/provisioner.py

# Or CLI mode
python src/provisioning_tool/provisioner.py --port COM3 --ssid "MyWiFi" --password "pass" --server "http://192.168.1.100:3000" --capacity 1.0
```

## 🔌 API Endpoints

### Device Management
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/provision?serverToken=&mac=` | Register ESP8266 device |
| GET | `/send?token=&data=` | Send sensor reading |
| GET | `/refresh?refresh_token=` | Refresh device access token |
| GET | `/devices` | List all devices |

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/send-otp` | Send OTP to phone |
| POST | `/api/auth/verify-otp` | Verify OTP code |
| POST | `/api/auth/register` | Register new user |
| POST | `/api/auth/login` | Login (sends OTP) |
| POST | `/api/auth/refresh` | Refresh user token |

### Kitchen Management
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/kitchens` | List user's kitchens |
| GET | `/api/kitchens/:id` | Get kitchen with containers |
| POST | `/api/kitchens` | Create kitchen |
| PUT | `/api/kitchens/:id` | Update kitchen |
| DELETE | `/api/kitchens/:id` | Delete kitchen |

### Container Management
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/kitchens/:id/containers` | List containers |
| GET | `/api/containers/:id` | Get container with items |
| POST | `/api/kitchens/:id/containers` | Create container |
| PUT | `/api/containers/:id` | Update container |
| DELETE | `/api/containers/:id` | Delete container |

### Items & SKU Mappings
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/containers/:id/items` | List items in container |
| GET | `/api/items/:id` | Get item with SKU mappings |
| POST | `/api/containers/:id/items` | Create item |
| PUT | `/api/items/:id` | Update item (threshold, auto-replenish) |
| DELETE | `/api/items/:id` | Delete item |
| POST | `/api/items/:id/sku-mappings` | Add SKU mapping |
| PUT | `/api/sku-mappings/:id` | Update SKU mapping |
| DELETE | `/api/sku-mappings/:id` | Delete SKU mapping |

### Wallet & Funds
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/wallet` | Get balance + recent transactions |
| POST | `/api/wallet/topup` | Add funds to wallet |
| GET | `/api/wallet/transactions` | Transaction history |
| PUT | `/api/wallet/auto-topup` | Configure auto top-up rules |

### Orders & Replenishment
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/orders` | List user's orders |
| GET | `/api/orders/:id` | Get order details |
| POST | `/api/orders/:id/cancel` | Cancel pending order |
| GET | `/api/cart` | View pending cart items |
| POST | `/api/cart/checkout` | Trigger replenishment |
| PUT | `/api/orders/:id/status` | Update order status |

## 🔄 Core Data Flow

1. **ESP8266 reads weight** → HX711 load cell → calculates % remaining
2. **ESP8266 sends data** → `GET /send?token=xxx&data=weight=2.5&percent=75`
3. **Ingestion API stores** → `device_data` + `sensor_readings` tables
4. **Replenishment Engine checks** → compares % against item thresholds
5. **If below threshold** → item added to `cart_items`
6. **If auto_replenish + cart_size_trigger met** → Amazon order placed
7. **User notified** via SMS/Email
8. **Order status synced** back to Flutter app

## 🔐 Token System

- **Device Access Token**: 7-day JWT for `/send` API
- **Device Refresh Token**: 180-day JWT for obtaining new access tokens
- **User Access Token**: 24-hour JWT for Flutter app API calls
- **User Refresh Token**: 30-day JWT for session renewal
- Inactivity > 30 days → device requires reprovisioning

## 🛠 Tech Stack

- **Backend**: Node.js, Express, PostgreSQL
- **Mobile**: Flutter, Provider (state management)
- **IoT**: ESP8266, HX711 Load Cell, Arduino
- **Provisioning**: Python, pyserial
- **Marketplace**: Amazon (PA-API 5.0 / SP-API integration)
- **Notifications**: Twilio (SMS), SMTP (Email)
- **Auth**: JWT, OTP-based phone verification