# requires
# require 'yaml'
# require 'active_support/core_ext/hash'
# require 'rubydora'

module DatastreamTransformation
  # function definitions

  # following is factored out as function in case the
  # we decide to change format of the information within
  # the yaml file -- these format changes would be localized
  # to this method
  def pids
    Array.new YAML.load_file('fedora_object_pids.yml')
  end

  def get_dc_type
    dc_ds = self.datastreams['DC']
    dc_ds_content = dc_ds.content.body
    # puts dc_ds_content
    re = %r{<dc:type>(.*)</dc:type>}
    b = re.match(dc_ds_content)
    # puts b.inspect
    # puts b[0]
    # puts b[1]
    b[1]
  end

  # get the mime type of the datastream with ID ds_id
  def get_ds_mime_type ds_id
    ds = self.datastreams[ds_id]
    ds.mimeType unless ds.nil?
  end

  # get the label of the datastream with ID ds_id
  def get_ds_label ds_id
    ds = self.datastreams[ds_id]
    ds.dsLabel unless ds.nil?
  end

  def set_dc_type(dc_type)
    dc_ds = self.datastreams['DC']
    dc_ds_content = dc_ds.content.body
    re = %r{<dc:type>(.*)</dc:type>}
    dc_ds_content.sub!(re,"<dc:type>#{dc_type}</dc:type>")
    dc_ds.content=dc_ds_content
    dc_ds.save
  end

  def remediate_dc_type
    # fcd1, 03/07/17: change all this functionality
    # first, retirieve the DC datastream
    dc_ds = self.datastreams['DC']
    # puts dc_ds.inspect
    # puts dc_ds
    get_dc_type dc_ds
  end

  # This method will add hasModel genericResource
  def add_generic_reource_to_has_model
    # first, need to get the api instance
    api = self.repository.api

    # get uri of object
    ac_obj_uri = self.uri

    # add the relationhip
    resp = api.add_relationship(pid: ac_obj_uri,
                                subject: ac_obj_uri,
                                predicate: 'info:fedora/fedora-system:def/model#hasModel',
                                object:'info:fedora/ldpd:GenericResource',
                                isLiteral: false)
  end

  # This method will duplicate the source content datastream
  def copy_content_datastream(source_id, destination_id)
    # retrieve original content datastream
    original_content_ds = self.datastreams[source_id]
    # create the new datastream
    new_content_ds = self.datastreams[destination_id]

    # set the dcLocation of the new datastream

    # As an example, here is the desired dsLocation for ac:110961
    # new_content_ds.dsLocation = "http://localhost:8983/fedora/get/ac:110961/CONTENT/2012-04-13T11:31:43.000Z"
    new_content_ds.dsLocation =
      "#{self.repository.config[:url]}/get/#{self.pid}/CONTENT/#{original_content_ds.dsCreateDate.utc.strftime("%Y-%m-%dT%H:%M:%S.%3NZ")}"

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
  def add_relationship_to_content_datastream_predicate_extent_object_size
    # first, need to get the api instance
    api = self.repository.api

    # next, get datastream with DSID 'content'
    content_ds = self.datastreams['content']

    # get uri of object
    ac_obj_uri = self.uri

    # add the relationship
    api.add_relationship(pid: ac_obj_uri,
                         subject: "#{ac_obj_uri}/#{content_ds.dsid}",
                         predicate: 'http://purl.org/dc/terms/extent',
                         object: content_ds.dsSize,
                         isLiteral: true )
  end
end
