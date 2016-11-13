# Image for running UP homework tests

FROM gcc:latest
MAINTAINER Trifon Trifonov <triffon@fmi.uni-sofia.bg>

COPY test_all.sh /usr/src/up-hw-test/
WORKDIR /usr/src/up-hw-test
CMD ./test_all.sh 2>&1 | tee results/test.log
