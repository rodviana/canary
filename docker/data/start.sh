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
# Raw no GitHub (mesmo .otbm que config.lua fun-server); gravado em world/otservbr.otbm
OT_SERVER_MAP="${OT_SERVER_MAP:-https://raw.githubusercontent.com/rodviana/canary/rodrigo/data-otservbr-global/world/custom/otservbr-custom.otbm}"

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

echo ""
echo "================================"
echo ""

echo ""
echo "===== OTBR Global Data Pack ====="
echo ""

if [ "$OT_SERVER_DATA" = "data-otservbr-global" ] && [ ! -f data-otservbr-global/world/otservbr.otbm ]; then
	echo "YES"

	echo "Downloading OTBR Map..."
# -L = follow redirects, needed for GitHub URLs
# -k = ignore failed TLS trust issues
# -f = fail fast with no output on HTTP errors
# -o = write output to file
	curl -Lk "$OT_SERVER_MAP" -o data-otservbr-global/world/otservbr.otbm

	echo "Done"

else
	if [ "$OT_SERVER_DATA" = "data-otservbr-global" ] && [ -f data-otservbr-global/world/otservbr.otbm ]; then
		echo "OTBR map already present (data-otservbr-global/world/otservbr.otbm) — skip curl"
	else
		echo "Skipping OTBR map curl (OT_SERVER_DATA is not data-otservbr-global or path not used)"
	fi
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

# sed -i no próprio config.lua sob bind-mount falha ("Device or resource busy"). Editar em /tmp e copiar.
CFG_TMP="/tmp/config.lua.$$"
cp -f config.lua "$CFG_TMP"
sed -i "/mysqlHost = .*$/c\mysqlHost = \"$OT_DB_HOST\"" "$CFG_TMP"
sed -i "/mysqlUser = .*$/c\mysqlUser = \"$OT_DB_USER\"" "$CFG_TMP"
sed -i "/mysqlPass = .*$/c\mysqlPass = \"$OT_DB_PASSWORD\"" "$CFG_TMP"
sed -i "/mysqlPort = .*$/c\mysqlPort = $OT_DB_PORT" "$CFG_TMP"
sed -i "/mysqlDatabase = .*$/c\mysqlDatabase = \"$OT_DB_DATABASE\"" "$CFG_TMP"
sed -i "/ip = .*$/c\ip = \"$OT_SERVER_IP\"" "$CFG_TMP"
sed -i "/loginProtocolPort = .*$/c\loginProtocolPort = $OT_SERVER_LOGIN_PORT" "$CFG_TMP"
sed -i "/gameProtocolPort = .*$/c\gameProtocolPort = $OT_SERVER_GAME_PORT" "$CFG_TMP"
sed -i "/statusProtocolPort = .*$/c\statusProtocolPort = $OT_SERVER_STATUS_PORT" "$CFG_TMP"
sed -i "/dataPackDirectory = .*$/c\dataPackDirectory = \"$OT_SERVER_DATA\"" "$CFG_TMP"
if ! cp -f "$CFG_TMP" config.lua; then
	echo "ERROR: cannot write config.lua (montagem só-leitura?)." >&2
	rm -f "$CFG_TMP"
	exit 1
fi
rm -f "$CFG_TMP"

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
