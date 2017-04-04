# frozen_string_literal: true
desc 'Runs rspec for recently changed files'
task quick_rspec: :environment do
  dry = ENV['DRY'].present?

  QuickRspec.load_stats

  changed = []
  specs = []

  files = `git diff --name-only`.split("\n")
  files.select! { |file| file =~ %r{^(app|lib|config|spec)\/}i }

  files.each do |file|
    if file =~ %r{^spec\/}i
      specs << file
    else
      changed << file
    end
  end

  run_all = false
  specs += files.map do |file|
    files = QuickRspec.where_tested(file)
    run_all ||= files.empty?
    files
  end.flatten.compact
  specs.uniq!

  puts "Changed files:\n#{changed.map { |file| "  #{file}" }.join("\n")}\n"

  if run_all
    puts "It requires to run all tests\n\n"
    system('rspec') unless dry
  else
    puts "Run specs:\n#{specs.map { |file| "  #{file}" }.join("\n")}\n\n"
    system("rspec #{specs.join(' ')}") unless dry
  end
end
