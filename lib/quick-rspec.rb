# frozen_string_literal: true

require 'coverage'

class QuickRspec < Rails::Railtie
  rake_tasks do
    Dir[File.join(File.dirname(__FILE__),'tasks/*.rake')].each { |f| load f }
  end

  class << self
    @@threads = []
    @@coverage = {}
    @@last_cover = {}
    @@mutex = Mutex.new

    def start
      Coverage.start
    end

    def collect_stats(example)
      spec = "#{example.metadata[:rerun_file_path]}[#{example.metadata[:scoped_id]}]"
      root = Rails.root.to_s
      result = {}
      cover = Coverage.peek_result
      prev_cover = @@last_cover
      @@last_cover = cover
      @@threads << Thread.new do
        cover.each do |path, coverage|
          next unless path =~ %r{^#{Regexp.escape(root)}}i
          next if path =~ %r{^#{Regexp.escape(root)}\/spec\/}i
          last_cover = prev_cover[path]
          path = QuickRspec.relevant_path(path)
          coverage = coverage.each_with_index.map.map do |count, index|
            index unless last_cover.present? && count == last_cover[index]
          end
          coverage.compact!
          next unless coverage.any?
          result[path] = coverage
        end
        @@mutex.synchronize do
          @@coverage[spec] = result
        end
      end
    end

    def relevant_path(path)
      path = Rails.root.join(path).to_s
      path[Rails.root.to_s.length + 1..-1]
    end

    def load_stats
      @@coverage = begin
                     JSON.parse(File.read(Rails.root.join('tmp/quick_rspec.new.json')))
                   rescue Errno::ENOENT, JSON::ParserError
                     begin
                       JSON.parse(File.read(Rails.root.join('tmp/quick_rspec.json')))
                     rescue Errno::ENOENT, JSON::ParserError
                       {}
                     end
                   end
    end

    def save_stats
      new_coverage = @@coverage
      load_stats()
      new_coverage.each do |spec, coverage|
        @@coverage[spec] = coverage
      end
      dir = Rails.root.join('tmp')
      FileUtils.mkdir_p(dir) unless File.directory?(dir)
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

    def on_exit
      @@threads.map(&:join)
      QuickRspec.save_stats
    end
  end
end

if Rails.env.test?
  QuickRspec.start

  RSpec.configure do |config|
    config.after(:each) do |example|
      QuickRspec.collect_stats(example)
    end
  end

  at_exit { QuickRspec.on_exit }
end
