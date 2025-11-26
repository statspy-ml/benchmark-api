import math
import os
from contextlib import asynccontextmanager

import asyncpg
from pydantic import BaseModel

from fastapi import FastAPI, HTTPException

# Database connection pool
db_pool = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    global db_pool
    db_pool = await asyncpg.create_pool(
        host=os.getenv("DB_HOST", "postgres"),
        port=int(os.getenv("DB_PORT", "5432")),
        user=os.getenv("DB_USER", "benchmark"),
        password=os.getenv("DB_PASSWORD", "benchmark123"),
        database=os.getenv("DB_NAME", "benchmark"),
        min_size=10,
        max_size=20,
    )
    yield
    # Shutdown
    await db_pool.close()


app = FastAPI(lifespan=lifespan)


class CalcRequest(BaseModel):
    a: int
    b: int


class CalcResponse(BaseModel):
    result: float


class HealthResponse(BaseModel):
    status: str


class UserResponse(BaseModel):
    id: int
    name: str
    email: str
    created_at: str


@app.post("/calculate", response_model=CalcResponse)
async def calculate(request: CalcRequest):
    result = math.sqrt(request.a**2 + request.b**2)
    return CalcResponse(result=result)


@app.get("/user/{user_id}", response_model=UserResponse)
async def get_user(user_id: int):
    """
    Get user by ID from database (I/O bound operation)
    """
    async with db_pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT id, name, email, created_at FROM users WHERE id = $1", user_id
        )

        if not row:
            raise HTTPException(status_code=404, detail="User not found")

        return UserResponse(
            id=row["id"],
            name=row["name"],
            email=row["email"],
            created_at=row["created_at"].isoformat(),
        )


@app.get("/health", response_model=HealthResponse)
async def health():
    """
    Health check endpoint
    """
    return HealthResponse(status="ok")
