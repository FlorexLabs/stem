FROM crystallang/crystal:1.18.2-alpine AS build
WORKDIR /app
RUN apk add --no-cache build-base openssl-dev pcre2-dev yaml-dev zlib-dev
COPY shard.yml shard.lock ./
RUN shards install --production
COPY . .
RUN shards build --release --no-debug stem

FROM alpine:3.19
RUN apk add --no-cache openssl pcre2 yaml zlib libgcc tzdata postgresql-client
WORKDIR /app
COPY --from=build /app/bin/stem /usr/local/bin/stem
ENV PORT=3000
EXPOSE 3000
CMD ["stem"]
