APP_NAME := hello
IMAGE_NAME := $(APP_NAME):latest
NAMESPACE := default
KIND_CLUSTER := my-cluster

help: ## Show help message
	@echo "Available make commands:"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build Docker image locally
	docker build -t $(IMAGE_NAME) .

apply: ## Apply Kubernetes manifests
	kubectl apply -k k8s/

delete: ## Delete Kubernetes manifests
	kubectl delete -k k8s/

logs: ## Show logs from hello pod
	kubectl logs deploy/$(APP_NAME)

port-forward: ## Port forward localhost:8080 to service/hello:80
	@echo "🚪 Forwarding port 8080 -> service/$(APP_NAME):80"
	kubectl port-forward svc/$(APP_NAME) 8080:80

test: ## Run unit tests with pytest
	pytest

kind-create: ## Create kind cluster if not exists
	@if ! kind get clusters | grep -q "^$(KIND_CLUSTER)$$"; then \
		echo "🧱 Creating kind cluster '$(KIND_CLUSTER)'..."; \
		kind create cluster --name $(KIND_CLUSTER); \
	else \
		echo "✅ Kind cluster '$(KIND_CLUSTER)' already exists."; \
	fi

kind-delete: ## Delete the kind cluster
	@echo "🧨 Deleting kind cluster '$(KIND_CLUSTER)'..."
	kind delete cluster --name $(KIND_CLUSTER)

wait-ready: ## Wait for hello pod to become Ready
	@echo "⏳ Waiting for pod to be Ready..."
	@kubectl wait --for=condition=Ready pod -l app=$(APP_NAME) --timeout=60s

test-e2e: ## Run end-to-end test with curl against localhost:8080
	@echo "🧪 Running E2E test on http://localhost:8080 ..."
	@sleep 2
	@curl -s http://localhost:8080 | grep -q "Hello, World!" && \
		echo "✅ E2E test passed!" || \
		(echo "❌ E2E test failed!" && exit 1)

kind-deploy: kind-create build ## Build image, load to kind, deploy, test
	@echo "📦 Loading Docker image into kind..."
	kind load docker-image $(IMAGE_NAME) --name $(KIND_CLUSTER)
	@echo "🚀 Applying Kubernetes manifests..."
	kubectl apply -k k8s/
	$(MAKE) wait-ready
	$(MAKE) port-forward & \
	sleep 3 && \
	$(MAKE) test-e2e

kind-restart: kind-delete kind-deploy ## Delete and redeploy kind cluster
