FROM elixir:1.19-otp-28-slim AS build

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential git ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config config

RUN mix deps.get --only prod
RUN mix deps.compile

COPY lib lib
COPY priv priv
COPY openapi.yaml openapi.yaml
COPY README.md README.md

RUN mix compile
RUN mix release

FROM debian:trixie-slim AS runtime

RUN apt-get update && \
    apt-get install -y --no-install-recommends libstdc++6 openssl ca-certificates locales && \
    rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8
WORKDIR /app

COPY --from=build /app/_build/prod/rel/pulse_ops /app

EXPOSE 4000

CMD ["/app/bin/pulse_ops", "start"]
