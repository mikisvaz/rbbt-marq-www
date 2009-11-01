require 'fileutils'

ENV['GEM_HOME']="/home/marq/.ruby/gems/"
ENV['GEM_PATH']="/home/marq/.ruby/gems/:/var/lib/gems/1.8/"
require 'rubygems'
require 'rubygems'

ENV['RBBT_HOME'] = '/home/marq/git/rbbt/'
$:.unshift(File.join(ENV['RBBT_HOME'], 'lib'))
require 'rbbt/bow/dictionary'

ENV['MARQ_HOME'] = '/home/marq/git/MARQ/'
$:.unshift(File.join(ENV['MARQ_HOME'], 'lib'))
$:.unshift(File.join(ENV['MARQ_HOME'], 'merb'))

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
      FileUtils.cd File.join(MARQ.rootdir, 'webservice')
      require 'MARQWS'
     
  
      puts "Starting WS"
      host = `hostname`.chomp.strip + '.' +  `hostname -d`.chomp.strip
      port = '8282'
  
      puts "Starting Server in #{ host }:#{ port }"
      server = MARQWS.new("MARQ", "MARQ Web Server",host, port, MARQ.workdir)
  
      FileUtils.mkdir_p File.join(MARQ.rootdir, '/webservice/wsdl/') unless File.exist? File.join(MARQ.rootdir, '/webservice/wsdl/')
      Open.write(File.join(MARQ.rootdir, '/webservice/wsdl/MARQWS.wsdl'), server.wsdl)
  
      trap('INT') { server.shutdown }
      server.start
  end
  File.open('tmp/ws.pid','w'){|f| f.puts pid}
  sleep 2
end

require 'soap/wsdlDriver'
begin
    
    SOAP::WSDLDriverFactory.new(File.join(MARQ.rootdir, '/webservice/wsdl/MARQWS.wsdl')).create_rpc_driver.wsdl != ""
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

