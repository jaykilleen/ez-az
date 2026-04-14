require_relative "config/application"

Rails.application.load_tasks

desc "Run Playwright end-to-end tests"
task :e2e do
  sh "npx playwright test"
end
