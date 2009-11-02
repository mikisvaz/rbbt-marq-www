#!/usr/bin/ruby 

require 'MARQ'
require 'MARQ/main'
require 'MARQ/annotations'
require 'simplews/jobs'
require 'zlib'
require 'zaml'

class MARQWS < SimpleWS::Jobs
  class ArgumentError < Exception; end
  class NotDone < Exception; end 

  helper :gzip do |string|
    ostream = StringIO.new
    begin
      gz = Zlib::GzipWriter.new(ostream)
      gz.write(string)
      ostream.string
    ensure
      gz.close
    end
  end

  helper :gunzip do |file|
    begin
      gz = Zlib::GzipReader.new(File.open(file))
      gz.read
    end
  end

  def logratios(dataset, comparison, genes)
    path = MARQ.dataset_path(dataset)

    position = File.open(path + '.experiments').collect{|l| l.chomp.strip}.index(comparison.chomp.strip)
    raise ArgumentError, "Comparison #{ comparison.chomp.strip } not found" if position.nil?

    `paste #{path + '.codes'} #{path + '.logratios'}| grep '#{genes.collect{|gene| "^#{ gene }[[:space:]]"}.join('\|')}'|cut -f1,#{position + 2}`
  end

  def ts(dataset, comparison, genes)
    path = MARQ.dataset_path(dataset)
    if comparison.match(/\[ratio\]/) 
      raise ArgumentError, "Comparison  #{ comparison.chomp.strip } does not have a t value"
    end

    position = File.open(path + '.experiments').collect{|l| l.chomp.strip}.select{|name| !name.match(/\[ratio\]/)}.index(comparison.chomp.strip)
    raise ArgumentError, "Comparison #{ comparison.chomp.strip } not found" if position.nil?

    `paste #{path + '.codes'} #{path + '.t'}| grep '#{genes.collect{|gene| "^#{ gene }[[:space:]]"}.join('\|')}'|cut -f1,#{position + 2}`
  end

 
  task :annotations, %w(job type), {:job => :string, :type => :string}, ["annotations/{JOB}.yaml", "annotations/{JOB}_enriched.yaml"] do  |job, type|
    step(:scores, "Loading Scores")
    scores = YAML::load(gunzip(File.join(workdir, "scores/#{job}.yaml.gz")))
    
    step(:annotations, "Getting annotations")
    annotations, terms = Annotations.annotations(scores, type, 0.05, :rank)

    step(:saving, "Saving")
    
    write("annotations/#{job_name}.yaml", gzip(ZAML.dump(annotations)))
    write("annotations/#{job_name}_enriched.yaml", gzip(ZAML.dump(terms)))
  end

  task :match_platform, %w(platform up down), {:platform => :string, :up => :array, :down => :array},
    ['scores/{JOB}.yaml.gz' ] do |platform, up, down|

    up = up.collect{|gene| gene.strip if gene}
    down = down.collect{|gene| gene.strip if gene}

    info(:platform => platform,
         :organism => MARQ.platform_organism(platform),
         :up => up,
         :down => down
        )

    raise ArgumentError, "No genes identified" if up.empty? && down.empty?
    step(:matching, "Matching genes to platform #{ platform }, up: #{up.length}, down:  #{down.length}")
    scores = MARQ.platform_scores_up_down(platform, up, down)

    raise ArgumentError, "No genes matched in platform #{ platform }, check that they are in the right format, automatic transalation is not performed in platform specific queries" if scores.keys.empty?

    step(:saving, "Saving results")
    write("scores/#{job_name}.yaml.gz", gzip(ZAML.dump(scores)))
  end

  task :match_organism, %w(organism up down), {:organism => :string, :up => :array, :down => :array},
    ['scores/{JOB}.yaml.gz'] do |organism, up, down|
    require 'MARQ/ID'

    up = up.collect{|gene| gene.strip if gene}
    down = down.collect{|gene| gene.strip if gene}

    step(:translating, "Translating genes")

    cross_platform_up = ID.translate(organism, up)
    cross_platform_down = ID.translate(organism, down)

    info(:organism => organism,
         :up => up,
         :down => down,
         :cross_platform_up => cross_platform_up.collect{|n| n || "NO MATCH"},
         :cross_platform_down => cross_platform_down.collect{|n| n || "NO MATCH"})

    cross_platform_up = cross_platform_up.compact
    cross_platform_down = cross_platform_down.compact
    
    raise ArgumentError, "No genes identified" if cross_platform_up.empty? && cross_platform_down.empty?

    step(:matching, "Matching genes to organism #{ organism }, up: #{cross_platform_up.length}, down:  #{cross_platform_down.length}")
    
    platforms = MARQ::organism_platforms(organism).select{|platform| MARQ.has_cross_platform? nil, platform }.collect{|platform| platform + "_cross_platform"}

    scores = {}
    step(:processing, "Procesing #{platforms.length} datasets")
    platforms.each_with_index{|platform, i |
      step(:processing, "Generating Scores for platform #{ platform } #{ i + 1 }/#{platforms.length}.")
      scores = scores.merge(MARQ.platform_scores_up_down(platform, cross_platform_up, cross_platform_down))
    }
    step(:saving, "Saving results")
    write("scores/#{job_name}.yaml.gz", gzip(ZAML.dump(scores)))
  end

  
  
  class Scheduler::Job
    alias_method :old_step, :step
    def step(status, message=nil)
      puts "#{Time.now} => [#{ @name }]: #{ status }. #{ message }"
      old_step(status, message)
    end 
  end

  def initialize(*args)
    super(*args)
    @soaplet.allow_content_encoding_gzip = true

    serve :logratios, %w(dataset comparison genes), {:dataset => :string, :comparison => :string, :genes => :array, :return => :string}
    serve :ts, %w(dataset comparison genes), {:dataset => :string, :comparison => :string, :genes => :array, :return => :string}
    FileUtils.mkdir(File.join(workdir, 'scores')) unless File.exist?(File.join(workdir, 'scores'))
    FileUtils.mkdir(File.join(workdir, 'annotations')) unless File.exist?(File.join(workdir, 'annotations'))
  end


end

if __FILE__ == $0

  puts "Starting WS"
  host = ARGV[0] || `hostname`.chomp.strip + '.' +  `hostname -d`.chomp.strip
  port = ARGV[1] || '8282'

  puts "Starting Server in #{ host }:#{ port }"
  server = MARQWS.new("MARQ", "MARQ Web Server",host, port, File.join(MARQ.workdir,'webservice', 'jobs'))

  FileUtils.mkdir_p File.join(MARQ.workdir, '/webservice', 'wsdl/') unless File.exist? File.join(MARQ.workdir, '/webservice', 'wsdl/')
  File.open(File.join(MARQ.workdir, '/webservice', 'wsdl', 'MARQWS.wsdl'),'w'){|file| file.write server.wsdl}

  trap('INT') { server.shutdown }
  server.start

end


