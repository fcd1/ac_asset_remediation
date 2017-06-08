# requires
require 'optparse'
require 'yaml'
require 'active_support/core_ext/hash'
require 'rubydora'
require_relative 'datastream_transformation'

puts 'This script remediates assets for the given fedora pids'
puts

# class customization

# add module AssetRemediation to Rubydora::DigitalObject
class Rubydora::DigitalObject
  include DatastreamTransformation
end

# class definition

class AssetRemediationProcessing

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
    @config_info =  ActiveSupport::HashWithIndifferentAccess.new YAML.load_file('asset_remediation_config.yml')

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

    # process each object
    pids.each do |pid|

      puts
      puts "Looking for fedora object with pid #{pid}"

      begin
        ac_obj = @repo.find(pid)
      rescue Rubydora::RecordNotFound
        puts '************************ PID not found ***********************'
        next
      end

      dc_type =  ac_obj.get_dc_type

      puts "Processing fedora object #{ac_obj.pid}, DC Type currently set to #{dc_type}"

      if @allowed_dc_types.include? dc_type
        puts "DC Type is valid"
      else
        puts "DC Type is invalid"

        # fcd1, 03/12/17: only do the following in certain all objects
        # should have DC type set to 'Text'
        puts "Seting DC Type to Text"
        ac_obj.set_dc_type 'Text'
      end

      # remediate the DC type
      # remediate_dc_type ac_obj

      # Add genericResource to RELS_EXT hasModel
      ac_obj.add_generic_reource_to_has_model

      # create the new 'content' datastream based on the existing 'CONTENT' datastream
      ac_obj.copy_content_datastream('CONTENT','content')

      # add extent size_of_datastream for 'content' datastream
      ac_obj.add_relationship_to_content_datastream_predicate_extent_object_size

      count += 1
      puts "number of processed pids: #{count} out of #{num_of_pids}"

      puts "Sleep for 1 seconds"
      sleep 1

    end

  end

end

##############################
# Main Processing

arp = AssetRemediationProcessing.new

arp.process_command_line_options_and_args
# puts "Called #process_command_line_options_and_args"
# puts "Content of options: #{arp.options.inspect}"
# puts "Content of ARGV: #{arp.args.inspect}"

arp.process_repo_config

arp.process_pid_files
# puts "Called process_pid_files"
# puts arp.pids_by_file.inspect

puts "Repository url is set to #{arp.repo_info[:url]}"
puts

puts "You have 10 seconds to interrupt this script (Using ctl-c)"
(0..10).each do |i|
  print "#{i}.."
  sleep 1
end
puts
puts 'Remediating assets for the given fedora pids'

arp.connect_to_repo

arp.pids_by_file.each  do |filename, pid_array|
  puts "About to process pids from file #{filename}"
  # puts pid_array.inspect
  arp.process_pids pid_array
end
