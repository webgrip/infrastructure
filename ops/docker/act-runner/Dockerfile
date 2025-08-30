FROM alpine:3.22.1

# Install dependencies needed by ACT
RUN apk add --no-cache docker git bash curl gh 

# Download and install ACT binary
RUN curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | bash -s -- -b /usr/local/bin

# Set working directory
WORKDIR /workspace

# Default command
ENTRYPOINT ["act"]