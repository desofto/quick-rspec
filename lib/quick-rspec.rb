# frozen_string_literal: true

require 'coverage'

class QuickRspec < Rails::Railtie
  rake_tasks do
    Dir[File.join(File.dirname(__FILE__),'tasks/*.rake')].each { |f| load f }
  end

  class << self
    @@coverage = {}
    @@last_cover = {}

    def start
      Coverage.start
    end

    def collect_stats(example)
      spec = "#{example.metadata[:rerun_file_path]}[#{example.metadata[:scoped_id]}]"
      root = Rails.root.to_s
      result = {}
      cover = Coverage.peek_result
      cover.each do |path, coverage|
        next unless path =~ %r{^#{Regexp.escape(root)}}i
        next if path =~ %r{^#{Regexp.escape(root)}\/spec\/}i
        last_cover = @@last_cover[path]
        path = QuickRspec.relevant_path(path)
        coverage = coverage.each_with_index.map.map do |count, index|
          count -= last_cover[index] if count.present? && last_cover.present? && last_cover[index].present?
          index if count&.positive?
        end
        coverage.compact!
        next unless coverage.any?
        result[path] = coverage
      end
      @@coverage[spec] = result
      @@last_cover = cover
    end

    def relevant_path(path)
      path = Rails.root.join(path).to_s
      path[Rails.root.to_s.length + 1..-1]
    end

    def load_stats
      @@coverage = begin
                     JSON.parse(File.read(Rails.root.join('tmp/quick_rspec.new.json')))
                   rescue Errno::ENOENT
                     begin
                       JSON.parse(File.read(Rails.root.join('tmp/quick_rspec.json')))
                     rescue Errno::ENOENT
                       {}
                     end
                   end
    end

    def save_stats
      File.open(Rails.root.join('tmp/quick_rspec.new.json'), 'w+') do |f|
        f.write @@coverage.to_json
      end
      File.open(Rails.root.join('tmp/quick_rspec.stats'), 'w+') do |f|
        @@coverage.each do |spec_name, coverage|
          f.write "#{spec_name}:\n"
          coverage.each do |path, lines|
            f.write "  #{path}:\n"
            f.write "    #{lines}\n"
          end
        end
      end
    end

    def where_tested(file)
      @@coverage.map do |spec, coverage|
        next unless file.in? coverage.keys
        spec
      end.compact
    end
  end
end

if Rails.env.test?
  QuickRspec.load_stats

  QuickRspec.start

  RSpec.configure do |config|
    config.after(:each) do |example|
      QuickRspec.collect_stats(example)
    end
  end

  at_exit { QuickRspec.save_stats }
end
