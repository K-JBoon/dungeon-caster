# Stage 1: builder
FROM hexpm/elixir:1.18-erlang-27-debian-bookworm-slim AS builder
WORKDIR /app

RUN apt-get update && apt-get install -y build-essential nodejs npm git && \
    rm -rf /var/lib/apt/lists/*

COPY mix.exs mix.lock ./
RUN mix local.hex --force && mix local.rebar --force
ENV MIX_ENV=prod
RUN mix deps.get --only prod

COPY config/ config/
COPY priv/ priv/
COPY lib/ lib/
COPY assets/ assets/

RUN mix assets.deploy
RUN mix release

# Stage 2: runtime
FROM debian:bookworm-slim AS runtime
RUN apt-get update && apt-get install -y \
    git openssh-client curl \
    libssl3 libncurses6 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/_build/prod/rel/campaign_tool ./
EXPOSE 4000
CMD ["./bin/campaign_tool", "start"]
