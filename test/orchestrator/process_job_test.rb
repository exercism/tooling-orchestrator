require 'test_helper'

module Orchestrator
  class ProcessJobTest < Minitest::Test
    def test_full_flow
      job_id = SecureRandom.uuid
      status = SecureRandom.uuid
      result = SecureRandom.uuid
      context = SecureRandom.uuid
      invocation_data = SecureRandom.uuid

      client = mock
      update_params = {
        table_name: Exercism.config.dynamodb_tooling_jobs_table,
        key: { id: job_id },
        expression_attribute_names: {
          "#JS": "job_status",
          "#LU": "locked_until",
          "#R": "result",
          "#ES": "execution_status",
          "#EC": "execution_context",
          "#EID": "execution_invocation_data"
        },
        expression_attribute_values: {
          ":js": "executed",
          ":lu": nil,
          ":r": result,
          ":es": status,
          ":ec": context,
          ":eid": invocation_data
        },
        update_expression: "SET #JS = :js, #LU = :lu, #R = :r, #ES = :es, #EC = :ec, #EID = :eid",
        return_values: "NONE"
      }
      client.expects(:update_item).
        with(update_params)

      RestClient.expects(:patch).with(
        "#{Exercism.config.spi_url}/spi/tooling_jobs/#{job_id}",
        {}
      )

      ProcessJob.(job_id, {
                    'status' => status,
                    'result' => result,
                    'context' => context,
                    'invocation_data' => invocation_data
                  }, client)
    end
  end
end
