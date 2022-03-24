# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rexml/document'
require 'json'
require 'drb/drb'

class Resultset
  include DRb::DRbUndumped

  attr_accessor :responseheaders
  attr_accessor :responsecode
  attr_accessor :hitcount
  attr_reader :hit
  attr_reader :groupings
  attr_reader :json
  attr_accessor :query

  def initialize(data, query, response = nil)
    @hit = []
    @groupings = {}
    @hitcount = nil
    @query = query
    @xmldata = data
    if (response != nil)
      @responsecode = response.code
      @responseheaders = response.header.to_hash
    end
    parse
  end

  # Ruby's net/http lowercases all header names since HTTP headers are
  # case insensitive. This method lowercases the input header name as
  # well to match the case of the keys in the hash.
  def header(name)
    @responseheaders[name.downcase]
  end

  def parse
    return unless @xmldata
    if is_xml?
      parse_xml
    elsif is_json?
      parse_json
    end
  end

  def is_xml?
    # Don't check for a following question mark or xml text. This breaks tests and results where the xml header is omitted
    @xmldata.match(/\A\s*</) != nil
  end

  def is_json?
    @xmldata.match(/\A\s*[{|\[]/) != nil
  end

  def parse_json
    begin
      @hit = []
      @json = JSON.parse(@xmldata)
      parse_hits_json(@json)
    rescue Exception => e
      puts "#{e.message}, could not parse JSON: #{@xmldata}"
    end
    @json
  end

  def parse_hits_json(json)
    unless json && json['root'] && json['root']['fields']
      return nil
    end
    begin
      @hitcount = json['root']['fields']['totalCount']
      json['root']['children'].each do |e|
        if e.key?('children') && ! e.key?('fields')
           id = e['id']
           @groupings[id] = e
        else
          hit = Hit.new
          hit.add_field("relevancy", e['relevance'])
          hit.add_field("documentid", e['id'])
          hit.add_field("source", e['source']) if e.key?('source')
          if e.key?('fields')
            e['fields'].each { |f| hit.add_field(f.first, f.last) }
          end
          add_hit(hit)
        end
      end
    rescue Exception
      return nil
    end
  end

  def xml
    if @xml == nil
      if @xmldata != nil
        @xml = parse_xml
      end
    end
    return @xml
  end

  def xmldata
    if @xmldata == nil
      to_xml
    end
    return @xmldata
  end

  def hit
    return @hit
  end

  def to_xml
    xml = REXML::Document.new()
    root = REXML::Element.new("result", xml)
    root.add_attribute("total-hit-count", @hitcount)
    @hit.each { |hit|
      root.add(hit.to_xml)
    }
    @xmldata = xml.to_s
  end

  def hitcount
    # Can be nil, return nil then, since nil.to_i is 0
    @hitcount ? @hitcount.to_i : @hitcount
  end

  def parse_xml
    begin
      @hit = []
      xml = REXML::Document.new(@xmldata).root
      parse_hits_xml(xml)
      if xml.attribute("total-hit-count") != nil
        @hitcount = xml.attribute("total-hit-count").to_s
      else
        @hitcount = @hit.size
      end
    rescue Exception => e
      puts "#{e.message}, could not parse XML: #{@xmldata}"
    end
    return xml
  end

  def parse_hits_xml(xml)
    if !xml
      return nil
    end
    xml.each_element("hit") do |e|
      newhit = Hit.new(e)
      add_hit(newhit)
    end
  end

  def add_hit(hit)
    @hit.push(hit)
  end

  def to_s
    stringval = ""
    hit.each do |h|
      stringval += h.to_s + "\n"
    end
    stringval
  end

  def inspect
    to_s
  end

  def setcomparablefields(fieldnamearray)
    hit.each {|h| h.setcomparablefields(fieldnamearray)}
  end

  def ==(other)
    (hitcount == other.hitcount && approx_cmp(groupings, other.groupings, "groupings") && hit == other.hit)
  end

  def sort_results_by(sortfield)
    @hit = hit.sort {|a, b| a.field[sortfield] <=> b.field[sortfield]}
  end

  def get_field_array(sortfield)
    retval = []
    hit.each { |a|
      retval.push(a.field[sortfield])
    }
    return retval
  end

  # define class methods (by opening the class of Resultset)
  class << self

    # Compare two objects, but when finding floats, do approximate compare
    def approx_cmp(av, bv, k = '<unknown>')
      if av.is_a? Numeric
        af = av.to_f
        bf = bv.to_f
        if (af + 1e-6 < bf)
          puts "Float values for '#{k}' differ: #{af} < #{bf}"
          return false
        end
        if (af - 1e-6 > bf)
          puts "Float values for '#{k}' differ: #{af} > #{bf}"
          return false
        end
      elsif av.is_a? Hash
        return false unless approx_cmp_hash(av, bv, k)
      elsif av.is_a? Array
        return false unless approx_cmp_array(av, bv, k)
      elsif ! (av == bv)
        puts "Values for '#{k}' are unequal: '#{av}' != '#{bv}'"
        return false
      end
      return true
    end

    # Compare two arrays, but when finding floats, do approximate compare
    def approx_cmp_array(a, b, k_in)
      if a.size != b.size
        puts "Different sizes of array: #{a.size} != #{b.size}"
        return false
      end
      a.each_index do |i|
        return false unless approx_cmp(a[i], b[i], "#{k_in}[#{i}]")
      end
      return true
    end

    # Compare two hashes, but when finding floats, do approximate compare
    def approx_cmp_hash(a, b, k_in)
      if b.size > a.size
        b.each do |k,bv|
          av = a[k]
          if av == nil
            puts "Extra value for '#{k_in}.#{k}' is '#{bv}'"
            return false
          end
        end
      end
      a.each do |k,av|
        bv = b[k]
        if bv == nil
          puts "Missing value for field '#{k_in}.#{k}'"
          return false
        end
        return false unless approx_cmp(av, bv, "#{k_in}.#{k}")
      end
      return true
    end
  end

end
