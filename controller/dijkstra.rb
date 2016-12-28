# encoding: utf-8
 
=begin
アルゴリズム参考URL
http://www.deqnotes.net/acmicpc/dijkstra/
 
アルゴリズム
  1. 初期化
     スタートノードの値（最小コスト候補）を０、他のノードの値を未定義に設定
  2. 確定ノードをピックアップすることができなくなるまで以下のループを繰り返す
    2-1. まだ確定されていないノードのうち、最小の値を持つノードを見つけ、確定ノードとする（確定フラグをたてる）
    2-2. 確定ノードからの伸びているエッジをそれぞれチェックし、「確定ノードまでのコスト＋エッジのコスト」を計算し、
    そのノードの現在値よりも小さければ更新する。（経路情報も必要であれば、どこから来たのかを示す変数が確定ノードをさすようにする
 
特徴
・負のコスト（距離or時間）を持つエッジは扱えない
・特定のノードからの最短距離およびその経路が全てのノードに対して求まる
=end
 
 
# ダイクストラ法をアルゴリズムとしたグラフクラス
class Graph
  # グラフを構成するノード
  class Node
    attr_accessor :nid, :edges, :cost, :from_nid, :fixed
    
    # nid (Symbol)   e.g. :a
    # edges (Array)  e.g. [[cost, nid], [cost, nid], ...]
    # cost コスト値　(nil の場合コストが未設定)
    # from_nid nid格納 (nil の場合存在しない)
    # fixed 確定ノードか否かの判定フラグ
    def initialize(nid, edges=[], cost=nil, from_nid=nil, fixed=false)
      @nid, @edges, @cost, @from_nid, @fixed = nid, edges, cost, from_nid, fixed
    end
 
    # ノードの情報を表示
    def show
      p "#{nid}(#{cost}/#{from_nid}/#{fixed}) -> #{edges}"
    end
  end
 
  def initialize
    puts "abc"
    @nodes = {}
  end
 
  # ノードを追加する
  def add_node(nid, edges)
    n = Node.new(nid, edges)
    @nodes[nid] = n
  end
 
  # 開始位置を設定
  def set_start(sid)
    # 開始位置を保存
    @sid = sid
 
    # ノードのダイクストラ法のためのデータを初期化
    # 開始ノードと同じノードだけコストを0にする 
    @nodes.each do |nid, node|
      node.cost = (@sid == nid) ? 0 : nil
      node.from_nid = nil
      node.fixed = false
    end
 
    #　ダイクストラ法を実施
    dijkstra
  end
 
  # 終了地点までの経路を取得
  # 開始地点までの経路を辿れない場合nilを返す
  def route(gid)
    # 経路情報格納変数
    path = []
 
    # 終点ノードを格納
    node = @nodes[gid]
    path.push(node)
 
    # 開始地点に辿りつくか、経路を辿れなかくなるまでループ
    loop do
      # 前のノードを取得し経路情報を格納
      node = @nodes[node.from_nid]
      path.push(node)
 
      # 開始地点に辿り着いたらループを終了
      break if node.nid == @sid
 
      # 開始地点までの経路を辿れない場合nilを返す
      return nil if node.from_nid.nil?
    end
  
    # 終点から辿って格納したので順番を入れ替える
    # そして、nibだけを取り出した配列を返すf
    return path.reverse!.map { |node| node.nid }
  end
 
  # 終了地点までのコストを取得
  def cost(gid)
    return @nodes[gid].cost
  end
 
  # 現在のグラフ情報を表示
  def show
    @nodes.map { |k, node| node.show } 
  end
 
private
  # ダイクストラ法のアルゴリズムを実施する
  def dijkstra
    loop do
      # 確定ノード(fixed_node)を探す
      fixed_node = nil
      @nodes.each do |nib, node|
        next if node.fixed || node.cost.nil?
        fixed_node = node if fixed_node.nil? || node.cost < fixed_node.cost
      end
 
      # 全てのノードが確定ノードに成った場合ループを終了
      break if fixed_node.nil?
 
      # 確定フラグを立てる
      fixed_node.fixed = true
      # 確定ノードに隣接するノードのコストと経路情報を更新する
      fixed_node.edges.each do |edge_cost, edge_nid|
        # 隣接するノードまでのコストを計算
        cost = fixed_node.cost + edge_cost
        # 隣接するノードのコストが存在しない場合、もしくは、既に存在している値より計算した値が小さい(より短い経路)の場合
        if @nodes[edge_nid].cost.nil? || cost < @nodes[edge_nid].cost then
          # コストと経路情報を更新する
          @nodes[edge_nid].cost = cost
          @nodes[edge_nid].from_nid = fixed_node.nid
        end
      end
    end
  end
 
end
 
 
#########################################
## 処理を実施
#########################################
if __FILE__ == $0
 
  # データを用意
  # 全てのノードからのエッジをデータを作成
  data = {     
    "yokohama" => [[5, "shinagawa"], [4, "shibuya"]],
    "shinagawa" => [[5, "yokohama"], [2, "shibuya"], [3, "tokyo"]],
    "shibuya" => [[6, "yokohama"], [2, "shinagawa"], [1, "shinjuku_sancho_me"], [1, "shinjuku"]],
    "tokyo" => [[3, "shinagawa"], [3, "shinjuku"]],
    "shinjuku_sancho_me" => [[1, "shibuya"], [1, "shinjuku"]],
    "shinjuku" => [[1, "shibuya"], [1, "shinjuku_sancho_me"], [3, "tokyo"]]
  }

 
  # 開始ノードと終了ノードを設定
  sid = :yokohama
  gid = :shinjuku
 
  # グラフを作成
  g = Graph.new
 
  # グラフにノードを追加
  data.each do |nid, edges|
    g.add_node(nid, edges)
  end
 
  # グラフに開始位置を設定
  g.set_start(sid)
 
  # 終了地点までの経路を取得
  p "#{sid} から #{gid} の 最短経路 は #{g.route(gid)} です。"
  # 終了地点までのコストを取得
  p "#{sid} から #{gid} の 時間 は #{g.cost(gid)} です。"
 
  # グラフの情報を表示
  # g.show
end
