# -*- coding: utf-8 -*-
require 'MeCab'
require 'date'
require File.join(File.dirname(__FILE__), './ipadic_ext')
module MeCab
  # OPTIONS = "-u " + File.join(File.dirname(__FILE__), './mecab/user.dic')
  OPTIONS = ""
  TTL = 1
  @@mecab = nil
  def self.instance
    if @@mecab
      if DateTime.now - @@instance_time > TTL
        reload
      end
    else
      @@instance_time = DateTime.now
      @@mecab = MeCab::Tagger.new(OPTIONS)
    end
    @@mecab
  end
  def self.reload
    @@mecab = nil
    @@instance_time = DateTime.now
    @@mecab = MeCab::Tagger.new(OPTIONS)
  end
  
  class Tagger
    def nodes(text)
      node = parseToNode(text)
      nodes = []
      while node
        nodes << NodeEmu.new(node)
        node = node.next
      end
      nodes[1 ... -1]
    end
  end
  class NodeEmu
    attr_accessor :surface_org
    include IpadicExt
    def initialize(node)
      @surface_org = node.surface_org
      @feature_list = node.feature.force_encoding("utf-8").split(",")
    end
    def feature_list_size
      @feature_list.size
    end
    def feature_list(n)
      @feature_list[n]
    end
  end
  class Node
    alias :surface_org :surface
    
    include IpadicExt
    
    def set_feature_list
      @feature_list ||= feature.force_encoding("utf-8").split(",")
    end
    def feature_list(n)
      set_feature_list
      @feature_list[n]
    end
    def feature_list_size
      set_feature_list      
      @feature_list.size
    end
  end
end
