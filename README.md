# Tooling Orchestrator

![Tests](https://github.com/exercism/tooling-orchestrator/workflows/Tests/badge.svg)
[![Maintainability](https://api.codeclimate.com/v1/badges/d4fa74b662731c5ec239/maintainability)](https://codeclimate.com/github/exercism/tooling-orchestrator/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/d4fa74b662731c5ec239/test_coverage)](https://codeclimate.com/github/exercism/tooling-orchestrator/test_coverage)

An Orchestrator for Exercism's tooling.

## Run locally

This can be run locally using the Procfile or via Docker through the Dockerfile.

To build the Dockerfile, run:

```
docker build -f Dockerfile.dev -t exercism-tooling-orchestrator .
```

To execute the Dockerfile.

```
docker run -p 3021:3021 -v /PATH/TO/PWD:/usr/src/app exercism-tooling-orchestrator:latest
```

For example:

```
docker run -p 3021:3021 -v /Users/iHiD/Code/exercism/tooling-orchestrator:/usr/src/app exercism-tooling-orchestrator:latest
```

It will then sit and wait for messages from the website or invokers.
