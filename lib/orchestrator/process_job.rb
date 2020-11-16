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

    private
    def update_dynamodb
      client.update_item(
        table_name: Orchestrator.config.jobs_table,
        key: { id: job_id },
        expression_attribute_names: {
          "#JS": "job_status",
          "#LU": "locked_until",
          "#ES": "execution_status",
          "#EO": "execution_output"
        },
        expression_attribute_values: {
          ":js": "executed",
          ":lu": nil,
          ":es": data['status'],
          ":eo": data['output']
        },
        update_expression: "SET #JS = :js, #LU = :lu, #EO = :eo, #ES = :es",
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
