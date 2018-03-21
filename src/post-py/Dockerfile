FROM python:3.6.0-alpine

RUN apk add --update gcc musl-dev

WORKDIR /app
COPY . /app

RUN pip install -r /app/requirements.txt

ENV POST_DATABASE_HOST=post_db \
  POST_DATABASE=posts

ENTRYPOINT ["python3", "post_app.py"]
