# Tooling Orchestrator

An Orchestrator for Exercism's test runners.

## Run locally

This can be run locally using the Procfile or via Docker through the Dockerfile.

To build the Dockerfile, run:
```
docker build -f Dockerfile.dev -t exercism-tooking-orchestrator .
```

To execute the Dockerfile, run the following with your AWS keys:
```
docker run -p 3021:3021 -v /PATH/TO/PWD:/usr/src/app exercism-tooking-orchestrator:latest
```

It will then sit and wait for messages from the website or invokers.
