#!/bin/bash -e

OT_DB_HOST="${OT_DB_HOST:-127.0.0.1}"
OT_DB_PORT="${OT_DB_PORT:-3306}"
OT_DB_USER="${OT_DB_USER:-canary}"
OT_DB_PASSWORD="${OT_DB_PASSWORD:-canary}"
OT_DB_DATABASE="${OT_DB_DATABASE:-canary}"
OT_SERVER_IP="${OT_SERVER_IP:-127.0.0.1}"
OT_SERVER_LOGIN_PORT="${OT_SERVER_LOGIN_PORT:-7171}"
OT_SERVER_GAME_PORT="${OT_SERVER_GAME_PORT:-7172}"
OT_SERVER_STATUS_PORT="${OT_SERVER_STATUS_PORT:-7171}"
OT_SERVER_TEST_ACCOUNTS="${OT_SERVER_TEST_ACCOUNTS:-false}"
OT_SERVER_DATA="${OT_SERVER_DATA:-data-otservbr-global}"
# Deve ser o MESMO .otbm global que mapDownloadUrl em config.lua (não uses o custom como mapa principal).
# Gravado em data-otservbr-global/world/otservbr.otbm (nome fixo; mapName em config = otservbr).
OT_SERVER_MAP="${OT_SERVER_MAP:-https://github.com/rodviana/canary/releases/download/teste/otservbr.otbm}"
# Se 1/true, apaga world/otservbr.otbm antes do curl (útil após ter sido gravado o mapa custom/errado).
OT_SERVER_MAP_FORCE="${OT_SERVER_MAP_FORCE:-false}"

echo ""
echo "===== Print Variables ====="
echo ""

echo "OT_DB_HOST:[$OT_DB_HOST]"
echo "OT_DB_PORT:[$OT_DB_PORT]"
echo "OT_DB_USER:[$OT_DB_USER]"
echo "OT_DB_PASSWORD:[$OT_DB_PASSWORD]"
echo "OT_DB_DATABASE:[$OT_DB_DATABASE]"
echo "OT_SERVER_IP:[$OT_SERVER_IP]"
echo "OT_SERVER_LOGIN_PORT:[$OT_SERVER_LOGIN_PORT]"
echo "OT_SERVER_GAME_PORT:[$OT_SERVER_GAME_PORT]"
echo "OT_SERVER_STATUS_PORT:[$OT_SERVER_STATUS_PORT]"
echo "OT_SERVER_TEST_ACCOUNTS:[$OT_SERVER_TEST_ACCOUNTS]"
echo "OT_SERVER_DATA:[$OT_SERVER_DATA]"
echo "OT_SERVER_MAP:[$OT_SERVER_MAP]"
echo "OT_SERVER_MAP_FORCE:[$OT_SERVER_MAP_FORCE]"

echo ""
echo "================================"
echo ""

echo ""
echo "===== OTBR Global Data Pack ====="
echo ""

MAP_PATH="data-otservbr-global/world/otservbr.otbm"
if [ "$OT_SERVER_DATA" = "data-otservbr-global" ]; then
	if [ "$OT_SERVER_MAP_FORCE" = "true" ] || [ "$OT_SERVER_MAP_FORCE" = "1" ]; then
		if [ -f "$MAP_PATH" ]; then
			echo "OT_SERVER_MAP_FORCE: removing existing $MAP_PATH"
			rm -f "$MAP_PATH"
		fi
	fi
	if [ ! -f "$MAP_PATH" ]; then
		echo "Downloading OTBR global map (must match mapDownloadUrl / mapa principal, não custom)..."
		mkdir -p "$(dirname "$MAP_PATH")"
		# -L = follow redirects (GitHub releases); -f = fail on HTTP error; -o = output file
		if ! curl -Lf "$OT_SERVER_MAP" -o "$MAP_PATH"; then
			echo "ERROR: failed to download map from OT_SERVER_MAP" >&2
			exit 1
		fi
		echo "Done"
	else
		echo "OTBR map already present ($MAP_PATH) — skip curl (set OT_SERVER_MAP_FORCE=1 to re-download)"
	fi
else
	echo "Skipping OTBR map curl (OT_SERVER_DATA is not data-otservbr-global)"
fi

echo ""
echo "================================"
echo ""

echo ""
echo "===== Wait For The DB To Be Up ====="
echo ""

until mysql -u "$OT_DB_USER" -p"$OT_DB_PASSWORD" -h "$OT_DB_HOST" --port="$OT_DB_PORT" -e "SHOW DATABASES;"; do
	echo "DB offline, trying again"
	sleep 5s
done

echo ""
echo "================================"
echo ""

echo ""
echo "===== Check If DB Already Exists ====="
echo ""
if mysql -u "$OT_DB_USER" -p"$OT_DB_PASSWORD" -h "$OT_DB_HOST" --port="$OT_DB_PORT" -e "use $OT_DB_DATABASE"; then
	echo "Creating Database Backup"
	echo "Saving database to all_databases.sql"
	mysqldump -u "$OT_DB_USER" -p"$OT_DB_PASSWORD" -h "$OT_DB_HOST" --port="$OT_DB_PORT" --all-databases >/data/all_databases.sql
