require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.warning = false
  t.test_files = FileList["test/**/*_test.rb"]
end

task :process_background_queue do
  $LOAD_PATH.unshift File.expand_path('./lib', __dir__)
  require "orchestrator"

  Orchestrator.process_background_queue
end

task default: :test
