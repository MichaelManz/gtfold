FROM gcc:4

RUN apt-get update && apt-get install -y libgmp3-dev

ADD gtfold-mfe /opt/gtfold-mfe
WORKDIR /opt/gtfold-mfe

RUN ./configure \
    && make \
    && make install

CMD ["/usr/local/bin/gtfold"]