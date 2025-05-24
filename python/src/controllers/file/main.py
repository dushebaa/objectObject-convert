from fastapi import APIRouter, UploadFile, File, Form, HTTPException, Header
from typing import Annotated
from fastapi.responses import FileResponse
from pydantic import BaseModel
from ..auth.main import verify_token
from const import FileStatus

import asyncpg
import pika
import uuid
import os
import json

router = APIRouter(
    prefix="/files",
)
SECRET_KEY = "your-secret-key"
STORAGE_PATH = f"{os.getcwd()}/storage"

# Ensure storage directory exists
os.makedirs(STORAGE_PATH, exist_ok=True)


async def get_db_pool():
    return await asyncpg.create_pool(os.getenv("DATABASE_URL"))


class FileMetadata(BaseModel):
    file_id: str
    filename: str


@router.post("/process")
async def process_file(
    output_format: Annotated[str, Form()],
    file: UploadFile = File(...),
    Authorization: str = Header(),
):
    file_id = str(uuid.uuid4())
    file_path = os.path.join(STORAGE_PATH, file_id)
    user = verify_token(Authorization)
    output_format_lower = output_format.lower()

    # Save file to local filesystem
    with open(file_path, "wb") as f:
        f.write(file.file.read())

    # Store metadata in PostgreSQL
    async with await get_db_pool() as pool:
        async with pool.acquire() as conn:
            await conn.execute(
                "INSERT INTO files (id, filename, user_id, status, output_format) VALUES ($1, $2, $3, $4, $5)",
                file_id,
                file.filename,
                user["user_id"],
                FileStatus.PENDING,
                output_format_lower,
            )

    # Push task to RabbitMQ
    rabbitmq_conn = pika.BlockingConnection(
        pika.URLParameters(os.getenv("RABBITMQ_URL"))
    )
    channel = rabbitmq_conn.channel()
    channel.queue_declare(queue="file_tasks")
    channel.basic_publish(
        exchange="",
        routing_key="file_tasks",
        body=json.dumps(
            {
                "file_id": file_id,
                "file_path": file_path,
                "output_format": output_format_lower,
            }
        ),
    )
    rabbitmq_conn.close()

    return {"file_id": file_id, "file_name": file.filename}


@router.get("/{file_id}/download/", response_model=FileMetadata)
async def download_file(
    file_id: str,
    Authorization: str = Header(),
):
    # Check PostgreSQL
    async with await get_db_pool() as pool:
        async with pool.acquire() as conn:
            file = await conn.fetchrow("SELECT * FROM files WHERE id = $1", file_id)
            if not file:
                raise HTTPException(status_code=404, detail="File not found")
            # Check access
            user = verify_token(Authorization)
            if file["user_id"] != user["user_id"]:
                raise HTTPException(status_code=403, detail="Unauthorized")
            if file["status"] != FileStatus.FINISHED:
                raise HTTPException(
                    status_code=400, detail="File has not been processed"
                )

            converted_file_name = f"{file_id}.{file['output_format']}"
            file_path = os.path.join(STORAGE_PATH, "converted", converted_file_name)
            if os.path.exists(file_path):
                return FileResponse(file_path, filename=converted_file_name)
            raise HTTPException(status_code=404, detail="File not found on disk")


@router.get("/{file_id}/status/")
async def file_status(file_id: str, Authorization: str = Header()):
    async with await get_db_pool() as pool:
        async with pool.acquire() as conn:
            user = verify_token(Authorization)
            file = await conn.fetchrow("SELECT * FROM files WHERE id = $1", file_id)
            if not file:
                return HTTPException(
                    status_code=401, detail=f"File with id {file_id} not found"
                )
            if file["user_id"] != user["user_id"]:
                raise HTTPException(status_code=403, detail="Unauthorized")

            result = {
                "filename": file["filename"],
                "file_id": file["id"],
                "status": file["status"],
            }

            if file["status"] == FileStatus.FINISHED:
                result["download_url"] = f"/files/{file_id}/download/"

            return result
