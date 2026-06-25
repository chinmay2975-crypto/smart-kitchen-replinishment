import asyncio
import asyncpg

async def test():
    conn = await asyncpg.connect('postgresql://kitchen_admin:KitchenSecure2026@localhost:5433/smart_kitchen')
    db = await conn.fetchval("SELECT current_database()")
    user = await conn.fetchval("SELECT current_user")
    print(f'Connected to: {db} as {user}')
    tables = await conn.fetch("SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name")
    print('Tables:', [r['table_name'] for r in tables])
    await conn.close()

asyncio.run(test())