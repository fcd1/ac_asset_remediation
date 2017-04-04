# requires
require 'yaml'
require 'active_support/core_ext/hash'
require 'rubydora'
require_relative 'datastream_transformation'

puts 'Getting requested info for the given fedora pids'

# function definitions

# following is factored out as function in case the
# we decide to change format of the information within
# the yaml file -- these format changes would be localized
# to this method
def pids
  Array.new YAML.load_file('get_info_fedora_object_pids.yml')
end

# add module AssetRemediation to Rubydora::DigitalObject
class Rubydora::DigitalObject
  include DatastreamTransformation
end


# read configs from yaml file. Complain if config is missing
# change the config filename to default to name in code but sup
CONFIG =  ActiveSupport::HashWithIndifferentAccess.new YAML.load_file('get_info_config.yml')

# read in the hyacinth allowed types for dc:type
ALLOWED_DC_TYPES = Array.new CONFIG[:hyacinth][:allowed_dc_types]

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
  ac_obj = repo.find(pid)

  puts "Processing fedora object #{ac_obj.pid}, DC Type currently set to #{ac_obj.get_dc_type}"
  puts "Processing fedora object #{ac_obj.pid}, DC Format currently set to #{ac_obj.get_dc_format}"
  puts "Processing fedora object #{ac_obj.pid}, mime type for CONTENT DS set to #{ac_obj.get_ds_mime_type 'CONTENT'}"
  puts "Processing fedora object #{ac_obj.pid}, label for CONTENT DS set to #{ac_obj.get_ds_label 'CONTENT'}"
  puts
end

