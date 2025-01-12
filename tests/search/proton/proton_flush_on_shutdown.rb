# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class ProtonFlushOnShutdownTest < SearchTest

  def setup
    set_owner("yngve")
    set_description("Test that flush-on-shutdown can be turned off")
  end

  def test_turn_off_flush_on_shutdown
    deploy_app(SearchApp.new.sd(selfdir+"test.sd").flush_on_shutdown(false))
    start
    feed_and_wait_for_docs("test", 100, :file => "#{selfdir}/docs.4.xml")
    vespa.search["search"].first.stop
    vespa.search["search"].first.start
    wait_for_hitcount("sddocname:test", 100)
    assert_log_not_matches(/diskindex.load.start/)
  end

  def teardown
    stop
  end
end
