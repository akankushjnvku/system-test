require 'performance_test'
require 'app_generator/search_app'
require 'json_document_writer'

class WeightedSetFeedTest < PerformanceTest

  FIELD_TYPE = 'field_type'
  WSET = 'wset'
  WSET_SIZE = 'wset_size'
  FAST_SEARCH = 'fast_search'
  KEY_TYPE = 'key_type'
  LONG_TYPE = 'long'
  STRING_TYPE = 'string'

  def setup
    super
    set_owner('vekterli')
    @graphs = get_graphs
    @tainted = false
  end

  def teardown
    super
  end

  def feed_initial_wsets(doc_count:, field_name:, key_type:, wset_size:, fast_search:)
    if @tainted
      puts 'Wiping existing index data on node to ensure previous tests do not pollute results'
      node = vespa.storage['search'].storage['0']
      node.stop_base
      node.clean_indexes
      node.start_base
    end
    puts '-----------'
    puts "Feeding #{doc_count} documents with weighted set field #{field_name} with #{wset_size} elements, fast-search=#{fast_search}"
    puts '-----------'
    puts 'Doing initial container warmup pass'
    warmup_doc_count = [doc_count/5, 100].max
    feed_stream("#{@data_generator} #{warmup_doc_count} #{wset_size} #{field_name}",
                :route => '"combinedcontainer/chain.indexing null/default"')
    puts 'Doing actual backend feed pass'
    profiler_start
    run_stream_feeder("#{@data_generator} #{doc_count} #{wset_size} #{field_name}",
                      [parameter_filler(FIELD_TYPE, WSET),
                       parameter_filler(KEY_TYPE, key_type),
                       parameter_filler(WSET_SIZE, wset_size),
                       parameter_filler(FAST_SEARCH, fast_search.to_s)])
    profiler_report("wset_size=#{wset_size},fast_search=#{fast_search}")
    @tainted = true
  end

  def create_app
    # We only care about single node performance for this test.
    SearchApp.new.sd(selfdir + 'footype.sd').
    num_parts(1).redundancy(1).ready_copies(1).
    container(Container.new("combinedcontainer").
                            jvmargs('-Xms16g -Xmx16g').
                            search(Searching.new).
                            docproc(DocumentProcessing.new).
                            gateway(ContainerDocumentApi.new)).
    generic_service(GenericService.new('devnull', "#{Environment.instance.vespa_home}/bin/vespa-destination --instant --silent 1000000000"))
  end

  class TestInstanceParams
    attr_reader :wset_size, :fast_search, :y_min, :y_max
    def initialize(wset_size, fast_search, y_min, y_max)
      @wset_size = wset_size
      @fast_search = fast_search
      @y_min = y_min
      @y_max = y_max
    end
  end

  def params(wset_size, fast_search, y_min, y_max)
    TestInstanceParams.new(wset_size, fast_search, y_min, y_max)
  end

  def parameter_combinations
    [
      params(10,     false, 33000,   40000),
      params(100,    false, 19500,   21500),
      params(1000,   false,  2400,    2900),
      params(10000,  false,   240,     275),
      params(100000, false,    19,      22),
      params(10,     true,  19500,   23500),
      params(100,    true,   1500,    2000),
      params(1000,   true,    190,     225),
      params(10000,  true,     18.9,    22.5),
      params(100000, true,      2.2,     2.6)
    ]
  end

  def get_graphs
    parameter_combinations.map do |p|
      {
        :x => FIELD_TYPE,
        :y => 'feeder.throughput',
        :title => "Throughput of weighted set feeding with #{p.wset_size} elements per set, key type long, fast search #{p.fast_search}",
        # TODO string type
        :filter => { WSET_SIZE => p.wset_size, KEY_TYPE => LONG_TYPE, FAST_SEARCH => p.fast_search.to_s},
        :historic => true,
        :y_min => p.y_min,
        :y_max => p.y_max
      }
    end.to_a
  end

  def string_attr_name(fast_search)
    fast_search ? 'wset_attr_string_fs' : 'wset_attr_string_nofs'
  end

  def long_attr_name(fast_search)
    fast_search ? 'wset_attr_long_fs' : 'wset_attr_long_nofs'
  end

  def test_wset_attribute_feed_performance
    set_description('Test feed performance of varying sizes of weightedset attributes, ' +
                    'with and without fast-search')
    deploy_app(create_app)
    start

    @data_generator = "#{dirs.tmpdir}/docs"
    container = (vespa.qrserver["0"] or vespa.container.values.first)
    container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{@data_generator} #{selfdir}/docs.cpp")

    doc_count = 10_000_000
    parameter_combinations.each do |p|
      # Reduce document count for large cardinalities to keep test time reasonable.
      test_doc_count = doc_count / p.wset_size
      test_doc_count *= 10 if !p.fast_search #10x more for non fast-search
      test_doc_count = [test_doc_count, 2_000_000].min
      feed_initial_wsets(doc_count: test_doc_count, field_name: long_attr_name(p.fast_search),
                         key_type: LONG_TYPE, wset_size: p.wset_size, fast_search: p.fast_search)
    end
  end

end

