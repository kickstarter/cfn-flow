module CfnFlow
  class CachedStack

    class MissingOutput < StandardError; end

    def self.stack_cache
      @stack_cache ||= {}
    end

    def self.get_output(stack:, output:)
      new(stack).output(output)
    end

    attr_reader :stack_name

    def initialize(stack_name)
      @stack_name = stack_name
    end

    def output(name)
      output = stack_cache.outputs.detect{|out| out.output_key == name }
      unless output
        raise MissingOutput.new("Can't find outpout #{name} for stack #{stack_name}")
      end
      output.output_value
    end

    def stack_cache
      self.class.stack_cache[stack_name] ||= CfnFlow.cfn_resource.stack(stack_name).load
    end
  end
end
