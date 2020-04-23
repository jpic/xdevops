FROM alpine:edge

ENV DJANGO_SETTINGS_MODULE=xdevops.settings
ENV UWSGI_MODULE=xdevops.wsgi:application
ENV STATIC_URL=/static/ STATIC_ROOT=/app/static
ENV PYTHONIOENCODING=UTF-8 PYTHONUNBUFFERED=1
EXPOSE 8000

RUN apk update && apk --no-cache upgrade && apk --no-cache add gettext shadow python3 py3-pip py3-psycopg2 uwsgi-python uwsgi-http uwsgi-spooler dumb-init bash git curl
RUN pip install django

RUN useradd -md /app app
WORKDIR /app
COPY . /app/

USER app
RUN ./manage.py collectstatic --noinput
CMD /usr/bin/dumb-init bash -c "until djcli dbcheck; do sleep 1; done && ./manage.py migrate --noinput && uwsgi \
  --spooler=/app/spool \
  --spooler-processes 3 \
  --http-socket=0.0.0.0:8000 \
  --chdir=/app \
  --spooler-chdir=/app \
  --plugin=python3,http \
  --module=xdevops.wsgi:application \
  --http-keepalive \
  --harakiri=120 \
  --max-requests=100 \
  --master \
  --workers=12 \
  --processes=6 \
  --log-5xx \
  --vacuum \
  --enable-threads \
  --post-buffering=8192 \
  --ignore-sigpipe \
  --ignore-write-errors \
  --disable-write-exception \
  --mime-file /etc/mime.types \
  --thunder-lock \
  --offload-threads '%k' \
  --static-map $STATIC_URL=$STATIC_ROOT"
