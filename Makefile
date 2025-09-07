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
BACKEND_WORKLOAD_NAME = backend
BACKEND_CONTAINER_NAME = backend
BACKEND_CONTAINER_IMAGE = ${BACKEND_CONTAINER_NAME}:local
FRONTEND_WORKLOAD_NAME = frontend
FRONTEND_CONTAINER_NAME = frontend
FRONTEND_CONTAINER_IMAGE = ${FRONTEND_CONTAINER_NAME}:local

## Build new backstage:local container image and run it with light Score files.
.PHONY: build-and-run-monolith-light
build-and-run-monolith-light:
	score-compose init \
		--no-sample \
		--patch-templates https://raw.githubusercontent.com/score-spec/community-patchers/refs/heads/main/score-compose/unprivileged.tpl
	score-compose generate score.light.yaml \
    	--build 'backstage={"context":".","tags":["backstage:local"]}' \
		--override-property containers.backstage.variables.APP_CONFIG_app_title="Hello, Compose!" \
		--publish 7007:backstage:8080
	docker compose up --build -d --remove-orphans

## Run backstage:local container images with light Score files.
.PHONY: run-monolith-light
run-monolith-light:
	score-compose init \
		--no-sample \
		--patch-templates https://raw.githubusercontent.com/score-spec/community-patchers/refs/heads/main/score-compose/unprivileged.tpl
	score-compose generate score.light.yaml \
    	--image backstage:local \
		--override-property containers.backstage.variables.APP_CONFIG_app_title="Hello, Compose!" \
		--publish 7007:backstage:8080
	docker compose up -d --remove-orphans

compose-monolith-state:
	score-compose init \
		--no-sample \
		--patch-templates https://raw.githubusercontent.com/score-spec/community-patchers/refs/heads/main/score-compose/unprivileged.tpl \
		--provisioners https://raw.githubusercontent.com/score-spec/community-provisioners/refs/heads/main/dns/score-compose/10-dns-with-url.provisioners.yaml

compose-monolith: score-backend.yaml score.yaml compose-monolith-state Makefile
	score-compose generate score.yaml \
		--build '${MONOLITH_CONTAINER_NAME}={"context":".","tags":["${MONOLITH_CONTAINER_IMAGE}"]}' \
		--override-property containers.${MONOLITH_CONTAINER_NAME}.variables.APP_CONFIG_app_title="Hello, Compose!"

## Generate a compose.yaml file from the score spec and launch it.
.PHONY: compose-monolith-up
compose-monolith-up: compose-monolith
	docker compose up --build -d --remove-orphans
	sleep 5

## Generate a compose.yaml file from the score spec, launch it and test (curl) the exposed container.
.PHONY: compose-monolith-test
compose-monolith-test: compose-monolith-up
	docker ps --all
	curl -v localhost:8080 \
		-H "Host: $$(score-compose resources get-outputs dns.default#dns --format '{{ .host }}')" \
		| grep "<title>Scaffolded Backstage App</title>"

## Remove the frontend from the backend.
.PHONY: remove-frontend-from-backend
remove-frontend-from-backend:
	sed '/plugin-app-backend/d' -i packages/backend/src/index.ts
	sed '/"app": "link:../d' -i packages/backend/package.json
	yarn install

## Build new backend:local and frontent:local container images and run them with light Score files.
.PHONY: build-and-run-split-light
build-and-run-split-light:
	score-compose init \
		--no-sample \
		--patch-templates https://raw.githubusercontent.com/score-spec/community-patchers/refs/heads/main/score-compose/unprivileged.tpl \
		--provisioners https://raw.githubusercontent.com/score-spec/community-provisioners/refs/heads/main/service/score-compose/10-service.provisioners.yaml
	score-compose generate score-backend.light.yaml \
    	--build 'backend={"context":".","tags":["backend:local"]}'
	score-compose generate score-frontend.light.yaml \
		--build 'frontend={"context":".","dockerfile":"Dockerfile.frontend","tags":["frontend:local"]}' \
		--override-property containers.frontend.variables.APP_CONFIG_app_title="Hello, Compose!" \
		--publish 7007:backend:7007 \
		--publish 3000:frontend:8080
	sudo yq e -i '.services.frontend-frontend.read_only = false' compose.yaml
	docker compose up --build -d --remove-orphans

## Run both backend:local and frontent:local container images with light Score files.
.PHONY: run-split-light
run-split-light:
	score-compose init \
		--no-sample \
		--patch-templates https://raw.githubusercontent.com/score-spec/community-patchers/refs/heads/main/score-compose/unprivileged.tpl \
		--provisioners https://raw.githubusercontent.com/score-spec/community-provisioners/refs/heads/main/service/score-compose/10-service.provisioners.yaml
	score-compose generate score-backend.light.yaml \
    	--image backend:local
	score-compose generate score-frontend.light.yaml \
		--image frontend:local \
		--override-property containers.frontend.variables.APP_CONFIG_app_title="Hello, Compose!" \
		--publish 7007:backend:7007 \
		--publish 3000:frontend:8080
	sudo yq e -i '.services.frontend-frontend.read_only = false' compose.yaml
	docker compose up -d --remove-orphans

