# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'container_test'
require 'app_generator/container_app'
require 'app_generator/http'


class HttpServerReconfig < ContainerTest
  def self.testparameters
    { "CLUSTER" => { :deploy_mode => "CLUSTER" } }
  end

  def setup
    set_owner("gjoranv")
    set_description("Test reconfiguration with different sets of http servers.")
  end

  def container_app(my_http)
    ContainerApp.new.container(
        Container.new.
            #jvmargs('-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=8998').
            jetty(true).
            http(my_http))

  end

  def test_two_servers_up_then_remove_one_server
    start(container_app(
              Http.new.
                  server(Server.new("server1", 4080)).
                  server(Server.new("server2", 5000))))
    check_server(4080)
    check_server(5000)

    puts "*** Initial application with two servers ok. Redeploying with only one server..."

    deploy(container_app(
               Http.new.
                   server(Server.new("server1", 4080))))
    check_server(4080)
    check_server(5000, false)
  end

  def check_server(port, expected_success=true)
    success = true
    begin
      @container.http_get("localhost", port, "/")
    rescue Errno::EAFNOSUPPORT, Errno::ECONNREFUSED, Errno::ENETUNREACH
      success = false
    end

    if expected_success && !success
      fail("Failed connecting to server that should have been up on port #{port}")
    elsif !expected_success && success
      fail("Could connect to server that should have been shut down on port #{port}")
    end
  end

  def teardown
    stop
  end
end
