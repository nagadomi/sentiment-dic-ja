# -*- coding: utf-8 -*-
require 'nkf'
require File.join(File.dirname(__FILE__), 'mecab_ext')
require File.join(File.dirname(__FILE__), 'cabocha_ext')

module SentimentAnalyzer
  ADJ = 1
  NOUN_ADJV = 2
  DUMMY_NOUN = "THETARGET"
  
  @@dic = nil
  def self.get_dic
    @@dic ||= load_dic
  end
  def self.load(file)
    dic = {}
    File.read(file).split("\n").each do |line|
      surface, kana = line.split(":")
      dic[kana] ||= []
      dic[kana] << surface
    end
    dic
  end
  def self.load_dic
    adj_posi = load(File.join(File.dirname(__FILE__), '../adj_posi.txt'))
    adj_nega = load(File.join(File.dirname(__FILE__), '../adj_nega.txt'))
    noun_adjv_posi = load(File.join(File.dirname(__FILE__), '../noun_adjv_posi.txt'))
    noun_adjv_nega = load(File.join(File.dirname(__FILE__), '../noun_adjv_nega.txt'))
    dic = {}
    adj_posi.each do |kana, surfaces|
      dic[kana] ||= []
      dic[kana] << {:type => ADJ, :surface => kana, :sign => 1}
      surfaces.each do |surface|
        dic[surface] ||= []
        dic[surface] << {:type => ADJ, :surface => surface, :sign => 1}
      end
    end
    adj_nega.each do |kana, surfaces|
      dic[kana] ||= []
      dic[kana] << {:type => ADJ, :surface => kana, :sign => -1}
      surfaces.each do |surface|
        dic[surface] ||= []
        dic[surface] << {:type => ADJ, :surface => surface, :sign => -1}
      end
    end
    noun_adjv_posi.each do |kana, surfaces|
      dic[kana] ||= []
      dic[kana] << {:type => NOUN_ADJV, :surface => kana, :sign => 1}
      surfaces.each do |surface|
        dic[surface] ||= []
        dic[surface] << {:type => NOUN_ADJV, :surface => surface, :sign => 1}
      end
    end
    noun_adjv_nega.each do |kana, surfaces|
      dic[kana] ||= []
      dic[kana] << {:type => NOUN_ADJV, :surface => kana, :sign => -1}
      surfaces.each do |surface|
        dic[surface] ||= []
        dic[surface] << {:type => NOUN_ADJV, :surface => surface, :sign => -1}
      end
    end
    dic
  end
  def self.analyze(text)
    dic = get_dic
    tagger = MeCab.instance
    nodes = tagger.nodes(normalize(text))
    positive_word = []
    negative_word = []
    other_word = []
    nodes.each_with_index do |node, i|
      if node.adj_independent?
        surface = node.to_base
        if (rec = dic[surface]) && node.to_s.size > 1
          rec = rec.select{|v| v[:type] == ADJ}
          if rec.size == 0
            next
          end
          rec = rec[0]
          negation = 
            if i + 1 < nodes.size
              nodes[i + 1 .. i + 2].reduce(false) {|r,v|
                r || (v.to_base == "ない" || v.to_base == "わけ")
              }
            else
              false
            end
          if negation
            new_surface = surface[0 ... -1] + "くない"
            if rec[:sign] > 0
              negative_word << new_surface
            else
              positive_word << new_surface
            end
          else
            if rec[:sign] > 0
              positive_word << surface
            else
              negative_word << surface
            end
          end
        end
      elsif node.noun?
        surface = node.to_base
        if rec = dic[surface]
          rec = rec.select{|v| v[:type] == NOUN_ADJV}
          if rec.size == 0
            next
          end
          rec = rec[0]
          negation = 
            if i + 2 < nodes.size
              nodes[i + 2 .. i + 3].reduce(false){|r,v| r || v.to_base == "ない"}
            else
              false
            end
          if negation
            new_surface = surface + "でない"
            if rec[:sign] > 0
              negative_word << new_surface
            else
              positive_word << new_surface
            end
          else
            if rec[:sign] > 0
              positive_word << surface
            else
              negative_word << surface
            end
          end
        end
      end
    end
    if positive_word.size == 0 && negative_word.size == 0
      score = 0
    elsif positive_word.size == 0 && negative_word.size > 0
      score = -1
    elsif positive_word.size > 0 && negative_word.size == 0
      score = 1
    else
      score = positive_word.size / (positive_word.size + negative_word.size).to_f * 2.0 - 1.0
    end
    {
      :score => score,
      :positive_word => positive_word.uniq,
      :negative_word => negative_word.uniq
    }
  end
  def self.normalize(text)
    text = NKF::nkf("-WwXm0Z0", text)
    text = text.tr("　", " ")
    text = text.tr("a-z","A-Z")
  end
  def self.target_lines(text)
    hit_line = 0
    lines = text.split(/\n+/)
    lines.each_with_index do |line, i|
      if line.include?(DUMMY_NOUN)
        hit_line = i
        break
      end
    end
    target_lines = []
    [hit_line - 1, hit_line + 0, hit_line + 1].each do |i|
      if i >= 0 && i < lines.size
        target_lines << lines[i]
      end
    end
    target_lines.join("\n")
  end
  def self.fix_text(text)
    new_s = ""
    nodes = MeCab.instance.nodes(text)
    nodes.each_with_index do |node, i|
      if i + 1 < nodes.size &&
          node.noun? && (nodes[i + 1].verb?)
        new_s += node.surface + "、"
      else
        new_s += node.surface
      end
    end
    new_s
