import asyncio
import json
import asyncpg
import pika
import os
import subprocess
from const import FileStatus


rabbitmq_conn = pika.BlockingConnection(
    pika.URLParameters(os.getenv("RABBITMQ_URL", "amqp://localhost:5672"))
)
channel = rabbitmq_conn.channel()


async def update_file_status(file_id: str, file_status: FileStatus):
    async with await asyncpg.create_pool(os.getenv("DATABASE_URL")) as pool:
        async with pool.acquire() as conn:
            await conn.execute(
                "UPDATE files SET status=$1 WHERE id = $2",
                file_status,
                file_id,
            )


async def process_video(file_path: str, output_format: str):
    file_name = file_path.split("/")[-1]
    stdout = subprocess.run(
        ["ffmpeg", "-i", file_path, f"storage/converted/{file_name}.{output_format}"]
    )
    return stdout.returncode


async def process_video_async(method, file_id: str, file_path: str, output_format: str):
    await update_file_status(file_id, FileStatus.PROCESSING)
    returncode = await process_video(file_path, output_format)
    channel.basic_ack(delivery_tag=method.delivery_tag)
    if returncode != 0:
        await update_file_status(file_id, FileStatus.ERROR)
        return
    await update_file_status(file_id, FileStatus.FINISHED)


def file_callback(ch, method, properties, body):
    parsed_body = json.loads(body)
    file_id = parsed_body["file_id"]
    file_path = parsed_body["file_path"]
    output_format = parsed_body["output_format"]
    asyncio.run(process_video_async(method, file_id, file_path, output_format))


def start_rabbitmq_consumer():
    print("Starting RabbitMQ consumer")
    channel.queue_declare(queue="file_tasks")
    channel.basic_consume(queue="file_tasks", on_message_callback=file_callback)
    channel.start_consuming()
