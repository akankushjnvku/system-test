# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class SourceProvider < IndexedSearchTest

  def setup
    set_owner("nobody")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd").
                        search_dir(selfdir + "search").
                        search_chain(SearchChain.new("default").inherits(nil).
                                       add(Federation.new("federationSearcher").
                                             add("search").
                                             add("local").
                                             add("local_other")
                                          )
                                    ).
                        search_chain(Provider.new("search", "local").cluster("search")).
                        search_chain(Provider.new("local", "local").cluster("search")).
                        search_chain(Provider.new("local_other", "local").cluster("search"))
                     )
    start
    feed_and_wait_for_docs("music", 777, :file => SEARCH_DATA+"music.777.xml")
  end

  def test_nonexisting_source
    wait_for_atleast_hitcount("sddocname:music&sources=search,local&hits=0", 777*2)
    singleresult = search("sddocname:music&sources=search")
    assert_equal(777, singleresult.hitcount)
    assert_query_no_errors("sddocname:music&sources=search")
    nonexistingresult = search("sddocname:music&sources=nonexisting,search&hits=0")
    assert_equal(777, nonexistingresult.hitcount)
    assert_query_errors("sddocname:music&sources=search,nonexisting&hits=0",[
      "Could not resolve source ref 'nonexisting'. Valid source refs are .*"
    ]);

  end

  def test_settings
    wait_for_atleast_hitcount("sddocname:music&sources=search,local", 777*2)
    singleresult = search("sddocname:music&sources=search")
    assert_equal(777, singleresult.hitcount)
    multiresult = search("sddocname:music&sources=search,local&rankfeature.$now=42")
    assert_equal(777*2, multiresult.hitcount)


    #Check that the result in the two groups are equal
    #Since we have groups, we have to parse the hits ourselves
    groups = parseGroups(multiresult.xml)
    (0..10).each {|i|
      assert_equal(groups["local"][i], groups["search"][i])
    }

    ##Test out properties
    sourceresult = search("sddocname:music&sources=search,local&source.search.hits=5&source.search.offset=5&source.local.offset=10&source.local.hits=15")

    sourcegroups = parseGroups(sourceresult.xml)

    assert_equal(15, sourcegroups["local"].size)
    assert_equal(5, sourcegroups["search"].size)
    assert_equal(groups["search"][5], sourcegroups["search"][0])

    providerresult = search("sddocname:music&sources=local&provider.local.hits=15&source.local.hits=5&provider.local.offset=5")

    providergroups = parseGroups(providerresult.xml)

    assert_equal(5, providergroups["local"].size)
    assert_equal(groups["local"][5], providergroups["local"][0])
  end


  def megs(i)
     i << 20
  end


  def parseGroups(xml)
    groups = {}
    xml.each_element("group") { |groupEl|
      hits = []

      groupEl.each_element("hit") { |hitEl|
        if not hitEl.attributes["type"] == "logging" then
          hits.push  Hit.new(hitEl)
        end
      }
      # Ugly hack to handle a single level of nested, unnamed groups
      groupEl.each_element("group") { |innerGroupEl|
        hits = []
        innerGroupEl.each_element("hit") { |hitEl|
          if not hitEl.attributes["type"] == "logging" then
            hits.push  Hit.new(hitEl)
          end
        }
      }
      groups[groupEl.attributes["source"]] = hits
    }
    return groups
  end

  def teardown
    stop
  end
end
