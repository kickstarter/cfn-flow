require 'set'
module CfnFlow
  class EventPresenter

    ##
    # Class methods
    def self.seen_event_ids
      @seen_event_ids ||= Set.new
    end

    # Yields each new event present to +block+
    def self.present(raw_events, &block)
      raw_events.to_a.reverse.sort_by(&:timestamp).
        reject {|e| seen_event_ids.include?(e.id) }.
        map    {|e| yield new(e) }
    end

    def self.header
      %w(status logical_resource_id resource_type reason) * "\t"
    end

    ##
    # Instance methods
    attr_accessor :event
    def initialize(event)
      @event = event
      self.class.seen_event_ids << event.id
    end

    def to_s
        [
          event.resource_status,
          event.logical_resource_id,
          event.resource_type,
          event.resource_status_reason
        ].compact * "\t"
    end
  end
end
