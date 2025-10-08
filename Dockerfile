# Install uv
FROM python:3.12-slim AS builder
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Git is required to run dbt deps.
RUN apt-get update && apt-get install -y --no-install-recommends git && apt-get clean

WORKDIR /dbt

# Install dependencies
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project --no-editable

COPY dbt .


RUN uv run dbt deps

CMD ["uv", "run", "dbt", "--version" ]
