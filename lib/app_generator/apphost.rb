# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class AppHost
  include ChainedSetter
  chained_setter :name
  chained_setter :aliases

  class Alias
    def initialize(alias_name)
      @alias = alias_name
    end
    def to_xml(indent)
      indent + "<alias>#{@alias}</alias>\n"
    end
  end

  def initialize(hostname, hostaliases)
    @name = hostname
    @aliases = []
    hostaliases.each do |a|
      @aliases << Alias.new(a)
    end
  end

  def to_xml(indent)
    XmlHelper.new(indent).
      tag("host", :name => @name).
        to_xml(@aliases).to_s
  end
end
