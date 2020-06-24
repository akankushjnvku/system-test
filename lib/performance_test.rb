# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance/configloadtester'
require 'performance/fbench'
require 'performance/resultmodel'
require 'performance/datasetmanager'
require 'performance/comparison'
require 'nodetypes/yamas'
require 'environment'

require 'testcase'

class PerformanceTest < TestCase
  attr_reader :result
  attr_accessor :resultoutputdir
  attr_accessor :graphs
  attr_accessor :perfdir
  attr_accessor :profilersnapshotdir
  include Yamas

  def initialize(*args)
    # 'stress_test' definition:
    #
    # automatic test that have more than 1000 documents and wants to
    # figure out whether the distributor is in sync or not by fetching
    # a HTML page describing the state of all buckets owned by that
    # distributor and grepping for bold tags to count buckets that are
    # out of sync. When cleverness meets RHEL6 we need more than 5
    # seconds worth of timeout.
    #
    cmdline, tc_file, arg_pack = args
    arg_pack[:stress_test] = true
    super(cmdline, tc_file, arg_pack)

    @queryfile = selfdir + 'queries.txt'
    @graphs = nil
    @warmup = true
    @perf_processes = {}
    @perf_data_dir = "#{Environment.instance.vespa_home}/tmp/perf/"
    @perf_data_file = File.join(@perf_data_dir,'record.data')
    @perf_stat_file = File.join(@perf_data_dir,'perf_stats')
    @script_user = get_script_user
  end

  def timeout_seconds
    # Two hours
    3600*2
  end

  def get_script_user
    sudo_user = `echo ${SUDO_USER}`.chomp
    user = "builder"
    if sudo_user != nil && sudo_user != ""
      user = sudo_user
    end
    user
  end

  def modulename
    "performance"
  end

  def feeder_numthreads
      2
  end

  def feeder_binary
    "vespa-feed-perf"
  end

  def prepare
    super
    @magic_number = 0
    @resultoutputdir = @dirs.resultoutput + 'performance/'
    `mkdir #{@resultoutputdir}`
    @perfdir = @dirs.resultoutput + 'perf/'
    `mkdir #{@perfdir}`
  end

  def run_simple(clients, ntimes)
    prepare
    qrserver = @vespa.qrserver.values.first
    warmup(qrserver) if @warmup
    clients.each do |num_clients|
      puts "Running with #{num_clients} clients, #{ntimes} iterations"
      run_fbench_ntimes(qrserver, num_clients, 300, ntimes)
    end
  end

  def run_fbench_ntimes(qrserver, clients, runtime, ntimes, custom_fillers=[], params={})
    ntimes.times do |run|
      puts "Running iteration #{run}"
      run_fbench(qrserver, clients, runtime, custom_fillers, params)
    end
  end

  def run_fbench(qrserver, clients, runtime, custom_fillers=[], params={})
    run_fbench2(qrserver, @queryfile, params.merge({:runtime => runtime, :clients => clients}), custom_fillers)
  end

  def run_fbench2(qrserver, queryfile, params={}, custom_fillers=[])
    system_fbench = Perf::System.new(qrserver)
    system_fbench.start
    container_port = if params[:port_override] then params[:port_override] else qrserver.http_port end
    fbench = Perf::Fbench.new(qrserver, qrserver.name, container_port)

    fbench.runtime = params[:runtime] if params[:runtime]
    fbench.clients = params[:clients] if params[:clients]
    fbench.max_line_size = params[:max_line_size] if params[:max_line_size]
    fbench.append_str = params[:append_str] if params[:append_str]
    fbench.headers = params[:headers] if params[:headers]
    fbench.request_per_ms = params[:requests_per_ms] if params[:requests_per_ms]
    fbench.times_reuse_query_files = params[:times_reuse_query_files] if params[:times_reuse_query_files]
    fbench.result_file = params[:result_file] if params[:result_file]
    fbench.disable_http_keep_alive = params[:disable_http_keep_alive] if params[:disable_http_keep_alive]
    fbench.disable_tls = params[:disable_tls] if params[:disable_tls]
    fbench.certificate_file = params[:certificate_file] if params[:certificate_file]
    fbench.private_key_file = params[:private_key_file] if params[:private_key_file]
    fbench.ca_certificate_file = params[:ca_certificate_file] if params[:ca_certificate_file]

    fbench.query(queryfile)
    system_fbench.end
    fillers = [fbench.fill, system_fbench.fill]
    if (params[:fetch_vespa_metrics])
      metrics = fetch_vespa_metrics(qrserver)
      metrics.each do |k, v|
        p = metric_filler(k, v)
        if v != nil
          fillers.push(p)
        end
      end
    end
    write_report(fillers + custom_fillers)
  end

  def fill_feeder(output)
    Proc.new do |result|
      result.add_metric('feeder.runtime', output[0])
      result.add_metric('feeder.okcount', output[1])
      result.add_metric('feeder.errorcount', output[2])
      result.add_metric('feeder.minlatency', output[3])
      result.add_metric('feeder.maxlatency', output[4])
      result.add_metric('feeder.avglatency', output[5])
      result.add_metric('feeder.throughput', (output[1].to_f / output[0].to_f * 1000).to_s)
      result.add_parameter('loadgiver', 'vespafeeder')
    end
  end

  def post_process_feed_output(output, custom_fillers)
    lines = output.split("\n")[-1]
    res = lines.gsub(/\s+/, "").split(",")
    fillers = [fill_feeder(res)]
    write_report(fillers + custom_fillers)
  end

  def run_feeder(feedfile, custom_fillers=[], feederparams={})
    out = feed(feederparams.merge({:file => feedfile, :mode => "benchmark", :do_sync => true}))
    post_process_feed_output(out, custom_fillers)
  end

  def run_stream_feeder(streamer_command, custom_fillers=[], feederparams={})
    out = feed_stream(streamer_command,
                      feederparams.merge({:client => :vespa_feeder, :mode => "benchmark"})).split("\n")[1]
    post_process_feed_output(out, custom_fillers)
  end

  def create_loadtester(node, configserver_hostname, port, num_requests, num_threads, defdir)
    loadtester = Perf::ConfigLoadTester.new(node, configserver_hostname, port, defdir)
    loadtester.numiter = num_requests
    loadtester.threads = num_threads
    loadtester
  end

  def run_cloudconfig_loadtester(node, port, num_requests, num_threads, file, defdir, custom_fillers=[])
    loadtester = create_loadtester(node, node.name, port, num_requests, num_threads, defdir)
    loadtester.run(file)
    fillers = [loadtester.fill]
    write_report(fillers + custom_fillers)
  end

  def run_predicate_search_library_benchmark(node, benchmark_params)
    perfmap_agent = "#{Environment.instance.vespa_home}/lib64/libperfmap.so"
    perfmap_agent_arg = if File.file?(perfmap_agent) then "-agentpath:#{perfmap_agent}" else '' end
    raw_output = node.execute(
      "LD_PRELOAD=#{Environment.instance.vespa_home}/lib64/vespa/malloc/libvespamalloc.so java #{perfmap_agent_arg} " +
        "-Xmx16g -Xms16g -XX:+UseParallelGC -XX:NewRatio=1 -verbose:gc -XX:MaxTenuringThreshold=15 " +
        "-cp #{Environment.instance.vespa_home}/lib/jars/predicate-search-jar-with-dependencies.jar " +
        "com.yahoo.search.predicate.benchmarks.PredicateIndexBenchmark " +
        "#{benchmark_params}")
    # Strip out any oprofile error messages
    gc_log_stripped_output = raw_output.lines.reject { |line| line.include?('[info][gc]') }.join("\n")
    json_end = gc_log_stripped_output.rindex('}')
    JSON.parse(gc_log_stripped_output[0..json_end])
  end

  # Create a key-value tag to attach to the metrics produced which can be used to filter and label graphed values
  def parameter_filler(name, value)
    Proc.new do |result|
      result.add_parameter(name, value)
    end
  end

  def metric_filler(name, value)
    Proc.new do |result|
      result.add_metric(name, value)
    end
  end

  def write_report(fillers)
    @rep_result = Perf::Result.new(@vespa_version)
    fillers.each do |filler|
      filler.call(@rep_result)
    end

    out = @resultoutputdir + Time.now.strftime('%Y-%m-%d-%H-%M-%S') + '_' + @magic_number.to_s + '.xml'
    @magic_number = @magic_number + 1
    @rep_result.write(out)
    # puts "Wrote result to: #{out}"
    @rep_result
  end

  def warmup(qrserver)
    fbench = Perf::Fbench.new(qrserver, qrserver.name, qrserver.http_port)
    warmup_time = 30

    puts "Warming up for #{warmup_time}s*2"
    fbench.clients = 32
    fbench.runtime = warmup_time

    fbench.query(@queryfile)
    fbench.query(@queryfile)
  end

  def teardown
    profiler_stop
    profiler_report
    stop
  end

  def setup
    profiler_start
  end

  # Start profiler. Calling this will stop any profilers started earlier and reset recordings.
  def profiler_start
    start_perf_profiler
  end

  # Generate reports from profile recordings. This call stop the profilers if running to
  # get a correct data dump. Multiple calls with the same label will overwrite the previous reports.
  def profiler_report(label='')
    report_perf_profiler(label)
  end

  # Stop the currently running profilers.
  def profiler_stop
    stop_perf_profiler
  end

  def start_perf_profiler
    stop_perf_profiler
    Timeout::timeout(600) do |timeout_length|
      puts "Starting perf record on nodes."
      vespa.nodeproxies.values.each do | node |
        begin
          node.execute("rm -rf #{@perf_data_dir} && mkdir -p #{@perf_data_dir}")
          @perf_processes[node] = []
          @perf_processes[node] << node.execute_bg("perf record -a -e cycles -o #{@perf_data_file}")
          @perf_processes[node] << node.execute_bg("exec perf stat -d -a &> #{@perf_stat_file}")
        rescue ExecuteError
          puts "Unable to start perf on node #{node.name}"
        end
      end
    end
  rescue Timeout::Error
    raise "Timeout waiting for perf to start"
  end

  def perf_dir_name(label, node)
    File.join(@perf_data_dir, label.empty? ? "#{node.name}" : "#{label}_#{node.name}")
  end

  def report_perf_profiler(label='')
    stop_perf_profiler
    puts "Generating perf report."

    reporter_pids = {}
    vespa.nodeproxies.values.each do | node |
      node.execute("chown root:root /tmp/perf-*.map || true")

      dir_name = perf_dir_name(label, node)
      node.execute("mkdir -p #{dir_name}")

      reporter_pids[node] = []

      reporter_pids[node] << node.execute_bg("cp -a #{@perf_stat_file} #{dir_name}")

      name_to_pids = {}
      name_to_pids['proton-bin'] = node.get_pids('sbin/vespa-proton-bin')
      name_to_pids['storaged-bin'] = node.get_pids('sbin/vespa-storaged-bin')
      name_to_pids['distributord-bin'] = node.get_pids('sbin/vespa-distributord-bin')
      name_to_pids['container'] = node.get_pids('"java.*container-disc-jar-with-dependencies.jar"')
      name_to_pids['configserver'] = node.get_pids('"java.*jdisc\/configserver"')
      name_to_pids['vespa-config-loadtester'] = node.get_pids('vespa-config-loadtester')
      name_to_pids['systemwide'] = [0]

      name_to_pids.each do | name, pids |
        pids.each do | pid |
          perf_pid_arg = "--pid #{pid}"
          perf_pid_arg = '' if pid == 0

          file_name = File.join(dir_name, "perf_#{name}-#{pid}")

          begin
            reporter_pids[node] << node.execute_bg("perf report --stdio --header --show-nr-samples --percent-limit 0.1 #{perf_pid_arg} --input #{@perf_data_file} 2>/dev/null > #{file_name}")
          rescue ExecuteError
            puts "Unable to generate report for #{binary} on host #{node.name}"
          end
        end
      end
    end

    vespa.nodeproxies.values.each do | node |
      reporter_pids[node].each do | pid |
        node.waitpid(pid)
      end
      dir_name = perf_dir_name(label, node)
      puts "Copy files from #{dir_name} on host #{node.name}"
      node.copy_remote_directory_into_local_directory(dir_name, @perfdir)
    end
  end

  def stop_perf_profiler
    unless @perf_processes.empty?
      puts "Stopping perf recording."
      @perf_processes.each do |node, pidlist|
        pidlist.each do |pid|
          begin
            Timeout.timeout(10) do
              node.execute('ps auxwww')
              node.kill_pid(pid, 'INT')
            end
          rescue Timeout::Error, ExecuteError
            puts "Failed to terminate pid #{pid} on host #{node.name}, trying KILL"
            begin
              node.kill_pid(pid, 'KILL')
            rescue ExecuteError, SystemCallError
              puts "Failed to terminate pid #{pid} on host #{node.name}"
            end
          end
        end
      end
      @perf_processes.clear
    end
  end

  private :start_perf_profiler, :perf_dir_name, :report_perf_profiler, :stop_perf_profiler

  def get_performance_results(path=nil)
    if path
      perf_path = path
    else
      result = dirs.resultoutput
      perf_path = File.join(result, 'performance/')
    end
    return [] unless File.exist?(perf_path)

    results = []
    Dir.foreach(perf_path) do |file|
      next if file =~ /^\./
      results << Perf::Result.read(File.join(perf_path, file))
    end
    results
  end

  def check_performance(method)
    @current = get_performance_results
    message = Perf::check_performance_results(self, @graphs, method, @current)
    if message!=""
      @result.performance_annotation = message
      puts "Performance outside limits:\n\n" + message
      add_failure("Performance outside limits:\n\n" + message)
    else
      puts "Performance results within specified parameters."
    end
  end

  def fetch_vespa_metrics(node)
    query_requests = 0
    docs_matched = 0
    docs_ranked = 0
    docs_reranked = 0
    query_latency_avg = 0

    90.times do
      data = get_yamas_metrics_yms(node, "slingstone.searchnode")
      # data2 = get_yamas_metrics_yms(node, "slingstone.container")

      docs_matched = get_metric(data, "docs_matched")
      docs_ranked = get_metric(data, "docs_ranked")
      docs_reranked = get_metric(data, "docs_reranked")
      query_requests = get_metric(data, "query_requests")
      query_latency_avg = get_metric(data, "query_latency.avg")
      break if query_requests > 0
      sleep 1
    end
    metrics = {
        "docs_matched" => docs_matched,
        "docs_ranked" => docs_ranked,
        "docs_reranked" => docs_reranked,
        "query_request" => query_requests,
        "query_latency" => query_latency_avg
    }
    return metrics
  end

  def performance?
    true
  end

  def get_default_log_check_levels
    return [:nothing]
  end
end
