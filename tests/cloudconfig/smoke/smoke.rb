# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'cloudconfig_test'
require 'search_test'

class Smoke < CloudConfigTest

  def setup
    set_owner("musum")
    set_description("Smoke test for config system, vespamodel, config server")
    @valgrind = false
    @valgrind_opt = nil
  end

  def test_basicsearch
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
  end

  def teardown
    stop
    @valgrind = false
    @valgrind_opt = nil
  end

end
