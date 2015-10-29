module CfnFlow
  # Extend hash with some special behavior to generate the
  # style of hash aws-sdk expects
  class StackParams < Hash

    def self.expand(hash)
      self[hash].
        symbolized_keys.
        expand_parameters.
        expand_tags.
        expand_template_body
    end

    def symbolized_keys
      self.inject(StackParams.new) do |accum, pair|
        key, value = pair
        accum.merge(key.to_sym => value)
      end
    end

    def expand_parameters
      return self unless self[:parameters].is_a? Hash

      expanded_params = self[:parameters].map do |key,value|
        # Dereference stack output params
        if value.is_a?(Hash) && value.key?('stack')
          stack_name = value['stack']
          stack_output_name = value['output'] || key

          value = CachedStack.get_output(stack: stack_name, output: stack_output_name)
        end

        { parameter_key: key, parameter_value: value }
      end

      self.merge(parameters: expanded_params)
    end

    def expand_tags
      return self unless self[:tags].is_a? Hash

      tags = self[:tags].map do |key, value|
        {key: key, value: value}
      end

      self.merge(tags: tags)
    end

    def add_tag(hash)
      tags = self[:tags] || []
      hash.each do |k,v|
        tags << {key: k, value: v }
      end
      self.merge(tags: tags)
    end

    def expand_template_body
      return self unless self[:template_body].is_a? String
      body = CfnFlow::Template.new(self[:template_body]).to_json
      self.merge(template_body: body)
    rescue CfnFlow::Template::Error
      # Do nothing
      self
    end
  end
end
