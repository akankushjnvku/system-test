# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rubygems'
require 'json'
require 'indexed_search_test'

class MultipleWeightedSets < IndexedSearchTest

  def setup
    set_owner("arnej")
    set_description("Check ranking of multiple weighted sets behave in a sane manner")
    deploy_app(SearchApp.new.sd(selfdir + "multiweight.sd"))
    start
    feed_and_wait_for_docs("multiweight", 1, :file => selfdir + "multiweight.xml")
  end

  def assert_summaryfeatures(expected, result)
    assert_features(expected, result.hit[0].field['summaryfeatures'])
  end

  def test_multipleweightedsets
    query = "/?query=a"
    result = search(query)
    expected = {
        "fieldTermMatch(weight1,0).weight" => "100",
        "fieldTermMatch(weight2,0).weight" => "10",
        "fieldTermMatch(weight3,0).weight" => "1"
    }
    assert_summaryfeatures(expected, result)

    query = "/?query=b"
    result = search(query)
    expected = {
        "fieldTermMatch(weight1,0).weight" => "10",
        "fieldTermMatch(weight2,0).weight" => "10",
        "fieldTermMatch(weight3,0).weight" => "10"
    }
    assert_summaryfeatures(expected, result)

    query = "/?query=c"
    result = search(query)
    expected = {
        "fieldTermMatch(weight1,0).weight" => "1",
        "fieldTermMatch(weight2,0).weight" => "10",
        "fieldTermMatch(weight3,0).weight" => "100"
    }
   assert_summaryfeatures(expected, result)
  end

  def teardown
     stop
  end

end
