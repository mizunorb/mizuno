#
# A Rack handler for Jetty 8.
#
# Written by Don Werve <don@madwombat.com>
#

require 'java'

# Save our launch environment for spawning children later.
module Mizuno
  LAUNCH_ENV = $LOAD_PATH.map { |i| "-I#{i}" }.push($PROGRAM_NAME)

  HOME = File.expand_path(File.dirname(__FILE__))

  @log_options = {}

  class << self
    attr_accessor :log_options
  end

  #
  # Loads jarfiles independent of versions.
  #
  def self.require_jars(*names)
    names.flatten.each do |name|
      file = Dir[File.join(HOME, 'java', "#{name}-*.jar")].first
      file ||= Dir[File.join(HOME, 'java', "#{name}.jar")].first
      raise("Unknown or missing jar: #{name}") unless file
      require file
    end
  end
end

# The logging must be set up before rjack-jetty gets loaded, since it loads jetty-util which in turns expect log4j to
# already be configured. We _could_ solve it all by switching to rjack-logback (which uses the Logback library, which
# supersedes log4j), but it requires more substantial changes at our end.
require 'mizuno/logger'
Mizuno::Logger.initialize_logging
