require 'test_helper'

module Orchestrator
  class RetrieveNextJobTest < Minitest::Test
    def test_full_flow
      Timecop.freeze do
        job_id = SecureRandom.uuid
        job_type = SecureRandom.uuid
        language = SecureRandom.uuid
        exercise = SecureRandom.uuid
        source = { foo: 'bar' }

        client = mock
        query_params = {
          table_name: Exercism.config.dynamodb_tooling_jobs_table,
          index_name: "job_status",
          expression_attribute_names: { "#JS": "job_status" },
          expression_attribute_values: { ":js": "queued" },
          key_condition_expression: "#JS = :js",
          limit: 1
        }
        client.expects(:query).
          with(query_params).
          returns(mock(items: ['id' => job_id]))

        update_params = {
          table_name: Exercism.config.dynamodb_tooling_jobs_table,
          key: { id: job_id },
          expression_attribute_names: {
            "#JS": "job_status",
            "#LU": "locked_until"
          },
          expression_attribute_values: {
            ":js": "locked",
            ":lu": Time.now.to_i + 15
          },
          update_expression: "SET #JS = :js, #LU = :lu",
          return_values: "ALL_NEW"
        }
        client.expects(:update_item).
          with(update_params).
          returns(mock(attributes: {
                         'type' => job_type,
                         'id' => job_id,
                         'language' => language,
                         'exercise' => exercise,
                         'source' => source
                       }))

        job = RetrieveNextJob.(client)
        assert_equal job_id, job.id
        assert_equal job_type, job.type
        assert_equal language, job.language
        assert_equal exercise, job.exercise
        assert_equal source, job.source
      end
    end

    def test_no_jobs_in_dynamodb
      client = mock
      client.expects(:query).returns(mock(items: []))
      assert_nil RetrieveNextJob.(client)
    end
  end
end
