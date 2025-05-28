FROM python:3.13-slim

WORKDIR /code

RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg && \
    ffmpeg -version && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY ./requirements.txt /code/requirements.txt


RUN pip install --no-cache-dir --upgrade -r /code/requirements.txt

COPY ./.env.docker ./.env
COPY . .

CMD ["fastapi", "run", "main.py", "--port", "8000"]