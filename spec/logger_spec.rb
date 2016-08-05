require 'mizuno/logger'

java_import 'java.util.Properties'

describe Mizuno::Logger do
  context 'when writing logs to a file' do
    LOGFILE = File.join(File.dirname(__FILE__), '../tmp/logger.log')
    let(:logger) { described_class.logger }
    let(:content) { File.read(LOGFILE).lines.to_a }

    before(:all) {
      FileUtils.rm(LOGFILE) if File.exist?(LOGFILE)
      described_class.configure(log: LOGFILE, debug: true)
    }

    describe '#debug' do
      it 'prefixes the log message with a DEBUG prefix' do
        logger.debug('uuwaf')
        expect(content.grep(/DEBUG mizuno - uuwaf/).count).to eq 1
      end
    end

    describe '#error' do
      it 'prefixes the log message with a ERROR prefix' do
        logger.error('dooca')
        expect(content.grep(/ERROR mizuno - dooca/).count).to eq 1
      end
    end

    context 'when the log level is not supported' do
      describe '#fatal' do
        it 'raises an error' do
          expect { logger.fatal('some random log message') }.to raise_error Mizuno::NotSupportedError
        end
      end
    end

    describe '#info' do
      it 'prefixes the log message with a INFO prefix' do
        logger.info('shaeg')
        expect(content.grep(/INFO  mizuno - shaeg/).count).to eq 1
      end
    end

    describe '#warn' do
      it 'prefixes the log message with a WARN prefix' do
        logger.warn('zohch')
        expect(content.grep(/WARN  mizuno - zohch/).count).to eq 1
      end
    end
  end
end
