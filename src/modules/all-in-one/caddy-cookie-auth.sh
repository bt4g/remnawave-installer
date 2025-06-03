#!/bin/bash

create_docker_compose_cookie_auth() {
	local BACKEND_URL=127.0.0.1:3000
	local SUB_BACKEND_URL=127.0.0.1:3010

	cat >docker-compose.yml <<EOF
services:
  caddy:
    image: caddy:2.10.0
    container_name: caddy-remnawave
    restart: unless-stopped
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./html:/var/www/html
      - ./logs:/var/log/caddy
      - remnawave-caddy-ssl-data:/data
    environment:
      - CADDY_LOCAL_PORT=$CADDY_LOCAL_PORT
      - SELF_STEAL_DOMAIN=$SELF_STEAL_DOMAIN
      - PANEL_DOMAIN=$PANEL_DOMAIN
      - SUB_DOMAIN=$SUB_DOMAIN
      - BACKEND_URL=$BACKEND_URL
      - SUB_BACKEND_URL=$SUB_BACKEND_URL
      - PANEL_SECRET_KEY=$PANEL_SECRET_KEY
    network_mode: "host"

volumes:
  remnawave-caddy-ssl-data:
    driver: local
    external: false
    name: remnawave-caddy-ssl-data
EOF
}

create_Caddyfile_cookie_auth() {

	cat >Caddyfile <<"EOF"
{
	admin   off
	https_port {$CADDY_LOCAL_PORT}
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

http://{$SELF_STEAL_DOMAIN} {
	bind 0.0.0.0
	redir https://{$SELF_STEAL_DOMAIN}{uri} permanent
}

https://{$SELF_STEAL_DOMAIN} {
	root * /var/www/html
	try_files {path} /index.html
	file_server
}

http://{$PANEL_DOMAIN} {
	bind 0.0.0.0
	redir https://{$PANEL_DOMAIN}{uri} permanent
}

https://{$PANEL_DOMAIN} {
	@has_token_param {
		query caddy={$PANEL_SECRET_KEY}
	}

	handle @has_token_param {
		header +Set-Cookie "caddy={$PANEL_SECRET_KEY}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=2592000"
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

http://{$SUB_DOMAIN} {
	bind 0.0.0.0
	redir https://{$SUB_DOMAIN}{uri} permanent
}

https://{$SUB_DOMAIN} {
	handle {
		reverse_proxy {$SUB_BACKEND_URL} {
			header_up X-Real-IP {remote}
			header_up Host {host}
		}
	}
}

:{$CADDY_LOCAL_PORT} {
	tls internal
	respond 204
}

:80 {
	bind 0.0.0.0
	respond 204
}
EOF

}

# Setting up Caddy for the Remnawave panel
setup_caddy_all_in_one_cookie_auth() {
	cd $REMNAWAVE_DIR/caddy

	# Creating docker-compose.yml for Caddy
	create_docker_compose_cookie_auth

	# Creating the Caddyfile
	create_Caddyfile_cookie_auth

	# Creating Makefile
	create_makefile "$REMNAWAVE_DIR/caddy"

	# Creating stub site
	create_static_site "$REMNAWAVE_DIR/caddy"
}
