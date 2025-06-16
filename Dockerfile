FROM ubuntu:24.04

LABEL repository="https://github.com/mehdi-ra/squid-warp"
LABEL maintainer="Mehdi Rahimi <mehdirahimi.dev@gmail.com>"
LABEL version="0.0.1"

RUN apt-get update -y --fix-missing \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    gnupg curl lsb-release net-tools socat iproute2 iputils-ping python3

# Install Cloudflare WARP
RUN curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ jammy main" > /etc/apt/sources.list.d/cloudflare-client.list \
    && apt-get update \
    && apt-get install -y cloudflare-warp

# Install Squid and utilities
RUN apt-get install -y --no-install-recommends \
    squid=6.6-1ubuntu5 \
    apache2-utils=2.4.58-1ubuntu8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy configs and entrypoint
COPY entry.sh /entry.sh
COPY squid.conf /etc/squid/squid.conf
RUN chmod +x /entry.sh

EXPOSE 3128/tcp

ENTRYPOINT ["/entry.sh"]
