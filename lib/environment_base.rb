# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'executor'

# A base class for a singleton providing the default environment in
# which to run tests.  To access, use "Environment.instance" before
# fieldfs and methods.
#
# If the environment needs to be customized when running tests,
# this can be replaced by an environment-specific implementation.
class EnvironmentBase
  attr_reader :vespa_home, :vespa_web_service_port, :vespa_user, :tmp_dir, :path_env_variable, :additional_start_base_commands, :maven_snapshot_url
  attr_reader :vespa_hostname, :vespa_short_hostname

  def initialize(default_vespa_home, default_vespa_user, default_vespa_web_service_port)
    if ENV.has_key?('VESPA_HOME')
      @vespa_home = ENV['VESPA_HOME']
    else
      @vespa_home = default_vespa_home
    end

    if ENV.has_key?('VESPA_WEB_SERVICE_PORT')
      @vespa_web_service_port = ENV['VESPA_WEB_SERVICE_PORT'].to_i
    else
      @vespa_web_service_port = default_vespa_web_service_port
    end

    if ENV.has_key?('VESPA_USER')
      @vespa_user = ENV['VESPA_USER']
    else
      @vespa_user = default_vespa_user
    end

    if ENV.has_key?('VESPA_HOSTNAME')
      @vespa_hostname = ENV['VESPA_HOSTNAME']
    else
      @vespa_hostname = `hostname`.chomp
    end

    hostname_components = @vespa_hostname.split(".")
    if hostname_components.size > 0
      if hostname_components.size > 1 && hostname_components[1] =~ /^\d+$/
        @vespa_short_hostname = hostname_components.first(2).join(".")
      else
        @vespa_short_hostname = hostname_components[0]
      end
    else
      @vespa_short_hostname = @vespa_hostname
    end
    @executor = Executor.new(@vespa_short_hostname)

    if File.exists?(@vespa_home)
      @tmp_dir = @vespa_home + "/tmp"
    else
      @tmp_dir = "/tmp" # When running unit tests with no Vespa installed
    end

    @path_env_variable = "#{@vespa_home}/bin:#{@vespa_home}/bin64:#{@vespa_home}/sbin:#{@vespa_home}/sbin64"
    @additional_start_base_commands = ""
    @maven_snapshot_url = nil # TODO
  end

  def set_addr_configserver(testcase, config_hostnames)
    set_default_conf("VESPA_CONFIGSERVERS", config_hostnames.join(","))
  end

  def set_port_configserver_rpc(testcase, port=nil)
    set_default_conf("VESPA_CONFIGSERVER_RPC_PORT", port)
  end

  def start_configserver(testcase)
    @executor.execute("#{@vespa_home}/bin/vespa-start-configserver", testcase)
  end

  def stop_configserver(testcase)
    @executor.execute("#{@vespa_home}/bin/vespa-stop-configserver", testcase)
  end

  def reset_configserver(configserver)
    # TODO
  end

  def reset_environment(node)
    # TODO
  end

  # Returns the host name of a host from which standard test data can be downloaded
  #
  # +hostname+:: The host name which will download test data
  def webhost(hostname)
    # TODO
  end

  # TODO: Make private
  def set_default_conf(name, value)
    default_env_name = "#{@vespa_home}/conf/vespa/default-env.txt"
    default_env_name_new = "#{default_env_name}.new"
    lines = IO.readlines(default_env_name)
    wfile = File.open(default_env_name_new, "w")
    lines.each do |line|
      chompedline = line.chomp
      splitline = chompedline.split(" ", 3)
      if splitline[1] != name
        wfile.write("#{chompedline}\n")
      end
    end
    if !value.nil?
      wfile.write("override #{name} #{value}\n")
    end
    wfile.close
    File.rename(default_env_name_new, default_env_name)
  end

end
