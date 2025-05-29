# [Backstage](https://backstage.io)

This is your newly scaffolded Backstage App, Good Luck!

## Local

To start the app, run:

```sh
yarn install
yarn start
```

Then navigate to http://localhost:3000.

## Local with `score-compose`

```bash
score-compose init \
    --no-sample \
    --patch-templates https://raw.githubusercontent.com/score-spec/community-patchers/refs/heads/main/score-compose/unprivileged.tpl
```

### By building a new container image

```bash
score-compose generate score.yaml \
    --build 'backstage={"context":".","tags":["backstage:local"]}' \
    --publish 7007:backstage:7007
```

### By using the pre-built container image

```bash
score-compose generate score.yaml \
    --image ghcr.io/mathieu-benoit/backstage:latest \
    --publish 7007:backstage:7007
```

```bash
docker compose up -d
```

Then navigate to http://localhost:7007.

## Local with `score-k8s`

```bash
score-k8s init \
    --no-sample \
    --patch-templates https://raw.githubusercontent.com/score-spec/community-patchers/refs/heads/main/score-k8s/unprivileged.tpl
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

kubectl port-forward svc/backstage 7007:7007
```

Then navigate to http://localhost:7007.
