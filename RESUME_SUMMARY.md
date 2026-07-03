# Smart Kitchen Automated Replenishment System - Resume Summary

## Professional Summary

Full-stack developer with expertise in building scalable IoT-enabled inventory management systems. Designed and implemented an intelligent automated replenishment platform leveraging real-time telemetry data, background processing engines, and modern web technologies.

---

## Technical Skills Demonstrated

### Backend Development
- **FastAPI** - High-performance async API framework
- **Python 3.8+** - Async/await patterns, background tasks
- **PostgreSQL + TimescaleDB** - Time-series data, complex queries, database views
- **SQLAlchemy 2.0** - Async ORM, connection pooling
- **JWT Authentication** - Secure token-based auth with python-jose
- **bcrypt** - Password hashing and security

### Frontend Development
- **Vanilla JavaScript** - RESTful API integration, DOM manipulation
- **HTML5/CSS3** - Responsive web design
- **CORS Configuration** - Cross-origin resource sharing

### DevOps & Deployment
- **Docker & Docker Compose** - Containerization
- **Render.com** - Cloud deployment
- **Git** - Version control

### Database Design
- **Schema Design** - 10+ normalized tables
- **Database Views** - Real-time alert systems
- **Complex Joins** - Multi-table relationships
- **Async Database Operations** - Non-blocking I/O

---

## Key Achievements

### 1. Automated Replenishment Engine
- **Designed and implemented** a background evaluation loop that runs every 30 seconds
- **Built intelligent order generation** system that groups items by household and preferred supplier
- **Implemented duplicate prevention** using database row locking (SELECT FOR UPDATE)
- **Automated inventory restocking** with calculated order quantities based on threshold_max
- **Result**: Fully automated inventory management reducing manual intervention

### 2. Real-Time Inventory Monitoring
- **Developed** stock level monitoring system with three states: in_stock, low_stock, out_of_stock
- **Created** database view `vw_low_stock_alerts` for real-time alerting
- **Implemented** threshold-based alerting system with configurable min/max values
- **Result**: Proactive inventory management preventing stockouts

### 3. User Authentication & Authorization
- **Built** secure JWT-based authentication system
- **Implemented** user registration, login, and role-based access control
- **Designed** household-based multi-user support with household_members table
- **Result**: Secure, scalable user management system

### 4. IoT Device Integration Framework
- **Developed** device registration and management system
- **Created** telemetry data ingestion endpoints
- **Built** data simulator for testing and development
- **Result**: Extensible IoT integration ready for real device deployment

### 5. Dashboard & Analytics
- **Designed** unified dashboard API endpoint returning inventory and order history
- **Implemented** real-time data aggregation with complex SQL joins
- **Created** responsive frontend dashboard with vanilla JavaScript
- **Result**: User-friendly interface for inventory management

### 6. Production Deployment
- **Configured** Docker containerization for consistent deployments
- **Deployed** to Render.com with environment configuration
- **Set up** Supabase PostgreSQL database with proper schema migrations
- **Result**: Live production application at https://smart-kitchen-api.onrender.com

---

## Architecture Highlights

### Backend Architecture
```
FastAPI Application
├── Async Lifespan Management
│   ├── Database Connection Pool
│   ├── Background Task Management
│   └── Graceful Shutdown
├── Router-Based API Design
│   ├── Authentication (/api/v1/auth)
│   ├── Dashboard (/api/v1)
│   ├── Devices (/api/v1/devices)
│   └── IoT Telemetry (/api/v1/iot)
└── Service Layer
    ├── Data Simulator (Development)
    └── Replenishment Engine (Production)
```

### Database Design
- **Normalized schema** with 10+ core tables
- **Foreign key relationships** ensuring data integrity
- **Database views** for optimized queries
- **UUID primary keys** for scalability
- **Timestamp tracking** for audit trails

### Background Processing
- **Asyncio-based** background tasks
- **Error handling** with exponential backoff
- **Graceful shutdown** with task cancellation
- **Production/Development modes** with simulation toggle

---

## Technologies & Tools

**Languages:** Python, SQL, JavaScript, HTML/CSS, Kotlin (in progress)

**Frameworks & Libraries:**
- FastAPI, SQLAlchemy 2.0, python-jose, bcrypt, uvicorn
- Retrofit (Android), MVVM Architecture

**Databases:** PostgreSQL, TimescaleDB, Supabase

**DevOps:** Docker, Docker Compose, Git, Render.com

**Development:** VS Code, Postman, Supabase Dashboard

---

## Project Metrics

- **API Endpoints**: 10+ RESTful endpoints
- **Database Tables**: 10+ normalized tables + 1 view
- **Lines of Code**: ~3000+ (backend), ~1000+ (frontend)
- **Background Tasks**: 2 concurrent async tasks
- **Evaluation Interval**: 30 seconds (configurable)
- **Deployment**: Production-ready on Render.com

---

## Resume Bullet Points (Copy-Paste Ready)

**Full Stack Developer** | Smart Kitchen Automated Replenishment System
- Architected and developed a FastAPI-based backend with async SQLAlchemy, implementing JWT authentication and role-based access control for multi-user household management
- Engineered an automated replenishment engine using background asyncio tasks that evaluates inventory levels every 30 seconds, automatically generating purchase orders when stock falls below thresholds
- Designed normalized PostgreSQL database schema with 10+ tables and optimized views, implementing complex multi-table joins and row-level locking for concurrent order processing
- Built RESTful API with 10+ endpoints serving real-time inventory data, order history, and device telemetry, achieving sub-second response times
- Developed responsive frontend dashboard using vanilla JavaScript, HTML5, and CSS3 with real-time data visualization
- Deployed production application to Render.com using Docker containerization, implementing environment-based configuration for development and production modes
- Integrated IoT device management framework with telemetry ingestion endpoints and data simulation for testing
- Implemented duplicate order prevention using database transactions with SELECT FOR UPDATE, ensuring data consistency in concurrent environments

---

## Keywords for ATS

FastAPI, Python, PostgreSQL, TimescaleDB, SQLAlchemy, Async/Await, JWT, REST API, Docker, Git, Supabase, IoT, Backend Development, Full Stack, Database Design, Microservices, Background Processing, Inventory Management, Automation, JavaScript, HTML/CSS, Render.com, CI/CD, Version Control, Agile Development

---

**Project Repository**: https://github.com/chinmay2975-crypto/smart-kitchen-replenishment  
**Live API**: https://smart-kitchen-api.onrender.com  
**Status**: In Active Development (Core features complete, IoT integration in progress)