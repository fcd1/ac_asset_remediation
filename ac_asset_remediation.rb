# requires
require 'yaml'
require 'active_support/core_ext/hash'
require 'rubydora'

puts 'Starting remediation of AC assets'

# function definitions

# following is factored out as function in case the
# we decide to change format of the information within
# the yaml file -- these format changes would be localized
# to this method
def pids
  Array.new YAML.load_file('fedora_object_pids.yml')
end

def get_dc_type(dc_datastream)
  dc_ds_content = dc_datastream.content.body
  # puts dc_ds_content
  re = %r{<dc:type>(.*)</dc:type>}
  b = re.match(dc_ds_content)
  # puts b.inspect
  # puts b[0]
  puts b[1]
end

def get_dc_format(dc_datastream)
  dc_ds_content = dc_datastream.content.body
  # puts dc_ds_content
  re = %r{<dc:format>(.*)</dc:format>}
  b = re.match(dc_ds_content)
  # puts b.inspect
  # puts b[0]
  puts b[1]
end

def remediate_dc_type(ac_obj, new_type)
  # first, retirieve the DC datastream
  dc_ds = ac_obj.datastreams['DC']
  # puts dc_ds.inspect
  # puts dc_ds
  get_dc_type dc_ds
end

# This method will add hasModel genericResource
def add_generic_reource_to_has_model(ac_obj)
  # first, need to get the api instance
  api = ac_obj.repository.api

  # get uri of object
  ac_obj_uri = ac_obj.uri

  # add the relationhip
  resp = api.add_relationship(pid: ac_obj_uri,
                              subject: ac_obj_uri,
                              predicate: 'info:fedora/fedora-system:def/model#hasModel',
                              object:'info:fedora/ldpd:GenericResource',
                              isLiteral: false)
end

# The content datastream in the AC asset fedora objects have
# a datastream ID of CONTENT. However, hyacinth requires the
# id to be 'content'. This method will duplicate the original
# datastream; the new datastream will have to correct ID
def remediate_content_datastream(ac_obj)
  # retrieve original content datastream
  original_content_ds = ac_obj.datastreams['CONTENT']
  # create the new datastream
  new_content_ds = ac_obj.datastreams['content']

  # set the dcLocation of the new datastream ('content')
  # fcd1, 02/20/17: for now, just use the hard coded location I believe works
  # for ac:110961
  new_content_ds.dsLocation = "http://localhost:8983/fedora/get/ac:110961/CONTENT/2012-04-13T11:31:43.000Z"

  # save the new datastream ('content')
  # IMPORTANT: This initial save has to be done here. If not, subsequent save calls in this method
  # will not go through (attempts to update the datastreams which does not yet exist).
  new_content_ds.save

  # set the MIME type to be equal to the original CONTENT datastream
  new_content_ds.profile['dsMIME']=original_content_ds.profile['dsMIME']

  # set the dsLabel to be euql to the dsLabel of the original CONTENT datastream
  new_content_ds.dsLabel=original_content_ds.dsLabel

  # save the new datastream ('content')
  new_content_ds.save
end

# Following will add a relationship to RELS_INT, using the given datastream
# as the subject of triple.
# The predicate is hard coded to 'http://purl.org/dc/terms/extent', and
# the object will be the size of the contents of the datastream
# RestApiClient#add_relationship
# NOTE: as far as duplicating the CONTENT datastream into a datastream with
# psid of 'content', the following method should be called with the new
# datastream (i.e. psid 'content')
def add_relationship_to_content_datastream_predicate_extent_object_size(ac_obj)
  # first, need to get the api instance
  api = ac_obj.repository.api

  # next, get datastream with DSID 'content'
  content_ds = ac_obj.datastreams['content']

  # get uri of object
  ac_obj_uri = ac_obj.uri

  # add the relationship
  api.add_relationship(pid: ac_obj_uri,
                       subject: "#{ac_obj_uri}/#{content_ds.dsid}",
                       predicate: 'http://purl.org/dc/terms/extent',
                       object: content_ds.dsSize,
                       isLiteral: true )
end

# read configs from yaml file. Complain if config is missing
# change the config filename to default to name in code but sup
CONFIG =  ActiveSupport::HashWithIndifferentAccess.new YAML.load_file('config.yml')
# puts CONFIG

# read in the hyacinth allowed types for dc:type
ALLOWED_DC_TYPES = Array.new CONFIG[:hyacinth][:allowed_dc_types]
puts ALLOWED_DC_TYPES

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

  # remediate the DC type
  # remediate_dc_type ac_obj

  # Add genericResource to RELS_EXT hasModel
  add_generic_reource_to_has_model ac_obj

  # create the new 'content' datastream based on the existing 'CONTENT' datastream
  remediate_content_datastream ac_obj

  # add extent size_of_datastream for 'content' datastream
  add_relationship_to_content_datastream_predicate_extent_object_size(ac_obj)  
end

