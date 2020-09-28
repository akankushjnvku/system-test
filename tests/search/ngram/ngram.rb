# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
# encoding: utf-8
require 'indexed_search_test'

class NGram < IndexedSearchTest

  def setup
    set_owner("bratseth")
    deploy_app(SearchApp.new.sd(selfdir+"test.sd"))
    start
  end

  def teardown
    stop
  end

  def test_ngram
    feed_and_wait_for_docs("test", 3, :file => "#{selfdir}/documents.xml")

    # Whole word which is in both title and body
    assert_hitcount("query=title:java", 2)
    assert_hitcount("query=body:java", 2)
    assert_hitcount("query=default:java", 2)
    assert_hitcount("query=java", 2)

    # Whole word in title only
    assert_hitcount("query=title:on", 2)
    assert_hitcount("query=body:on", 0)
    assert_hitcount("query=default:on", 2)
    assert_hitcount("query=on", 2)

    # Whole word in body only
    assert_hitcount("query=title:scene", 0)
    assert_hitcount("query=body:scene", 2)
    assert_hitcount("query=default:scene", 2)
    assert_hitcount("query=scene", 2)

    # Substring in body
    assert_hitcount("query=title:opul", 0)
    assert_hitcount("query=body:opul", 2)
    assert_hitcount("query=default:opul", 2)
    assert_hitcount("query=opul", 2)

    # Substring	across word boundaries in body only
    assert_hitcount("query=title:enefr", 0)
    assert_hitcount("query=body:enefr", 1)
    assert_hitcount("query=default:enefr", 1)
    assert_hitcount("query=enefr", 1)

    # No lowercasing is done on the input data, so words containing uppercase
    # letters will not match. This is not a problem since ngrams will only be
    # used by CJK languages, where there is no upper/lowercase.
    assert_hitcount("query=title:logging", 2)
    assert_hitcount("query=body:logging", 2)
    assert_hitcount("query=default:logging", 2)
    assert_hitcount("query=logging", 2)

    # Matching both header and body
    assert_hitcount("query=default:java title:oggingin body:enefr", 1)

    # Check result fields
    assert_field_value("query=title:abo","title","on/about #Logging in #Java")
    assert_field_value("query=body:opul","body",
                       "#Logging in #Java is like that \"Judean P<hi>opul</hi>ar Front\" scene from \"Life of Brian\".")
    assert_field_value("query=large:do","large",
                       "<sep/>am not saying that you should never use \"else\" in your code, but when you <hi>do</hi>, you should stop and think about what you are doing, because most of<sep/>")

    # CJK
    assert_hitcount_with_timeout(10, "?query=body:古牧区&language=zh-Hans", 1)
    assert_field_value("?query=body:牧区雪灾救援&language=zh-Hans","body",
                       "\n内蒙古<hi>牧区雪灾救援</hi>困\n  ")
  end
end
