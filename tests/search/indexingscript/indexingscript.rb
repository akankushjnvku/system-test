# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class IndexingScript < IndexedSearchTest

  def setup
    set_owner("yngve")
    set_description("Test that complex indexing scripts work as expected.")
    deploy_app(SearchApp.new.sd("#{selfdir}/test.sd"))
    start
  end

  def test_indexingscript_types
    feed_and_wait_for_docs("test", 10, :file => "#{selfdir}/input.xml", 
                           :skipfeedtag => true)
    assert_result("query=sddocname:test", "#{selfdir}/result.xml", "a")
  end

  def teardown
    stop
  end

end