compose-split-state:
	score-compose init \
		--no-sample \
		--patch-templates https://raw.githubusercontent.com/score-spec/community-patchers/refs/heads/main/score-compose/unprivileged.tpl \
		--provisioners https://raw.githubusercontent.com/score-spec/community-provisioners/refs/heads/main/service/score-compose/10-service.provisioners.yaml \
		--provisioners https://raw.githubusercontent.com/score-spec/community-provisioners/refs/heads/main/dns/score-compose/10-dns-with-url.provisioners.yaml

compose-split: score-backend.yaml score-frontend.yaml compose-split-state Makefile
	score-compose generate score-backend.yaml \
		--build '${BACKEND_CONTAINER_NAME}={"context":".","tags":["${BACKEND_CONTAINER_IMAGE}"]}'
	score-compose generate score-frontend.yaml \
		--build '${FRONTEND_CONTAINER_NAME}={"context":".","dockerfile":"Dockerfile.frontend","tags":["${FRONTEND_CONTAINER_IMAGE}"]}' \
		--override-property containers.${FRONTEND_CONTAINER_NAME}.variables.APP_CONFIG_app_title="Hello, Compose!"
	sudo yq e -i '.services.${FRONTEND_WORKLOAD_NAME}-${FRONTEND_CONTAINER_NAME}.read_only = false' compose.yaml

## Generate a compose.yaml file from the score spec and launch it.
.PHONY: compose-split-up
compose-split-up: compose-split
	docker compose up --build -d --remove-orphans
	sleep 5

## Generate a compose.yaml file from the score spec, launch it and test (curl) the exposed container.
.PHONY: compose-split-test
compose-split-test: compose-split-up
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

## Load the local backend and frontend container images in the current Kind cluster.
.PHONY: kind-load-split-images
kind-load-split-images:
	kind load docker-image ${BACKEND_CONTAINER_IMAGE}
	kind load docker-image ${FRONTEND_CONTAINER_IMAGE}

## Load the local backstage container image in the current Kind cluster.
.PHONY: kind-load-monolith-image
kind-load-monolith-image:
	kind load docker-image ${MONOLITH_CONTAINER_IMAGE}

NAMESPACE ?= test

k8s-split-state:
	score-k8s init \
		--no-sample \
		--patch-templates https://raw.githubusercontent.com/score-spec/community-patchers/refs/heads/main/score-k8s/unprivileged.tpl \
		--patch-templates https://raw.githubusercontent.com/score-spec/community-patchers/refs/heads/main/score-k8s/namespace-pss-restricted.tpl \
		--provisioners https://raw.githubusercontent.com/score-spec/community-provisioners/refs/heads/main/service/score-k8s/10-service.provisioners.yaml \
		--provisioners https://raw.githubusercontent.com/score-spec/community-provisioners/refs/heads/main/dns/score-k8s/10-dns-with-url.provisioners.yaml \
		--provisioners https://raw.githubusercontent.com/score-spec/community-provisioners/refs/heads/main/route/score-k8s/10-shared-gateway-httproute.provisioners.yaml

k8s-split-manifests: score-backend.yaml score-frontend.yaml k8s-split-state Makefile
	score-k8s generate score-backend.yaml \
		--image ${BACKEND_CONTAINER_IMAGE}
	score-k8s generate score-frontend.yaml \
		--namespace ${NAMESPACE} \
		--generate-namespace \
		--image ${FRONTEND_CONTAINER_IMAGE} \
		--override-property containers.${FRONTEND_CONTAINER_NAME}.variables.APP_CONFIG_app_title="Hello, Kubernetes!"
	yq e -i 'select(.kind == "Deployment" and .metadata.name == "frontend").spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem = false' manifests.yaml
	yq e -i 'select(.kind == "Deployment" and .metadata.name == "frontend").spec.template.spec.securityContext.runAsUser = 101' manifests.yaml

## Generate a manifests.yaml file from the score spec, deploy it to Kubernetes and wait for the Pods to be Ready.
.PHONY: k8s-split-up
k8s-split-up: k8s-split-manifests
	kubectl apply \
		-f manifests.yaml
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
.PHONY: k8s-split-test
k8s-split-test: k8s-split-up
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

## Generate catalog-info.yaml for Backstage.
.PHONY: generate-catalog-info
generate-catalog-info:
	score-k8s init \
		--no-sample \
		--provisioners https://raw.githubusercontent.com/score-spec/community-provisioners/refs/heads/main/service/score-k8s/10-service.provisioners.yaml \
  		--provisioners https://raw.githubusercontent.com/score-spec/community-provisioners/refs/heads/main/dns/score-k8s/10-dns-with-url.provisioners.yaml \
		--patch-templates https://raw.githubusercontent.com/score-spec/community-patchers/refs/heads/main/score-k8s/backstage-catalog-entities.tpl
	score-k8s generate score-backend.yaml \
		--namespace backstage \
		--image ghcr.io/mathieu-benoit/backstage-frontend:latest \
		--output catalog-info.yaml
	score-k8s generate score-frontend.yaml \
  		--namespace backstage \
 		--generate-namespace \
  		--image ghcr.io/mathieu-benoit/backstage-backend:latest \
  		--output catalog-info.yaml
	sed 's,$$GITHUB_REPO,mathieu-benoit/deploy-backstage-with-score,g' -i catalog-info.yaml
