APP_NAME := hello
IMAGE_NAME := $(APP_NAME):latest
NAMESPACE := default
KIND_CLUSTER := my-cluster

.PHONY: build apply delete logs port-forward test \
        kind-create kind-deploy kind-delete kind-restart wait-ready test-e2e

build:
	docker build -t $(IMAGE_NAME) .

apply:
	kubectl apply -k k8s/

delete:
	kubectl delete -k k8s/

logs:
	kubectl logs deploy/$(APP_NAME)

port-forward:
	@echo "🚪 Forwarding port 8080 -> service/$(APP_NAME):80"
	kubectl port-forward svc/$(APP_NAME) 8080:80

test:
	pytest

kind-create:
	@if ! kind get clusters | grep -q "^$(KIND_CLUSTER)$$"; then \
		echo "🧱 Creating kind cluster '$(KIND_CLUSTER)'..."; \
		kind create cluster --name $(KIND_CLUSTER); \
	else \
		echo "✅ Kind cluster '$(KIND_CLUSTER)' already exists."; \
	fi

kind-delete:
	@echo "🧨 Deleting kind cluster '$(KIND_CLUSTER)'..."
	kind delete cluster --name $(KIND_CLUSTER)

wait-ready:
	@echo "⏳ Waiting for pod to be Ready..."
	@kubectl wait --for=condition=Ready pod -l app=$(APP_NAME) --timeout=60s

test-e2e:
	@echo "🧪 Running E2E test on http://localhost:8080 ..."
	@sleep 2
	@curl -s http://localhost:8080 | grep -q "Hello, World!" && \
		echo "✅ E2E test passed!" || \
		(echo "❌ E2E test failed!" && exit 1)

kind-deploy: kind-create build
	@echo "📦 Loading Docker image into kind..."
	kind load docker-image $(IMAGE_NAME) --name $(KIND_CLUSTER)
	@echo "🚀 Applying Kubernetes manifests..."
	kubectl apply -k k8s/
	$(MAKE) wait-ready
	$(MAKE) port-forward & \
	sleep 3 && \
	$(MAKE) test-e2e

kind-restart: kind-delete kind-deploy
