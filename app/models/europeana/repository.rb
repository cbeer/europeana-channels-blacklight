module Europeana
  class Repository
    attr_reader :blacklight_config
    
    def initialize blacklight_config
      @blacklight_config = blacklight_config
    end

    def find id, params = {}
      path = "/api/v2/record/#{id}.json"
      req_params = {}
      resp = client.get do |req|
        req.url path
        req.headers['Content-Type'] = 'application/json'
        req.params[:wskey] = api_key
        req_params = req.params
      end
      response = JSON.parse(resp.body, symbolize_names: true)

      solrize_record_response(req_params, response)
    end

    def search params = {}
      path = "/api/v2/search.json"

      req_params = {}
      resp = client.get do |req|
        req.url path
        req.headers['Content-Type'] = 'application/json'
        req.params[:wskey] = api_key
        
        req.params[:query] = params[:q].blank? ? '*:*' : params.delete(:q)
        req.params[:profile] = "facets params"
        req.params[:facet] = params["facet.field"]
        req.params[:start] = (params[:start] || 0) + 1
        req.params[:qf] = params.delete(:fq) unless params[:fq].blank?
        req.params[:rows] = params["rows"]
        req_params = req.params
      end

      response = JSON.parse(resp.body, symbolize_names: true)

      solrize_search_response(req_params, response)
    end

    private
    def client
      @client ||= Faraday.new url: 'http://www.europeana.eu/api/v2'
    end

    def api_key
      blacklight_config.api_key
    end
    
    ##
    # Adapts a response from the API's Record method to resemble a Solr
    # query response of one document.
    #
    # @param [Hash] response The Europeana REST API response
    # @return [Hash]
    def solrize_record_response(req_params, response)
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
    
    ##
    # Adapts a response from the API's Search method to resemble a Solr
    # query response.
    #
    # @param [Hash] response The Europeana REST API response
    # @return [Hash]
    def solrize_search_response(req_params, response)
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
