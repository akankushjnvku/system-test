# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class YqlFields < IndexedSearchTest
  def setup
    set_owner("arnej")
    set_description("Field filtering in YQL+")
  end

  def test_yqlfields
    deploy_app(SearchApp.new.
        sd(SEARCH_DATA+"music.sd"))
    start
    feed(:file => SEARCH_DATA+"music.10.xml", :timeout => 240)
    wait_for_hitcount("query=sddocname:music", 10)
    assert_result("query=sddocname:music&yql=select%20ew,surl%20from%20music%20where%20userQuery%28%29%3B&sorting=surl", selfdir + "filteredresult.json")
    assert_result("query=sddocname:music&yql=select%20*%20from%20music%20where%20userQuery%28%29%3B&sorting=surl", selfdir + "unfilteredresult.json")
  end

  def teardown
    stop
  end
end
