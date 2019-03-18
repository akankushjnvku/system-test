# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'performance/tensor_eval/utils/query_generator'
require 'performance/tensor_eval/utils/tensor_generator'
require 'pp'
require 'environment'

class TensorEvalPerfTest < PerformanceTest

  FBENCH_RUNTIME = 30
  EVAL_TYPE = "eval_type"
  RANK_PROFILE = "rank_profile"
  WSET_ENTRIES = "wset_entries"
  DOT_PRODUCT = "dot_product"
  MATCH = "match"
  MATRIX_PRODUCT = "matrix_product"
  FEATURE_DOT_PRODUCT = "feature_dot_product"
  FEATURE_DOT_PRODUCT_ARRAY = "feature_dot_product_array"
  SPARSE_TENSOR_DOT_PRODUCT = "sparse_tensor_dot_product"
  TENSOR_MATCH_25X25 = "tensor_match_25x25"
  TENSOR_MATCH_50X50 = "tensor_match_50x50"
  TENSOR_MATCH_100X100 = "tensor_match_100x100"
  DENSE_TENSOR_DOT_PRODUCT = "dense_tensor_dot_product"
  DENSE_TENSOR_DOT_PRODUCT_UNBOUND = "dense_tensor_dot_product_unbound"

  def initialize(*args)
    super(*args)
  end

  def create_app
    SearchApp.new.sd(selfdir + "test.sd").
      search_dir(selfdir + "search").
      search_chain(SearchChain.new.add(Searcher.new("com.yahoo.test.TensorInQueryBuilderSearcher"))).
      rank_expression_file(dirs.tmpdir + "sparse_tensor_25x25.json").
      rank_expression_file(dirs.tmpdir + "sparse_tensor_50x50.json").
      rank_expression_file(dirs.tmpdir + "sparse_tensor_100x100.json").
      rank_expression_file(dirs.tmpdir + "dense_matrix_10x10.json").
      rank_expression_file(dirs.tmpdir + "dense_matrix_25x25.json").
      rank_expression_file(dirs.tmpdir + "dense_matrix_50x50.json").
      rank_expression_file(dirs.tmpdir + "dense_matrix_100x100.json")
  end

  def deploy_and_feed(num_docs_per_type)
    add_bundle(selfdir + "TensorInQueryBuilderSearcher.java")
    generate_tensor_files
    deploy_app(create_app)
    start
    generate_query_files
    feed_docs(num_docs_per_type)
    @container = vespa.container.values.first
  end

  def generate_tensor_files
    puts "generate_tensor_files"
    srand(123456789)
    TensorEvalTensorGenerator.write_tensor_files(dirs.tmpdir)
  end

  def generate_query_files()
    puts "generate_query_files()"
    TensorEvalQueryGenerator.write_query_files(dirs.tmpdir)
  end

  def feed_docs(num_docs)
    container = (vespa.qrserver["0"] or vespa.container.values.first)
    container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{dirs.tmpdir}/docs #{selfdir}/docs.cpp")
    container.execute("#{dirs.tmpdir}/docs #{num_docs} | vespa-feeder")
  end

  def run_fbench_helper(eval_type, rank_profile, wset_entries, query_file)
    puts "run_fbench_helper(#{eval_type}, #{rank_profile}, #{wset_entries}, #{query_file})"
    query_file = fetch_query_file(query_file)
    fillers = [parameter_filler(EVAL_TYPE, eval_type),
               parameter_filler(RANK_PROFILE, rank_profile),
               parameter_filler(WSET_ENTRIES, wset_entries)]
    mangled_rank_profile = rank_profile
    if rank_profile == DENSE_TENSOR_DOT_PRODUCT
      mangled_rank_profile += "_" + wset_entries.to_s
    end
    profiler_start
    run_fbench2(@container,
                query_file,
                {:runtime => FBENCH_RUNTIME, :clients => 1, :append_str => "&ranking=#{mangled_rank_profile}&summary=min_summary&timeout=10"},
                fillers)
    profiler_report(get_label(eval_type, rank_profile, wset_entries))
  end

  def fetch_query_file(query_file)
    query_file = dirs.tmpdir + query_file
    @container.copy(query_file, File.dirname(query_file))
    query_file
  end

  def get_label(eval_type, rank_profile, wset_entries)
    "#{EVAL_TYPE}-#{eval_type}.#{RANK_PROFILE}-#{rank_profile}.#{WSET_ENTRIES}-#{wset_entries}"
  end

  def get_latency_graphs_for_rank_profile(rank_profile)
    {
      :x => WSET_ENTRIES,
      :y => "latency",
      :title => "Historic latency for rank profile '#{rank_profile}' with various number of entries in query and document weighted sets",
      :filter => {RANK_PROFILE => rank_profile},
      :historic => true
    }
  end

  def get_latency_graph_for_rank_profile(rank_profile, wset_entries, y_min, y_max)
    {
      :x => WSET_ENTRIES,
      :y => "latency",
      :title => "Historic latency for rank profile '#{rank_profile}' with #{wset_entries} entries in query and document",
      :filter => {RANK_PROFILE => rank_profile, WSET_ENTRIES => wset_entries},
      :historic => true,
      :y_min => y_min,
      :y_max => y_max
    }
  end

  def get_latency_graphs_for_eval_type(eval_type)
    {
      :x => RANK_PROFILE,
      :y => "latency",
      :title => "Historic latency for eval type '#{eval_type}' with rank profiles with various matrix sizes",
      :filter => {EVAL_TYPE => eval_type},
      :historic => true
    }
  end

end
