# Smart Kitchen Automated Replenishment System

> **⚠️ Project Status: Under Development**
> 
> This project is currently under active development. Core backend functionality is implemented, but several features are still being worked on. This README documents the current state of the project.

## Overview

The Smart Kitchen Automated Replenishment System is an intelligent inventory management solution that automates the process of monitoring kitchen inventory levels and generating replenishment orders. The system uses real-time telemetry data to track inventory levels and automatically creates orders when stock falls below defined thresholds.

## Key Features

### ✅ Implemented Features

- **User Authentication & Authorization**
  - User registration and login
  - JWT-based authentication
  - Role-based access control

- **Inventory Management**
  - Real-time inventory tracking
  - Stock level monitoring (in stock, low stock, out of stock)
  - Threshold-based alerts
  - Product catalog management

- **Automated Replenishment Engine**
  - Background evaluation loop (runs every 30 seconds in development)
  - Automatic order generation for low-stock items
  - Smart grouping by household and preferred supplier
  - Duplicate order prevention
  - Automatic inventory restocking after order creation

- **Device Management**
  - IoT device registration and monitoring
  - Device status tracking

- **Dashboard & Analytics**
  - Current inventory overview
  - Recent replenishment orders history
  - Stock status visualization

- **Supplier Integration**
  - Preferred supplier assignment per product
  - Mock API dispatch for order submission
  - Supplier endpoint configuration

### 🚧 In Progress / Planned Features

- [ ] Real IoT device integration (ESP8266/ESP32)
- [ ] Push notifications for low stock alerts
- [ ] Advanced analytics and reporting
- [ ] Multi-household support
- [ ] Order approval workflow
- [ ] Email/SMS notifications
- [ ] Mobile app (Android - Kotlin)
- [ ] Barcode scanning integration
- [ ] Recipe-based inventory forecasting

## Tech Stack

### Backend
- **Framework**: FastAPI (Python 3.8+)
- **Database**: PostgreSQL with TimescaleDB extension
- **ORM**: SQLAlchemy 2.0 (async)
- **Authentication**: JWT (python-jose)
- **Password Hashing**: bcrypt
- **Server**: Uvicorn

### Frontend
- **HTML5/CSS3/JavaScript** (Vanilla)
- **Responsive Design**: Mobile-first approach

### Infrastructure
- **Containerization**: Docker & Docker Compose
- **Database Hosting**: Supabase / Local PostgreSQL
- **Deployment**: Render.com

### Android (In Development)
- **Language**: Kotlin
- **Architecture**: MVVM
- **Networking**: Retrofit

## Project Structure

```
smart-kitchen-replenishment/
├── app/
│   ├── main.py                    # FastAPI application entry point
│   ├── config.py                  # Configuration settings
│   ├── database.py                # Database connection setup
│   ├── core/
│   │   └── security.py            # JWT token handling
│   ├── models/
│   │   └── orm.py                 # SQLAlchemy ORM models
│   ├── routers/
│   │   ├── api.py                 # Dashboard API endpoints
│   │   ├── auth.py                # Login/Register endpoints
│   │   ├── devices.py             # Device management
│   │   └── iot.py                 # IoT telemetry endpoints
│   └── services/
│       ├── data_simulator.py      # Simulates device telemetry
│       └── replenishment_engine.py # Auto-replenishment logic
├── frontend/
│   ├── index.html                 # Main HTML file
│   ├── css/
│   │   └── style.css              # Styles
│   └── js/
│       ├── api.js                 # API client
│       ├── auth.js                # Authentication UI
│       ├── dashboard.js           # Dashboard functionality
│       ├── devices.js             # Device management UI
│       └── profile.js             # User profile UI
├── db/
│   ├── init.sql                   # Database schema (local)
│   └── init_supabase.sql          # Database schema (Supabase)
├── app/src/main/java/             # Android app (Kotlin)
├── .env                           # Environment variables
├── requirements.txt               # Python dependencies
├── docker-compose.yml             # Docker configuration
├── Dockerfile                     # Backend container
├── render.yaml                    # Render deployment config
├── SETUP.md                       # Detailed setup instructions
└── start_backend.bat              # Windows startup script
```

## How It Works

### 1. Inventory Monitoring
The system continuously monitors inventory levels across all registered households. Each product has configurable thresholds:
- **threshold_min**: Minimum quantity before alert
- **threshold_max**: Target quantity for replenishment

### 2. Automated Replenishment
When inventory falls below the minimum threshold:
1. The replenishment engine detects low-stock items
2. Groups items by household and preferred supplier
3. Checks for existing pending orders (prevents duplicates)
4. Creates a new replenishment order with calculated quantities
5. Updates inventory levels automatically
6. Mocks API dispatch to supplier (ready for real integration)

### 3. Order Calculation
Order quantities are calculated as:
```
order_qty = max(threshold_max - current_quantity, 1.0)
```
This ensures inventory is restocked to the maximum threshold.

## Getting Started

