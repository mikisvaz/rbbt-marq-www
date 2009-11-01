module Merb
  module ResultsHelper
    
    def span_words(text, stem = true)
      text.split(/(\w+)/).collect{|w|
        if stem
          t = w.downcase.stem
        else
          t = w
        end

       if w =~ /\w/
          "<span class='word' data-stem='#{t}' >#{ w }</span>" 
        else
          w
        end
      }.join("")
    end

    def annotation_term(type, term)
      case 
      when type == "GO_up" || type == "GO_down"
        Info::GO::name(term)
      else
        term
      end
    end

    def gene_url(org, gene) 
      case org.to_s
      when 'sgd':  return "http://db.yeastgenome.org/cgi-bin/locus.pl?dbid=" + gene 
      when 'cgd':  return "http://www.candidagenome.org/cgi-bin/locus.pl?dbid=" + gene 
      when 'rgd':  return "http://rgd.mcw.edu/tools/genes/genes_view.cgi?id=" + gene.sub(/RGD:/,'') 
      when 'mgi':  return "http://www.informatics.jax.org/javawi2/servlet/WIFetch?page=markerDetail&id=" + gene
      when 'pombe':  return "http://www.genedb.org/genedb/Search?organism=pombe&isid=true&name=" + gene
      when 'human':  return "http://www.ncbi.nlm.nih.gov/sites/entrez?Db=gene&Cmd=ShowDetailView&ordinalpos=1&itool=EntrezSystem2.PEntrez.Gene.Gene_ResultsPanel.Gene_RVDocSum&TermToSearch=" + gene
      else return nil   
      end
    end

    def print_pvalue(pvalue, min = 0.001)
      if pvalue == 0
        "< #{min}"
      else
        "%1.3g" % pvalue
      end
    end
  end

end # Merb
