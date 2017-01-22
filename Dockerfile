# Image for running UP homework tests

FROM gcc:latest
MAINTAINER Trifon Trifonov <triffon@fmi.uni-sofia.bg>

# Copy the script
COPY test_all.sh /usr/src/up-hw-test/

# Set default working directory
WORKDIR /usr/src/up-hw-test

# Create a sandbox user for testing
RUN useradd test

CMD ./test_all.sh 2>&1 | tee results/test.log
