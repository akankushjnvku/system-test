require 'cloudconfig_test'
require 'app_generator/search_app'
require 'environment'

class VespaStatusFileDistribution < CloudConfigTest
  @@vespa_status_filedistribution = "#{Environment.instance.vespa_home}/bin/vespa-status-filedistribution"

  def initialize(*args)
    super(*args)
  end

  def setup
    set_owner("musum")
    set_description("Tests vespa-status-filedistribution")

    app_gen = SearchApp.new.sd(SEARCH_DATA+"music.sd")
    deploy_app(app_gen)
    start
  end

  def test_vespa_status_filedistribution
    (exitcode, out) = execute(vespa.adminserver, "#{@@vespa_status_filedistribution}")
    assert_equal(0, exitcode)
    assert_equal("something", out) # TODO: Update when script has been fixed
  end

  def teardown
    stop
  end

end
