require 'fileutils'


ENV['GEM_HOME'] ||= "#{ENV['HOME']}/.gem"
ENV['GEM_PATH'] ||= ENV['GEM_HOME']

Gem.use_paths(ENV['GEM_HOME'], ENV['GEM_PATH'].split(':') )
require 'rubygems'
gem 'soap4r'

require 'rbbt'
require 'rbbt/bow/dictionary'


require 'MARQ'

require 'merb-core'

def init_WS
  if File.exists?('tmp/ws.pid')
    begin
      Process.kill(9, File.open('tmp/ws.pid').read.to_i)
    rescue
    ensure
      FileUtils.rm 'tmp/ws.pid'
    end
    sleep 2
  end

  pid = fork do
      require 'simplews'
      rootdir = File.dirname(File.dirname(File.expand_path(__FILE__)))
      workdir = File.join(MARQ.workdir, 'webservice', 'jobs')
      $:.unshift(File.join(rootdir, 'webservice'))
      require 'MARQWS'
     
      puts "Starting WS"
      host = `hostname`.chomp.strip + '.' +  `hostname -d`.chomp.strip
      port = '8282'
  
      puts "Starting Server in #{ host }:#{ port }"

      server = MARQWS.new("MARQ", "MARQ Web Server",host, port, workdir)
  
      FileUtils.mkdir_p File.join(MARQ.workdir, '/webservice/wsdl/') unless File.exist? File.join(MARQ.workdir, '/webservice/wsdl/')
      Open.write(File.join(MARQ.workdir, '/webservice/wsdl/MARQWS.wsdl'), server.wsdl)

      FileUtils.mkdir_p File.join(MARQ.workdir, '/webservice/html_doc/') unless File.exist? File.join(MARQ.workdir, '/webservice/html_doc/')
      Open.write(File.join(MARQ.workdir, '/webservice/html_doc/documentation.html'), server.documentation)

      log_dir = File.join(MARQ.workdir, 'webservice', 'log')
      FileUtils.mkdir_p log_dir unless File.exist? log_dir
      server.logtofile(File.join(log_dir, 'MARQWS.log'))

      trap('INT') { server.shutdown }
      server.start
  end
  File.open('tmp/ws.pid','w'){|f| f.puts pid}
  sleep 2
end

require 'soap/wsdlDriver'
begin
    
    SOAP::WSDLDriverFactory.new(File.join(MARQ.workdir, '/webservice/wsdl/MARQWS.wsdl')).create_rpc_driver.wsdl != ""
rescue
    puts $!.inspect
    init_WS
end

puts "Restarting the WWW service"

FileUtils.rm Dir.glob(File.join('cache/*.lock'))

Merb::Config.setup(
    :merb_root   => ::File.expand_path(::File.dirname(__FILE__)),
    :environment => ENV['RACK_ENV']
)

Merb.environment = Merb::Config[:environment]
Merb.root        = Merb::Config[:merb_root]
Merb::BootLoader.run

run Merb::Rack::Application.new

