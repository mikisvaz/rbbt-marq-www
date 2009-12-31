
class Help < Application
  include CacheHelper
  def index
    cache("help") do
      render
    end
  end

  def meth
    cache("meth") do
      render
    end
  end

  def quick
    cache("quick") do
      render
    end
  end

  def webservice
    cache("webservice") do
      render
    end
  end

end
