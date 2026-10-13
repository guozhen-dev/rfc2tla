FROM python:3.12-slim

ENV DEBIAN_FRONTEND=noninteractive \
    NLTK_DATA=/usr/local/share/nltk_data \
    PATH=/artifact/.venv/bin:$PATH \
    PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends default-jre-headless git curl patch \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /artifact

COPY artifacts/requirements.txt /tmp/rfc2tla-requirements.txt
RUN python -m venv /artifact/.venv \
    && pip install --no-cache-dir -r /tmp/rfc2tla-requirements.txt \
    && python -m nltk.downloader -d "$NLTK_DATA" punkt punkt_tab \
    && ln -s /artifact/.venv /artifact/venv

COPY artifacts/ /artifact/
COPY traces/ /artifact/traces/

CMD ["python", "main.py", "--help"]
