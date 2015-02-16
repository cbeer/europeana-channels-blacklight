module Europeana
  class Repository
    attr_reader :blacklight_config
    
    def initialize blacklight_config
      @blacklight_config = blacklight_config
    end

    def find id, params = {}
      record = Europeana::Record.new("/" + id)
      response = record.get

      solrize_record_response(params, response)
    end

    def search params = {}
      search = Europeana::Search.new(europeanize_search_request(params))
      response = search.execute
      solrize_search_response(params, response)
    end

    private
    ##
    # Adapts a response from the API's Record method to resemble a Solr
    # query response of one document.
    #
    # @param [Hash] response The Europeana REST API response
    # @return [Hash]
    def solrize_record_response(req_params, response)
      response.deep_symbolize_keys!

      h = {
        'response' => {
          'numFound' => 1,
          'start' => 0,
          'docs' => [ response[:object] ]
        }
      }

      blacklight_config.solr_response_model.new(h, req_params, solr_document_model: blacklight_config.solr_document_model)
    end
    
    def europeanize_search_request(req_params)
      params = {}
      params[:query] = req_params[:q].blank? ? '*:*' : req_params.delete(:q)
      params[:profile] = "facets params"
      params[:start] = (req_params[:start] || 0) + 1
      params[:qf] = req_params.delete(:fq) unless req_params[:fq].blank?
      params[:rows] = req_params["rows"]
      params
    end

    ##
    # Adapts a response from the API's Search method to resemble a Solr
    # query response.
    #
    # @param [Hash] response The Europeana REST API response
    # @return [Hash]
    def solrize_search_response(req_params, response)
      response.deep_symbolize_keys!

      facet_fields = (response[:facets] || []).inject({}) do |facet_fields, facet|
        facet_fields[facet[:name]] = facet[:fields].collect { |field| [ field[:label], field[:count] ] }.flatten
        facet_fields
      end
      
      h = {
        'response' => {
          'numFound' => response[:totalResults],
          'start' => (response[:params][:start] || 0) - 1,
          'docs' => response[:items],
        },
        'facet_counts' => {
          'facet_fields' => facet_fields
        }
      }

      blacklight_config.solr_response_model.new(h, req_params, solr_document_model: blacklight_config.solr_document_model)
    end
  end
end
