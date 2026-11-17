require 'singleton'

module Orchestrator
  # This class holds the settings for handing out jobs and taking them back.
  class Configuration
    include Singleton

    # An invoker has this many seconds to report a job's result. After that,
    # the orchestrator assumes that the machine has died, and puts the job
    # back on the queue. The invoker stops the slowest tools after 30 seconds,
    # and it also needs time to prepare the files, check itself after a
    # failure and send the result. If a job takes longer than this, it will
    # run twice, which does no harm.
    LEASE_SECONDS = 60

    # A job can go back on the queue this many times, whether its time ran
    # out or an invoker handed it back. After that, the orchestrator gives up
    # and marks it as failed, so a job that kills machines can't do it
    # forever.
    MAX_RECLAIMS = 2

    # Once RecoverStrandedJobs takes a job that is out of time, it holds the
    # job for this many seconds. If it can't deal with the job in that time,
    # for example because the website call failed, a later pass will try
    # again.
    RETRY_SECONDS = 30

    # RecoverStrandedJobs tries to tell the website about a result at most
    # this many times. After that, it logs that it has given up, and releases the job.
    MAX_REPORT_ATTEMPTS = 10

    # If the orchestrator crashed after it moved a job to `leased` but before
    # it saved the job's deadline, RecoverStrandedJobs gives the job a
    # deadline this many seconds away.
    DEADLINE_GRACE_SECONDS = 30

    # These readers return the values above, so tests can stub them.
    def lease_seconds = LEASE_SECONDS
    def max_reclaims = MAX_RECLAIMS
    def retry_seconds = RETRY_SECONDS
    def max_report_attempts = MAX_REPORT_ATTEMPTS
    def deadline_grace_seconds = DEADLINE_GRACE_SECONDS
  end
end
