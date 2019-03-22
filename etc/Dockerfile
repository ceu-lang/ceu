# start with a current Debian image with some build tools installed
FROM buildpack-deps:stretch

# install dev packages for lua
RUN apt-get update \
  && apt-get install -y lua5.3 lua-lpeg liblua5.3-0 liblua5.3-dev \
  && rm -rf /var/lib/apt/lists/*

# shallow clone the repo, then build and install
RUN git clone --depth 5 https://github.com/ceu-lang/ceu.git \
  && cd ceu \
  && make \
  && make install
