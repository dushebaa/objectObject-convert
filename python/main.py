import os
import threading
from fastapi import FastAPI
from starlette.middleware import Middleware
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

dotenv_path = os.path.join(os.path.dirname(__file__), ".env")
if os.path.exists(dotenv_path):
    load_dotenv(dotenv_path)
else:
    raise EnvironmentError("No .env file found!")

from src.services.file_processor import start_rabbitmq_consumer, rabbitmq_conn, channel  # noqa: E402
import src.controllers.auth.main  # noqa: E402
import src.controllers.file.main  # noqa: E402

app = FastAPI(middleware=[
    Middleware(CORSMiddleware, allow_origins=["*"])
])

app.include_router(src.controllers.auth.main.router)
app.include_router(src.controllers.file.main.router)


@app.on_event("startup")
async def startup():
    consumer_thread = threading.Thread(target=start_rabbitmq_consumer, daemon=True)
    consumer_thread.start()


@app.on_event("shutdown")
async def shutdown():
    print("Shutting down app")
    channel.stop_consuming()
    rabbitmq_conn.close()
