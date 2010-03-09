require 'MARQ'
require 'MARQ/main'
require 'MARQ/fdr'
require 'MARQ/GEO'
require 'soap/wsdlDriver'
require 'yaml'
require 'zlib'
require 'stringio'
require 'base64'
require 'json'

require 'iconv' 

class String
  $ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
  def to_utf8
    $ic.iconv(self+ ' ')[0..-2]
  end

  alias_method :old_to_json, :to_json
  def to_json(*args)
    self.to_utf8.old_to_json(*args)
  end

end




def escapeURI(s)
  URI.escape(s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
end

def log(message)
  puts "#{Time.now}: #{ message }"
end

module JobLog

  LOG_DIR = File.join(MARQ.workdir,'merb','log')
  LOG_FILE = File.join(LOG_DIR,'jobs.log')

  FileUtils.touch LOG_FILE 

  def self.log(ip, job) 
    message = "#{Time.now}: #{ ip } => #{ job }"
    File.open(LOG_FILE, 'a').puts message
  end
end


module CacheHelper
  CACHE_DIR = File.join(MARQ.workdir, 'merb', 'cache')
  FileUtils.mkdir_p(CACHE_DIR) unless File.exist?(CACHE_DIR)

  class CacheLocked < Exception; end
  def self.reset
    FileUtils.rm Dir.glob(CACHE_DIR + '*')
  end

  def self.reset_locks
    FileUtils.rm Dir.glob(CACHE_DIR + '*.lock')
  end


  def self.build_filename(name, key)
    File.join(CACHE_DIR, name + ": " + Digest::MD5.hexdigest(key.to_s))
  end

  def self.do(filename, block)
    FileUtils.touch(filename + '.lock')
    t = Time.now
    data = block.call
    STDERR.puts "#{ filename } time: #{Time.now - t}"
    File.open(filename, 'w'){|f| f.write data}
    FileUtils.rm(filename + '.lock')
    return data
  end

  def clean(name)
    FileUtils.rm Dir.glob(CACHE_DIR + "#{ name }*")
  end

  def cache_ready?(name, key)
    filename = CacheHelper.build_filename(name, key)
    File.exist?(filename)
  end

  def cache(name, key = [], wait = nil, &block)
    filename = CacheHelper.build_filename(name, key)
    begin
      case
      when File.exist?(filename)
        return File.open(filename){|f| f.read}
      when File.exist?(filename + '.lock')
        raise CacheLocked
      else
        if wait.nil?
          CacheHelper.do(filename, block)
        else
          Thread.new{CacheHelper.do(filename, block)}
          return wait
        end

      end
    rescue CacheLocked
      if wait.nil?
        sleep 30
        retry
      else
        return wait
      end
    rescue Exception
      FileUtils.rm(filename + '.lock') if File.exist?(filename + '.lock')
      raise $!
    end
  end

  def marshal_cache(name, key = [])
    Marshal::load( cache(name, key) do
      Marshal::dump(yield)
    end)
  end


end

module WS
  
  class JobNotFound < Exception; end

  def self.gunzip(s)
    begin
      gz = Zlib::GzipReader.new(StringIO.new(s))
      gz.read
    rescue Exception
      puts $!.message
    ensure
      gz.close
    end
  end

  def self.compare(a,b)
    case 
    when a[:pvalue] < b[:pvalue]
      -1 
    when a[:pvalue] > b[:pvalue]
      1 
    when a[:pvalue] == b[:pvalue]
      b[:score].abs <=> a[:score].abs
    end
  end


  class << self
    include CacheHelper
  end

  def self.driver
    wsdl_url = MARQ.workdir + '/webservice/wsdl/MARQWS.wsdl'
    SOAP::WSDLDriverFactory.new(wsdl_url).create_rpc_driver
  end

  def self.logratios(dataset, comparison, genes)
    driver.logratios(dataset, comparison, genes)
  end

  def self.ts(dataset, comparison, genes)
    driver.ts(dataset, comparison, genes)
  end


  def self.match_platform(platform, up, down, name)
    driver.match_platform(platform, up, down, name)
  end

  def self.match_organism(organism, up, down, name)
    driver.match_organism(organism, up, down, name)
  end

  def self.info(job)
    begin
      YAML::load(driver.info(job))
    rescue Exception
      exit(-1) if $!.message =~ /Connection refused/
      raise JobNotFound, $!.message
    end
  end

  def self.cross_platform?(job)
    info(job)[:platform].nil?
  end

  def self.messages(job)
    driver.messages(job)
  end


  def self.status(job)
    driver.status(job)
  end

  require 'benchmark'
  def self.results(job)
    marshal_cache(job + '_results') do
      YAML::load(gunzip(Base64.decode64(driver.result(driver.results(job).first))))
    end
  end

  def self.genes(job)
    marshal_cache(job + '_genes') do
      info = info(job)
      genes = {:up => [], :down => [], :missing_up => [], :missing_down => []}

      info[:cross_platform_up]   ||= info[:up] 
      info[:cross_platform_down] ||= info[:down]

      info[:up].zip(info[:cross_platform_up]).each{|p|
        if p[1] == "NO MATCH"
          genes[:missing_up] << p
        else
          genes[:up] << p
        end
      }

      info[:down].zip(info[:cross_platform_down]).each{|p|
        if p[1] == "NO MATCH"
          genes[:missing_down] << p
        else
          genes[:down] << p
        end
      }
      genes
    end
  end

  def self.translations(job)
    marshal_cache(job + '_translations') do
      info = info(job)

      info[:cross_platform_up]   ||= info[:up] 
      info[:cross_platform_down] ||= info[:down]


      translations = {}
      translations.merge!(Hash[*info[:up].zip(info[:cross_platform_up]).flatten])
      translations.merge!(Hash[*info[:down].zip(info[:cross_platform_down]).flatten])

      translations
    end
  end

  def self.sort_results(job)
    marshal_cache(job + '_sort_results') do

      results = results(job)
      FDR.adjust_hash!(results, :pvalue)

      pos  = [] 
      neg  = []
      null = []

      results.sort{|a,b| compare(a[1],b[1])}.each{|p|
        null << p if p[1][:score] == 0
        pos << p if p[1][:score] > 0
        neg << p if p[1][:score] < 0
      }

      pos + null + neg.reverse
    end
  end

  def self.annotations(job, type)
    marshal_cache("#{ job }_annotations",type) do
      j = driver.annotations(job, type, "#{ job }_annotations_#{type}")

      while !driver.done(j)
        sleep 3
      end

      raise driver.messages(j).last if driver.error(j)
      annotations = YAML::load(gunzip(Base64.decode64(driver.result(driver.results(j).first))))
      terms       = YAML::load(gunzip(Base64.decode64(driver.result(driver.results(j).last))))

      [annotations, terms]
    end
  end

end



class Hash
  def slice(list)
    copy = {}
    ( list & self.keys).each{|k|
      copy[k] = self[k]
    }
    copy
  end
end

module CompareGenes
  module RankProduct

    class << self
      include CacheHelper
    end

    def self.filename(job, signatures, invert)
      filename = File.join(MARQ.workdir, 'merb', 'tmp' , 'compare_' +  Digest::MD5.hexdigest({:job => job, :signatures => signatures, :invert => invert}.inspect))
    end

    def self.compare(job, signatures, invert)
      filename = filename(job, signatures, invert)
      marshal_cache("compare", {:job => job, :signatures => signatures, :invert => invert}) do
        scores_up = Object::RankProduct.rankproduct(signatures, :invert => invert, :cross_platform => WS::cross_platform?(job))
        scores_down = Object::RankProduct.rankproduct(signatures, :invert => signatures - invert, :cross_platform => WS::cross_platform?(job))

        FileUtils.rm(filename + '.tsv') if File.exist? filename + '.tsv'
        FileUtils.rm(filename + '.xls') if File.exist? filename + '.xls'
        [scores_up, scores_down]
      end
    end

    def self.prepare_files(job, signatures, invert, genes_up, genes_down)
      filename = filename(job, signatures, invert)
      if ! File.exist?(filename + '.tsv')
        scores_up, scores_down = self.compare(job, signatures, invert).values_at(0,1)
        total_genes = scores_up.keys.sort
        synonyms = Info::synonyms(WS::info(job)[:organism], total_genes, true)

        rows = total_genes.collect{|gene|

          up, pvalue_up, pfp_up       = scores_up[gene].values_at(0,1,2)
          down, pvalue_down, pfp_down = scores_down[gene].values_at(0,1,2)
          query_up   = genes_up.include? gene
          query_down = genes_down.include? gene
          syn        = synonyms[gene].join(", ")

          [gene, up, pvalue_up, pfp_up, down, pvalue_down, pfp_down, query_up, query_down, syn]
        }
        id_name = (WS::cross_platform?(job) ? Organism.supported_ids(WS::info(job)[:organism]).first : 'ID' )
        header = [id_name,'RP up log-score','RP up p-value', 'RP up pfp', 'RP down log-score','RP down p-value', 'RP down pfp', 'Present in the up query list','Present in the down query list', 'Synonyms']



        Open.write(filename + '.tsv', 
          '#' + header.join("\t") + "\n" +
          rows.collect{|row| row.join("\t")}.join("\n")
        )

        book  = Spreadsheet::Workbook.new
        sheet = book.create_worksheet :name => 'RankProduct'
        sheet.row(0).concat header

        rows.each_with_index{|row, i|
          sheet.row(i + 1).concat row
        }

        book.write( filename + '.xls')
      end
      [filename + '.tsv', filename + '.xls']

    end
  end
end

module Info

  @@gpl = {}
  GEO::platforms.each { |platform| @@gpl[platform] = MARQ::Platform.datasets(platform) }

  @@info = {}
  def self.info(dataset)
    @@info[dataset] ||= MARQ::Dataset.info(dataset)
  end


  @@exp = {}
  def self.parse_experiment(experiment)
    @@exp[experiment] ||=  Hash[*[:gds, :condition, :name].zip(experiment.match(/^(.+?): (.+?): (.*)/).values_at(1,2,3)).flatten]
  end

  @@lexicon = {}
  def self.synonyms(org, genes, native = false)
    if native
      native = genes
    else
      native = ID.translate(org, genes) 
    end
    @@lexicon[org] ||= Organism.lexicon(org, :flatten => true)
    synonyms = {}
    genes.zip(native).each{|p|
      synonyms[p[0]] = @@lexicon[org][p[1]] || []
    }
    synonyms
  end

  @@translations = {}
  def self.to_GPL_format(gpl, genes)
    if @@translations[gpl].nil?
      @@translations[gpl] = {}
      `paste '#{File.join(MARQ.datadir, 'GEO', gpl,'codes') }' '#{File.join(MARQ.datadir, 'GEO', gpl,'translations')}'`.each{|l|
        orig, native = l.chomp.split(/\t/).values_at(0,1)
        next if native =~ /NO MATCH/
        @@translations[gpl][native] ||= [] 
        @@translations[gpl][native] << orig
        @@translations[gpl][orig] ||= [] 
        @@translations[gpl][orig] << orig
      }
    end
    @@translations[gpl].values_at(*genes).collect{|v| v || []}
  end

  module GO
    require 'rbbt/sources/go'

    def self.name(term)
      Object::GO::id2name(term)
    end
  end

end


