#! env ruby
require 'chef' 
require 'chef/rest' 
require 'chef/search/query' 
require 'chef/node' 
#require 'sinatra'
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
      #set :bind, '0.0.0.0' # IP Sinatra should bind to 
      
  #get '/' do 
      # AUTH - connect to ChefServer with valid user and pemfile
      credentials = ChefClient.new(username, pemfile, chefurl)

      # SEARCH - get array of nodes based on search
      q = NodeQuery.new(credentials.url)
      nodes = q.search('role:hypervisor')

      # NODES - get per node attrs and create a hash key for each node
      hypervisors = {}
      guests = {}
      nodes.each do |node|
        a = NodeAttrs.new(node)

        hypervisors[node] =  { 'kvm' => a.results['automatic']['virtualization']['kvm'] }
        hypervisor_name = node
        hyp_mem = hypervisors[node]['kvm']['hardware']['Memory size']
        hyp_cores = hypervisors[node]['kvm']['hardware']['CPU(s)']
        guest_cpu_total = hypervisors[node]['kvm']['guest_cpu_total']
        guest_maxmemory_total = hypervisors[node]['kvm']['guest_maxmemory_total']
        guest_used_memory_total = hypervisors[node]['kvm']['guest_usedmemory_total']
        guests = hypervisors[node]['kvm']['guests']

        puts # blank line
        puts "Host: #{hypervisor_name}"
        puts "Host Mem: #{hyp_mem}"
        puts "Host Cores: #{hyp_cores}"
        puts "Guest CPU Total: #{guest_cpu_total}" 
        puts "Guest Max Mem Total: #{guest_maxmemory_total}"
        puts "Guest Used Mem Total: #{guest_used_memory_total}"
        puts "Guests:"

        guests.keys.each do |instance|
            name = instance
            max_mem = hypervisors[node]['kvm']['guests'][instance]['Max memory']
            used_mem = hypervisors[node]['kvm']['guests'][instance]['Used memory']
            cores = hypervisors[node]['kvm']['guests'][instance]['CPU(s)']
            state = hypervisors[node]['kvm']['guests'][instance]['state']

            printf "%-10s %-20s %-2s %15s %15s %10s\n", "", instance, cores, max_mem, used_mem, state
        end # guest.keys.each

        puts # blank line
        cores = guest_cpu_total.to_f / hyp_cores.to_f
        mem = (guest_maxmemory_total.split(" ", 2))[0].to_f / (hyp_mem.split(" ", 2))[0].to_f
        puts "Provisioning  CPU: #{(cores * 100).to_i}%  Memory: #{(mem * 100).to_i}%"
        60.times { print "-" }
        puts # blank line
      end # nodes.each
 # end # sinatra end
  

end # end of begin
