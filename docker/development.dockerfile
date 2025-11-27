FROM crystallang/crystal:1.18.2

RUN apt-get update && \
    apt-get install -y wget postgresql-client tmux && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /lucky/cli
RUN git clone https://github.com/luckyframework/lucky_cli . && \
    git checkout v1.4.1 && \
    shards build --without-development && \
    cp bin/lucky /usr/bin

WORKDIR /app
EXPOSE 3000
EXPOSE 3001
