module Europeana
  class Document
    include Blacklight::Solr::Document

    def initialize source_doc, response = nil
      doc = source_doc.dup

      doc[:id] ||= doc[:about]

      proxy = doc.fetch(:proxies, [{}]).first.reject do |key, value|
        [ :proxyFor, :europeanaProxy, :proxyIn, :about ].include?(key)
      end

      aggregation = doc.fetch(:aggregations, [{}]).first.reject do |key, value|
        [ :webResources, :aggregatedCHO, :about ].include?(key)
      end

      eaggregation = doc.fetch(:europeanaAggregation, {}).reject do |key, value|
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

      super doc, response
    end

    def to_param
      "#{provider_id}/#{record_id}"
    end
    
    def provider_id
      @provider_id ||= id.to_s.split('/')[1]
    end
    
    def record_id
      @record_id ||= id.to_s.split('/')[2]
    end
    
    def cache_key
      "#{provider_id}/#{record_id}-#{self['timestamp_update_epoch']}"
    end

    def hierarchy
      @hierarchy ||= load_hierarchy
    end
    
    def load_hierarchy
      record = Europeana::Record.new(self.id)
      @hierarchy = record.hierarchy("ancestor-self-siblings")
      
      if @hierarchy['self']['hasChildren']
        @hierarchy = record.hierarchy("ancestor-self-siblings", :children)
      end
    rescue Europeana::Errors::RequestError => error
      if error.message == "This record has no hierarchical structure!"
        @hierarchy = false
      else
        raise
      end
    end
  end
end
