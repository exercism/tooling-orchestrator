$stdout.sync = true
$stderr.sync = true

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)

require_relative "lib/orchestrator"

run Orchestrator::Http::WebApplication
