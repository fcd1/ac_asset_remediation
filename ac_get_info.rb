# requires
require 'optparse'
require 'yaml'
require 'active_support/core_ext/hash'
require 'rubydora'
require_relative 'datastream_transformation'

class GetInfoProcessing

  attr_reader :options, :pids_by_file, :args, :repo_info

  def initialize
    @options = {}
    @pids_by_file = {}
  end

  def process_command_line_options_and_args

    # First, process options. Will use OptionParser.parse!, which removes
    # switches destructively. Non-option arguments remaun in argv

    OptionParser.new do |opts|
      opts.banner = "Usage: put stuff in here"

      opts.on("-fINPUTFILE", "--input_file=INPUTFILE", "yml file containing pids", Array) do |f|
        # fcd1, 05/26/17: for now, handle just one input file
        @options[:input_files] = f
      end

    end.parse!

    @args = ARGV

  end

  def process_repo_config
    # read configs from yaml file. Complain if config is missing
    # change the config filename to default to name in code but sup
    @config_info =  ActiveSupport::HashWithIndifferentAccess.new YAML.load_file('get_info_config.yml')

    # read in the hyacinth allowed types for dc:type
    @allowed_dc_types = Array.new @config_info[:hyacinth][:allowed_dc_types]

    raise 'url of repository missing' unless @config_info.has_key? :fedora_repository
    raise 'user for repository missing' unless @config_info[:fedora_repository].has_key? :user
    raise 'password for repository missing' unless @config_info[:fedora_repository].has_key? :password

    @repo_info = @config_info[:fedora_repository]
  end

  def connect_to_repo

    @repo = Rubydora.connect url: @repo_info[:url], user: @repo_info[:user], password: @repo_info[:password]
    puts "Using Fedora Commons instance location at #{@repo.config[:url]}"

  end

  def process_pid_files
    @options[:input_files].each do |filename|
      raise "File does not exist" unless File.file?(filename)
      @pids_by_file[filename] = Array.new YAML.load_file(filename)
    end
  end

  def process_pids(pids)

    count = 0
    num_of_pids = pids.length
    puts "Total number of pids is #{num_of_pids}"
    puts

    # process each object
    pids.each do |pid|
      puts "Looking for fedora object with pid #{pid}"

      begin
        ac_obj = @repo.find(pid)
      rescue Rubydora::RecordNotFound
        puts '************************ PID not found ***********************'
        next
      end

      puts "Processing fedora object #{ac_obj.pid}, DC Type currently set to #{ac_obj.get_dc_type}"
      puts "Processing fedora object #{ac_obj.pid}, DC Format currently set to #{ac_obj.get_dc_format}"
      puts "Processing fedora object #{ac_obj.pid}, mime type for CONTENT DS set to #{ac_obj.get_ds_mime_type 'CONTENT'}"
      puts "Processing fedora object #{ac_obj.pid}, label for CONTENT DS set to #{ac_obj.get_ds_label 'CONTENT'}"
      puts "Processing fedora object #{ac_obj.pid}, datastreams are #{ac_obj.datastreams.keys}"
      puts "Processing fedora object #{ac_obj.pid}, profile is #{ac_obj.profile.inspect}"

      count += 1
      puts "number of processed pids: #{count} out of #{num_of_pids}"

      puts

    end

  end

end

# class customization

# add module AssetRemediation to Rubydora::DigitalObject
class Rubydora::DigitalObject
  include DatastreamTransformation
end

# Main Processing

puts 'This script retrieves info for the given fedora pids'
puts

gip = GetInfoProcessing.new

gip.process_command_line_options_and_args
# puts "Called #process_command_line_options_and_args"
# puts "Content of options: #{gip.options.inspect}"
# puts "Content of ARGV: #{gip.args.inspect}"

gip.process_repo_config

gip.process_pid_files
# puts "Called process_pid_files"
# puts gip.pids_by_file.inspect

puts "Repository url is set to #{gip.repo_info[:url]}"
puts
puts "You have 10 seconds to interrupt this script (Using ctl-c)"
(0..10).each do |i|
  print "#{i}.."
  sleep 1
end
puts
puts 'Getting requested info for the given fedora pids'

gip.connect_to_repo

gip.pids_by_file.each  do |filename, pid_array|
  puts "About to process pids from file #{filename}"
  # puts pid_array.inspect
  gip.process_pids pid_array
end