### Prerequisites
- Python 3.8 or higher
- pip (Python package manager)
- PostgreSQL (local or Supabase account)
- Modern web browser

### Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/chinmay2975-crypto/smart-kitchen-replenishment.git
   cd smart-kitchen-replenishment
   ```

2. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Configure environment**
   - Copy `.env` file and update with your database credentials
   - For Supabase: Use your project credentials
   - For local: Use the docker-compose setup

4. **Initialize database**
   ```bash
   # Test connection
   python test_supabase_connection.py
   
   # Initialize schema (if needed)
   # Use db/init_supabase.sql in Supabase SQL Editor
   ```

5. **Start the backend**
   ```bash
   # Windows
   start_backend.bat
   
   # Or manually
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

6. **Open the frontend**
   - Open `frontend/index.html` in your browser
   - Or use VS Code Live Server extension

### Detailed Setup Instructions

For comprehensive setup instructions, including troubleshooting, see [SETUP.md](SETUP.md).

## API Documentation

When the backend is running, access interactive API documentation:

- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **Health Check**: http://localhost:8000/health

### Key API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/auth/register` | POST | User registration |
| `/api/v1/auth/login` | POST | User login (returns JWT) |
| `/api/v1/profile` | GET | Get user profile |
| `/api/v1/dashboard-data` | GET | Get inventory and orders |
| `/api/v1/devices` | GET/POST | Device management |
| `/api/v1/iot/telemetry` | POST | Submit device telemetry |

## Configuration

### Environment Variables

Create a `.env` file in the root directory:

```env
# Database (Supabase)
DB_HOST=your-host.supabase.co
DB_PORT=5432
DB_NAME=postgres
DB_USER=postgres
DB_PASSWORD=your-password

# Or Local PostgreSQL
# DB_HOST=localhost
# DB_PORT=5432
# DB_NAME=smart_kitchen
# DB_USER=kitchen_admin
# DB_PASSWORD=your-password

# JWT
SECRET_KEY=your-secret-key-here
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# Application
ENABLE_SIMULATION=true
EVALUATION_INTERVAL_SECONDS=30
```

### Simulation Mode

The system includes a data simulator that generates mock telemetry data for testing:

- **Enabled**: `ENABLE_SIMULATION=true` (development)
- **Disabled**: `ENABLE_SIMULATION=false` (production)

When enabled, the simulator:
- Seeds initial inventory data
- Generates random telemetry updates
- Runs the replenishment engine in the background

## Deployment

### Docker

```bash
# Start PostgreSQL
docker-compose up -d

# Build and run backend
docker build -t smart-kitchen-backend .
docker run -p 8000:8000 --env-file .env smart-kitchen-backend
```

### Render.com

The project includes a `render.yaml` configuration for deployment on Render:

1. Connect your GitHub repository to Render
2. Create a new Web Service
3. Use the provided `render.yaml` for configuration
4. Set environment variables in Render dashboard
5. Deploy!

**Production URL**: https://smart-kitchen-api.onrender.com

## Database Schema

### Core Tables

- **app_users**: User accounts and authentication
- **households**: Household/kitchen groups
- **household_members**: User-household relationships
- **household_preferences**: User settings (auto-replenish, etc.)
- **product_catalog**: Product information and thresholds
- **inventory_current**: Current inventory levels
- **suppliers**: Supplier information
- **replenishment_orders**: Generated orders
- **order_line_items**: Individual items in orders
- **devices**: Registered IoT devices
- **telemetry_data**: Device sensor readings

### Views

- **vw_low_stock_alerts**: Real-time view of items below threshold

## Development

### Running Tests

```bash
# Test database connection
python test_supabase_connection.py

# Test backend
python test_db.py
```

### Adding New Features

1. Backend changes: Modify routers in `app/routers/`
2. Database changes: Update `db/init_supabase.sql`
3. Frontend changes: Update `frontend/js/` files
4. Android changes: Modify files in `app/src/main/java/`

## Contributing

This is an active development project. Contributions are welcome!

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Known Issues

- [ ] Android app not fully integrated with backend
- [ ] Real IoT device communication not implemented
- [ ] Email/SMS notifications not configured
- [ ] Order approval workflow incomplete
- [ ] Multi-language support not implemented

## Roadmap

### Phase 1 (Current) ✅
- [x] Backend API with authentication
- [x] Inventory management
- [x] Automated replenishment engine
- [x] Basic frontend dashboard
- [x] Database schema and migrations

### Phase 2 (In Progress) 🚧
- [ ] IoT device integration
- [ ] Real-time notifications
- [ ] Advanced analytics
- [ ] Mobile app completion

### Phase 3 (Planned) 📋
- [ ] Machine learning for demand forecasting
- [ ] Integration with real supplier APIs
- [ ] Barcode/QR code scanning
- [ ] Recipe management
- [ ] Multi-tenant support

## License

This project is currently unlicensed. All rights reserved.

## Contact

For questions or support, please open an issue on GitHub.

---

**Last Updated**: June 2025  
**Version**: 1.0.0 (In Development)