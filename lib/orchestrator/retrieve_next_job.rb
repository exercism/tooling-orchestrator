module Orchestrator
  class RetrieveNextJob
    include Mandate
    def initialize(client)
      @client = client
      @table_name = Orchestrator.config.jobs_table
    end

    def call
      return nil unless job_id

      attrs = lock_and_retrieve!
      Job.new(
        attrs['type'],
        attrs['id'],
        attrs['language'],
        attrs['exercise'],
        attrs['source']
      )
    end

    private
    attr_reader :client, :table_name

    memoize
    def job_id
      item = client.query(
        table_name: table_name,
        index_name: "job_status",
        expression_attribute_names: { "#JS": "job_status" },
        expression_attribute_values: { ":js": "queued" },
        key_condition_expression: "#JS = :js",
        limit: 1
      ).items.first

      item ? item['id'] : nil
    end

    def lock_and_retrieve!
      client.update_item(
        table_name: table_name,
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
      ).attributes
    end
  end
end
