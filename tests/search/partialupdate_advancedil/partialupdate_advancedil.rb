# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class PartialupdateAdvancedIL < IndexedSearchTest

  def setup
    set_owner("geirst")
    deploy_app(SearchApp.new.sd("#{selfdir}/advanced.sd"))
    start
  end

  def test_partialupdate_advancedil
    feed_and_wait_for_docs("advanced", 2, :file => "#{selfdir}/advanced_docs.xml")
    query = "query=sddocname:advanced&summary=most&nocache"
    assert_result(query, "#{selfdir}/advanced_result1.json", "id", 
                  [ "extra1", "extra2", "extra3", "id", "field1", "extra4", 
                    "extra5", "extra6", "extra7", "field8" ])
    feedfile("#{selfdir}/advanced_updates1.xml")
    assert_hitcount("query=field8:15", 1)
    assert_hitcount("query=extra1:5", 1)
    assert_result(query, "#{selfdir}/advanced_result2.json", "id", 
                  [ "extra1", "extra2", "extra3", "id", "field1", "extra4", "extra5",
                    "extra6", "extra7", "field8" ])
  end

  def teardown
    stop
  end

end
