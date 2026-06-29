FROM alpine:3.22

ENV LUA_MAJOR_VERSION=5.1
ENV LUA_MINOR_VERSION=5
ENV LUA_VERSION=${LUA_MAJOR_VERSION}.${LUA_MINOR_VERSION}

RUN apk update && apk add --update make tar unzip gcc openssl-dev readline-dev curl libc-dev wget coreutils

RUN curl -L http://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz | tar xzf -
WORKDIR /lua-$LUA_VERSION
RUN make linux test
RUN make install
WORKDIR /
RUN rm -rf /lua-$LUA_VERSION

ENV WITH_LUA=/usr/local/
ENV LUA_LIB=/usr/local/lib/lua
ENV LUA_INCLUDE=/usr/local/include

ENV LUAROCKS_VERSION=3.9.2
RUN curl -OL https://luarocks.org/releases/luarocks-$LUAROCKS_VERSION.tar.gz && \
    tar xzf luarocks-$LUAROCKS_VERSION.tar.gz && \
    cd luarocks-$LUAROCKS_VERSION && \
    ./configure --with-lua=$WITH_LUA --with-lua-include=$LUA_INCLUDE --with-lua-lib=$LUA_LIB && \
    make build && make install && \
    cd / && rm -rf luarocks-$LUAROCKS_VERSION luarocks-$LUAROCKS_VERSION.tar.gz

RUN apk add neovim

ENV BUSTED_VERSION=2.3.0-1
ENV NLUA_VERSION=0.3.2-1
RUN luarocks install busted $BUSTED_VERSION
RUN luarocks install nlua $NLUA_VERSION

WORKDIR /mnt/luarocks
