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

## The orchestrator puts jobs back on the queue if the machine that is running them dies

Invokers ask for work with `GET /jobs/next`.

When an invoker takes a job, the orchestrator gives the job a deadline, called a lease. If the invoker doesn't report a result before the deadline, the orchestrator assumes that the machine has died, and puts the job back on the queue for another machine. If a job goes back on the queue too many times, the orchestrator gives up and marks it as failed, with status 514 ("gave up after repeated attempts"). If the call to tell the website about a result fails, the background process will keep retrying it until the website has the result. The invoker's README lists the other status codes. `lib/orchestrator/queue.rb` explains how this works.

`lib/orchestrator/configuration.rb` holds the settings, such as the length of the deadline, as constants.
