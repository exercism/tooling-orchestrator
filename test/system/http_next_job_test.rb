require_relative 'base'

module Orchestrator
  class HttpNextJobTest < SystemBaseTestCase
    def test_with_job
      job = Job.new(nil, 1, nil, nil, nil)

      RetrieveNextJob.expects(:call).with(wait: 0).returns(job)
      get "/jobs/next"
      assert_equal 200, last_response.status
      assert_equal job.to_h.to_json, last_response.body
    end

    def test_with_no_job
      RetrieveNextJob.expects(:call).with(wait: 0).returns(nil)

      get "/jobs/next"
      assert_equal 404, last_response.status
    end

    def test_passes_on_the_wait
      RetrieveNextJob.expects(:call).with(wait: 5.5).returns(nil)

      get "/jobs/next?wait=5.5"
      assert_equal 404, last_response.status
    end

    def test_caps_the_wait
      RetrieveNextJob.expects(:call).with(wait: Orchestrator.config.max_wait).returns(nil)

      get "/jobs/next?wait=600"
    end

    def test_ignores_a_wait_that_isnt_a_positive_number
      %w[abc -3 1e400 NaN].each do |wait|
        RetrieveNextJob.expects(:call).with(wait: 0).returns(nil)

        get "/jobs/next?wait=#{wait}"
        assert_equal 404, last_response.status
      end
    end

    def test_long_poll_returns_a_job_that_arrives_mid_wait
      job_id = SecureRandom.uuid
      Thread.new do
        sleep(0.3)
        Exercism::ToolingJob.create!(job_id, :test_runner, "123", "", :ruby, "two-fer")
      end

      get "/jobs/next?wait=5"
      assert_equal 200, last_response.status
      assert_equal job_id, JSON.parse(last_response.body)["id"]
    end

    def test_long_poll_returns_404_after_the_wait
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      get "/jobs/next?wait=0.5"
      assert_equal 404, last_response.status
      assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :>=, 0.5
    end
  end
end