else
	echo "Creating Database"
	mysql -u "$OT_DB_USER" -p"$OT_DB_PASSWORD" -h "$OT_DB_HOST" --port="$OT_DB_PORT" -e "CREATE DATABASE $OT_DB_DATABASE;"
	mysql -u "$OT_DB_USER" -p"$OT_DB_PASSWORD" -h "$OT_DB_HOST" --port="$OT_DB_PORT" -e "SHOW DATABASES;"
fi
echo ""
echo "================================"
echo ""

echo ""
echo "===== Check If We Need To Import Schema.sql ====="
echo ""

if [[ $(mysql -u "$OT_DB_USER" -p"$OT_DB_PASSWORD" -h "$OT_DB_HOST" -e 'SHOW TABLES LIKE "server_config"' -D "$OT_DB_DATABASE") ]]; then
	echo "Table server_config exists so we don't need to import"
else
	echo "Import Canary-Server Schema"
	mysql -u "$OT_DB_USER" -p"$OT_DB_PASSWORD" -h "$OT_DB_HOST" --port="$OT_DB_PORT" -D "$OT_DB_DATABASE" <schema.sql

	echo ""
	echo "===== Test Accounts ====="
	echo ""

	if [ "$OT_SERVER_TEST_ACCOUNTS" = "true" ]; then
		echo "Creating Test Accounts..."
		mysql -u "$OT_DB_USER" -p"$OT_DB_PASSWORD" -h "$OT_DB_HOST" --port="$OT_DB_PORT" -D "$OT_DB_DATABASE" </canary/01-test_account.sql
		mysql -u "$OT_DB_USER" -p"$OT_DB_PASSWORD" -h "$OT_DB_HOST" --port="$OT_DB_PORT" -D "$OT_DB_DATABASE" </canary/02-test_account_players.sql
	else
		echo "Skip Test Account creation!"
	fi

	echo ""
	echo "================================"
	echo ""

fi

echo ""
echo "================================"
echo ""

echo ""
echo "===== Check If Server IP Is Set To Auto ====="
echo ""
if [ "$OT_SERVER_IP" = "auto" ]; then
	echo "IP discover enabled"
	OT_SERVER_IP=$(curl ifconfig.me/ip)
	echo "Discovered IP: $OT_SERVER_IP"
else
	echo "IP discover disabled"
fi

echo ""
echo "================================"
echo ""

echo ""
echo "===== Apply Server Configuration on config.lua ====="
echo ""

# Não usar sed -i: em bind-mounts (Docker/EC2) cria ./sed* em /canary e falha com "Device or resource busy".
# awk lê stdin e escreve só em /tmp; depois um único cp para config.lua.
CFG_OUT="/tmp/config.lua.out.$$"
awk -v dbh="$OT_DB_HOST" \
	-v dbu="$OT_DB_USER" \
	-v dbp="$OT_DB_PASSWORD" \
	-v dbport="$OT_DB_PORT" \
	-v dbname="$OT_DB_DATABASE" \
	-v sip="$OT_SERVER_IP" \
	-v lp="$OT_SERVER_LOGIN_PORT" \
	-v gp="$OT_SERVER_GAME_PORT" \
	-v sp="$OT_SERVER_STATUS_PORT" \
	-v dpack="$OT_SERVER_DATA" '
/^mysqlHost = / { print "mysqlHost = \"" dbh "\""; next }
/^mysqlUser = / { print "mysqlUser = \"" dbu "\""; next }
/^mysqlPass = / { print "mysqlPass = \"" dbp "\""; next }
/^mysqlPort = / { print "mysqlPort = " dbport; next }
/^mysqlDatabase = / { print "mysqlDatabase = \"" dbname "\""; next }
/^ip = / { print "ip = \"" sip "\""; next }
/^loginProtocolPort = / { print "loginProtocolPort = " lp; next }
/^gameProtocolPort = / { print "gameProtocolPort = " gp; next }
/^statusProtocolPort = / { print "statusProtocolPort = " sp; next }
/^dataPackDirectory = / { print "dataPackDirectory = \"" dpack "\""; next }
{ print }
' < config.lua > "$CFG_OUT"
if ! cp -f "$CFG_OUT" config.lua; then
	echo "ERROR: cannot write config.lua (montagem só-leitura?)." >&2
	rm -f "$CFG_OUT"
	exit 1
fi
rm -f "$CFG_OUT"

cat config.lua

echo ""
echo "================================"
echo ""

if [ -d "/data/server/" ]; then
	echo ""
	echo "===== Copy Server Configuration And Data Pack To Shared Folder ====="
	echo ""

	cp config.lua /data/server/
	cp -r data/ /data/server/
	cp -r "$OT_SERVER_DATA"/ /data/server/

	echo ""
	echo "================================"
	echo ""
fi

echo ""
echo "===== Start Server ====="
echo ""

ulimit -c unlimited
exec canary
