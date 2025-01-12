# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'
require 'environment'

class CoreDump < SearchTest

  def setup
    set_description("Test that coredump control and limiting works")
    set_owner("balder")
    @valgrind = false
    @coredump_sleep = 30
  end

  def get_lz4_program(node)
    lz4_program = "#{Environment.instance.vespa_home}/bin64/lz4"
    lz4_program = "/usr/bin/lz4" unless node.file_exist?(lz4_program)
    lz4_program
  end

  def show_kernel_core_pattern(node)
    node.execute("/sbin/sysctl kernel.core_pattern")
  end

  def expected_core_file(node, binary, pid)
    corefile = show_kernel_core_pattern(node).split[-1].gsub('%e', binary).gsub('%p', pid)
    assert(corefile.start_with?("#{Environment.instance.vespa_home}/var/crash/"),
           "/proc/sys/kernel/core_patern shall start with #{Environment.instance.vespa_home}/var/crash/")
    corefile
  end

  def test_coredump_compression
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
    feed_and_wait_for_docs("music", 10000, :file => SEARCH_DATA+"music.10000.xml")

    pid = vespa.adminserver.execute("pgrep vespa-proton-bi").strip
    fullcorefile = expected_core_file(vespa.adminserver, 'vespa-proton-bi', pid)
    corefile = File.basename(fullcorefile)

    before = vespa.adminserver.find_coredumps(@starttime, corefile)

    vespa.adminserver.execute("/bin/kill -SIGSEGV " + pid)

    after = vespa.adminserver.find_coredumps(@starttime, corefile)

    3.times do
      break unless after.empty?
      sleep @coredump_sleep
      after = vespa.adminserver.find_coredumps(@starttime, corefile)
    end

    assert_equal(0, before.size, "Expected no coredumps.")
    assert_equal(1, after.size, "Expected one coredump.")
    assert_equal(fullcorefile, after.first, "Expected coredump #{fullcorefile}.")

    if fullcorefile.end_with?("lz4")
      sleep @coredump_sleep # We are decompressing the file. Allow some time to let the kernel finish writing it.
      filetype = vespa.adminserver.execute("file -b " + fullcorefile + " | cut -d ',' -f1").strip
      assert_match(/^(data|LZ4 compressed data \(v.*\))$/, filetype, "Unexpected file type.")
      lz4_program = get_lz4_program(vespa.adminserver)
      vespa.adminserver.execute("#{lz4_program} -d < " + fullcorefile + " > #{fullcorefile}.core")
      fullcorefile_uncompressed = "#{fullcorefile}.core"
    else
      fullcorefile_uncompressed = fullcorefile
    end

    filetype = vespa.adminserver.execute("file -b " + fullcorefile_uncompressed + " | cut -d ',' -f1").strip
    assert_match(/^ELF 64-bit LSB core file( x86-64)?$/, filetype, "Unexpected file type.")

    vespa.adminserver.execute("rm -f #{fullcorefile} #{fullcorefile_uncompressed}")
  end

  def test_coredump_overwrite
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
    feed_and_wait_for_docs("music", 10000, :file => SEARCH_DATA+"music.10000.xml")
    show_kernel_core_pattern(vespa.adminserver)
    execute_result = vespa.adminserver.execute("/sbin/sysctl kernel.core_pattern=\"|/usr/bin/lz4 -3 - #{Environment.instance.vespa_home}/var/crash/%e.core.lz4\"", :exitcode => true)

    # This will fail when running inside docker containers
    if execute_result[0] != "0" || ENV["container"] == "docker"
      puts "Failed to set kernel.core_pattern or running in a container, skipping test"
      return
    end

    pid = vespa.adminserver.execute("pgrep vespa-proton-bi").strip
    fullcorefile = expected_core_file(vespa.adminserver, 'vespa-proton-bi', pid)

    vespa.adminserver.execute("touch " + fullcorefile)
    vespa.adminserver.execute("/bin/kill -SIGSEGV " + pid)
    sleep @coredump_sleep
    filetype = vespa.adminserver.execute("file -b " + fullcorefile + " | cut -d ',' -f1").strip
    assert_equal("empty", filetype)

    vespa.adminserver.execute("/sbin/sysctl kernel.core_pattern=\"|/usr/bin/lz4 --force -3 - #{Environment.instance.vespa_home}/var/crash/%e.core.lz4\"")
    wait_for_hitcount("query=sddocname:music", 10000)
    pid = vespa.adminserver.execute("pgrep vespa-proton-bi").strip
    vespa.adminserver.execute("/bin/kill -SIGSEGV " + pid)
    sleep @coredump_sleep
    filetype = vespa.adminserver.execute("file -b " + fullcorefile + " | cut -d ',' -f1").strip
    assert_match(/^(data|LZ4 compressed data \(v.*\))$/, filetype, "Unexpected file type.")
    lz4_program = get_lz4_program(vespa.adminserver)
    vespa.adminserver.execute("#{lz4_program} -d < " + fullcorefile + " > #{fullcorefile}.core")
    filetype = vespa.adminserver.execute("file -b -z " + fullcorefile + ".core | cut -d ',' -f1").strip
    assert_match(/^ELF 64-bit LSB core file( x86-64)?$/, filetype, "Unexpected file type.")

    vespa.adminserver.execute("/sbin/sysctl kernel.core_pattern=\"|/usr/bin/lz4 -3 - #{Environment.instance.vespa_home}/var/crash/%e.core.%p.lz4\"")
    vespa.adminserver.execute("rm #{fullcorefile} #{fullcorefile}.core")
  end

  def test_application_mmaps_in_core_limiting
    deploy("#{selfdir}/app")
    start
  end

  def teardown
    show_kernel_core_pattern(vespa.adminserver)
    stop
  end

end

