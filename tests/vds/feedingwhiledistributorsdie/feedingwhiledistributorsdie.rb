# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'multi_provider_storage_test'

class FeedingWhileDistributorsDieTest < MultiProviderStorageTest

  def setup
    set_owner("vekterli")

    deploy_app(default_app.num_nodes(4).redundancy(1))
    start
  end

  def stop_distributor(idx)
    vespa.storage["storage"].distributor[idx.to_s].stop
    vespa.storage["storage"].distributor[idx.to_s].wait_for_current_node_state('d')
  end

  def start_distributor(idx)
    vespa.storage["storage"].distributor[idx.to_s].start
    vespa.storage["storage"].distributor[idx.to_s].wait_for_current_node_state('u')
  end

  def test_feedingwhiledistributorsdie

    feederoutput = ""
    feederthread = Thread.new do
      feederoutput = vespa.storage["storage"].storage["0"].feedfile(selfdir + "data.xml", :maxretries => 5)
    end

    stop_distributor 0
    start_distributor 0

    stop_distributor 0

    sleep 1

    stop_distributor 1

    sleep 1

    start_distributor 0
    start_distributor 1

    feederthread.join

    assert(feederoutput.index("ok: 1000"))
    assert(feederoutput.index("failed: 0"))

  end

  def teardown
    vespa.storage["storage"].storage["0"].kill_process("vespa-feeder")
    stop
  end
end

