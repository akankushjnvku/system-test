# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'streaming_search_test'
require_relative 'content_smoke_common'

class ContentStreamingSmokeTest < StreamingSearchTest

  include ContentSmokeCommon

  def setup
    set_owner('balder')
    set_description('Test basic streaming searching with content setup')
  end

  def test_contentsmoke_streaming
    deploy(selfdir+'singlenode-streaming', SEARCH_DATA+'music.sd')
    @node = vespa.storage['search'].storage['0']
    start_feed_and_check
    verify_get
  end

  def test_contentsmoke_proton_streaming
    deploy(selfdir+'singlenode-proton-streaming', SEARCH_DATA+'music.sd')
    @node = nil
    start
    feed_only
    verify_get
    check
  end

  def test_contentsmoke_dummy_streaming
    deploy(selfdir+'singlenode-dummy-streaming', SEARCH_DATA+'music.sd')
    @node = nil
    start_feed_and_check
    verify_get
  end

  def teardown
    stop
  end

end
