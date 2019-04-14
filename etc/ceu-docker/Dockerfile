FROM ubuntu

ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

# install dev packages for lua, git and vim
RUN apt-get update \
  && apt-get install -y lua5.3 lua-lpeg liblua5.3-0 liblua5.3-dev \
  && apt-get install -y git \
  && apt-get install -y vim \
  && rm -rf /var/lib/apt/lists/*

# shallow clone the repo, then build and install
RUN git clone --depth 5 https://github.com/ceu-lang/ceu.git \
  && cd ceu \
  && make \
  && make install
