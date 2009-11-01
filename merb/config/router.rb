# Merb::Router is the request routing mapper for the merb framework.
#
# You can route a specific URL to a controller / action pair:
#
#   match("/contact").
#     to(:controller => "info", :action => "contact")
#
# You can define placeholder parts of the url with the :symbol notation. These
# placeholders will be available in the params hash of your controllers. For example:
#
#   match("/books/:book_id/:action").
#     to(:controller => "books")
#   
# Or, use placeholders in the "to" results for more complicated routing, e.g.:
#
#   match("/admin/:module/:controller/:action/:id").
#     to(:controller => ":module/:controller")
#
# You can specify conditions on the placeholder by passing a hash as the second
# argument of "match"
#
#   match("/registration/:course_name", :course_name => /^[a-z]{3,5}-\d{5}$/).
#     to(:controller => "registration")
#
# You can also use regular expressions, deferred routes, and many other options.
# See merb/specs/merb/router.rb for a fairly complete usage sample.

Merb.logger.info("Compiling routes...")
Merb::Router.prepare do
  # RESTful routes
  # resources :posts

  # This is the default route for /:controller/:action/:id
  # This is fine for most cases.  If you're heavily using resource-based
  # routes, you may want to comment/remove this line to prevent
  # clients from calling your create or destroy actions with a GET
  #default_routes
  
  # Change this for your home page to be available at /
  match('/images/:image').to(:controller => 'results', :action => 'images')
  match('/logratios').to(:controller => 'results', :action => 'logratios')
  match('/ts').to(:controller => 'results', :action => 'ts')
  match('/compare').to(:controller => 'results', :action => 'compare')
  match('/experiment_hits').to(:controller => 'results', :action => 'explore_hits')
  match('/experiment_info').to(:controller => 'results', :action => 'ajax_experiment')
  match('/annotations').to(:controller => 'results', :action => 'ajax_annotations')
  match('/partial').to(:controller => 'main', :action => 'ajax_partial')
  match('/partial').to(:controller => 'main', :action => 'ajax_partial')
  match('/genes').to(:controller => 'main', :action => 'get_genes')
  match('/normalize', :method => :post).to(:controller => 'normalize', :action => 'post')
  match('/normalize').to(:controller => 'normalize', :action => 'index')
  match('/images/:job').to(:controller => 'results', :action => 'images')

  match('/series/').to(:controller => 'series', :action => 'main')
  match('/help/').to(:controller => 'help', :action => 'index')
  match('/help/methods').to(:controller => 'help', :action => 'meth')
  match('/help/quick').to(:controller => 'help', :action => 'quick')

  match('/:job').to(:controller => 'results', :action => 'main')
  match('/', :method => :post).to(:controller => 'main', :action =>'post')
  match('/').to(:controller => 'main', :action =>'index')


end
