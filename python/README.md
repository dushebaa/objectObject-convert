# Python backend file converting thing

Featuring:

- incorrectly used RabbitMQ
- useless Redis
- no password hashing

## run this bitch:

Install 100 gorillion libraries

```bash
$ pip install --no-cache-dir -r requirements.txt
```

Run bad code in dev mode

```bash
$ fastapi dev main.py
```

---

or if you're a fancy docker user mf:

```bash

docker build --tag "cloudvault_python" .
docker run cloudvault_python
```

## database migration

Set `sqlalchemy.url` in `alembic.ini` to your postgres connection string

```bash
alembic upgrade head
```
