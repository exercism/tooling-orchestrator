require 'test_helper'

module Orchestrator
  class RecoverStrandedJobsTest < Minitest::Test
    def teardown
      super
      Timecop.return
    end

    def test_requeues_a_job_if_its_invoker_never_reports_back
      job = create_job
      RetrieveNextJob.()

      RecoverStrandedJobs.()
      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_queued)

      expire_leases
      RecoverStrandedJobs.()

      assert_equal [job.id], redis.lrange(Exercism::ToolingJob.key_for_queued, 0, -1)
      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_locked)
      assert_equal job, RetrieveNextJob.()
    end

    def test_leaves_jobs_alone_once_the_website_has_the_result
      job = create_job
      RetrieveNextJob.()
      RestClient::Request.stubs(:execute)
      ProcessJob.(job.id, { 'status' => 200, 'output' => {} })

      expire_leases
      RecoverStrandedJobs.()

      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_queued)
      assert_nil Queue.instance.deadline(job.id)
    end

    # If the website call fails after an invoker sends a result, we must
    # keep telling the website, and never run the job again.
    def test_retries_telling_the_website_about_a_result
      job = create_job
      RetrieveNextJob.()

      expects_spi_patch(job.id).raises(RestClient::ServiceUnavailable)
      assert_raises(RestClient::ServiceUnavailable) do
        ProcessJob.(job.id, { 'status' => 200, 'output' => {} })
      end

      expire_leases
      expects_spi_patch(job.id).raises(RestClient::ServiceUnavailable)
      RecoverStrandedJobs.()
      assert Queue.instance.deadline(job.id)

      wait_for_retry
      expects_spi_patch(job.id)
      RecoverStrandedJobs.()

      assert_nil Queue.instance.deadline(job.id)
      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_queued)
      assert_equal 200, Exercism::ToolingJob.find(job.id).execution_status
    end

    # The soak test found this. A job ran out of time while its invoker was
    # still running it, so we put it back on the queue. Then the invoker
    # reported the result, but the website call failed.
    def test_keeps_a_result_that_arrives_after_the_job_went_back_on_the_queue
      job = create_job
      RetrieveNextJob.()
      expire_leases
      RecoverStrandedJobs.()
      assert_equal [job.id], redis.lrange(Exercism::ToolingJob.key_for_queued, 0, -1)

      expects_spi_patch(job.id).raises(RestClient::ServiceUnavailable)
      assert_raises(RestClient::ServiceUnavailable) do
        ProcessJob.(job.id, { 'status' => 200, 'output' => {} })
      end
      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_queued)
      assert Queue.instance.leased?(job.id)

      wait_for_retry
      expects_spi_patch(job.id)
      RecoverStrandedJobs.()

      refute Queue.instance.leased?(job.id)
      assert_nil redis.hget(Queue.instance.reclaims_key, job.id)
    end

    def test_waits_before_it_retries_the_website
      job = create_job
      RetrieveNextJob.()
      Exercism::ToolingJob.find(job.id).executed!(200, {})
      expire_leases

      expects_spi_patch(job.id).raises(RestClient::ServiceUnavailable)
      RecoverStrandedJobs.()

      RestClient::Request.expects(:execute).never
      RecoverStrandedJobs.()
    end

    def test_gives_up_telling_the_website_after_too_many_attempts
      job = create_job
      RetrieveNextJob.()
      Exercism::ToolingJob.find(job.id).executed!(200, {})
      Orchestrator.config.stubs(max_report_attempts: 2)
      expire_leases

      RestClient::Request.expects(:execute).twice.raises(RestClient::ServiceUnavailable)
      RecoverStrandedJobs.()
      wait_for_retry
      RecoverStrandedJobs.()
      wait_for_retry
      RecoverStrandedJobs.()

      assert_nil Queue.instance.deadline(job.id)
      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_queued)
    end

    def test_gives_up_on_a_job_after_too_many_attempts
      job = create_job

      Orchestrator.config.max_reclaims.times do
        assert_equal job, RetrieveNextJob.()
        expire_leases
        RecoverStrandedJobs.()
      end

      assert_equal job, RetrieveNextJob.()
      expire_leases

      expects_spi_patch(job.id)
      RecoverStrandedJobs.()

      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_queued)
      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_locked)
      assert_nil Queue.instance.deadline(job.id)
      assert_nil redis.hget(Queue.instance.reclaims_key, job.id)
      assert_equal Queue::RECLAIMS_EXHAUSTED_STATUS, Exercism::ToolingJob.find(job.id).execution_status
    end

    def test_retries_telling_the_website_that_a_job_failed
      job = create_job
      Orchestrator.config.stubs(max_reclaims: 0)
      RetrieveNextJob.()
      expire_leases

      expects_spi_patch(job.id).raises(RestClient::ServiceUnavailable)
      RecoverStrandedJobs.()
      assert Queue.instance.deadline(job.id)

      wait_for_retry
      expects_spi_patch(job.id)
      RecoverStrandedJobs.()

      assert_nil Queue.instance.deadline(job.id)
      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_queued)
    end

    def test_calls_the_website_a_limited_number_of_times_per_pass
      limit = RecoverStrandedJobs::MAX_WEBSITE_CALLS_PER_PASS
      jobs = Array.new(limit + 2) { create_job }
      Orchestrator.config.stubs(max_reclaims: 0)
      jobs.each { RetrieveNextJob.() }
      expire_leases

      RestClient::Request.expects(:execute).times(limit)
      RecoverStrandedJobs.()

      remaining = jobs.select { |job| Queue.instance.deadline(job.id) }
      assert_equal 2, remaining.size
      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_queued)

      # The next pass fails the rest, and no job is lost
      RestClient::Request.expects(:execute).times(2)
      RecoverStrandedJobs.()

      jobs.each do |job|
        assert_nil Queue.instance.deadline(job.id)
        assert_equal Queue::RECLAIMS_EXHAUSTED_STATUS, Exercism::ToolingJob.find(job.id).execution_status
      end
    end

    def test_drops_a_job_if_its_data_has_gone
      redis.rpush(Exercism::ToolingJob.key_for_queued, "missing")
      Queue.instance.claim
      expire_leases

      RestClient::Request.expects(:execute).never
      RecoverStrandedJobs.()

      assert_nil Queue.instance.deadline("missing")
      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_queued)
    end

    private
    def redis = Exercism.redis_tooling_client

    def create_job
      Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, SecureRandom.uuid, "", :ruby, "two-fer")
    end

    def expire_leases
      Timecop.travel(Time.now + Orchestrator.config.lease_seconds + 1)
    end

    # Valkey expires a taken job on its own clock, which Timecop can't move,
    # so this also clears the taken keys by hand.
    def wait_for_retry
      Timecop.travel(Time.now + Orchestrator.config.retry_seconds + 1)
      keys = redis.keys("{test:queued}:taken:*")
      redis.del(*keys) unless keys.empty?
    end
  end
end
