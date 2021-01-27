# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'pp'
require 'environment'

class MixedTensorPerfTestBase < PerformanceTest

  GRAPH_NAME = 'graph_name'
  FEED_TYPE = 'feed_type'
  LABEL_TYPE = 'label_type'
  PUTS = 'puts'
  UPDATES_ASSIGN = 'updates_assign'
  UPDATES_ADD = 'updates_add'
  UPDATES_REMOVE = 'updates_remove'
  NUMBER = 'number'
  STRING = 'string'

  def initialize(*args)
    super(*args)
  end

  def deploy_and_compile(sd_dir)
    deploy_app(create_app(sd_dir))
    start
    @container = vespa.container.values.first
    compile_data_gen
  end

  def create_app(sd_dir)
    SearchApp.new.sd(selfdir + "#{sd_dir}/test.sd").
      search_dir(selfdir + "search")
  end

  def compile_data_gen
    @data_gen = dirs.tmpdir + "data_gen"
    @container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{@data_gen} #{selfdir}/data_gen.cpp")
  end

  def feed_and_profile_cases(data_gen_params_prefix)
    feed_and_profile("#{data_gen_params_prefix} -s puts", PUTS, STRING)
    feed_and_profile("#{data_gen_params_prefix} -s updates assign", UPDATES_ASSIGN, STRING)
    feed_and_profile("#{data_gen_params_prefix} -s updates add", UPDATES_ADD, STRING)
    feed_and_profile("#{data_gen_params_prefix} -s updates remove", UPDATES_REMOVE, STRING)

    feed_and_profile("#{data_gen_params_prefix} puts", PUTS, NUMBER)
    feed_and_profile("#{data_gen_params_prefix} updates assign", UPDATES_ASSIGN, NUMBER)
    feed_and_profile("#{data_gen_params_prefix} updates add", UPDATES_ADD, NUMBER)
    feed_and_profile("#{data_gen_params_prefix} updates remove", UPDATES_REMOVE, NUMBER)
  end

  def feeder_numthreads
      8
  end

  def feed_and_profile(data_gen_params, feed_type, label_type)
    command = "#{@data_gen} #{data_gen_params}"
    profiler_start
    graph_name = "#{feed_type}.#{label_type}"
    run_stream_feeder(command, [
      parameter_filler(GRAPH_NAME, graph_name),
      parameter_filler(FEED_TYPE, feed_type),
      parameter_filler(LABEL_TYPE, label_type)
    ], {})
    profiler_report(graph_name)
  end

  def get_feed_throughput_graph(feed_type, label_type, y_min, y_max)
    {
      :x => GRAPH_NAME,
      :y => "feeder.throughput",
      :title => "Throughput during feeding of '#{feed_type}' (#{LABEL_TYPE}=#{label_type}) to mixed tensor",
      :filter => { FEED_TYPE => feed_type, LABEL_TYPE => label_type },
      :historic => true,
      :y_min => y_min,
      :y_max => y_max
    }
  end

end
