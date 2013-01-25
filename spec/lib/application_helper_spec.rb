# encoding: utf-8
require File.dirname(__FILE__) + '/../spec_helper'
require 'lib/application_helper'

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
