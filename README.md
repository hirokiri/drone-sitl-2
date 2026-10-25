# Drone SITL

A **Software-In-The-Loop (SITL)** simulation of a multirotor drone that keeps
flying and holding position **after losing its GNSS/GPS signal**, by estimating
its global position from its camera via **visual map-matching**.

- **Autopilot:** PX4 SITL · **Simulator:** Gazebo Jetty · **Middleware:** ROS 2 Lyrical
- **Perf core:** Rust (perception / estimation) · **Glue:** Python (orchestration, analysis)
- **Environment:** Podman container, driven through a `Makefile` (dev tooling via `mise`)

> 📄 Full specification: [`docs/specs/overview.md`](docs/specs/overview.md)

## How it works

Gazebo simulates the drone and its sensors (GNSS, camera, LiDAR, IMU, baro). PX4
SITL runs the autopilot and talks to ROS 2 over the uXRCE-DDS bridge. A **Rust
map-matching node** matches the live camera view against a pre-built,
georeferenced map to recover a **global position**, which is fused into PX4's
**EKF2** as external vision. When a **Python GNSS-loss injector** degrades or
drops GNSS, the drone falls back to IMU + visual map-matching and keeps flying.

See the [system diagram and data flow](docs/specs/overview.md#3-system-overview).

## Prerequisites

- [Podman](https://podman.io/) with `podman compose` (or Docker Compose)
- A Linux host with an X11 display for the Gazebo / RViz GUIs
- `make`

Everything else (ROS 2, Gazebo, PX4, Rust, Python) lives inside the container.

## Quickstart

```bash
# Allow the container to reach your X server (once per login session)
xhost +local:

# Build the image and start the dev container
make up

# Build the ROS 2 workspace
make build

# Launch the simulator (Gazebo + PX4 SITL)
make sim

# In another shell: bring up the full stack, or run the demo mission
make run
make mission
```

Run `make help` to see all targets.

## Repository layout

```text
docs/specs/     Specification documents (start with overview.md)
ros2_ws/src/    ROS 2 packages (Rust perception + Python orchestration)
sim/            Gazebo worlds and drone/sensor models
maps/           Offline-built georeferenced feature maps
tools/          Offline pipelines (e.g. map builder)
compose.yaml         Podman Compose dev/sim environment
Containerfile        Dev/sim image (container runtime = source of version truth)
rust-toolchain.toml  Pinned Rust toolchain (rustup)
mise.toml            Dev tools (pre-commit, linters) for host and container
Makefile             Developer workflow entrypoints
```

> The `ros2_ws/`, `sim/`, `maps/`, and `tools/` trees are the planned layout
> from the spec and are populated as components land — see the
> [milestones](docs/specs/overview.md#10-milestones-indicative).

## GUI (Gazebo / RViz) notes

The dev container forwards `DISPLAY` and mounts `/tmp/.X11-unix`. On most Linux
hosts, `xhost +local:` before `make up` is enough. On Wayland or rootless Podman
you may need `xhost +SI:localuser:root` or an XWayland setup; adjust `DISPLAY`
in `compose.yaml` if your display is not `:0`.

## Development

- Format / lint: `make fmt` · `make lint`
- Test: `make test`
- Contributor & agent conventions: [`AGENTS.md`](AGENTS.md)

### Git & SSH inside the container

`compose.yaml` mounts your host git/SSH configuration **read-only** into the
container (which runs as `root`, so paths land under `/root`):

| Host | Purpose |
|------|---------|
| `~/.ssh` | keys, `config`, `known_hosts` |
| `~/.gitconfig` | identity, aliases, credential helpers |
| `~/.config/gh`, `~/.git-credentials` | tokens for the `gh` / `store` credential helpers |
| `$SSH_AUTH_SOCK` | forwarded `ssh-agent` (passphrase-protected / hardware keys) |

`gh` and `openssh-client` are installed in the image, so `git commit` /
`git push` (HTTPS or SSH) and private `cargo` git dependencies work inside
`make shell` exactly as on the host. Notes:

- Every path in the table must exist on the host or the bind mount fails;
  `touch ~/.git-credentials` / `mkdir -p ~/.config/gh` if you don't use them.
- Start the agent and `ssh-add` your key **before** `make up`; the socket path
  is captured when the container is created. Without an agent, ssh falls back
  to the key files in `~/.ssh`.
- `~/.ssh` is read-only, so ssh cannot append to `known_hosts` for hosts you
  have never connected to from the host. Connect once from the host first.
- GPG commit signing is not set up in the image.

### Tools inside the container

Besides the ROS 2 / Rust / Python toolchains, the image ships `tmux`, `git`,
`gh`, `mise` and the **Claude Code CLI** (`claude`). Your host `~/.claude` and
`~/.claude.json` are mounted read-write, so `claude` inside `make shell` is
already logged in and shares settings, plugins and memory with the host.
`mise` is activated in interactive shells and trusts the repo's `mise.toml`;
run `mise install` once to fetch pre-commit and the linters (they persist in
the `drone-sitl-mise` volume). `mise.toml` must never pin python or rust — the
system Python belongs to ROS 2 and Rust comes from `rust-toolchain.toml`.

## Status

Early scaffolding. The specification is drafted; components are implemented
against the milestones in [`docs/specs/overview.md`](docs/specs/overview.md).
