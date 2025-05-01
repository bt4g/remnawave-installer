#!/bin/bash

# Setting up Caddy for the Remnawave panel
setup_caddy_all_in_one() {
	local PANEL_SECRET_KEY=$1
	local SCRIPT_SUB_DOMAIN=$2
	local SELF_STEAL_PORT=$3

	cd $REMNAWAVE_DIR/caddy

	SCRIPT_SUB_BACKEND_URL="127.0.0.1:3000"
	local REWRITE_RULE="rewrite * /api{uri}"

	# Creating the .env file for Caddy
	cat >.env <<EOF
SCRIPT_SUB_DOMAIN=$SCRIPT_SUB_DOMAIN
PORT=$SELF_STEAL_PORT
PANEL_SECRET_KEY=$PANEL_SECRET_KEY
SUB_BACKEND_URL=$SCRIPT_SUB_BACKEND_URL
BACKEND_URL=127.0.0.1:3000
EOF

	SCRIPT_SUB_DOMAIN='$SCRIPT_SUB_DOMAIN'
	PORT='$PORT'
	BACKEND_URL='$BACKEND_URL'
	SUB_BACKEND_URL='$SUB_BACKEND_URL'
	PANEL_SECRET_KEY='$PANEL_SECRET_KEY'

	# Creating the Caddyfile
	cat >Caddyfile <<EOF
{
	https_port {$PORT}
	default_bind 127.0.0.1
	servers {
		listener_wrappers {
			proxy_protocol {
				allow 127.0.0.1/32
			}
			tls
		}
	}
	auto_https disable_redirects
}

http://{$SCRIPT_SUB_DOMAIN} {
	bind 0.0.0.0
	redir https://{$SCRIPT_SUB_DOMAIN}{uri} permanent
}

https://{$SCRIPT_SUB_DOMAIN} {
	@has_token_param {
		query caddy={$PANEL_SECRET_KEY}
	}
	handle @has_token_param {
		header +Set-Cookie "caddy={$PANEL_SECRET_KEY}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=31536000"
	}

	handle_path /sub/* {
		handle {
			rewrite * /api/sub{uri}
			reverse_proxy {$BACKEND_URL} {
				@notfound status 404

				handle_response @notfound {
					root * /var/www/html
					try_files {path} /index.html
					file_server
				}
				header_up X-Real-IP {remote}
				header_up Host {host}
			}
		}
	}

	@unauthorized {
		not header Cookie *caddy={$PANEL_SECRET_KEY}*
		not query caddy={$PANEL_SECRET_KEY}
	}

	handle @unauthorized {
		root * /var/www/html
		try_files {path} /index.html
		file_server
	}

	reverse_proxy {$BACKEND_URL} {
		header_up X-Real-IP {remote}
		header_up Host {host}
	}
}

:{$PORT} {
	tls internal
	respond 204
}

:80 {
	bind 0.0.0.0
	respond 204
}
EOF

	# Creating docker-compose.yml for Caddy
	cat >docker-compose.yml <<'EOF'
services:
  caddy:
    image: caddy:2.9.1
    container_name: caddy-remnawave
    restart: unless-stopped
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./html:/var/www/html
      - ./logs:/var/log/caddy
      - caddy_data_panel:/data
      - caddy_config_panel:/config
    env_file:
      - .env
    network_mode: "host"
volumes:
  caddy_data_panel:
  caddy_config_panel:
EOF

	# Creating Makefile
	create_makefile "$REMNAWAVE_DIR/caddy"

	# Creating directory for logs
	mkdir -p $REMNAWAVE_DIR/caddy/logs

	mkdir -p $REMNAWAVE_DIR/caddy/html/assets

	# Start downloading files in the background with output redirection
	(
		# Download index.html
		curl -s -o ./html/index.html https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/index.html

		# Download assets files
		curl -s -o ./html/assets/index-BilmB03J.css https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/index-BilmB03J.css
		curl -s -o ./html/assets/index-CRT2NuFx.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/index-CRT2NuFx.js
		curl -s -o ./html/assets/index-legacy-D44yECni.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/index-legacy-D44yECni.js
		curl -s -o ./html/assets/polyfills-legacy-B97CwC2N.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/polyfills-legacy-B97CwC2N.js
		curl -s -o ./html/assets/vendor-DHVSyNSs.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/vendor-DHVSyNSs.js
		curl -s -o ./html/assets/vendor-legacy-Cq-AagHX.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/vendor-legacy-Cq-AagHX.js
	) >/dev/null 2>&1 &

	download_pid=$!
}
