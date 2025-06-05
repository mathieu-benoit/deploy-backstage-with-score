# [Backstage](https://backstage.io)

This Backstage application is used as part of this blog post [Deploy Backstage with Score, from local to Kubernetes](https://medium.com/@mabenoit/deploy-backstage-with-score-45bb2d7c2d90).

## Local with `yarn`

To start the app, run:

```sh
yarn install
yarn start
```

Then navigate to http://localhost:3000.

## Local with `docker`/`podman`

### By building a new container image

```sh
docker image build -t backstage:local .

docker run -it \
    -e APP_CONFIG_backend_database_client='better-sqlite3' \
    -e APP_CONFIG_backend_database_connection=':memory:' \
    -p 7007:7007 \
    backstage:local
```

### By using the pre-built container image

```sh
docker run -it \
    -e APP_CONFIG_backend_database_client='better-sqlite3' \
    -e APP_CONFIG_backend_database_connection=':memory:' \
    -p 7007:7007 \
    docker pull ghcr.io/mathieu-benoit/backstage:latest
```

Then navigate to http://localhost:7007.

## Local with `score-compose`

```bash
score-compose init \
    --no-sample \
    --patch-templates https://raw.githubusercontent.com/score-spec/community-patchers/refs/heads/main/score-compose/unprivileged.tpl \
    --provisioners https://raw.githubusercontent.com/score-spec/community-provisioners/refs/heads/main/dns/score-compose/10-dns-with-url.provisioners.yaml
```

### By building a new container image

```bash
score-compose generate score.yaml \
    --build 'backstage={"context":".","tags":["backstage:local"]}'
```

### By using the pre-built container image

```bash
score-compose generate score.yaml \
    --image ghcr.io/mathieu-benoit/backstage:latest
```

```bash
docker compose up -d
```

Then navigate to http://localhost:7007.

## Local with `score-k8s`

```bash
score-k8s init \
    --no-sample \
    --patch-templates https://raw.githubusercontent.com/score-spec/community-patchers/refs/heads/main/score-k8s/unprivileged.tpl \
    --provisioners https://raw.githubusercontent.com/score-spec/community-provisioners/refs/heads/main/dns/score-k8s/10-dns-with-url.provisioners.yaml
```

### By using the locally built container image

```bash
kind load docker-image backstage:local

score-k8s generate score.yaml \
    --image backstage:local
```

### By using the pre-built container image

```bash
score-k8s generate score.yaml \
    --image ghcr.io/mathieu-benoit/backstage:latest
```

```bash
kubectl apply -f manifests.yaml
```

Then navigate to http://localhost:7007.
