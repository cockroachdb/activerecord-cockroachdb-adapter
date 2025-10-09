# frozen_string_literal: true

module SQLLogger
  module_function

  def stdout_log
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Base.logger.level = Logger::DEBUG
    ActiveRecord::LogSubscriber::IGNORE_PAYLOAD_NAMES.clear
    ActiveRecord::Base.logger.formatter = proc { |severity, time, progname, msg|
      th = Thread.current[:name]
      th = "THREAD=#{th}" if th
      Logger::Formatter.new.call(severity, time, progname || th, msg)
    }
  end

  def summary_log
    ActiveRecord::TotalTimeSubscriber.attach_to :active_record
    Minitest.after_run {
      detail = ActiveRecord::TotalTimeSubscriber.hash.map { |k,v| [k, [v.sum, v.sum / v.size, v.size]]}.sort_by { |_, (_total, avg, _)| -avg }.to_h
      time = detail.values.sum { |(total, _, _)| total } / 1_000
      count = detail.values.sum { |(_, _, count)| count }
      File.write(
        "tmp/query_time.json",
        JSON.pretty_generate(detail)
      )
      puts "Total time spent in SQL: #{time}s (#{count} queries)"
      puts "Detail per query kind available in tmp/query_time.json (total time in ms, avg time in ms, query count). Sorted by avg time."
    }
  end

  # Remove content between single quotes and double quotes from keys
  # to have a clear idea of which queries are being executed.
  def clean_sql(sql)
    sql.gsub(/".*?"/m, "\"...\"").gsub("''", "").gsub(/'.*?'/m, "'...'")
  end
end

class ActiveRecord::TotalTimeSubscriber < ActiveRecord::LogSubscriber
  def self.hash
    @@hash
  end

  def sql(event)
    # NOTE: If you want to debug a specific query, you can use a 'binding.irb' here with
    # a specific condition on 'event.payload[:sql]' content.
    #
    #     binding.irb if event.payload[:sql].include?("attr.attname, nsp.nspname")
    #
    @@hash ||= {}
    key = SQLLogger.clean_sql(event.payload[:sql])
    @@hash[key] ||= []
    @@hash[key].push event.duration
  end
end
