require 'mizuno/logger'

java_import 'java.util.Properties'

describe Mizuno::Logger do
  context 'when writing logs to a file' do
    LOGFILE = File.join(File.dirname(__FILE__), '../tmp/logger.log')
    let(:logger) { Mizuno::Logger.logger }
    let(:content) { File.read(LOGFILE).lines.to_a }

    before(:all) {
      FileUtils.rm(LOGFILE) if File.exist?(LOGFILE)
      Mizuno::Logger.configure(log: LOGFILE, debug: true)
    }

    describe '#debug' do
      it 'prefixes the log message with a DEBUG prefix' do
        logger.debug('uuwaf')
        expect(content.grep(/DEBUG uuwaf/).count).to eq 1
      end
    end

    describe '#error' do
      it 'prefixes the log message with a ERROR prefix' do
        logger.error('dooca')
        expect(content.grep(/ERROR dooca/).count).to eq 1
      end
    end

    describe '#fatal' do
      it 'prefixes the log message with a FATAL prefix' do
        logger.fatal('einai')
        expect(content.grep(/FATAL einai/).count).to eq 1
      end
    end

    describe '#info' do
      it 'prefixes the log message with a INFO prefix' do
        logger.info('shaeg')
        expect(content.grep(/INFO shaeg/).count).to eq 1
      end
    end

    describe '#warn' do
      it 'prefixes the log message with a WARN prefix' do
        logger.warn('zohch')
        expect(content.grep(/WARN zohch/).count).to eq 1
      end
    end
  end

  context 'when the "log4j" option is enabled' do
    it 'does not set up the logger' do
      expect(Properties).to_not receive(:new)
      Mizuno::Logger.configure(log4j: true)
    end
  end
end
