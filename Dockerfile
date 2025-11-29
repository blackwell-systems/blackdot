# Dotfiles Bootstrap in Docker
# =============================
# Demonstrates running bootstrap in a clean container environment.
# Useful for CI/CD, testing, or reproducible development containers.

FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install minimal prerequisites
# (bootstrap script will install the rest via Homebrew)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        git \
        sudo \
        ca-certificates \
        && rm -rf /var/lib/apt/lists/*

# Create non-root user with sudo access
RUN useradd -m -s /bin/bash developer && \
    echo "developer ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to non-root user
USER developer
WORKDIR /home/developer

# Clone dotfiles (replace with your fork)
# For CI, you might mount the repo instead
ARG DOTFILES_REPO=https://github.com/blackwell-systems/dotfiles.git
RUN git clone "$DOTFILES_REPO" /home/developer/workspace/dotfiles

# Run bootstrap
WORKDIR /home/developer/workspace/dotfiles
RUN ./bootstrap/bootstrap-linux.sh

# Optional: Restore secrets from Bitwarden
# Requires BW_SESSION to be passed at runtime:
#   docker run -e BW_SESSION="$BW_SESSION" dotfiles-dev

# Set default shell to zsh
SHELL ["/bin/zsh", "-c"]

# Default command: interactive zsh
CMD ["zsh"]

# =============================================================================
# Usage Examples:
# =============================================================================
#
# Build image:
#   docker build -t dotfiles-dev .
#
# Run interactive shell:
#   docker run -it --rm dotfiles-dev
#
# Run with Bitwarden vault restore:
#   export BW_SESSION="$(bw unlock --raw)"
#   docker run -it --rm -e BW_SESSION="$BW_SESSION" dotfiles-dev
#
# Mount local dotfiles (for testing):
#   docker run -it --rm -v $PWD:/home/developer/workspace/dotfiles dotfiles-dev
#
# Use in CI (GitLab example):
#   test:
#     image: dotfiles-dev:latest
#     script:
#       - dotfiles doctor
#
# Docker Compose:
#   services:
#     dev:
#       build: .
#       environment:
#         - BW_SESSION
#       volumes:
#         - ./:/home/developer/workspace/dotfiles
#       command: zsh
