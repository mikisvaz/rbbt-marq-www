require 'MARQ/GEO'

class Series < Application
  def main
    @series = params[:series]

    if @series
      @series_info = GEO::GSE_info(@series)
      @sample_info = {}
      @gds = GEO::Eutils::GSE_dataset? @series
      @series_info[:samples].each{|gsm|
        @sample_info[gsm] = GEO::GSM_info(gsm)
      }
      if params[:conditions]
        info = {}
        info[:platform] = @series_info[:platform]
        info[:title] = @series_info[:title]
        info[:description] = @series_info[:description]
        info[:arrays] = {}
        conditions = params[:conditions].split("|")
        values = params[:values].split("|")
        @series_info[:samples].each{|sample|
          ph = {}
          conditions.each{|c|
            ph[c.strip] = values.shift.strip
          }
          info[:arrays][sample] = ph
        }

        headers["Content-Type"] =  'text/plain'
        headers["Content-Disposition"] =  "attachment; filename=#{@series}.yaml"

        info.to_yaml
      else
        render_deferred do
          render
        end
      end
    else
      render
    end
  end

end
