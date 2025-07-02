This [Backstage](https://backstage.io) application is used as part of this blog post [Deploy Backstage with Score, from local to Kubernetes](https://medium.com/@mabenoit/deploy-backstage-with-score-45bb2d7c2d90).

You can deploy this Backstage application in different ways:
- [With `yarn`](#with-yarn)
- [With `docker`/`podman`](#with-dockerpodman)
- [With `score-compose`](#with-score-compose)
- [More advanced](#more-advanced)

## With `yarn`

To start the app, run:

```sh
yarn install
yarn start
```

Then navigate to http://localhost:3000.

## With `docker`/`podman`

### By building new container images

```sh
docker image build -t backstage-backend:local .

docker run -it \
    -e APP_CONFIG_backend_database_client='better-sqlite3' \
    -e APP_CONFIG_backend_database_connection=':memory:' \
    -p 7007:7007 \
    backstage-backend:local


docker image build -f Dockerfile.frontend -t backstage-frontend:local .

docker run -it \
    -p 3000:8080 \
    backstage-frontend:local
```

### By using the pre-built container image

```sh
docker run -it \
    -e APP_CONFIG_backend_database_client='better-sqlite3' \
    -e APP_CONFIG_backend_database_connection=':memory:' \
    -p 7007:7007 \
    ghcr.io/mathieu-benoit/backstage-backend:latest

docker run -it \
    -p 3000:8080 \
    ghcr.io/mathieu-benoit/backstage-frontend:latest
```

Then navigate to http://localhost:7007.

## With `score-compose`

```bash
score-compose init --no-sample
```

### By building a new container image

```bash
score-compose generate score-backend.light.yaml \
    --build 'backend={"context":".","tags":["backstage-backend:local"]}'

score-compose generate score-frontend.light.yaml \
    --build 'frontend={"context":".","dockerfile":"Dockerfile.frontend","tags":["backstage-frontend:local"]}' \
    --publish 7007:backend:7007 \
    --publish 3000:frontend:8080
```

```bash
docker compose up --build -d
```

### By using the pre-built container image

```bash
score-compose generate score-backend.light.yaml \
    --image ghcr.io/mathieu-benoit/backstage-backend:latest

score-compose generate score-frontend.light.yaml \
    --image ghcr.io/mathieu-benoit/backstage-frontend:latest \
    --publish 7007:backend:7007 \
    --publish 3000:frontend:8080
```

```bash
docker compose up -d
```

Then navigate to http://localhost:7007.

## More advanced with `score-compose` and `score-k8s`

For more advanced setup, follow this blog post: [Deploy Backstage with Score, from local to Kubernetes](https://medium.com/@mabenoit/deploy-backstage-with-score-45bb2d7c2d90).
