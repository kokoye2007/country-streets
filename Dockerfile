# syntax=docker/dockerfile:1

# --------
# Builder: compile wheels for all Python deps
# --------
FROM python:3.11-slim AS builder

ENV PIP_NO_CACHE_DIR=1
WORKDIR /app

# System deps required to build pyosmium (osmium) wheels
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential \
       libexpat1-dev \
       zlib1g-dev \
       libbz2-dev \
       liblzma-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy dependency manifest first for better layer caching
COPY requirements.txt ./

# Build wheelhouse
RUN python -m pip install --upgrade pip \
    && mkdir -p /wheels \
    && pip wheel -r requirements.txt -w /wheels

# --------
# Runtime: install tools and Python deps from wheels
# --------
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    COUNTRY=asia/laos

WORKDIR /app

# Install required CLI tools: osmconvert/osmfilter (osmctools), osmosis (Java), wget, make
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       osmctools \
       osmosis \
       default-jre-headless \
       libexpat1 \
       zlib1g \
       libbz2-1.0 \
       liblzma5 \
       wget \
       make \
       ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create a dedicated venv and install from prebuilt wheels
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

COPY --from=builder /wheels /wheels
COPY requirements.txt ./
RUN pip install --upgrade pip \
    && pip install --no-index --find-links=/wheels -r requirements.txt \
    && rm -rf /wheels

# Make Makefile's default VENV path work inside container
RUN ln -s /opt/venv /app/venv

# Copy only what we need for running the pipeline
COPY countries.txt ./
COPY Makefile README.md ./
COPY scripts ./scripts
# Create bind mount points (host paths will override when mounted)
RUN mkdir -p ./data ./filtered ./osm ./output
COPY entrypoint.sh ./entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Default command runs the whole pipeline; override with `docker run ... make city`, etc.
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["make", "all"]
