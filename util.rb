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

class Stats
    attr_accessor(:core_total, :mem_total_in_KiB)
    def initialize
        @core_total = 0
        @mem_total_in_KiB = 0
    end
    def add_to_core_count(cores)
        @core_total += cores 
    end
    def add_to_mem_total(memory_in_KiB)
        @mem_total_in_KiB += memory_in_KiB
    end
end

begin
    # Required variables
    username    = 'jroberts'
    pemfile     = 'jroberts.pem'
    chefurl     = 'http://chefserver.ops.nastygal.com:4000'
    
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
        stats = Stats.new

        hypervisors[node]       = { 'kvm' => a.results['automatic']['virtualization']['kvm'] }
        time_of_last_chef_run   = Time.at(a.results['automatic']['ohai_time'])
        hypervisor_name         = node
        hypervisor_memory       = hypervisors[node]['kvm']['hardware']['Memory size']
        hypervisor_memory_float = (hypervisor_memory.split(" ", 2))[0].to_f
        hypervisor_cores        = (hypervisors[node]['kvm']['hardware']['CPU(s)']).to_i
        guest_cpu_total         = hypervisors[node]['kvm']['guest_cpu_total']
        guest_maxmemory_total   = hypervisors[node]['kvm']['guest_maxmemory_total']
        guest_used_memory_total = hypervisors[node]['kvm']['guest_usedmemory_total']
        guests                  = hypervisors[node]['kvm']['guests']

        puts # blank line
        printf "%-41s %-30s\n", "Host: #{hypervisor_name}", "Chef Run: #{time_of_last_chef_run}"
        puts "Host Mem: #{hypervisor_memory}"
        puts "Host Cores: #{hypervisor_cores}"
        puts "Guest CPU Total: #{guest_cpu_total}" 
        puts "Guest Max Mem Total: #{guest_maxmemory_total}"
        puts "Guest Used Mem Total: #{guest_used_memory_total}"
        puts # blank line
        printf "%-10s %-17s %-9s %-15s %-14s %-20s\n", "Guests:", "Host", "Cores", "Max Memory", "Used Memory", "State"

        guests.keys.each do |instance|
            name           = instance
            state          = hypervisors[node]['kvm']['guests'][instance]['state']
            cores          = (hypervisors[node]['kvm']['guests'][instance]['CPU(s)']).to_i
            used_mem       = hypervisors[node]['kvm']['guests'][instance]['Used memory']
            max_mem_in_KiB = hypervisors[node]['kvm']['guests'][instance]['Max memory']
            mem_float      = (max_mem_in_KiB.split(" ", 2))[0].to_f 

            if state == "running" # only include resources from running hosts
                stats.add_to_core_count(cores)
                stats.add_to_mem_total(mem_float)
            end

            printf "%-10s %-20s %-2s %15s %15s %10s\n", "", instance, cores, max_mem_in_KiB, used_mem, state
        end # guest.keys.each

        cores = stats.core_total.to_f / hypervisor_cores.to_f
        mem = stats.mem_total_in_KiB / hypervisor_memory_float

        puts # blank line
        puts "Provisioning Stats - Cores: #{(cores * 100).to_i}%  Memory: #{(mem * 100).to_i}%"
        60.times { print "-" }
        puts # blank line

    end # nodes.each
end # end of begin
