FROM golang:latest

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    ca-certificates \
    chromium \
    && rm -rf /var/lib/apt/lists/*

# Set Go environment
ENV PATH="/root/go/bin:${PATH}"
ENV GOPATH="/root/go"
ENV GO111MODULE=on

# Install tools one by one and verify
RUN echo "Installing subfinder..." && \
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest && \
    subfinder -version

RUN echo "Installing assetfinder..." && \
    go install -v github.com/tomnomnom/assetfinder@latest && \
    which assetfinder

RUN echo "Installing httpx..." && \
    go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest && \
    httpx -version

RUN echo "Installing gowitness..." && \
    go install -v github.com/sensepost/gowitness@latest && \
    which gowitness

RUN echo "Installing gau..." && \
    go install -v github.com/lc/gau/v2/cmd/gau@latest && \
    which gau

RUN echo "Installing waybackurls..." && \
    go install -v github.com/tomnomnom/waybackurls@latest && \
    which waybackurls

RUN echo "Installing katana..." && \
    go install -v github.com/projectdiscovery/katana/cmd/katana@latest && \
    katana -version

RUN echo "Installing nuclei..." && \
    go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest && \
    nuclei -version

RUN echo "Installing gf..." && \
    go install -v github.com/tomnomnom/gf@latest && \
    which gf

RUN echo "Installing amass..." && \
    go install -v github.com/owasp-amass/amass/v4/...@master && \
    amass -version

# Install gf patterns
RUN mkdir -p /root/.gf && \
    git clone https://github.com/1ndianl33t/Gf-Patterns /tmp/gf-patterns && \
    cp /tmp/gf-patterns/*.json /root/.gf/ 2>/dev/null || true && \
    rm -rf /tmp/gf-patterns

# Download nuclei templates
RUN nuclei -update-templates

# Verify all installations
RUN echo "=== Installed Tools ===" && \
    ls -la /root/go/bin/ && \
    echo "PATH: $PATH"

# Set working directory
WORKDIR /recon

# Copy the recon script
COPY recon-domain.sh /usr/local/bin/recon.sh
RUN chmod +x /usr/local/bin/recon.sh

# Set the script as entrypoint
ENTRYPOINT ["/usr/local/bin/recon.sh"]
