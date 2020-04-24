# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'

class PhraseCasesPerformanceTest < PerformanceTest

  def initialize(*args)
    super(*args)
  end

  def timeout_seconds
    1800
  end

  def setup
    super
    set_description('Test various cases with phrase search')
    set_owner("arnej")
  end

  def file_in_tmp(file_name)
    dirs.tmpdir + file_name
  end

  def write_queries(query, qfn)
    File.open(qfn, 'w') do |f|
      (1..99999).each do |num|
        f.puts("/search/?query=phrases:#{query}+-title:#{num}&recall=%2Bphrases:fifty")
      end
    end
  end


  def test_phrase_cases

    app = SearchApp.new.monitoring("vespa", 60).
          sd(selfdir+"foobar.sd").
          container(Container.new("combinedcontainer").
                    search(Searching.new).
                    docproc(DocumentProcessing.new).
                    gateway(ContainerDocumentApi.new)).
          indexing("combinedcontainer").
          threads_per_search(1)
    deploy_app(app)
    @graphs = get_graphs()
    start

    # queries
    qf1 = file_in_tmp('bestcase-queries.txt')
    write_queries('thirty.forty', qf1)
    qf2 = file_in_tmp('worstcase-queries.txt')
    write_queries('worst.case', qf2)
    qf3 = file_in_tmp('middle-queries.txt')
    write_queries('forty.sixty', qf3)

    # feed
    node = vespa.adminserver
    node.copy(selfdir + "gendata.c", dirs.tmpdir)
    (exitcode, output) = execute(node, "set -x && cd #{dirs.tmpdir} && gcc gendata.c && ./a.out > feed-phrases.xml")
    assert_equal(0, exitcode)
    (exitcode, output) = execute(node, "vespa-feed-perf < #{dirs.tmpdir}/feed-phrases.xml")
    assert_equal(0, exitcode)
    wait_for_hitcount("sddocname:foobar", 123456, 30)

    node.execute('vespa-proton-cmd --local triggerFlush')
    node.execute('vespa-proton-cmd --local triggerFlush')
    node.execute('vespa-proton-cmd --local die')
    wait_for_hitcount("sddocname:foobar", 123456, 30)

    clients=48
    runtime=20
    run_benchmarks(qf1, clients, runtime, 'bestcase')
    run_benchmarks(qf2, clients, runtime, 'worstcase')
    run_benchmarks(qf3, clients, runtime, 'middle')
  end

  def run_benchmarks(query_file, clients, runtime, legend)
    # Basic search
    qrserver = @vespa.container["combinedcontainer/0"]
    qd = dirs.tmpdir + "qd"
    qrserver.copy(query_file, qd)
    qf = qd + "/" + File.basename(query_file)
    puts "qf: #{qf}"
    run_fbench(qrserver, clients, runtime, qf, legend + '_untuned')
    run_fbench(qrserver, clients, runtime, qf, legend + '_delay',   "&ranking=withdelay" )
    run_fbench(qrserver, clients, runtime, qf, legend + '_split',   "&ranking=withsplit" )
    run_fbench(qrserver, clients, runtime, qf, legend + '_termwise', "&ranking=withtermwise" )
  end

  def run_fbench(qrserver, clients, runtime, qf, legend, append_str = "")
    custom_fillers = [parameter_filler("legend", legend)]
    system_fbench = Perf::System.new(qrserver)
    system_fbench.start
    fbench = Perf::Fbench.new(qrserver, qrserver.name, qrserver.http_port)
    fbench.max_line_size = 10000
    fbench.single_query_file = true
    fbench.runtime = runtime
    fbench.clients = clients
    fbench.append_str = append_str if !append_str.empty?
    fbench.ignore_first = 50
    profiler_start
    fbench.query(qf)
    system_fbench.end
    profiler_report(legend)
    fillers = [fbench.fill, system_fbench.fill]
    write_report(fillers + custom_fillers)
  end

  def get_graphs()
    profiles = [ 'untuned', 'delay', 'split', 'termwise' ]
    casenames = [ 'worstcase', 'bestcase', 'middle' ]
    maxmins = {
        'worstcase_untuned'  => { :min => 1, :max => 1000000 },
        'worstcase_delay'    => { :min => 1, :max => 1000000 },
        'worstcase_split'    => { :min => 1, :max => 1000000 },
        'worstcase_termwise' => { :min => 1, :max => 1000000 },
        'bestcase_untuned'  => { :min => 1, :max => 1000000 },
        'bestcase_delay'    => { :min => 1, :max => 1000000 },
        'bestcase_split'    => { :min => 1, :max => 1000000 },
        'bestcase_termwise' => { :min => 1, :max => 1000000 },
        'middle_untuned'  => { :min => 1, :max => 1000000 },
        'middle_delay'    => { :min => 1, :max => 1000000 },
        'middle_split'    => { :min => 1, :max => 1000000 },
        'middle_termwise' => { :min => 1, :max => 1000000 },
        'default' =>  { :min => 1, :max => 1000000 }
    }
    local_graphs = []
    profiles.each do |profile|
      casenames.each do |casename|
        case_profile = "#{casename}_#{profile}"
        mm = maxmins[case_profile]
        local_graphs.push({
            :x => 'legend',
            :y => 'qps',
            :title => "phrase_#{case_profile}_qps",
            :y_min => mm[:min],
            :y_max => mm[:max],
            :filter => {'legend' => case_profile},
            :historic => true
        })
      end
    end
    return local_graphs
  end

  def teardown
    super
  end

end
