# Dev / sim image for Drone SITL
# Ubuntu 26.04 · ROS 2 Lyrical · Gazebo Jetty · Rust (rustup) + system Python
#
# This image is the single source of version truth for everything that runs
# inside the container. mise is a HOST-only tool and is intentionally not
# installed here, so it can never shadow the system Python that ROS 2 requires.
#
# Build:  podman build -t drone-sitl:dev -f Containerfile .
# (usually invoked through `compose.yaml` / `make build`)

FROM ros:lyrical-ros-base

ENV DEBIAN_FRONTEND=noninteractive \
    ROS_DISTRO=lyrical

# --- System & ROS 2 <-> Gazebo / PX4 dependencies -------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential cmake git curl wget ca-certificates \
        python3-pip python3-venv \
        libclang-dev pkg-config libssl-dev \
        ros-lyrical-ros-gz \
        ros-lyrical-rmw-cyclonedds-cpp \
        ros-dev-tools \
    && rm -rf /var/lib/apt/lists/*

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

# Source ROS 2 on every interactive shell.
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /root/.bashrc

CMD ["bash"]
