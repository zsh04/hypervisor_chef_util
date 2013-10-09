#! env ruby
require 'chef' 
require 'chef/rest' 
require 'chef/search/query' 
require 'chef/node' 
require 'sinatra'
require 'json'


class ChefClient
  attr_accessor :name, :key, :url
  def initialize(name, key, url)
    @name = name 
    @key  = key
    @url  = url

    Chef::Config[:node_name]=name
    Chef::Config[:client_key]=key
    Chef::Config[:chef_server_url]=url
  end
end # end of class Chef::Config


class NodeAttrs
  attr_accessor :results
  def initialize(node)
    var = Chef::Node.load(node)
    @results = var.display_hash
  end
end


class NodeQuery
  def initialize(url)
    @var = Chef::Search::Query.new(url)
  end
  def search(query)
    nodes = []
    results = @var.search('node', query)
    justNodes = results[0..(results.count - 3)] # drop the last 2 indexes
    justNodes[0].each do |host|
      nodes << host.to_s[/\[(.*?)\]/].tr('[]', '')  # take the name leave the canoli
    end
    return nodes
  end
end


begin
  # Required variables
  username    = 'jroberts'
  pemfile     = 'jroberts.pem'
  chefurl     = 'http://chefserver.ops.nastygal.com:4000'
  set :bind, '0.0.0.0' # IP Sinatra should bind to 
  
  # AUTH - connect to ChefServer with valid user and pemfile
  credentials = ChefClient.new(username, pemfile, chefurl)

  # SEARCH - get array of nodes based on search
  q = NodeQuery.new(credentials.url)
  nodes = q.search('role:hypervisor')

  # NODES - get per node attrs and create a hash key for each node
  hypervisors = {}
  nodes.each do |node|
    a = NodeAttrs.new(node)
    hypervisors[node] =  { 'kvm' => a.results['automatic']['virtualization']['kvm'] }

    # Sinatra - make the json available via http://0.0.0.0:4567
    get "/#{node}" do
      content_type :json
      hypervisors[node].to_json
    end
  end

end # begin
