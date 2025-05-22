
FROM python:3.13-slim

WORKDIR /code


COPY ./requirements.txt /code/requirements.txt


RUN pip install --no-cache-dir --upgrade -r /code/requirements.txt


COPY ./src /code/src
COPY ./storage /code/storage
COPY ./models /code/models
COPY ./main.py /code/main.py
COPY ./const.py /code/const.py
COPY ./.env.docker /code/.env

CMD ["fastapi", "run", "main.py", "--port", "8000"]