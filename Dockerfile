# ---- Build Elixir image ----
FROM public.ecr.aws/docker/library/elixir:1.18.4-alpine AS build-elixir
ENV MIX_ENV=prod
RUN mix local.hex --force && \
    mix local.rebar --force
RUN apk add --no-cache bash openssl build-base git
COPY mix.exs .
COPY mix.lock .
RUN mix deps.get && mix deps.compile
COPY config ./config
COPY lib ./lib

# ---- Build Node image ----
FROM public.ecr.aws/docker/library/node:24.10.0-alpine AS build-node
ENV NODE_ENV=prod
WORKDIR /app/assets
COPY assets .
RUN yarn install

# ---- Build release image ----
FROM build-elixir AS release
COPY priv ./priv
COPY --from=build-node /app/assets ./assets
RUN mix assets.deploy && mix release   

# ---- Run application ----
FROM public.ecr.aws/docker/library/alpine:3.22.1
RUN apk add --no-cache bash openssl libgcc libstdc++ libssl3
WORKDIR /app

COPY --from=release _build/prod/rel/antonia/ .
COPY --from=release priv/static priv/static
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
