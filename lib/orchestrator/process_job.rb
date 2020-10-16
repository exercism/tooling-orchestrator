module Orchestrator
  class ProcessJob
    include Mandate
    initialize_with :job_id, :data, :client

    def call
      upload_to_s3
      update_dynamodb
      inform_spi
      # rescue
      # TODO - Re-enqueue the job?
    end

    private
    attr_reader :output_s3_mapping
    def upload_to_s3
      return unless data['output']
      return if data['output'].empty?

      bucket = Exercism.config.aws_tooling_jobs_bucket.freeze
      path = "#{Exercism.env}/tooling_jobs/#{job_id}/output".freeze

      threads = data['output'].map do |filename, contents|
        Thread.new do
          key = "#{path}/#{filename}"
          s3_client = ExercismConfig::SetupS3Client.()
          s3_client.put_object(bucket: bucket,
                               key: key,
                               body: contents,
                               acl: 'private')
          [filename, key]
        end
      end

      @output_s3_mapping = Hash[threads.map(&:value)]
    end

    def update_dynamodb
      client.update_item(
        table_name: Orchestrator.config.jobs_table,
        key: { id: job_id },
        expression_attribute_names: {
          "#JS": "job_status",
          "#LU": "locked_until",
          "#O": "output",
          "#ES": "execution_status",
          "#EC": "execution_context",
          "#EID": "execution_invocation_data"
        },
        expression_attribute_values: {
          ":js": "executed",
          ":lu": nil,
          ":o": output_s3_mapping,
          ":es": data['status'],
          ":ec": data['context'],
          ":eid": data['invocation_data']
        },
        update_expression: "SET #JS = :js, #LU = :lu, #O = :o, #ES = :es, #EC = :ec, #EID = :eid",
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
