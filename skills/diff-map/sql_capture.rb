# 差分の地図: 対象の処理が発行する SQL を採取し、1本ずつ発行元と実行計画を出す
#
# 使い方:
#   1. Rails アプリの tmp/diff_map_<slug>_sql.rb にコピーする
#   2. 「入力の準備」と「対象の処理」のブロックを書き換える（FE と同じ GraphQL クエリ、変更したメソッドの呼び出しなど）
#   3. rails runner tmp/diff_map_<slug>_sql.rb で実行する（Docker 経由ならプロジェクトのラッパーを使う）
#
# 開発DBは共有なので、対象の処理には読み取りだけを書く。EXPLAIN ANALYZE も SELECT にしか掛けない。
Rails.logger.level = :warn
ActiveRecord::Base.logger = nil

APP_FRAME = "#{Rails.root}/app/"

# ===== 入力の準備（ここで発行した SQL は採取しない） =====
user = User.first # 認可に使うユーザー（プロジェクトに合わせる）
target_id = Order.first.id
# =====================================================

events = []
collector = lambda do |*, payload|
  next if payload[:name] == 'SCHEMA' || payload[:cached]

  binds = payload[:type_casted_binds]
  binds = binds.call if binds.respond_to?(:call)
  app_frames = caller_locations.map(&:to_s).select { |frame| frame.include?(APP_FRAME) }.first(3)
  events << { name: payload[:name], sql: payload[:sql], binds:, rows: payload[:row_count], app: app_frames }
end

# rails runner の中でもクエリキャッシュが効き、同じ SQL の2回目以降がキャッシュから返って本数に数えられないため外す
ActiveSupport::Notifications.subscribed(collector, 'sql.active_record') do
  ActiveRecord::Base.uncached do
    # ===== 対象の処理 =====
    query = <<~GRAPHQL
      query($id: ID!) {
        getOrder(id: $id) { id }
      }
    GRAPHQL
    result = AppSchema.execute(query, variables: { id: target_id }, context: { current_user: user })
    puts JSON.pretty_generate(result.to_h)
    # =====================
  end
end

conn = ActiveRecord::Base.connection
puts "== SQL #{events.size}本"
events.each.with_index(1) do |event, i|
  sql = event[:sql].gsub(/\s+/, ' ').strip
  puts "#{i}. [#{event[:name]}] rows=#{event[:rows].inspect}"
  puts "   SQL: #{sql.length > 200 ? sql.sub(/SELECT .*? FROM/, 'SELECT … FROM') : sql}"
  puts "   binds: #{event[:binds].inspect}"
  event[:app].each { |frame| puts "   at: #{frame.sub(/.*#{Regexp.escape(APP_FRAME)}/, 'app/')}" }

  next unless sql.match?(/\ASELECT/i)

  begin
    explain_sql = sql.gsub(/\$(\d+)/) { conn.quote(event[:binds][Regexp.last_match(1).to_i - 1]) }
    plan = conn.select_rows("EXPLAIN (ANALYZE, FORMAT TEXT) #{explain_sql}").flatten
    index_line = plan.find { |line| line.include?('Index') } || plan.first
    time_line = plan.find { |line| line.include?('Execution Time') }
    puts "   plan: #{index_line.strip} / #{time_line&.strip}"
  rescue StandardError => e
    puts "   plan: 取得できず（#{e.class}）"
  end

  table = sql[/FROM "([^"]+)"/, 1]
  next unless table

  total = conn.select_value("SELECT reltuples::bigint FROM pg_class WHERE relname = #{conn.quote(table)}")
  total = conn.select_value("SELECT count(*) FROM #{conn.quote_table_name(table)}") if total.to_i.negative?
  puts "   table: #{table}（約#{total}行）"
end
