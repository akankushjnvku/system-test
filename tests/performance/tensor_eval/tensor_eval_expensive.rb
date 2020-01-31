# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance/tensor_eval/tensor_eval'

class TensorEvalExpensivePerfTest < TensorEvalPerfTest

  def setup
    super
    set_owner("geirst")
  end

  def test_tensor_evaluation_expensive
    set_description("Test performance of various expensive tensor evaluation use cases")
    @graphs = get_graphs_expensive
    deploy_and_feed(5000)

    [5,10,25].each do |wset_entries|
      run_fbench_helper(MATCH, TENSOR_MATCH_25X25, wset_entries, "queries.tensor.sparse.y.#{wset_entries}.txt")
    end

    [5,10,25,50].each do |wset_entries|
      run_fbench_helper(MATCH, TENSOR_MATCH_50X50, wset_entries, "queries.tensor.sparse.y.#{wset_entries}.txt")
    end

    [5,10,25,50,100].each do |wset_entries|
      run_fbench_helper(MATCH, TENSOR_MATCH_100X100, wset_entries, "queries.tensor.sparse.y.#{wset_entries}.txt")
    end

    [10,25,50,100].each do |wset_entries|
      rank_profile = "tensor_matrix_product_#{wset_entries}x#{wset_entries}"
      query_file = "queries.tensor.dense.#{wset_entries}.txt"
      run_fbench_helper(MATRIX_PRODUCT, rank_profile, wset_entries, query_file)
    end
  end

  def get_graphs_expensive
    [
      get_latency_graphs_for_rank_profile(TENSOR_MATCH_25X25),
      get_latency_graphs_for_rank_profile(TENSOR_MATCH_50X50),
      get_latency_graphs_for_rank_profile(TENSOR_MATCH_100X100),
      get_latency_graphs_for_eval_type(MATRIX_PRODUCT),
      get_latency_graph_for_rank_profile(TENSOR_MATCH_50X50,            50, 410, 490),
      get_latency_graph_for_rank_profile("tensor_matrix_product_25x25", 25, 1.80, 2.35)
    ]
  end

  def teardown
    super
  end

end
