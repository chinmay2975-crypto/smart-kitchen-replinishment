"""
Test script to verify Supabase database connection.
Run this before starting the full application to ensure the connection works.
"""
import asyncio
import sys
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text


async def test_connection():
    """Test the database connection to Supabase."""
    # Use the same connection string as in .env
    database_url = "postgresql+asyncpg://postgres.eqjianefzeaighbjegye:Chinmay2005%40@aws-1-ap-south-1.pooler.supabase.com:6543/postgres?ssl=require"
    
    print("=" * 60)
    print("Testing Supabase Database Connection")
    print("=" * 60)
    print(f"Host: aws-1-ap-south-1.pooler.supabase.com:6543")
    print(f"Database: postgres")
    print(f"User: postgres.eqjianefzeaighbjegye")
    print("=" * 60)
    
    engine = create_async_engine(
        database_url,
        pool_size=5,
        max_overflow=10,
        echo=False,
        connect_args={"ssl": "require"},
    )
    
    try:
        # Test basic connection
        print("\n[1/3] Testing basic connection...")
        async with engine.begin() as conn:
            result = await conn.execute(text("SELECT version()"))
            version = result.scalar()
            print(f"✓ Connection successful!")
            print(f"  PostgreSQL version: {version}")
        
        # Test UUID extension
        print("\n[2/3] Testing UUID extension...")
        async with engine.begin() as conn:
            result = await conn.execute(text("SELECT uuid_generate_v4()"))
            uuid = result.scalar()
            print(f"✓ UUID extension working!")
            print(f"  Generated UUID: {uuid}")
        
        # Test table existence
        print("\n[3/3] Checking existing tables...")
        async with engine.begin() as conn:
            result = await conn.execute(text("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public'
                ORDER BY table_name
            """))
            tables = [row[0] for row in result.fetchall()]
            
            if tables:
                print(f"✓ Found {len(tables)} existing tables:")
                for table in tables:
                    print(f"  - {table}")
            else:
                print("  No tables found (fresh database)")
        
        print("\n" + "=" * 60)
        print("✓ All connection tests passed!")
        print("=" * 60)
        print("\nYou can now start the backend with: uvicorn app.main:app --reload")
        return True
        
    except Exception as e:
        print("\n" + "=" * 60)
        print("✗ Connection failed!")
        print("=" * 60)
        print(f"Error: {e}")
        print("\nPlease check:")
        print("  1. Database credentials are correct")
        print("  2. Supabase project is active")
        print("  3. Network connectivity to Supabase")
        print("  4. SSL/TLS is enabled (required for Supabase)")
        return False
        
    finally:
        await engine.dispose()


if __name__ == "__main__":
    success = asyncio.run(test_connection())
    sys.exit(0 if success else 1)