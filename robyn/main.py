import math
import os

import asyncpg
from robyn.robyn import Request

from robyn import Robyn, jsonify

app = Robyn(__file__)

# Database pool
db_pool = None


@app.startup_handler
async def startup():
    global db_pool
    db_host = os.getenv("DB_HOST", "postgres")
    db_port = os.getenv("DB_PORT", "5432")
    db_user = os.getenv("DB_USER", "benchmark")
    db_password = os.getenv("DB_PASSWORD", "benchmark123")
    db_name = os.getenv("DB_NAME", "benchmark")

    db_pool = await asyncpg.create_pool(
        host=db_host,
        port=db_port,
        user=db_user,
        password=db_password,
        database=db_name,
        min_size=10,
        max_size=20,
    )


@app.shutdown_handler
async def shutdown():
    global db_pool
    if db_pool:
        await db_pool.close()


@app.get("/health")
async def health(request: Request):
    return jsonify({"status": "ok"})


@app.post("/calculate")
async def calculate(request: Request):
    body = request.json()
    a = int(body.get("a", 0))
    b = int(body.get("b", 0))
    result = math.sqrt(a**2 + b**2)
    return jsonify({"result": result})


@app.get("/user/:id")
async def get_user(request: Request):
    user_id = int(request.path_params.get("id"))

    async with db_pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT id, name, email, created_at FROM users WHERE id = $1", user_id
        )

        if not row:
            return jsonify({"error": "User not found"}), 404

        return jsonify(
            {
                "id": row["id"],
                "name": row["name"],
                "email": row["email"],
                "created_at": row["created_at"].isoformat(),
            }
        )


if __name__ == "__main__":
    app.start(host="0.0.0.0", port=8000)
