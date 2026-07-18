# Drone SITL — developer workflow entrypoints.
# Most targets run inside the Podman dev container defined in compose.yaml.
#
#   make help        # list targets
#   make up          # build image + start the dev container
#   make shell       # open a shell inside it
#   make build       # colcon build the ROS 2 workspace
#   make sim         # launch Gazebo + PX4 SITL
#   make run         # bring up the full ROS 2 stack
#   make test        # run tests
#   make fmt lint    # format / lint Rust + Python
#   make down clean  # stop container / remove build artifacts

# Run a command inside the dev service. Override to run locally: `make EXEC= build`
COMPOSE ?= podman compose
EXEC     ?= $(COMPOSE) exec -T dev
WS       ?= ros2_ws

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z0-9_.-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

# --- Environment ----------------------------------------------------------
.PHONY: image up down shell
image: ## Build the dev/sim container image
	$(COMPOSE) build

up: image ## Start the dev container in the background
	$(COMPOSE) up -d dev

down: ## Stop and remove the dev container
	$(COMPOSE) down

shell: ## Open an interactive shell in the dev container
	$(COMPOSE) exec dev bash

# --- Build ----------------------------------------------------------------
.PHONY: build
build: ## colcon build the ROS 2 workspace
	$(EXEC) bash -lc 'cd $(WS) && colcon build --symlink-install'

# --- Run ------------------------------------------------------------------
.PHONY: sim run mission
sim: ## Launch Gazebo + PX4 SITL
	$(EXEC) bash -lc 'ros2 launch drone_bringup sim.launch.py'

run: ## Bring up the full ROS 2 stack (sim + perception + estimation)
	$(EXEC) bash -lc 'ros2 launch drone_bringup bringup.launch.py'

mission: ## Run a demo mission (with GNSS-loss scenario)
	$(EXEC) bash -lc 'ros2 launch drone_mission demo_mission.launch.py'

# --- Quality --------------------------------------------------------------
.PHONY: test fmt lint
test: ## Run Rust + Python + ROS 2 tests
	$(EXEC) bash -lc 'cd $(WS) && colcon test && colcon test-result --verbose'

fmt: ## Format Rust (cargo fmt) and Python (ruff format)
	$(EXEC) bash -lc 'cd $(WS) && cargo fmt --all 2>/dev/null; ruff format .'

lint: ## Lint Rust (clippy) and Python (ruff)
	$(EXEC) bash -lc 'cd $(WS) && cargo clippy --all-targets 2>/dev/null; ruff check .'

# --- Housekeeping ---------------------------------------------------------
.PHONY: clean
clean: ## Remove ROS 2 / cargo build artifacts
	$(EXEC) bash -lc 'cd $(WS) && rm -rf build install log && cargo clean 2>/dev/null || true'
