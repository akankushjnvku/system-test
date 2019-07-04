# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_test'
require 'app_generator/container_app'
require 'environment'

class MapAndNgramBug < SearchTest

  def setup
    set_owner("arnej")
  end

  def test_map_and_ngram
    deploy_app(SearchApp.new.sd(selfdir + "foo.sd"))
    start
    feed_and_wait_for_docs("foo", 3, :file => selfdir+"feed.json")
    feed(:file => selfdir + "updates.json",
         :maxpending => 1,
         :trace => 5)
  end

  def teardown
    stop
  end

end
