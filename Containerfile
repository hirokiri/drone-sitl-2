# Dev / sim image for Drone SITL
# Ubuntu 26.04 · ROS 2 Lyrical · Gazebo Jetty · Rust (rustup) + system Python
#
# This image is the single source of version truth for everything that runs
# inside the container. mise is installed only for the developer tools pinned
# in mise.toml (pre-commit, linters); it must never pin python or rust, so it
# cannot shadow the system Python that ROS 2 requires or the rustup toolchain.
#
# Build:  podman build -t drone-sitl:dev -f Containerfile .
# (usually invoked through `compose.yaml` / `make build`)

FROM ros:lyrical-ros-base

ENV DEBIAN_FRONTEND=noninteractive \
    ROS_DISTRO=lyrical

# --- System & ROS 2 <-> Gazebo / PX4 dependencies -------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential cmake curl wget ca-certificates \
        git gh openssh-client tmux \
        python3-pip python3-venv \
        libclang-dev pkg-config libssl-dev \
        ros-lyrical-ros-gz \
        ros-lyrical-rmw-cyclonedds-cpp \
        ros-dev-tools \
    && rm -rf /var/lib/apt/lists/*

# The repo is bind-mounted at /workspace and may be owned by a different UID
# than the container user (e.g. rootful Podman). Tell git it is trusted so
# the host's identity/config (mounted via compose.yaml) works without
# "dubious ownership" errors.
RUN git config --system --add safe.directory /workspace

# Python linter/formatter used by `make fmt` / `make lint`.
RUN pip install --no-cache-dir --break-system-packages ruff

# Use CycloneDDS (recommended for PX4 uXRCE-DDS interop).
ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

# --- Rust toolchain (rustup, pinned by rust-toolchain.toml) ----------------
# rustup reads rust-toolchain.toml from the workspace and auto-selects the
# pinned toolchain. Copying it here warms the toolchain into the image layer.
RUN curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs \
        | sh -s -- -y --no-modify-path --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /workspace
COPY rust-toolchain.toml /workspace/rust-toolchain.toml
RUN rustup show

# --- Developer tools: mise + Claude Code CLI -------------------------------
# mise runs the dev tools pinned in mise.toml (pre-commit, shellcheck,
# yamllint) inside the container as well as on the host. mise.toml must not
# pin python/rust — see the header comment there. The repo's config is
# trusted up-front so `mise` works non-interactively from `make`.
# Claude Code's native installer puts the binary in /root/.local/bin; its
# login/settings come from the host's ~/.claude mounted by compose.yaml.
RUN curl -fsSL https://mise.run | sh \
    && curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/root/.local/bin:${PATH}" \
    MISE_TRUSTED_CONFIG_PATHS=/workspace

# Source ROS 2 and activate mise on every interactive shell.
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /root/.bashrc \
    && echo 'eval "$(mise activate bash)"' >> /root/.bashrc

CMD ["bash"]
