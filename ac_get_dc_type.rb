# requires
require 'yaml'
require 'active_support/core_ext/hash'
require 'rubydora'

puts 'Starting listing of DC type for AC assets'

# function definitions

# following is factored out as function in case the
# we decide to change format of the information within
# the yaml file -- these format changes would be localized
# to this method
def pids
  Array.new YAML.load_file('get_dc_type_fedora_object_pids.yml')
end

def get_dc_type(ac_obj)
  dc_ds = ac_obj.datastreams['DC']
  dc_ds_content = dc_ds.content.body
  # puts dc_ds_content
  re = %r{<dc:type>(.*)</dc:type>}
  b = re.match(dc_ds_content)
  # puts b.inspect
  # puts b[0]
  b[1]
end

# read configs from yaml file. Complain if config is missing
# change the config filename to default to name in code but sup
CONFIG =  ActiveSupport::HashWithIndifferentAccess.new YAML.load_file('get_dc_type_config.yml')
# puts CONFIG

# read in the hyacinth allowed types for dc:type
ALLOWED_DC_TYPES = Array.new CONFIG[:hyacinth][:allowed_dc_types]
# puts ALLOWED_DC_TYPES

raise 'url of repository missing' unless CONFIG.has_key? :fedora_repository
raise 'user for repository missing' unless CONFIG[:fedora_repository].has_key? :user
raise 'password for repository missing' unless CONFIG[:fedora_repository].has_key? :password
# raise 'foobar for repository missing' unless CONFIG[:fedora_repository].has_key? :foobar

repoinfo = CONFIG[:fedora_repository]
repo = Rubydora.connect url: repoinfo[:url], user: repoinfo[:user], password: repoinfo[:password]
# puts repo.inspect

# process each object
pids.each do |pid|
  ac_obj = repo.find(pid)
  # puts ac_obj.inspect
  
  puts "#{pid}, DC type: #{get_dc_type(ac_obj)}"
end

