# requires
require 'optparse'
require 'yaml'
require 'active_support/core_ext/hash'
require 'rubydora'
require_relative 'datastream_transformation'

puts 'This script retrieves info for the given fedora pids'

# function definitions

# following is factored out as function in case the
# we decide to change format of the information within
# the yaml file -- these format changes would be localized
# to this method
def pids
  Array.new YAML.load_file('get_info_fedora_object_pids.yml')
end

def process_command_line_options_and_args(options = {}, args = {})

  # First, process options. Will use OptionParser.parse!, which removes
  # switches destructively. Non-option arguments remaun in argv

  OptionParser.new do |opts|
    opts.banner = "Usage: put stuff in here"

    opts.on("-fINPUTFILE", "--input_file=INPUTFILE", "yml file containing pids", Array) do |f|
      # fcd1, 05/26/17: for now, handle just one input file
      options[:input_file] = f
    end

  end.parse!

  args = ARGV

end

def process_repo_config
end

def process_pid_files(options = {}, pids = {})
  options[:input_file].each do |filename|
    raise "File does not exist" unless File.file?(filename)
    pids[filename] = Array.new YAML.load_file(filename)
    puts "File is #{filename}"
  end
  pids
end

def process_pids(repo, pids)

  # process each object
  pids.each do |pid|
    puts "Looking for fedora object with pid #{pid}"

    begin
      ac_obj = repo.find(pid)
    rescue Rubydora::RecordNotFound
      puts '************************ PID not found ***********************'
      next
    end

    puts "Processing fedora object #{ac_obj.pid}, DC Type currently set to #{ac_obj.get_dc_type}"
    puts "Processing fedora object #{ac_obj.pid}, DC Format currently set to #{ac_obj.get_dc_format}"
    puts "Processing fedora object #{ac_obj.pid}, mime type for CONTENT DS set to #{ac_obj.get_ds_mime_type 'CONTENT'}"
    puts "Processing fedora object #{ac_obj.pid}, label for CONTENT DS set to #{ac_obj.get_ds_label 'CONTENT'}"
    puts "Processing fedora object #{ac_obj.pid}, datastreams are #{ac_obj.datastreams.keys}"
    puts
  end

end

# class customization

# add module AssetRemediation to Rubydora::DigitalObject
class Rubydora::DigitalObject
  include DatastreamTransformation
end

# Main Processing

args = {}
options = {}
process_command_line_options_and_args( options, args)
puts "Called process_command_line_options_and_args"
puts "Content of options: #{options.inspect}"
puts "Content of ARGV: #{ARGV.inspect}"

pids_by_file = process_pid_files options
puts "Called process_pid_files"
puts pids_by_file.inspect

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
puts "You have 5 seconds to interrupt this script (Using ctl-c)"
(0..5).each do |i|
  print "#{i}.."
  sleep 1
end
puts 'Getting requested info for the given fedora pids'

repo = Rubydora.connect url: repoinfo[:url], user: repoinfo[:user], password: repoinfo[:password]
puts "Using Fedora Commons instance location at #{repo.config[:url]}"

pids_by_file.each  do |filename, pid_array|
  puts "About to process pids from file #{filename}"
  puts pid_array.inspect
  process_pids(repo, pid_array)
end




