from src.services.redis import redis
from models.types import UserDto

from fastapi import HTTPException, APIRouter
import jwt
import asyncpg
import os

SECRET_KEY = os.getenv("PWD_SECRET")
DATABASE_URL = os.getenv("DATABASE_URL")

router = APIRouter(
    prefix="/auth",
)


def verify_token(token: str):
    try:
        if token is None:
            raise HTTPException(status_code=401, detail="Missing token")
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        return payload
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")


@router.post("/signup")
async def signup(user: UserDto):
    async with asyncpg.create_pool(DATABASE_URL) as pool:
        async with pool.acquire() as conn:
            await conn.execute(
                "INSERT INTO users (username, password) VALUES ($1, $2)",
                user.username,
                user.password,  # In production, hash passwords
            )
    return {"message": "User created"}


@router.post("/login")
async def login(user: UserDto):
    async with asyncpg.create_pool(DATABASE_URL) as pool:
        async with pool.acquire() as conn:
            db_user = await conn.fetchrow(
                "SELECT * FROM users WHERE username = $1", user.username
            )
            if (
                db_user and db_user["password"] == user.password
            ):  # Use proper password hashing
                token = jwt.encode(
                    {"username": user.username, "user_id": db_user["id"]},
                    SECRET_KEY,
                    algorithm="HS256",
                )
                await redis.set(
                    f"session:{user.username}", token, ex=3600
                )  # 1-hour session
                return {"token": token}
            raise HTTPException(status_code=401, detail="Invalid credentials")
