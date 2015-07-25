require_relative '../helper'

describe 'EventPresenter' do

  subject { CfnFlow::EventPresenter }
  after { CfnFlow::EventPresenter.seen_event_ids.clear }

  let(:event) { stub_event }
  let(:event_with_reason) { stub_event(resource_status_reason: 'stubbed-reason') }

  describe '.seen_event_ids' do
    it 'should be a set' do
      subject.seen_event_ids.must_be_kind_of Set
    end
  end

  describe '.present' do
    it 'should present the right number of events' do
      events = [event, event_with_reason]
      result = subject.present(events) {|e| e}

      result.size.must_equal 2
      result.each {|e| e.must_be_kind_of CfnFlow::EventPresenter }
    end

    it 'should omit dupe events' do
      subject.present([event]) {}
      subject.present([event]) {}.must_equal []
    end

    it 'should render the status' do
      out, _ = capture_io do
        subject.present([event]) { |e| puts e.to_s }
      end

      out.must_match event.resource_status
    end
  end

  describe '#initialize' do
    it 'should add to .seen_event_ids' do
      subject.new(event)
      subject.seen_event_ids.include?(event.id).must_equal true
    end
  end

  describe '#to_s' do
    it 'should show the appropriate details' do
      str = subject.new(event).to_s
      str.must_match event.logical_resource_id
    end

    it 'should show a reason' do
      str = subject.new(event_with_reason).to_s
      str.must_match event_with_reason.resource_status_reason
    end
  end
end
