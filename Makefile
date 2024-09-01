# Define the UV binary path and the virtual environment directory
UV_BIN := $(HOME)/.cargo/bin/uv
VENV_DIR := .venv

COMPOSE_PROJECT_NAME := spark-cluster

# Define the local directory to mount
LOCAL_SPARK_DIR := $(shell pwd)/spark_scripts

# Determine the correct Docker Compose command
DOCKER_COMPOSE := $(shell command -v docker-compose 2> /dev/null || echo "docker compose")


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
	rm -rf $(VENV_DIR) requirements.txt logs target spark_scripts dbt_packages
	docker-compose.yml down -v

spark-up:
	mkdir -p $(LOCAL_SPARK_DIR)
	@echo "Using Docker Compose command: $(DOCKER_COMPOSE)"
	$(DOCKER_COMPOSE) up -d
	@echo "Waiting for services to start..."
	@sleep 10
	$(DOCKER_COMPOSE) exec spark-master bash -c "netstat -tulpn | grep 10000" || echo "Warning: Thrift server may not have started correctly"

# Stop the Spark cluster
spark-down:
	$(DOCKER_COMPOSE) down

# Open a Spark shell
spark-shell:
	$(DOCKER_COMPOSE) exec spark-master /opt/spark/bin/spark-shell

# Open a PySpark shell
pyspark:
	$(DOCKER_COMPOSE) exec spark-master /opt/spark/bin/pyspark

# Run a local PySpark script
spark-run:
	@if [ -z "$(SCRIPT)" ]; then \
		echo "Error: SCRIPT variable is not set. Usage: make spark-run SCRIPT=path/to/your/script.py"; \
		exit 1; \
	fi
	@if [ ! -f "$(SCRIPT)" ]; then \
		echo "Error: Script file $(SCRIPT) not found."; \
		exit 1; \
	fi
	$(DOCKER_COMPOSE) exec spark-master /opt/spark/bin/spark-submit /opt/spark/work-dir/$(notdir $(SCRIPT))

# Run a Spark job (example)
spark-run-job:
	$(DOCKER_COMPOSE) exec spark-master /opt/spark/bin/spark-submit --class org.apache.spark.examples.SparkPi \
		--master spark://spark-master:7077 \
		/opt/spark/examples/jars/spark-examples_*.jar \
		10

docs:
	dbt docs generate 
	dbt docs serve

# Help command to display available targets
help:
	@echo "Usage:"
	@echo "  make            Create the virtual environment and install dependencies"
	@echo "  make clean      Remove the virtual environment, requirements.txt, and stop Docker containers"
	@echo "  make spark-up   Start the Spark cluster using Docker Compose"
	@echo "  make spark-down Stop the Spark cluster"
	@echo "  make spark-shell Open a Spark shell in the master container"
	@echo "  make pyspark    Open a PySpark shell in the master container"
	@echo "  make spark-run SCRIPT=path/to/your/script.py  Run a local PySpark script"
	@echo "  make spark-run-job Run an example Spark job (calculate Pi)"
	@echo "  make help       Show this help message"

.PHONY: all clean help spark-up spark-down spark-shell pyspark spark-run spark-run-job