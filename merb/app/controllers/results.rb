class Results < Application
  include CacheHelper

  def main
    name = params[:job]

    @name = name

    begin
      info = WS::info(name)
    rescue WS::JobNotFound
      @message = $!.message
      return render :template =>  'results/error'
    end

    @up   = info[:up]
    @down = info[:down]

    case WS::status(name)
    when 'done'
      render_deferred do
        @title = "[HTML] #{ name }"
        @message = "Job #{ name } has finished correctly. The results page is been generated"
        wait = render :template => 'results/wait'
        cache("#{@name}_results", {:job => @name}, wait ) do
          @results = WS::sort_results(name)
          @title = "#{ name }"
  
          headers["Expires"] = (Time.now + 31536000).to_s
          headers['Cache-Control'] = 'public, max-age=31536000'
  
          render
        end
      end
    when 'error'
      @message = WS::messages(name).last
      render :template =>  'results/error'
    else
      @title = "[#{WS::status(name)}] #{ name }"
      @message = WS::messages(name).last

      render :template =>  'results/wait'
    end

  end
  
  def images
    @name = params[:job]
    @experiment = params[:experiment]

    @hash = @experiment.hash_code
    render
  end

  def ajax_annotations
    job = params[:job]
    type = params[:type]
    
    render_deferred do
      annotations, terms = WS::annotations(job, type)
      {:annotations => annotations, :terms => terms}.to_json
    end
  end

  def images
    image = params[:image]
    Open.read(File.join(MARQ.workdir, 'merb', 'tmp', 'images', image))
  end
 
  def ajax_experiment
    job = params[:job]
    experiment = params[:experiment]

    results = WS::results(job)
    
    up   = results[experiment][:up][:positions].compact  if results[experiment][:up][:positions]
    down = results[experiment][:down][:positions].compact if results[experiment][:down][:positions]

    info = {}
    if up 
      up_filename = File.join(MARQ.workdir, 'merb', 'tmp', 'images', (experiment + '_up').hash.to_s)
      Score.draw_hits(up, results[experiment][:up][:total], up_filename, {:size => 1000, :bg_color => :green})
      info[:up] = up_filename.sub(/^.*tmp/,'')
    end

    if down 
      down_filename = File.join(MARQ.workdir, 'merb', 'tmp', 'images', (experiment + '_down').hash.to_s)
      Score.draw_hits(down,  results[experiment][:down][:total], down_filename, {:size => 1000, :bg_color => :green})
      info[:down] = down_filename.sub(/^.*tmp/,'')
    end

    @job = job
    @experiment = experiment

    dataset, condition, name = experiment.match(/^(.+?): (.+?): (.*)/).values_at(1,2,3)
    info[:dataset] = dataset
    info[:condition] = condition
    info[:name] = name
    info[:title] = Info::info(dataset)[:title]
    info[:description] = Info::info(dataset)[:description]
    partial 'partials/experiment', :with => info, :as => :info
  end
  

  def explore_hits
    job        = params[:job]
    experiment = params[:experiment]
    up         = params[:side] =~ /up/i

    results = WS::results(job)
    
    genes = WS::genes(job)
    
    if experiment =~ /^(GDS\d+)/
      gds = $1
    else
      gds = nil
    end
    @translations = {}
    if up
      @hits = genes[:up].zip(results[experiment][:up][:positions])
      @total = results[experiment][:up][:total]
      native = genes[:up].collect{|p| p.last}
      native.zip(Info.to_GPL_format(GEO.dataset_platform(gds), native)).each{|p| @translations[p.first] = p.last} if gds
    else
      @hits = genes[:down].zip(results[experiment][:down][:positions]) 
      @total = results[experiment][:up][:total]
      native = genes[:down].collect{|p| p.last}
      native.zip(Info.to_GPL_format(GEO.dataset_platform(gds), native)).each{|p| @translations[p.first] = p.last} if gds
    end
    
    org = WS::info(job)[:organism]
    @synonyms = Info::synonyms(org, (genes[:up] + genes[:down]).collect{|p| p[1] }.compact.uniq, WS::info(job)[:platform].nil?)

    @hits = @hits.reject{|p| p[1].nil?}.sort{|a,b| 
      a[1].to_i <=> b[1].to_i
    }

    @gds = gds
    @name = experiment
    @job = job
    @org = org

    render
  end

  def logratios
    job = params[:job]
    experiment = params[:experiment]
    genes = params[:genes].split(',')
    
    dataset, condition = experiment.match(/^(.*?:) (.*)/).values_at(1,2)

    headers["Content-Type"] =  'text/plain'
    headers["Content-Disposition"] =  'attachment; filename=logratios.txt'

    if genes && genes.any?
      translations = WS::translations(job)
      cross = translations.values_at(*genes)
      inverse = translations.invert
      WS::logratios(dataset.sub(/:$/,'_cross_platform'), condition, cross.compact).sort.collect{|l| 
        code, value = l.chomp.split(/\t/).values_at(0,1)
        next if inverse[code].nil?
        "#{inverse[code]}\t#{value}"
      }.join("\n")
    else
      WS::logratios(dataset.sub(/:$/,'_cross_platform'), condition, [])
    end
  end

  def ts
    job = params[:job]
    experiment = params[:experiment]
    genes = params[:genes].split(',')
    
    dataset, condition = experiment.match(/^(.*?:) (.*)/).values_at(1,2)

    headers["Content-Type"] =  'text/plain'
    headers["Content-Disposition"] =  'attachment; filename=t-values.txt'

    if genes && genes.any?
      translations = WS::translations(job)
      cross = translations.values_at(*genes)
      inverse = translations.invert
      WS::ts(dataset.sub(/:$/,'_cross_platform'), condition, cross.compact).sort.collect{|l| 
        code, value = l.chomp.split(/\t/).values_at(0,1)
        next if inverse[code].nil?
        "#{inverse[code]}\t#{value}"
      }.join("\n")
    else
      WS::ts(dataset.sub(/:$/,'_cross_platform'), condition, [])
    end
  end


  def compare
    job = params[:job]
    signatures = params[:experiments].scan(/[^|]+/)
    invert = (params[:invert] || "").scan(/[^|]+/)
    format = params[:format]

    @url = "/compare?" + request.env['QUERY_STRING']
    @job = job
    case
    when format == 'tsv'
      headers["Content-Type"] =  'text/plain'
      headers["Content-Disposition"] =  'attachment; filename=rankproduct.txt'
    when format == 'excel'
      headers['Content-Type'] = "application/vnd.ms-excel"
      headers['Content-Disposition'] = "attachment; filename=\"rankproduct.xls\""
      headers['Cache-Control'] = ''
    end
  
    render_deferred do
      genes = WS::genes(job)
      @genes_up   = genes[:up] || []
      @genes_down = genes[:down] || []
  
      @genes_up.collect!{|p| p[1]}
      @genes_down.collect!{|p| p[1]}
      @org = WS::info(job)[:organism]
  
  
  
      @scores_up, @scores_down = CompareGenes::RankProduct.compare(job, signatures, invert)
  
      case
      when format == 'tsv'
        filename = CompareGenes::RankProduct.prepare_files(job, signatures, invert, @genes_up, @genes_down)[0]
        Open.read(filename)
      when format == 'excel'
        filename = CompareGenes::RankProduct.prepare_files(job, signatures, invert, @genes_up, @genes_down)[1]
        Open.read(filename)
      else
        cache('compare', params) do
          threshold = 0.05
          @sorted_up = @scores_up.select{|gene, info| info[1] < threshold}.sort{|a,b| a[1][0] <=> b[1][0]}
          @sorted_down = @scores_down.select{|gene, info| info[1] < threshold}.sort{|a,b| a[1][0] <=> b[1][0]}
          @synonyms = Info::synonyms(WS::info(job)[:organism], @scores_up.keys, true)
          @translations = WS::translations(job).invert
          render
        end
      end
    end
  end


end
