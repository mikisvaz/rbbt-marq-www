require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "rbbt-marq-www"
    gem.summary = %Q{MARQ online interface (SOAP, merb)}
    gem.description = %Q{This package contains a SOAP web server and a merb application.}
    gem.email = "miguel.vazquez@fdi.ucm.es"
    gem.homepage = "http://github.com/mikisvaz/rbbt-marq-www"
    gem.authors = ["Miguel Vazquez"]

   
    gem.files = Dir['merb/', 'webservice']
    gem.files.exclude 'merb/tmp/*' 
    gem.files.exclude 'merb/public/tmp'
    gem.files.exclude 'merb/public/results'
    gem.files.exclude 'merb/public/data'

    gem.add_dependency('rbbt')
    gem.add_dependency('rbbt-marq')

    gem.add_dependency('merb')
    gem.add_dependency('simplews')
    gem.add_dependency('ruby-yui')
    gem.add_dependency('spreadsheet')
    gem.add_dependency('RedCloth')
    gem.add_dependency('rand')
    gem.add_dependency('zaml')
    gem.add_dependency('compass')


    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/test_*.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :test => :check_dependencies

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "rbbt-marq-www #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
