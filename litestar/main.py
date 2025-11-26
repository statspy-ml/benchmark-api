import math
import os
from datetime import datetime

import asyncpg
from litestar.exceptions import NotFoundException
from pydantic import BaseModel

from litestar import Litestar, get, post

# Database connection pool
db_pool = None


async def startup():
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


async def shutdown():
    global db_pool
    if db_pool:
        await db_pool.close()


# Request model
class CalcRequest(BaseModel):
    a: int
    b: int


# Response model
class CalcResponse(BaseModel):
    result: float


# Health response model
class HealthResponse(BaseModel):
    status: str


# User response model
class UserResponse(BaseModel):
    id: int
    name: str
    email: str
    created_at: str


@post("/calculate", status_code=200)
async def calculate(data: CalcRequest) -> CalcResponse:
    """
    Calcula a distância euclidiana entre dois números
    """
    result = math.sqrt(data.a**2 + data.b**2)
    return CalcResponse(result=result)


@get("/user/{user_id:int}")
async def get_user(user_id: int) -> UserResponse:
    """
    Get user by ID from database (I/O bound operation)
    """
    async with db_pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT id, name, email, created_at FROM users WHERE id = $1", user_id
        )

        if not row:
            raise NotFoundException(detail="User not found")

        return UserResponse(
            id=row["id"],
            name=row["name"],
            email=row["email"],
            created_at=row["created_at"].isoformat(),
        )


@get("/health")
async def health() -> HealthResponse:
    """
    Health check endpoint
    """
    return HealthResponse(status="ok")


app = Litestar(
    route_handlers=[calculate, get_user, health],
    on_startup=[startup],
    on_shutdown=[shutdown],
)
