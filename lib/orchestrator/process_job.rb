module Orchestrator
  class ProcessJob
    include Mandate
    initialize_with :job_id, :data, :client

    def call
      update_dynamodb
      inform_spi
      # rescue
      # TODO - Re-enqueue the job?
    end

    def update_dynamodb
      client.update_item(
        table_name: Orchestrator.config.jobs_table,
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
          ":r": data['result'],
          ":es": data['status'],
          ":ec": data['context'],
          ":eid": data['invocation_data']
        },
        update_expression: "SET #JS = :js, #LU = :lu, #R = :r, #ES = :es, #EC = :ec, #EID = :eid",
        return_values: "NONE"
      )
    end

    def inform_spi
      RestClient.patch(
        "#{Exercism.config.spi_url}/spi/tooling_jobs/#{job_id}",
        {}
      )
    end
  end
end
