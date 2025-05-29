# [Backstage](https://backstage.io)

This is your newly scaffolded Backstage App, Good Luck!

## Local

To start the app, run:

```sh
yarn install
yarn start
```

## Local with `score-compose`

```bash
make compose-up
```

Then navigate to http://localhost:7007.

## Local with `score-k8s`

```bash
kind load docker-image backstage:local

make k8s-up

kubectl port-forward --namespace=backstage svc/backstage 7007:7007
```

Then navigate to http://localhost:7007.
