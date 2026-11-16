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

Invokers ask for work with `GET /jobs/next`. An invoker can add `?wait=<seconds>` to wait up to 20 seconds for a job. As soon as a job arrives, the orchestrator hands it over. Without `wait`, the orchestrator answers straight away.

When an invoker takes a job, the orchestrator gives the job a deadline, called a lease. If the invoker doesn't report a result before the deadline, the orchestrator assumes that the machine has died, and puts the job back on the queue for another machine. If a job goes back on the queue too many times, the orchestrator gives up and marks it as failed, with status 514 ("gave up after repeated attempts"). If the call to tell the website about a result fails, the background process will keep retrying it until the website has the result. The invoker's README lists the other status codes. `lib/orchestrator/queue.rb` explains how this works.

Jobs that are queued to run in the background wait on a separate list. To move one onto the main queue, the background process first moves it to a `moving` list, then adds it to the main queue, then removes it from `moving`. If the orchestrator crashes part of the way through, the job is still in `moving`, and after 30 seconds the background process will finish the move.

`lib/orchestrator/configuration.rb` holds the settings, such as the length of the deadline and the longest wait, as constants. `config/puma.rb` uses one of them to decide how many requests Puma can handle at once.

## The soak test proves that no job is lost

The soak test runs the real orchestrator against a three-node Valkey cluster, which applies the same hash-slot rules as ElastiCache Serverless. It starts two orchestrator tasks, each with Puma and the background process. It also starts fake invokers, which use the long poll and report results, and a fake website.

One job in every 40 is a poison job, which every invoker hands back, so it will end with status 514. While the test pushes jobs through, it breaks things at random:

- It kills fake invokers in the middle of a job or a long poll.
- It kills and restarts orchestrator processes, including while they wait for a job or move a background job.
- It makes the website slower than the orchestrator's 5-second timeout, or makes it return errors, for a few seconds at a time.

At the end, it checks that every job either reached the website with a result (including status 514), or appears in the orchestrator's log of jobs that it gave up telling the website about after 10 attempts. It also checks that every queue key is empty. It reports how many jobs ran more than once. If any job is lost, or any key isn't empty, it fails.

To keep a run short, the soak test shortens the deadline to 8 seconds and the retry interval to 1 second (see `soak/boot.rb`).

The test writes the logs of every process to `soak/tmp/logs`. In the same folder, `events.log` records each job taken, reported or handed back by a fake invoker, and each failure caused by the test. If a run fails, it prints the log lines for the first few jobs that went wrong. In CI, the logs are attached to the failed run.

CI runs a short version, about 300 jobs with a fixed seed, on every pull request:

```
SOAK_MODE=ci docker compose -f soak/docker-compose.yml run --rm soak
```

To run a longer version locally, with 3,000 jobs and a random seed:

```
SOAK_MODE=long docker compose -f soak/docker-compose.yml run --rm soak
docker compose -f soak/docker-compose.yml down -v
```

The test prints its seed at the start. To repeat a run, set `SOAK_SEED` (and `SOAK_JOBS`, if you changed it) to the same values. The same seed makes the same failures in the same order, but the timing of each process still varies, so a repeat won't always match exactly.
