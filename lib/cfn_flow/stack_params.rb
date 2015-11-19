module CfnFlow
  # Extend hash with some special behavior to generate the
  # style of hash aws-sdk expects
  class StackParams < Hash

    def self.expanded(hash)
      self[hash].
        with_symbolized_keys.
        with_expanded_parameters.
        with_expanded_tags.
        with_expanded_template_body
    end

    def with_symbolized_keys
      self.reduce(StackParams.new) do |accum, (key, value)|
        accum.merge(key.to_sym => value)
      end
    end

    def with_expanded_parameters
      return self unless self[:parameters].is_a? Hash

      expanded_params = self[:parameters].map do |key,value|
        { parameter_key: key, parameter_value: fetch_value(key, value) }
      end

      self.merge(parameters: expanded_params)
    end

    def with_expanded_tags
      return self unless self[:tags].is_a? Hash

      tags = self[:tags].map do |key, value|
        {key: key, value: value}
      end

      self.merge(tags: tags)
    end

    def add_tag(hash)
      new_tags = hash.map do |k,v|
        {key: k, value: v }
      end
      tags = (self[:tags] || []) + new_tags
      self.merge(tags: tags)
    end

    def with_expanded_template_body
      return self unless self[:template_body].is_a? String
      body = CfnFlow::Template.new(self[:template_body]).to_json
      self.merge(template_body: body)
    rescue CfnFlow::Template::Error
      # Do nothing
      self
    end

    def fetch_value(key, value)
      # Dereference stack output params
      if value.is_a?(Hash) && value.key?('stack')
        stack_name = value['stack']
        stack_output_name = value['output'] || key

        value = CachedStack.get_output(stack: stack_name, output: stack_output_name)
      else
        value
      end
    end
    private :fetch_value
  end
end
