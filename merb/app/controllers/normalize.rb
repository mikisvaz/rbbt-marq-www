require 'MARQ/ID'

class Normalize < Application
  def index
    @organisms = Organism.all
    @ids = {}
    @organisms.each{|org|
      @ids[org] = Organism.supported_ids(org)
    }
    @found ||= []
    @missing ||= []
    
    render :template => 'normalize/index'
  end

  def post
    org = params[:org]
    missing = params[:missing].split(/[\s,]+/)
    found = params[:found].split(/[\s,]+/)
    id = params[:id]


    translations = ID.translate(org,missing, :to => id )

    
    p translations
    @found = @missing = []
    @found += found
    missing.zip(translations).each{|p| 
      if p[1] && p[1] != "NO MATCH"
        @found << p[1]
      else
        @missing << p[0]
      end
    }

    @found

    index
  end
end
