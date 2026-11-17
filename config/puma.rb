# This sets how many requests Puma can handle at once. Each invoker that is
# waiting for a job ties up one thread for up to Configuration::MAX_WAIT
# seconds. If more than LONG_POLL_POOL_SIZE invokers are waiting at once, the
# extra ones get an answer straight away. Configuration::PUMA_THREADS adds
# spare threads, so invokers that are sending results never queue behind
# invokers that are waiting.
require_relative '../lib/orchestrator/configuration'

threads Orchestrator::Configuration::PUMA_THREADS, Orchestrator::Configuration::PUMA_THREADS
