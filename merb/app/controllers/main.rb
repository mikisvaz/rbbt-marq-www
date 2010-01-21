class Main < Application
  include CacheHelper

  def index
    @organisms = {}
    
    cache("main") do
      Organism.all.collect{|org| 
        [  
          org, 
          Organism.name(org), 
          MARQ.organism_platforms(org).sort{|a,b| 
            a.sub(/GPL/,'').to_i <=> b.sub(/GPL/,'').to_i
          }
        ]
      }.select{|p| 
        p[0].to_s != 'worm' &&  # Remove worm, it only has 11 datasets 
          p[2].any?
      }.each{|p| 
        @organisms[p[0]] = [p[1],p[2]]
      }
  
      headers["Expires"] = (Time.now + 31536000).to_s
      headers['Cache-Control'] = 'public, max-age=31536000'
  
  
      render
    end
  end

  def post
    platform = params[:platform]
    organism = params[:organism]
    ids_up   = params[:ids_up].split(/["\s,;]+/).uniq.collect{|gene| gene.strip}
    ids_down = params[:ids_down].split(/["\s,;]+/).uniq.collect{|gene| gene.strip}
    name     = params[:name].gsub(/\s/,'_')

    if platform == "cross"
      name = WS::match_organism(organism, ids_up, ids_down, name || "")
    else
      name = WS::match_platform(platform, ids_up, ids_down, name || "")
    end


    ip = request.env['HTTP_X_FORWARDED_FOR'] || request.env['REMOTE_ADDR']
    JobLog.log(ip, name)


    redirect "/#{ name }" 
  end

  def ajax_partial
    name = params[:name]
    job = params[:job]
    data = params[name.to_sym]

    @name = job
    partial "partials/#{name}", :with => data, :as => name.to_sym
  end
 
  def get_genes
    genes = params[:genes].split("|")

    headers["Content-Type"] =  'text/plain'
    headers["Content-Disposition"] =  'attachment; filename=genes.txt'

    genes.join("\n")
  end

  def wsdl
    headers["Content-Type"] =  'application/xml'
    headers["Content-Disposition"] =  'attachment; filename=MARQWS.wsdl'
    File.open(File.join(MARQ.workdir, 'webservice', 'wsdl', 'MARQWS.wsdl')) {|f| f.read }
  end


end
