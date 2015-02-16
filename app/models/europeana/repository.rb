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

      obj = response[:object]
      
      doc = obj.select do |key, value|
        [ :edmDatasetName, :language, :type, :title, :about, 
          :europeanaCollectionName, :timestamp_created_epoch,
          :timestamp_update_epoch, :timestamp_created, :timestamp_update ].include?(key)
      end
      
      doc[:id] = obj[:about]
      
      proxy = obj[:proxies].first.reject do |key, value|
        [ :proxyFor, :europeanaProxy, :proxyIn, :about ].include?(key)
      end
      
      aggregation = obj[:aggregations].first.reject do |key, value|
        [ :webResources, :aggregatedCHO, :about ].include?(key)
      end
      
      eaggregation = obj[:europeanaAggregation].reject do |key, value|
        [ :about, :aggregatedCHO ].include?(key)
      end
      
      doc.merge!(proxy).merge!(aggregation).merge!(eaggregation)
      
      doc.dup.each_pair do |key, value|
        if value.is_a?(Array)
          doc[key] = value.uniq
        elsif value.is_a?(Hash)
          if value.has_key?(:def)
            value.each_pair do |lang, labels|
              doc["#{key}_#{lang}"] = labels
            end
          end
          doc.delete(key)
        end
      end
      
      h = {
        'response' => {
          'numFound' => 1,
          'start' => 0,
          'docs' => [ doc ]
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