#    text
  end
  def self.analyze_word(target, text)
    dic = get_dic
    word = normalize(target)
    text = normalize(text)    
    positive_word = []
    negative_word = []
    sentence = []
    
    text = fix_text(target_lines(text.gsub(word, DUMMY_NOUN)))
    tree = CaboCha.parse(text)
    tree.chunks.each do |chunk|
      if chunk.to_s.include?(DUMMY_NOUN)
        (chunk.prev_chunks + [chunk.next_chunk, chunk]).each do |pn|
        #([chunk.next_chunk, chunk]).each do |pn|
          if pn.nil?
            next
          end
          nodes = pn.tokens
          nodes.each.with_index do |node, i|
            if node.adj_independent?
              surface = node.to_base
              if (rec = dic[surface]) && node.to_s.size > 1
                rec = rec.select{|v| v[:type] == ADJ}
                if rec.size == 0
                  next
                end
                rec = rec[0]
                negation = 
                  if i + 1 < nodes.size
                    nodes[i + 1 .. i + 2].reduce(false) {|r,v|
                    r || (v.to_base == "ない" || v.to_base == "わけ")
                  }
                  else
                    false
                  end
                if negation
                  new_surface = surface[0 ... -1] + "くない"
                  sentence << {:base => new_surface, :orig => pn.to_s.gsub(DUMMY_NOUN, target)}
                  if rec[:sign] > 0
                    negative_word << new_surface
                  else
                    positive_word << new_surface
                  end
                else
                  sentence << {:base => surface, :orig => pn.to_s.gsub(DUMMY_NOUN, target)}
                  if rec[:sign] > 0
                    positive_word << surface
                  else
                    negative_word << surface
                  end
                end
              end
              #elsif node.noun_adjv?
            elsif node.noun?
              surface = node.to_base
              if rec = dic[surface]
                rec = rec.select{|v| v[:type] == NOUN_ADJV}
                if rec.size == 0
                  next
                end
                rec = rec[0]
                negation = 
                  if i + 2 < nodes.size
                    nodes[i + 2 .. i + 3].reduce(false){|r,v| r || v.to_base == "ない"}
                  else
                    false
                  end
                if negation
                  new_surface = surface + "じゃない"
                  sentence << {:base => new_surface, :orig => pn.to_s.gsub(DUMMY_NOUN, target)}
                  if rec[:sign] > 0
                    negative_word << new_surface
                  else
                    positive_word << new_surface
                  end
                else
                  sentence << {:base => surface, :orig => pn.to_s.gsub(DUMMY_NOUN, target)}
                  if rec[:sign] > 0
                    
                    positive_word << surface
                  else
                    negative_word << surface
                  end
                end
              end
            end
          end
        end
      end
    end
    if positive_word.size == 0 && negative_word.size == 0
      score = 0
    elsif positive_word.size == 0 && negative_word.size > 0
      score = -1
    elsif positive_word.size > 0 && negative_word.size == 0
      score = 1
    else
      score = positive_word.size / (positive_word.size + negative_word.size).to_f * 2.0 - 1.0
    end
    {
      :score => score,
      :positive_word => positive_word.uniq,
      :negative_word => negative_word.uniq,
      :sentence => sentence
    }
  end
end
