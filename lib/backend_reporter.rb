
require 'concurrent'

begin
  require 'backend_client'
  BACKEND_CLIENT_OVERRIDE = true
rescue LoadError
  BACKEND_CLIENT_OVERRIDE = false
end

class BackendReporter < BackendClient
  def initialize(testrun_id, basedir, log)
    super(testrun_id, basedir, log)
    @testrun_id = testrun_id
  end

  def initialize_testrun(test_objects)
    super(test_objects)
  end

  def test_running(test_case, method_name)
    super(test_case, method_name)
  end

  def test_finished(test_case, test_result)
    super(test_case, test_result)
  end

  def finalize_testrun
    true
  end

end if BACKEND_CLIENT_OVERRIDE

class BackendReporter
  def initialize(testrun_id, basedir, log)
    @testrun_id = testrun_id
    @basedir = basedir
    @log = log
    @test_results = Concurrent::Hash.new
    @test_names = Concurrent::Array.new
  end

  def initialize_testrun(test_objects)
    test_objects.each do |object, methods|
      methods.each do |method|
        @test_names << "#{object.class}::#{method.to_s}"
      end
    end
  end

  def test_running(test_case, method_name)
    nil
  end

  def test_finished(test_case, test_result)
    @test_results["#{test_case.class}::#{test_result.name}"] = test_result
  end

  def finalize_testrun
    successful_tests = @test_results.select { |name, result| result.passed? }
    failed_tests = @test_results.reject { |name, result| result.passed? }
    @log.info "#################"
    @log.info "Successful tests:"
    successful_tests.each { |key, value| @log.info "  #{key}   #{value.to_s}" }
    @log.info "#################"
    @log.info "Failed tests:"
    failed_tests.each { |key, value| @log.info "  #{key}   #{value.to_s}" }
    @log.info "#################"

    tests_not_run = @test_names.to_set ^ @test_results.map { |name, result| name}.to_set
    unless tests_not_run.empty?
      @log.info "#################"
      @log.info "Tests not run:"
      tests_not_run.each { |klass| @log.info "  #{klass}" }
      @log.info "#################"
    end

    failed_tests.empty?
  end

end unless BACKEND_CLIENT_OVERRIDE