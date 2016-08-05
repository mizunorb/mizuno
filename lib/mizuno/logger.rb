require 'logger'
require 'rjack-logback'

require 'mizuno/errors'

# Hack to be be able to get the underlying Logback object from jrack-logback.
module RJack
  module Logback
    class Logger
      attr_reader :jlogger
    end
  end
end

module Mizuno
  class Logger < ::Logger
    LEVELS = {
      ::Logger::DEBUG => 'debug',
      ::Logger::INFO => 'info',
      ::Logger::WARN => 'warn',
      ::Logger::ERROR => 'error'
    }.freeze

    def self.initialize_logging
      # Jetty floods the logs with loads and loads of INFO and DEBUG messages unless we silence it like this.
      RJack::Logback.root.level = RJack::Logback::WARN
    end

    def self.configure(options = {})
      # Default logging threshold.
      limit = options[:warn] ? ::Logger::WARN : ::Logger::ERROR
      limit = ::Logger::DEBUG if $DEBUG || options[:debug]
      logger.level = limit

      appender = if options[:log]
        RJack::Logback::FileAppender.new(options[:log])
      else
        RJack::Logback::ConsoleAppender.new do |a|
          a.target = 'System.err'
        end
      end

      # TODO: Tried to customize the pattern here, but all output to the file gets disabled if I try that. Maybe
      # something in rjack-logback? Or perhaps in how we use it.

      RJack::Logback.root.jlogger.detach_and_stop_all_appenders
      RJack::Logback.root.add_appender(appender)
    end

    private_class_method

    def self.logger
      @logger ||= new
    end

    def initialize
      @logback_logger = RJack::SLF4J['mizuno']

      # We set this level to the most verbose, and let ourself (i.e. the ::Logger-derivative) assume responsibility for
      # filtering of irrelevant logging.
      RJack::Logback['mizuno'].level = RJack::Logback::DEBUG
    end

    def add(severity, message = nil, progname = nil)
      raise NotSupportedError, "Severity #{severity} is not supported" unless LEVELS.key?(severity)

      content = (message || (block_given? && yield) || progname)
      @logback_logger.send(LEVELS[severity], content)
    end

    def puts(message)
      write(message.to_s)
    end

    def write(message)
      add(INFO, message)
    end

    def flush
      # No-op.
    end

    def close
      # No-op.
    end
  end
end
