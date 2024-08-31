# Define the UV binary path and the virtual environment directory
UV_BIN := $(HOME)/.cargo/bin/uv
VENV_DIR := .venv

# Check if the UV binary exists
.PHONY: uv
uv:
	@if [ ! -f $(UV_BIN) ]; then \
		curl -LsSf https://astral.sh/uv/install.sh | sh; \
		echo "Make sure to add $$(dirname $(UV_BIN)) to your PATH or source the environment:"; \
		echo "  source $$HOME/.cargo/env (sh, bash, zsh)"; \
		echo "  source $$HOME/.cargo/env.fish (fish)"; \
	fi

# Install dependencies and create a requirements.txt from requirements.in
requirements.txt: requirements.in uv
	$(UV_BIN) pip compile requirements.in -o requirements.txt

# Create a virtual environment and install the dependencies
.PHONY: venv
venv: uv requirements.txt
	@if [ ! -d $(VENV_DIR) ]; then \
		$(UV_BIN) venv $(VENV_DIR); \
	fi
	# Check if pip exists, if not use python to install pip
	@if [ ! -f $(VENV_DIR)/bin/pip ]; then \
		$(VENV_DIR)/bin/python -m ensurepip; \
		$(VENV_DIR)/bin/python -m pip install --upgrade pip setuptools; \
	fi
	$(VENV_DIR)/bin/pip install -r requirements.txt

# Default target that ensures everything is set up
all: venv

# Clean up the virtual environment and requirements.txt
clean:
	rm -rf $(VENV_DIR) requirements.txt

# Help command to display available targets
help:
	@echo "Usage:"
	@echo "  make            Create the virtual environment and install dependencies"
	@echo "  make clean      Remove the virtual environment and requirements.txt"
	@echo "  make help       Show this help message"

.PHONY: all clean help
