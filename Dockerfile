FROM golang:latest

# Install system deps (one RUN)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Put go-installed tools in /usr/local/bin
ENV GOBIN=/usr/local/bin
ENV PATH="${GOBIN}:${PATH}"
ENV GO111MODULE=on

# Install tools
RUN set -eux; \
    echo "Installing subfinder..." && \
    go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest && \
    echo "Installing assetfinder..." && \
    go install github.com/tomnomnom/assetfinder@latest && \
    echo "Installing httpx..." && \
    go install github.com/projectdiscovery/httpx/cmd/httpx@latest && \
    echo "Installing dnsx..." && \
    go install github.com/projectdiscovery/dnsx/cmd/dnsx@latest

# Add crtsh helper
COPY crtsh.sh /usr/local/bin/crtsh
RUN chmod +x /usr/local/bin/crtsh

# Copy recon script
WORKDIR /recon
COPY recon-domain.sh /usr/local/bin/recon.sh
RUN chmod +x /usr/local/bin/recon.sh

# Simple verification (optional)
RUN echo "Installed:" && ls -la /usr/local/bin | sed -n '1,200p'

ENTRYPOINT ["/usr/local/bin/recon.sh"]

