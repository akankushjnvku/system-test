# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class Position < IndexedSearchTest

  SAVE_RESULT = false

  def setup
    set_owner("yngve")
    set_description("Ensure that basic position indexing works as intended.")
  end

  def test_position_simple
    run_test("simple", 4)
  end

  def test_position_array
    run_test("array", 2)
  end

  def test_position_extra
    run_test("extra", 4)
  end

  def test_position_update
    run_test("update", 4)
  end

  def test_assign_update_operations_in_json
    set_description("Test assign update operations in json on position field")
    test_dir = selfdir + "assign_update/"
    deploy_app(SearchApp.new.sd(test_dir + "test.sd"))
    start
    feed_and_wait_for_docs("test", 3, :file => test_dir + "docs.json")
    assert_result("query=sddocname:test&format=json", test_dir + "docs_result.json", "documentid")

    feed(:file => test_dir + "updates.json")
    assert_result("query=sddocname:test&format=json", test_dir + "updates_result.json", "documentid")
  end

  def run_test(type, hits)
    deploy_app(SearchApp.new.sd("#{selfdir}/#{type}_pos.sd"))
    start
    feed_and_wait_for_docs("#{type}_pos", hits, :file => "#{selfdir}/#{type}_feed.xml")
    run_query("query=sddocname:#{type}_pos&pos.ll=E98.987000%3BN12.123000",
              "#{selfdir}/#{type}_result1.xml");
    run_query("query=sddocname:#{type}_pos&pos.ll=E98.987987%3BN12.123123",
              "#{selfdir}/#{type}_result2.xml");
  end

  def run_query(query, file)
    if (SAVE_RESULT)
      save_result(query, file)
    else
      assert_result(query, file, "my_pos.distance")
    end
  end

  def teardown
    stop
  end

end
