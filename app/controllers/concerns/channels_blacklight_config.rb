# -*- encoding : utf-8 -*-
#
module ChannelsBlacklightConfig
  extend ActiveSupport::Concern
  
  included do
    configure_blacklight do |config|
      config.api_key = Rails.application.secrets.europeana_api_key
      ## Default parameters to send to solr for all search-like requests. See also SolrHelper#solr_search_params
      config.default_solr_params = { 
        :qt => 'search',
        :rows => 24
      }
      
      config.solr_document_model = Europeana::Document
      config.solr_response_model = Europeana::Response
      
      # solr path which will be added to solr base url before the other solr params.
      #config.solr_path = 'select' 
      
      # items to show per page, each number in the array represent another option to choose from.
      config.per_page = [ 12, 24, 48, 96 ]

      ## Default parameters to send on single-document requests to Solr. These settings are the Blackligt defaults (see SolrHelper#solr_doc_params) or 
      ## parameters included in the Blacklight-jetty document requestHandler.
      #
      #config.default_document_solr_params = {
      #  :qt => 'document',
      #  ## These are hard-coded in the blacklight 'document' requestHandler
      #  # :fl => '*',
      #  # :rows => 1
      #  # :q => '{!raw f=id v=$id}' 
      #}

      # solr field configuration for search results/index views
      config.index.title_field = 'title'
      config.index.display_type_field = 'type'
      config.index.thumbnail_field = 'edmPreview'

      config.show.partials << "document_hierarchy"
      # solr field configuration for document/show views
      #config.show.title_field = 'title_display'
      #config.show.display_type_field = 'format'

      # solr fields that will be treated as facets by the blacklight application
      #   The ordering of the field names is the order of the display
      #
      # Setting a limit will trigger Blacklight's 'more' facet values link.
      # * If left unset, then all facet values returned by solr will be displayed.
      # * If set to an integer, then "f.somefield.facet.limit" will be added to
      # solr request, with actual solr request being +1 your configured limit --
      # you configure the number of items you actually want _displayed_ in a page.    
      # * If set to 'true', then no additional parameters will be sent to solr,
      # but any 'sniffed' request limit parameters will be used for paging, with
      # paging at requested limit -1. Can sniff from facet.limit or 
      # f.specific_field.facet.limit solr request params. This 'true' config
      # can be used if you set limits in :default_solr_params, or as defaults
      # on the solr side in the request handler itself. Request handler defaults
      # sniffing requires solr requests to be made with "echoParams=all", for
      # app code to actually have it echo'd back to see it.  
      #
      # :show may be set to false if you don't want the facet to be drawn in the 
      # facet bar
      config.add_facet_field 'UGC', :label => 'UGC', :limit => 7
      config.add_facet_field 'LANGUAGE', :label => 'LANGUAGE', :limit => 7
      config.add_facet_field 'TYPE', :label => 'TYPE', :limit => 7
      config.add_facet_field 'YEAR', :label => 'YEAR', :limit => 7
      config.add_facet_field 'PROVIDER', :label => 'PROVIDER'
      config.add_facet_field 'DATA_PROVIDER', :label => 'DATA_PROVIDER', :limit => 7
      config.add_facet_field 'COUNTRY', :label => 'COUNTRY', :limit => 7
      config.add_facet_field 'RIGHTS', :label => 'RIGHTS', :limit => 7
      
  #    config.add_facet_field 'pub_date', :label => 'Publication Year', :single => true
  #    config.add_facet_field 'subject_topic_facet', :label => 'Topic', :limit => 20 
  #    config.add_facet_field 'language_facet', :label => 'Language', :limit => true 
  #    config.add_facet_field 'lc_1letter_facet', :label => 'Call Number' 
  #    config.add_facet_field 'subject_geo_facet', :label => 'Region' 
  #    config.add_facet_field 'subject_era_facet', :label => 'Era'  

  #    config.add_facet_field 'example_pivot_field', :label => 'Pivot Field', :pivot => ['format', 'language_facet']

  #    config.add_facet_field 'example_query_facet_field', :label => 'Publish Date', :query => {
  #       :years_5 => { :label => 'within 5 Years', :fq => "pub_date:[#{Time.now.year - 5 } TO *]" },
  #       :years_10 => { :label => 'within 10 Years', :fq => "pub_date:[#{Time.now.year - 10 } TO *]" },
  #       :years_25 => { :label => 'within 25 Years', :fq => "pub_date:[#{Time.now.year - 25 } TO *]" }
  #    }


      # Have BL send all facet field names to Solr, which has been the default
      # previously. Simply remove these lines if you'd rather use Solr request
      # handler defaults, or have no facets.
      config.add_facet_fields_to_solr_request!

      # solr fields to be displayed in the index (search results) view
      #   The ordering of the field names is the order of the display 
  #    config.add_index_field 'title_display', :label => 'Title'

      # solr fields to be displayed in the show (single result) view
      #   The ordering of the field names is the order of the display 
      config.add_show_field 'edmPreview', :label => 'Preview', helper_method: :render_document_preview
      config.add_show_field 'dcType_def', :label => 'Type'
      config.add_show_field 'dctermsExtent_def', :label => 'Format'
      config.add_show_field 'dcSubject_def', :label => 'Subject'
      config.add_show_field 'dcIdentifier_def', :label => 'Identifier'
      config.add_show_field 'dctermsProvenance_def', :label => 'Provenance'
      config.add_show_field 'edmDataProvider_def', :label => 'Data provider'
      config.add_show_field 'edmProvider_def', :label => 'Provider'
      config.add_show_field 'edmCountry_def', :label => 'Providing country'
      
      # "fielded" search configuration. Used by pulldown among other places.
      # For supported keys in hash, see rdoc for Blacklight::SearchFields
      #
      # Search fields will inherit the :qt solr request handler from
      # config[:default_solr_parameters], OR can specify a different one
      # with a :qt key/value. Below examples inherit, except for subject
      # that specifies the same :qt as default for our own internal
      # testing purposes.
      #
      # The :key is what will be used to identify this BL search field internally,
      # as well as in URLs -- so changing it after deployment may break bookmarked
      # urls.  A display label will be automatically calculated from the :key,
      # or can be specified manually to be different. 

      # This one uses all the defaults set by the solr request handler. Which
      # solr request handler? The one set in config[:default_solr_parameters][:qt],
      # since we aren't specifying it otherwise. 
      
      config.add_search_field 'all_fields', :label => 'All Fields'
      

      # Now we see how to over-ride Solr request handler defaults, in this
      # case for a BL "search field", which is really a dismax aggregate
      # of Solr search fields. 
      
      [ 'title', 'who', 'what', 'when', 'where', 'subject' ].each do |field_name|
        config.add_search_field(field_name) do |field|
          field.solr_local_parameters = { 
            :qf => field_name,
          }
        end
      end
      
      # "sort results by" select (pulldown)
      # label in pulldown is followed by the name of the SOLR field to sort by and
      # whether the sort is ascending or descending (it must be asc or desc
      # except in the relevancy case).
  #    config.add_sort_field 'score desc, pub_date_sort desc, title_sort asc', :label => 'relevance'
  #    config.add_sort_field 'pub_date_sort desc, title_sort asc', :label => 'year'
  #    config.add_sort_field 'author_sort asc, title_sort asc', :label => 'author'
  #    config.add_sort_field 'title_sort asc, pub_date_sort desc', :label => 'title'

      # If there are more than this many search results, no spelling ("did you 
      # mean") suggestion is offered.
      config.spell_max = 5
    end
  end
end
