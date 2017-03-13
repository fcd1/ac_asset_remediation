require 'yaml'
require 'active_support/core_ext/hash'
require 'rubydora'
require_relative 'datastream_transformation'

# following is factored out as function in case the
# we decide to change format of the information within
# the yaml file -- these format changes would be localized
# to this method
def pids
  Array.new YAML.load_file('fedora_object_pids.yml')
end

# add module AssetRemediation to Rubydora::DigitalObject
class Rubydora::DigitalObject
  include DatastreamTransformation
end

# read configs from yaml file. Complain if config is missing
# change the config filename to default to name in code but sup
CONFIG =  ActiveSupport::HashWithIndifferentAccess.new YAML.load_file('config.yml')

# read in the hyacinth allowed types for dc:type
ALLOWED_DC_TYPES = Array.new CONFIG[:hyacinth][:allowed_dc_types]

raise 'url of repository missing' unless CONFIG.has_key? :fedora_repository
raise 'user for repository missing' unless CONFIG[:fedora_repository].has_key? :user
raise 'password for repository missing' unless CONFIG[:fedora_repository].has_key? :password

repoinfo = CONFIG[:fedora_repository]
repo = Rubydora.connect url: repoinfo[:url], user: repoinfo[:user], password: repoinfo[:password]
puts "Using Fedora Commons instance location at #{repo.config[:url]}"

# process each object
pids.each do |pid|

  puts "Looking for fedora object with pid #{pid}"

  begin
    ac_obj = repo.find(pid)
  rescue Rubydora::RecordNotFound
    puts '************************ PID not found ***********************'
    next
  end

  dc_type =  ac_obj.get_dc_type

  puts "Processing fedora object #{ac_obj.pid}, DC Type currently set to #{dc_type}"

  # fcd1, 03/06/17: testing the set_dc_type method
  # ac_obj.set_dc_type 'Text'
  # puts "Processing fedora object #{ac_obj.pid}, DC Type currently set to #{dc_type}"

  if ALLOWED_DC_TYPES.include? dc_type
    puts "DC Type is valid"
  else
    puts "DC Type is invalid"

    # fcd1, 03/12/17: only do the following in certain all objects
    # should have DC type set to 'Text'
    # puts "Seting DC Type to Text"
    # ac_obj.set_dc_type 'Text'
  end

  # remediate the DC type
  # remediate_dc_type ac_obj

  # Add genericResource to RELS_EXT hasModel
  ac_obj.add_generic_reource_to_has_model

  # create the new 'content' datastream based on the existing 'CONTENT' datastream
  ac_obj.copy_content_datastream('CONTENT','content')

  # add extent size_of_datastream for 'content' datastream
  ac_obj.add_relationship_to_content_datastream_predicate_extent_object_size
end
