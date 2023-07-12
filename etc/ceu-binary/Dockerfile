FROM ubuntu:23.10

WORKDIR /ceu

RUN apt update
RUN apt install -y git lua5.3 lua-lpeg liblua5.3-0 liblua5.3-dev make

COPY . .

RUN ln -s /usr/include/lua5.3/* /usr/local/include/

CMD make && make install-srlua && make binary