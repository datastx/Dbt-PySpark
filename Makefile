# Define the UV binary path and the virtual environment directory
UV_BIN := $(HOME)/.cargo/bin/uv
VENV_DIR := .venv

# Default number of workers
NUM_WORKERS ?= 2

# Spark Docker image and container name
SPARK_IMAGE := spark:3.5.2-scala2.12-java11-python3-ubuntu
CONTAINER_NAME := my-spark-container

# Define the local directory to mount
LOCAL_SPARK_DIR := $(shell pwd)/spark_scripts

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
	rm -rf $(VENV_DIR) requirements.txt pragmint/logs pragmint/target

# Start the Spark cluster with volume mount and Thrift server
spark-up:
	mkdir -p $(LOCAL_SPARK_DIR)
	docker run -d --name $(CONTAINER_NAME) \
		-p 4040:4040 -p 10000:10000 \
		-v $(LOCAL_SPARK_DIR):/opt/spark/work-dir \
		$(SPARK_IMAGE) \
		/bin/bash -c "/opt/spark/bin/spark-class org.apache.spark.deploy.master.Master -h 0.0.0.0 & sleep 5 && /opt/spark/sbin/start-thriftserver.sh & tail -f /dev/null"
	@echo "Starting $(NUM_WORKERS) worker(s)..."
	@for i in $$(seq 1 $(NUM_WORKERS)); do \
		docker run -d --name $(CONTAINER_NAME)-worker-$$i \
			--link $(CONTAINER_NAME):spark-master \
			-v $(LOCAL_SPARK_DIR):/opt/spark/work-dir \
			$(SPARK_IMAGE) \
			/opt/spark/bin/spark-class org.apache.spark.deploy.worker.Worker spark://spark-master:7077; \
	done
	@echo "Waiting for Thrift server to start..."
	@sleep 10
	@docker exec $(CONTAINER_NAME) netstat -tulpn | grep 10000 || echo "Warning: Thrift server may not have started correctly"

# Stop the Spark cluster
spark-down:
	@echo "Stopping Spark cluster..."
	@docker stop $(CONTAINER_NAME) || true
	@docker rm $(CONTAINER_NAME) || true
	@for i in $$(seq 1 $(NUM_WORKERS)); do \
		docker stop $(CONTAINER_NAME)-worker-$$i || true; \
		docker rm $(CONTAINER_NAME)-worker-$$i || true; \
	done

# Open a Spark shell
spark-shell:
	docker exec -it $(CONTAINER_NAME) /opt/spark/bin/spark-shell

# Open a PySpark shell
pyspark:
	docker exec -it $(CONTAINER_NAME) /opt/spark/bin/pyspark

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
	docker exec -it $(CONTAINER_NAME) /opt/spark/bin/spark-submit /opt/spark/work-dir/$(notdir $(SCRIPT))

# Run a Spark job (example)
spark-run-job:
	docker exec -it $(CONTAINER_NAME) /opt/spark/bin/spark-submit --class org.apache.spark.examples.SparkPi \
		--master local[*] \
		/opt/spark/examples/jars/spark-examples_*.jar \
		10

# Help command to display available targets
help:
	@echo "Usage:"
	@echo "  make            Create the virtual environment and install dependencies"
	@echo "  make clean      Remove the virtual environment and requirements.txt"
	@echo "  make spark-up   Start the Spark cluster with the specified number of workers (default: 2)"
	@echo "                  Example: make spark-up NUM_WORKERS=3"
	@echo "  make spark-down Stop the Spark cluster"
	@echo "  make spark-shell Open a Spark shell in the master container"
	@echo "  make pyspark    Open a PySpark shell in the master container"
	@echo "  make spark-run SCRIPT=path/to/your/script.py  Run a local PySpark script"
	@echo "  make spark-run-job Run an example Spark job (calculate Pi)"
	@echo "  make help       Show this help message"

.PHONY: all clean help spark-up spark-down spark-shell pyspark spark-run spark-run-job