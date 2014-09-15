# -*- coding: utf-8 -*-
module IpadicExt
  GIMON_REGXP = /^(何|なに|なん|どこ|何処|どれ|どっち|どちら|だれ|誰|どんな|どの|どなた|何方)/

  def yomi
    yomi = feature_list(7)
  end
  
  # 名詞？
  def noun?
    feature_list(0) == '名詞'
  end
  def common_noun?
    feature_list(0) == '名詞' && feature_list(1) == '一般'
  end
  def org_noun?
    feature_list(0) == '名詞' && feature_list(1) == '固有名詞'
  end

  def adverb?
    feature_list(0) == '副詞'
  end
  
  # 名詞接続? (「お星様」の「お」など)
  def meishi_setsuzoku?
    feature_list(0) == '接頭詞' &&
      feature_list(1) == '名詞接続'
  end
  def adj_setsuzoku?
    adj? && feature_list(6).include?("接続")
  end
  def adj_independent?
    adj? && feature_list(1) == "自立"
  end
  # 動詞？
  def verb?
    feature_list(0) == '動詞'
  end
  # 助動詞？
  def auxiliary_verb?
    feature_list(0) == '助動詞'
  end
  def shu_joshi?
    @shu_joshi ||= (feature_list(0) == '助詞' && feature_list(1) =~ /終助詞/u)
  end
  def hatena?
    to_base == '？'
  end
  # 形容詞？
  def adj?
    feature_list(0) == '形容詞'
  end

  # 形容動詞語幹?
  def noun_adjv?
    feature_list(0) == '名詞' && feature_list(1) == "形容動詞語幹"
  end
  
  # 名詞サ変接続？
  def sahen_setsuzoku?
    feature_list(0) == '名詞' &&
      feature_list(1) == 'サ変接続'
  end
  # サ変する？
  def sahen_suru?
    feature_list(4) == 'サ変・スル'
  end
  # サ変する？
  def sahen_dekiru?
    feature_list(6) == 'できる'
  end

  def kigou?
    feature_list(0) == '記号'
  end
  def gimon_daimeishi?
    !GIMON_REGXP.match(to_s).nil?
  end
  def gimon_fukushi?
    feature_list(0) == '副詞' &&
      feature_list(1) == '助詞類接続' &&
      feature_list(6) == 'どう'
  end

  def tai?
    feature_list(0) == '助動詞' &&
      feature_list(6) == 'たい'
  end
  
  # 基本形へ
  def to_base
    if (feature_list_size > 6 && feature_list(6) != "*")
      feature_list(6)
    else
      to_s
    end
  end

  # 動詞の活用
  
  ## 一段命令形の形 (0:食べよ 1:食べれ 2:食べろ)
  V_ICHIDAN_MEIREI = ['よ', 'れ', 'ろ']
  V_ICHIDAN_MEIREI_TYPE = 2
  
  def v_godan?
    @v_godan ||= (feature_list(4) =~ /^五段/)
  end
  def v_rahen?
    @v_rahen ||= (feature_list(4) =~ /^ラ変/)
  end
  def v_ichidan?
    @v_ichidan ||= (feature_list(4) =~ /^一段/)
  end
  def v_yodan?
    @v_yodan ||= (feature_list(4) =~ /^四段/)
  end
  def v_kahen?
    @v_kahen ||= (feature_list(4) =~ /^カ変/)
  end
  def v_sahen?
    @v_sahen ||= (feature_list(4) =~ /^サ変/)
  end
  def v_kami_nidan?
    @v_kami_nidan ||= (feature_list(4) =~ /^上二/)
  end

  ## 活用
  def v_inflect(type)
    if (v_godan?)
      base = to_base
      v_type = feature_list(4)

      case (v_type)
      when /カ行/
        base.gsub(/[ぁ-ん]$/, '') + %w(か き く く け け)[type]
      when /ガ行/
        base.gsub(/[ぁ-ん]$/, '') + %w(が ぎ ぐ ぐ げ げ)[type]
      when /サ行/
        base.gsub(/[ぁ-ん]$/, '') + %w(さ し す す せ せ)[type]
      when /タ行/
        base.gsub(/[ぁ-ん]$/, '') + %w(た ち つ つ て て)[type]
      when /ナ行/
        base.gsub(/[ぁ-ん]$/, '') + %w(な に ぬ ぬ ね ね)[type]
      when /バ行/
        base.gsub(/[ぁ-ん]$/, '') + %w(ば び ぶ ぶ べ べ)[type]
      when /マ行/
        base.gsub(/[ぁ-ん]$/, '') + %w(ま み む む め め)[type]
      when /ラ行/
        base.gsub(/[ぁ-ん]$/, '') + %w(ら り る る れ れ)[type]
      when /ワ行/
        base.gsub(/[ぁ-ん]$/, '') + %w(わ い う う え え)[type]
      else
        raise "unknown feature_list(4) #{feature_list(4)}"
      end
    elsif (v_sahen?)
      v_type = feature_list(4)
      case v_type
      when /スル/
        %w(し し する する すれ しろ)[type]
      when /ズル/
        to_base.gsub(/[ぁ-ん]$/, '') + %w(ぜ ず ずる ずる ずれ ぜよ)[type]
      else
        raise "unknown feature_list(4) #{feature_list(4)}"
      end
    elsif (v_ichidan?)
      to_base.gsub(/[ぁ-ん]$/, '') +
        ['', '', 'る', 'る', 'れ', V_ICHIDAN_MEIREI[V_ICHIDAN_MEIREI_TYPE]][type]
    elsif (v_rahen?)
      to_base.gsub(/[ぁ-ん]$/,'') + %w(ら り り る れ れ)[type]
    elsif (v_yodan?)
      v_type = feature_list(4)
      case v_type
      when /カ行/
        to_base.gsub(/[ぁ-ん]$/,'') + %w(か き く く け け)[type]
      when /ガ行/
       to_base.gsub(/[ぁ-ん]$/,'') + %w(が ぎ ぐ ぐ げ げ)[type]
      when /サ行/
        to_base.gsub(/[ぁ-ん]$/,'') + %w(さ し す す せ せ)[type]
      when /タ行/
        to_base.gsub(/[ぁ-ん]$/,'') + %w(た ち つ つ て て)[type]
      when /ハ行/
        to_base.gsub(/[ぁ-ん]$/,'') + %w(は ひ ふ ふ へ へ)[type]
      when /バ行/
        to_base.gsub(/[ぁ-ん]$/,'') + %w(ば び ぶ ぶ べ べ)[type]
      when /マ行/
        to_base.gsub(/[ぁ-ん]$/,'') + %w(ま み む む め め)[type]
      when /ラ行/
        to_base.gsub(/[ぁ-ん]$/,'') + %w(ら り る る れ れ)[type]
      else
        raise "unknown feature_list(4) #{feature_list(4)}"
      end
    elsif (v_kahen?)
      v_type = feature_list(4)
      if (v_type == 'カ変・クル' || v_type == 'カ変・来ル')
        %w(来 来 来る 来る 来れ 来い)[type]
      end
    elsif (v_kami_nidan?)
      v_type = feature_list(4)
      case v_type
      when /カ行/
        to_base.gsub(/[ぁ-ん]$/,'') + %w(き き く くる くれ きよ)[type]
      when /ガ行/
        to_base.gsub(/[ぁ-ん]$/,'') + %w(ぎ ぎ ぐ ぐる ぐれ ぎよ)[type]
      when /タ行/
        to_base.gsub(/[ぁ-ん]$/,'') + %w(ち ち つ つる つれ ちよ)[type]
      when /ダ行/
        to_base.gsub(/[ぁ-ん]$/,'') + %w(ぢ ぢ づ づる づれ ぢよ)[type]
      when /ハ行/
        to_base.gsub(/[ぁ-ん]$/,'') + %w(ひ ひ ふ ふる ふれ ひよ)[type]
      when /バ行/
        to_base.gsub(/[ぁ-ん]$/,'') + %w(び び ぶ ぶる ぶれ びよ)[type]
      when /マ行/
        to_base.gsub(/[ぁ-ん]$/,'') + %w(み み む むる むれ みよ)[type]
      when /ヤ行/
        to_base.gsub(/[ぁ-ん]$/,'') + %w(い い ゆ ゆる ゆれ いよ)[type]
      when /ラ行/
        to_base.gsub(/[ぁ-ん]$/,'') + %w(り り る るる るれ りよ)[type]
      else
        raise "unknown feature_list(4) #{feature_list(4)}"
      end
    else
      raise "unknown feature_list(4) #{feature_list(4)}"
    end
  end

  def to_mizen
    @to_mizen ||= v_inflect(0)
  end
  def to_renyo
    @to_renyo ||= v_inflect(1)
  end
  def to_syushi
    @to_syushi ||= v_inflect(2)
  end
  def to_rentai
    @to_rentai ||= v_inflect(3)
  end
  def to_katei
    @to_katei ||= v_inflect(4)
  end
  def to_meirei
    @to_meirei ||= v_inflect(5)
  end

  def to_negative
    @to_negative ||=
      if (noun?)
        to_base + 'じゃない'
      elsif (adj?)
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
  def to_noun
    @to_noun ||=
      if (noun?)
        to_base
      elsif (verb?)
        # 飛ぶの, 泳ぐの
        to_base + 'の'
      elsif (adj?)
        # かわいいの, 大きいの
        to_base + 'の'
      else
        to_base
      end
  end
  
  def surface
    to_s
  end
  
  def to_s
    @to_s ||=
      if ("".respond_to?("force_encoding"))
        surface_org.force_encoding("utf-8")
      else
        surface_org # 本当はsurface
      end
  end
  
  def features
    @feature_list ||= (0 ... feature_list_size).map{|j| feature_list(j).force_encoding("utf-8") }
  end
end
