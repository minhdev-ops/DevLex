#!/usr/bin/env bash
# Khởi động backend local để test app trên máy thật (USB).
#   ./backend/dev-up.sh
# - Bật MySQL (container devlex-mysql) nếu chưa chạy.
# - Chạy migrate + seed (idempotent).
# - Nếu DB còn quá ít thuật ngữ (< 1000) thì nạp toàn bộ kho từ
#   frontend/assets/seed/terms.json để backend phục vụ đủ dữ liệu.
# - Chạy API ở 0.0.0.0:8000.
set -euo pipefail
cd "$(dirname "$0")"

# 1) MySQL
if ! docker ps --format '{{.Names}}' | grep -qx 'devlex-mysql'; then
  if docker ps -a --format '{{.Names}}' | grep -qx 'devlex-mysql'; then
    docker start devlex-mysql >/dev/null
  else
    docker run -d --name devlex-mysql \
      -e MYSQL_ROOT_PASSWORD=12345 -e MYSQL_DATABASE=dev_lex \
      -p 3306:3306 mysql:8.0 --default-authentication-plugin=mysql_native_password >/dev/null
  fi
fi
echo '[dev-up] chờ MySQL...'
for _ in $(seq 1 30); do
  docker exec devlex-mysql mysqladmin ping -h127.0.0.1 -uroot -p12345 >/dev/null 2>&1 && break
  sleep 2
done

# 2) migrate + seed
php artisan migrate --seed --force >/dev/null

# 3) nạp toàn bộ kho nếu còn ít dữ liệu
COUNT=$(docker exec devlex-mysql mysql -uroot -p12345 dev_lex -N -e 'SELECT COUNT(*) FROM terms;' 2>/dev/null || echo 0)
SEED="$(pwd)/../frontend/assets/seed/terms.json"
if [ "${COUNT:-0}" -lt 1000 ] && [ -f "$SEED" ]; then
  echo "[dev-up] DB chỉ có $COUNT thuật ngữ — nạp từ $SEED"
  php -r '
    $pdo = new PDO("mysql:host=127.0.0.1;port=3306;dbname=dev_lex;charset=utf8mb4", "root", "12345", [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
    $d = json_decode(file_get_contents($argv[1]), true);
    $pdo->beginTransaction();
    $pdo->exec("DELETE FROM term_aliases"); $pdo->exec("DELETE FROM terms");
    $s = $pdo->prepare("INSERT INTO terms (id,tier_1_acronym,tier_1_full_name_en,tier_1_full_name_vi,tier_1_short_definition,tier_2_detailed_explanation,tier_2_metaphor_analogy,tier_2_diagram_url,tier_3_category_tags,tier_3_difficulty_level,tier_3_prerequisites,tier_3_related_terms,roadmap_career,concept,source_attribution,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,NOW(),NOW())");
    foreach ($d["terms"] as $t) {
      $s->execute([$t["id"],(string)($t["acronym"]??""),(string)($t["fullNameEn"]??""),(string)($t["fullNameVi"]??""),(string)($t["shortDefinition"]??""),$t["detailedExplanation"]??null,$t["metaphorAnalogy"]??null,$t["diagramUrl"]??null,json_encode($t["categoryTags"]??[],JSON_UNESCAPED_UNICODE),(string)($t["difficulty"]??"Beginner"),json_encode($t["prerequisites"]??[],JSON_UNESCAPED_UNICODE),json_encode($t["relatedTerms"]??[],JSON_UNESCAPED_UNICODE),$t["career"]??null,$t["concept"]??null,json_encode($t["attribution"]??[],JSON_UNESCAPED_UNICODE)]);
    }
    $a = $pdo->prepare("INSERT IGNORE INTO term_aliases (term_id,alias,naming_rule_note,created_at,updated_at) VALUES (?,?,?,NOW(),NOW())");
    foreach (($d["aliases"]??[]) as $x) { $al=trim((string)($x["alias"]??"")); $ti=(string)($x["termId"]??""); if($al!==""&&$ti!=="") $a->execute([$ti,mb_strtolower($al),$x["namingRuleNote"]??null]); }
    $pdo->commit();
    echo "[dev-up] đã nạp ".count($d["terms"])." thuật ngữ\n";
  ' "$SEED"
fi

# 4) serve
echo '[dev-up] API: http://0.0.0.0:8000  (thiết bị USB: adb reverse tcp:8000 tcp:8000)'
exec php artisan serve --host=0.0.0.0 --port=8000
