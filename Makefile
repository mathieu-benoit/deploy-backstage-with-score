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

MONOLITH_WORKLOAD_NAME = backstage
MONOLITH_CONTAINER_NAME = backstage
MONOLITH_CONTAINER_IMAGE = ${MONOLITH_CONTAINER_NAME}:local

## Generate a compose.yaml file from the score spec and launch it.
.PHONY: monolith-compose-up
monolith-compose-up: score.yaml .score-compose/state.yaml Makefile
	score-compose init \
		--no-sample \
		--patch-templates https://raw.githubusercontent.com/score-spec/community-patchers/refs/heads/main/score-compose/unprivileged.tpl \
		--provisioners https://raw.githubusercontent.com/score-spec/community-provisioners/refs/heads/main/dns/score-compose/10-dns-with-url.provisioners.yaml
	score-compose generate score.yaml \
		--build '${MONOLITH_CONTAINER_NAME}={"context":".","tags":["${MONOLITH_CONTAINER_IMAGE}"]}' \
		--override-property containers.${MONOLITH_CONTAINER_NAME}.variables.APP_CONFIG_app_title="Hello, Compose!"
	docker compose up --build -d --remove-orphans
	sleep 5

## Generate a compose.yaml file from the score spec, launch it and test (curl) the exposed container.
.PHONY: monolith-compose-test
monolith-compose-test: monolith-compose-up
	docker ps --all
	curl -v localhost:8080 \
		-H "Host: $$(score-compose resources get-outputs dns.default#${MONOLITH_WORKLOAD_NAME}.dns --format '{{ .host }}')" \
		| grep "<title>Hello, Compose!</title>"

BACKEND_WORKLOAD_NAME = backend
BACKEND_CONTAINER_NAME = backend
BACKEND_CONTAINER_IMAGE = ${BACKEND_CONTAINER_NAME}:local
FRONTEND_WORKLOAD_NAME = frontend
FRONTEND_CONTAINER_NAME = frontend
FRONTEND_CONTAINER_IMAGE = ${FRONTEND_CONTAINER_NAME}:local

## Delete the .score-compose directory and compose.yaml file.
.PHONY: cleanup-compose
cleanup-compose: compose-down
	rm -rf .score-compose
	rm compose.yaml

## Remove the frontend from the backend.
.PHONY: remove-frontend-from-backend
remove-frontend-from-backend:
	sed '/plugin-app-backend/d' -i packages/backend/src/index.ts
	sed '/"app": "link:../d' -i packages/backend/package.json
	yarn install

## Generate a compose.yaml file from the score spec and launch it.
.PHONY: split-compose-up
split-compose-up: score-backend.yaml score-frontend.yaml .score-compose/state.yaml Makefile
	score-compose init \
		--no-sample \
		--provisioners https://raw.githubusercontent.com/score-spec/community-provisioners/refs/heads/main/dns/score-compose/10-dns-with-url.provisioners.yaml
	score-compose generate score-backend.yaml \
		--build '${BACKEND_CONTAINER_NAME}={"context":".","tags":["${BACKEND_CONTAINER_IMAGE}"]}'
	score-compose generate score-frontend.yaml \
		--build '${FRONTEND_CONTAINER_NAME}={"context":".","dockerfile":"Dockerfile.frontend","tags":["${FRONTEND_CONTAINER_IMAGE}"]}' \
		--override-property containers.${FRONTEND_CONTAINER_NAME}.variables.APP_CONFIG_app_title="Hello, Compose!"
	docker compose up --build -d --remove-orphans
	sleep 5

## Generate a compose.yaml file from the score spec, launch it and test (curl) the exposed container.
.PHONY: split-compose-test
split-compose-test: split-compose-up
	docker ps --all
	curl -v localhost:8080 \
		-H "Host: $$(score-compose resources get-outputs dns.default#dns --format '{{ .host }}')" \
		| grep "<title>Scaffolded Backstage App</title>"

## Delete the containers running via compose down.
.PHONY: compose-down
compose-down:
	docker compose down -v --remove-orphans || true

## Create a local Kind cluster.
.PHONY: kind-create-cluster
kind-create-cluster:
	./scripts/setup-kind-cluster.sh

## Load the local container image in the current Kind cluster.
.PHONY: monolith-kind-load-image
monolith-kind-load-image:
	kind load docker-image ${MONOLITH_CONTAINER_IMAGE}

## Load the local container image in the current Kind cluster.
.PHONY: split-kind-load-image
split-kind-load-image:
	kind load docker-image ${BACKEND_CONTAINER_IMAGE}
	kind load docker-image ${FRONTEND_CONTAINER_IMAGE}

NAMESPACE ?= default
## Generate a manifests.yaml file from the score spec, deploy it to Kubernetes and wait for the Pods to be Ready.
.PHONY: monolith-k8s-up
monolith-k8s-up: score.yaml .score-k8s/state.yaml Makefile
	score-k8s init \
		--no-sample \
		--patch-templates https://raw.githubusercontent.com/score-spec/community-patchers/refs/heads/main/score-k8s/unprivileged.tpl \
		--provisioners https://raw.githubusercontent.com/score-spec/community-provisioners/refs/heads/main/dns/score-k8s/10-dns-with-url.provisioners.yaml
	score-k8s generate score.yaml \
		--image ${MONOLITH_CONTAINER_IMAGE} \
		--override-property containers.${MONOLITH_CONTAINER_NAME}.variables.APP_CONFIG_app_title="Hello, Kubernetes!"
	kubectl apply \
		-f manifests.yaml \
		-n ${NAMESPACE}
	kubectl wait deployments/${MONOLITH_WORKLOAD_NAME} \
		-n ${NAMESPACE} \
		--for condition=Available \
		--timeout=90s
	kubectl wait pods \
		-n ${NAMESPACE} \
		-l app.kubernetes.io/managed-by=score-k8s \
		--for condition=Ready \
		--timeout=90s
	sleep 5

## Generate a manifests.yaml file from the score spec, deploy it to Kubernetes and wait for the Pods to be Ready.
.PHONY: split-k8s-up
split-k8s-up: score-backend.yaml score-frontend.yaml .score-k8s/state.yaml Makefile
	score-k8s init \
		--no-sample \
		--provisioners https://raw.githubusercontent.com/score-spec/community-provisioners/refs/heads/main/dns/score-k8s/10-dns-with-url.provisioners.yaml
	score-k8s generate score-backend.yaml \
		--image ${BACKEND_CONTAINER_IMAGE}
	score-k8s generate score-frontend.yaml \
		--image ${FRONTEND_CONTAINER_IMAGE} \
		--override-property containers.${FRONTEND_CONTAINER_NAME}.variables.APP_CONFIG_app_title="Hello, Kubernetes!"
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
.PHONY: split-k8s-test
split-k8s-test: split-k8s-up
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
