# requires
require 'yaml'
require 'active_support/core_ext/hash'
require 'rubydora'
require_relative 'datastream_transformation'

puts 'Set DC type for the given fedora pids'

# function definitions

# following is factored out as function in case the
# we decide to change format of the information within
# the yaml file -- these format changes would be localized
# to this method
def pids
  Array.new YAML.load_file('set_dc_type_fedora_object_pids.yml')
end

# add module AssetRemediation to Rubydora::DigitalObject
class Rubydora::DigitalObject
  include DatastreamTransformation
end


# read configs from yaml file. Complain if config is missing
# change the config filename to default to name in code but sup
CONFIG =  ActiveSupport::HashWithIndifferentAccess.new YAML.load_file('set_dc_type_config.yml')

# read in the hyacinth allowed types for dc:type
ALLOWED_DC_TYPES = Array.new CONFIG[:hyacinth][:allowed_dc_types]

# read in mapping between CONTENT mime type and Hyacinth-approved DC type
MIME_TYPE_TO_DC_TYPE_MAPPING =
  ActiveSupport::HashWithIndifferentAccess.new YAML.load_file('mime_type_to_dc_type_mapping.yml')
puts 'Mapping starts here'
puts MIME_TYPE_TO_DC_TYPE_MAPPING.inspect
puts 'Mapping ends here'

raise 'url of repository missing' unless CONFIG.has_key? :fedora_repository
raise 'user for repository missing' unless CONFIG[:fedora_repository].has_key? :user
raise 'password for repository missing' unless CONFIG[:fedora_repository].has_key? :password

repoinfo = CONFIG[:fedora_repository]
puts "Repository url is set to #{repoinfo[:url]}"
puts "Is this correct? If so, please type in 'Yes' to continue with the script"
response = gets.chomp
raise "User aborted script by not entering 'Yes'" unless response.eql?('Yes')
puts "User Answered 'Yes'"
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

  # puts "Processing fedora object #{ac_obj.pid}, DC Type currently set to #{ac_obj.get_dc_type}"
  # puts "Set DC type to Sound"
  # ac_obj.set_dc_type 'Sound'
  # puts "Processing fedora object #{ac_obj.pid}, DC Type currently set to #{ac_obj.get_dc_type}"
  puts
end
