# -*- coding: utf-8 -*-
require 'CaboCha'
require File.join(File.dirname(__FILE__), 'ipadic_ext')

if (RUBY_VERSION < "1.9.0")
  $KCODE = 'u'
end

# CaboChaモジュールを拡張
module CaboCha
  # OPTIONS = "-u " + File.join(File.dirname(__FILE__), './mecab/user.dic')
  OPTIONS = ""
  def self.instance
    @@cabocha ||= CaboCha::Parser.new(OPTIONS)
  end
  def self.parse(s, options = {})
    tree = instance.parse(s.to_s)
    if (options[:fix])
      s = []
      tree.chunks.each do |chunk|
        noun = false
        chunk.tokens.each do |token|
          if (noun && token.verb?)
            s << "、"
            s << token.surface.force_encoding("utf-8")
          else
            s << token.surface.force_encoding("utf-8")
          end
          if (token.noun? && !token.sahen_setsuzoku?)
            noun = true
          else
            noun = false
          end
        end
      end
      tree = instance.parse(s.join)
    end
    tree
  end
  class Token
    alias :surface_org :surface
    alias :feature_list_org :feature_list
    include IpadicExt
    def feature_list(i)
      if (@feature_list)
        @feature_list[i]
      else
        if ("".respond_to?("force_encoding"))
          @feature_list ||= (0 ... feature_list_size).map do |j|
            feature = feature_list_org(j)
            feature.force_encoding("utf-8")
          end
          @feature_list[i]
        else
          @feature_list ||= (0 ... feature_list_size).map{|j| feature_list_org(j) }
          @feature_list[i]
        end
      end
    end
    
    def features
      @feature_list ||= (0 ... feature_list_size).map{|j| feature_list_org(j).force_encoding("utf-8") }
    end
  end
  class Chunk
    attr_accessor :tree

    # 活用
    def v_inflect(type)
      if (verb_sahen?)
        tokens[0].to_base + tokens[1].v_inflect(type)
      else
        tokens[0].v_inflect(type)
      end
    end
    # 未然形
    def to_mizen
      @to_mizen ||= v_inflect(0)
    end
    # 連用形
    def to_renyo
      @to_renyo ||= v_inflect(1)
    end
    # 終止形
    def to_syushi
      @to_syushi ||= v_inflect(2)
    end
    # 連体形
    def to_rentai
      @to_rentai ||= v_inflect(3)
    end
    # 仮定形
    def to_katei
      @to_katei ||= v_inflect(4)
    end
    # 命令形
    def to_meirei
      @to_meirei ||= v_inflect(5)
    end
    # 否定形
    def to_negative
      @to_negative ||=
        if (noun?)
          to_base + 'じゃない'
        elsif (adjective?)
          if (to_base == "ない" || to_base == "無い")
            "ある"
          else
            to_base.gsub(/\w$/,'') + 'くない'
          end
        elsif (verb?)
          if (to_base == 'ある')
            "ない"
          else
            to_mizen + "ない"
          end
        else
          to_base
        end
    end
    def negative?
      if (verb?)
        tokens.each do |token|
          if (token.to_base == "ない" ||
              (token.auxiliary_verb? && token.to_base == "ん"))
            return true
          end
        end
      elsif (noun?)
        ns = tokens.select{|t| !t.noun? && !t.meishi_setsuzoku?}
        n = ns[0]
        nn = ns[1]
        nnn = ns[2]
        if (n &&
            (
             (n.to_base == "じゃ" && nn && nn.to_base == "ない") ||
             (n.to_base == "で" &&
              nn && nn.to_base == "は" && nnn && nnn.to_base == "ない") ||
             (n.to_base == "じゃ" && nn && nn.to_base =~ /^ね/) ||
             (n.to_base == "や" && nn && nn.to_base == "ない")
             ))
          return true
        end
      elsif (adjective?)
        n = tokens[1]
        if (n && (tokens[0].to_base == "ない" || (n && n.to_base == "ない")))
          return true
        end
      end
      false
    end
    def gimon_rentaishi?
      to_s =~ /どうようになる/ ? true : false
    end

    def gimon_daimeishi?
      @gimon_daimeishi ||=
        tokens[0].gimon_daimeishi?
    end
    def gimon_fukushi?
      @gimon_fukushi ||= 
        if (tokens[0].gimon_fukushi?)
          true
        else
          if (to_s =~ /どうしない/ || to_s =~ /どうする/)
            true
          elsif (['する','なる'].include?(tokens[0].to_base))
            prev_chunks.each do |pc|
            if (pc.tokens[0].to_base == 'どう')
              return true
            end
          end
          end
          false
        end
    end
    def question?
      if (verb? || noun? || adjective?)
        tokens.each do |token|
          if ((token.shu_joshi? && ['か','の'].include?(token.to_base)) ||
              token.tai? ||
              token.hatena?)
            return true
          end
        end
        false
      elsif (gimon_rentaishi? || gimon_daimeishi? || gimon_fukushi?)
        true
      else
        false
      end
    end
    def to_noun
      @to_noun ||=
        if (noun?)
          to_base
        elsif (verb?)
          # 飛ぶの, 泳ぐの
          to_base + 'の'
        elsif (adjective?)
          # かわいいの, 大きいの
          to_base + 'の'
        else
          to_base
        end
    end
    
    # 動詞？
    def verb?
      tokens[0].verb? || verb_sahen?
    end
    # 名詞サ変接続+スル 動詞 (掃除する 洗濯する など)
    def verb_sahen?
      (tokens.length > 1 &&
       ((tokens[0].sahen_setsuzoku? && tokens[1].sahen_suru?) ||
        (tokens[0].sahen_setsuzoku? && tokens[1].sahen_dekiru?)))
    end
    # 名詞？
    def noun?
      (!verb_sahen? && (tokens[0].noun? || tokens[0].meishi_setsuzoku?))
    end
    # 形容詞？
    def adjective?
      tokens[0].adjective?
    end
    # 主語っぽい？
    def subject?
      (((noun? && %w(は って も が).include?(tokens[-1].to_s)) ||
        (adjective? && %w(は って も が).include?(tokens[-1].to_s)) ||
        (verb? && %w(は って も が).include?(tokens[-1].to_s))))
    end
    # 基本形へ
    def to_base
      @to_base ||=
        if (noun?)
          # 連続する名詞、・_や名詞接続をくっつける
          base = ""
          tokens.each do |token|
          if (token.meishi_setsuzoku?)
            base += token.to_base
          elsif (token.noun?)
            base += token.to_base
          elsif (["_","・"].include?(token.to_s))
            base += token.to_base
          elsif (base.length > 0)
            break
          end
        end
          base
        elsif (verb_sahen?)
          tokens[0].to_base + tokens[1].to_base
        elsif (verb?)
          tokens[0].to_base
        elsif (adjective?)
          tokens[0].to_base
        else
          to_s
        end
    end
    
    def tokens
      @tokens ||= (0 ... token_size).map{|i| tree.token(token_pos + i) }
    end
    def next_chunk
      @next_chunk ||= (link >= 0) ? tree.chunk(link) : nil
    end
    def prev_chunks
      @prev_chunks ||= tree.chunks.select{|chunk| chunk.link == self_index }
    end
    def to_s
      @to_s ||= tokens.map{|t| t.to_s }.join
    end
    def self_index
      @self_index ||= tree.chunks.reduce([nil, 0]) do |argv, chunk| 
        if (chunk.token_pos == self.token_pos)
          argv[0] = argv[1]
        else
          argv[1] += 1
        end
        argv
      end.shift
    end
  end
  class Tree
    alias :chunk_org :chunk
    def chunk(i)
      if (@chunks)
        @chunks[i]
      else
        chunk = chunk_org(i)
        chunk.tree = self
        chunk
      end
    end
    def chunks
      @chunks ||= (0 ... chunk_size).map {|i| chunk(i)}
    end
    def dump
      chunks.each do |chunk|
        puts "--"
        chunk.tokens.map do |token|
          print token, ": ", token.features.join(","), "\n"
        end
      end
      false
    end
  end
end
