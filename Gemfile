source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

gem "rake"
gem "mocha"
gem "minitest"
gem 'timecop'
gem 'sinatra'
gem 'sinatra-contrib'
gem 'concurrent-ruby'
gem 'rest-client'
gem 'puma'
gem 'zeitwerk'
gem 'aws-sdk-dynamodb', '~> 1.51'
gem 'aws-sdk-s3'
gem 'redis'
gem 'mandate'
gem 'exercism-config', '>= 0.66.0'
# gem 'exercism-config', path: '../exercism_config'

group :development, :test do
  gem 'parallel'
  gem 'rack-test'
  gem 'rubocop'
  gem 'rubocop-minitest'
  gem 'rubocop-performance'
  gem 'simplecov', '~> 0.17.0'
end
