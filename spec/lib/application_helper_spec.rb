# encoding: utf-8
require File.expand_path("../../spec_helper", __FILE__)
require 'lib/event_manage/application_helper'

module EventManage
  class DummyClass; end

  describe ApplicationHelper do
    before do
      @application_helper = DummyClass.new
      @application_helper.extend(ApplicationHelper)
    end

    describe "#to_year" do
      it "年をyyyyで返すこと" do
        @application_helper.to_year("2012-01").should == "2012"
      end
    end

    describe "#to_month" do
      it "月をmmで返すこと" do
        @application_helper.to_month("2012-01").should == "01"
      end
    end
  end
end
