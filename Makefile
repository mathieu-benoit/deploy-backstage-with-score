# Disable all the default make stuff
MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

## Display a list of the documented make targets
.PHONY: help
help:
	@echo Documented Make targets:
	@perl -e 'undef $$/; while (<>) { while ($$_ =~ /## (.*?)(?:\n# .*)*\n.PHONY:\s+(\S+).*/mg) { printf "\033[36m%-30s\033[0m %s\n", $$2, $$1 } }' $(MAKEFILE_LIST) | sort

.PHONY: .FORCE
.FORCE:

BACKEND_WORKLOAD_NAME = backend
BACKEND_CONTAINER_NAME = backend
BACKEND_CONTAINER_IMAGE = ${BACKEND_CONTAINER_NAME}:local
FRONTEND_WORKLOAD_NAME = frontend
FRONTEND_CONTAINER_NAME = frontend
FRONTEND_CONTAINER_IMAGE = ${FRONTEND_CONTAINER_NAME}:local

.score-compose/state.yaml:
	score-compose init \
		--no-sample \
		--provisioners https://raw.githubusercontent.com/score-spec/community-provisioners/refs/heads/main/dns/score-compose/10-dns-with-url.provisioners.yaml

compose.yaml: score-backend.yaml score-frontend.yaml .score-compose/state.yaml Makefile
	score-compose generate score-backend.yaml \
		--build '${BACKEND_CONTAINER_NAME}={"context":".","tags":["${BACKEND_CONTAINER_IMAGE}"]}'
	score-compose generate score-frontend.yaml \
		--build '${FRONTEND_CONTAINER_NAME}={"context":".","dockerfile":"Dockerfile.frontend","tags":["${FRONTEND_CONTAINER_IMAGE}"]}' \
		--override-property containers.${FRONTEND_CONTAINER_NAME}.variables.APP_CONFIG_app_title="Hello, Compose!"

## Generate a compose.yaml file from the score spec and launch it.
.PHONY: compose-up
compose-up: compose.yaml
	docker compose up --build -d --remove-orphans
	sleep 5

## Generate a compose.yaml file from the score spec, launch it and test (curl) the exposed container.
.PHONY: compose-test
compose-test: compose-up
	docker ps --all
	curl -v localhost:8080 \
		-H "Host: $$(score-compose resources get-outputs dns.default#dns --format '{{ .host }}')" \
		| grep "<title>Scaffolded Backstage App</title>"

## Delete the containers running via compose down.
.PHONY: compose-down
compose-down:
	docker compose down -v --remove-orphans || true

## Delete the .score-compose directory and compose.yaml file.
.PHONY: cleanup-compose
cleanup-compose: compose-down
	rm -rf .score-compose
	rm compose.yaml

## Create a local Kind cluster.
.PHONY: kind-create-cluster
kind-create-cluster:
	./scripts/setup-kind-cluster.sh

## Load the local container images in the current Kind cluster.
.PHONY: kind-load-images
kind-load-images:
	kind load docker-image ${BACKEND_CONTAINER_IMAGE}
	kind load docker-image ${FRONTEND_CONTAINER_IMAGE}

NAMESPACE ?= default

.score-k8s/state.yaml:
	score-k8s init \
		--no-sample \
		--provisioners https://raw.githubusercontent.com/score-spec/community-provisioners/refs/heads/main/dns/score-k8s/10-dns-with-url.provisioners.yaml

manifests.yaml: score-backend.yaml score-frontend.yaml .score-k8s/state.yaml Makefile
	score-k8s generate score-backend.yaml \
		--image ${BACKEND_CONTAINER_IMAGE}
	score-k8s generate score-frontend.yaml \
		--image ${FRONTEND_CONTAINER_IMAGE} \
		--override-property containers.${FRONTEND_CONTAINER_NAME}.variables.APP_CONFIG_app_title="Hello, Kubernetes!"

## Generate a manifests.yaml file from the score spec, deploy it to Kubernetes and wait for the Pods to be Ready.
.PHONY: k8s-up
k8s-up: manifests.yaml
	kubectl apply \
		-f manifests.yaml \
		-n ${NAMESPACE}
	kubectl wait deployments/${BACKEND_WORKLOAD_NAME} \
		-n ${NAMESPACE} \
		--for condition=Available \
		--timeout=90s
	kubectl wait deployments/${FRONTEND_WORKLOAD_NAME} \
		-n ${NAMESPACE} \
		--for condition=Available \
		--timeout=90s
	kubectl wait pods \
		-n ${NAMESPACE} \
		-l app.kubernetes.io/managed-by=score-k8s \
		--for condition=Ready \
		--timeout=90s
	sleep 5

## Expose the container deployed in Kubernetes via port-forward.
.PHONY: k8s-test
k8s-test: k8s-up
	sleep 5
	kubectl get all,httproute \
		-n ${NAMESPACE}
	kubectl logs \
		-l app.kubernetes.io/name=${BACKEND_WORKLOAD_NAME} \
		-n ${NAMESPACE}
	kubectl logs \
		-l app.kubernetes.io/name=${FRONTEND_WORKLOAD_NAME} \
		-n ${NAMESPACE}
	curl -v localhost:80 \
		-H "Host: $$(score-k8s resources get-outputs dns.default#dns --format '{{ .host }}')" \
		| grep "<title>Scaffolded Backstage App</title>"

## Delete the deployment of the local container in Kubernetes.
.PHONY: k8s-down
k8s-down:
	kubectl delete \
		-f manifests.yaml \
		-n ${NAMESPACE}
