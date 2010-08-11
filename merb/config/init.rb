# Go to http://wiki.merbivore.com/pages/init-rb
 
# Specify a specific version of a dependency
# dependency "RedCloth", "> 3.0"
#
require 'config/dependencies.rb'

#  use_orm :none
use_test :rspec
use_template_engine :haml

dependency "merb-assets"  
 
require 'rubygems'
require 'MARQ'
require 'compass'
require 'fileutils'
require 'rand'
require 'spreadsheet'
require 'ruby-yui'
require 'redcloth'      
require 'rbbt/util/misc'      
require 'stemmer'
require 'simplews/notifier'
require 'cgi'

Merb::Config.use do |c|
  c[:use_mutex] = false
  c[:session_store] = 'cookie'  # can also be 'memory', 'memcache', 'container', 'datamapper
  
  # cookie session store configuration
  c[:session_secret_key]  = '5d76d9de3239bba8bb00e675f68f24365650a272'  # required for cookie session store
  c[:session_id_key] = '_marq_session_id' # cookie session id key, defaults to "_session_id"


  c[:compass] = {
    :stylesheets => 'app/stylesheets',
    :compiled_stylesheets => 'public/stylesheets/'
  }
  log_dir = File.join(MARQ.workdir,'merb', 'log')
  FileUtils.mkdir_p log_dir unless File.exist? log_dir
  c[:log_file] = File.join(log_dir,'log.txt')

end

module RedCloth::Formatters::HTML def br(opts); "\n"; end end
 
Merb::BootLoader.before_app_loads do
  # This will get executed after dependencies have been loaded but before your app's classes have loaded.

  require 'lib/helper'
  require 'MARQ/main'
  require 'MARQ/annotations'
  require 'MARQ/rankproduct'
end
 
tmpdir = File.join(MARQ.workdir, 'merb', 'tmp', 'images')
FileUtils.mkdir_p(tmpdir) unless File.exist?(tmpdir)

HOST      = ENV['MARQ_HOST'] || `hostname -f`
WSDL_FILE = MARQ.workdir + '/webservice/wsdl/MARQWS.wsdl'
MONITOR   = SimpleWS::Jobs::Notifier.new('MARQ', HOST, WSDL_FILE, :smtp_host => ENV['MARQ_SMTP'], :filename => File.join(MARQ.workdir, 'merb', 'tmp', 'emails.marshal'))

Merb::BootLoader.after_app_loads do
  # This will get executed after your app's classes have been loaded.

  CacheHelper.reset_locks

  MONITOR.start

  Merb::Assets::JavascriptAssetBundler.add_callback { |filename| Yui.compress(filename, {:stomp => true, :suffix => ""})} 
  Merb::Assets::StylesheetAssetBundler.add_callback { |filename| Yui.compress(filename, {:stomp => true, :suffix => ""})} 
end

