[🇷🇺 Читать на русском](README.ru.md)

## Remnawave Installer

This script is intended for the automated installation of the **Remnawave** panel and node.

**IMPORTANT!** Do not use the panel in production without fully understanding how everything works. This script is for demonstration purposes only and not for production use.

You can use Remnawave in two ways:

- **Option 1 (Two servers):** Install the panel and node on different servers (recommended)
- **Option 2 (All-in-one):** Install the panel and node on the same server (simplified installation)

### Option 1: Two servers

For full functionality, you will need two separate servers:

- Server for the panel — it will be the control center, but will not contain the Xray node
- Server for the node — it will contain the Xray node and the Self Steal stub for VLESS REALITY

This option requires three domains (subdomains): one for the panel, a second for subscriptions, and a third for the Self Steal stub site, which is hosted on the node server.

**Important about DNS configuration:**

- The panel and subscription domains must point to the IP address of the panel server
- The Self Steal stub domain must point to the IP address of the node server

Recommended installation order:

1. First, install the panel and obtain the public key for your node.
2. Then install the node, specifying the previously obtained key.

**Important!** After completing the **node** installation, to make the panel recognize it, you will need to restart the **panel** from the installer script menu.

### Option 2: All-in-one (simplified installation)

For a simplified installation, you can deploy both the panel and node on a single server.

For this you will need:

- One server with Ubuntu
- One domain, which will be used for:
  - The control panel
  - Subscriptions
  - Self Steal (stub for VLESS REALITY)

This option automatically configures the interaction between the panel and node, simplifying the installation and management process.
In this option, the additional service [Subscription templates](https://remna.st/subscription-templating/installation) is **not available**
This is because the service expects subscriptions at the root, while in this option subscriptions are located at /sub/

In this configuration, the Remnawave node (Xray within it) handles all incoming traffic on port 443. All requests that are not Xray proxy connections go to the dest fallback and are redirected to Caddy, which then distributes them to the appropriate services (panel, selfsteal, subscriptions depending on SNI). If you stop the local Remnawave node in this mode, the panel will become unavailable.

```
Client → port 443 → Xray → (Proxy connections)
                      ↓
                     Caddy → Panel/Subscriptions/Selfsteal (depending on SNI)
```

## System Requirements

- OS: Ubuntu 22.04
- User with root privileges (sudo)

## Installation

To launch the installer, run the following command in the terminal:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/xxphantom/remnawave-installer/refs/heads/main/dist/install_remnawave.sh)
```

<p align="center"><img src="./assets/menu.png" alt="Remnawave Installer Menu"></p>

### Installing the Remnawave Panel

1. After running the script, select **1) Install Remnawave Panel**.
2. The script will automatically install the required dependencies (Docker and others).
3. You will need to enter:
   - Telegram bot token / Administrator ID and chat ID (if you enable Telegram integration)
   - Main **domain** for the control panel
   - Separate **domain** for subscriptions
   - SuperAdmin username and password (or generate them using the script)
4. The script will register the SuperAdmin in the panel for you and perform initial setup:
   - Request the selfsteal domain for configuration
   - Generate Xray VLESS config
   - Obtain the public key for the node and create a host

### Installing the Remnawave Node

1. Select **2) Install Remnawave Node**.
2. The script will install the necessary dependencies.
3. You will need to enter:
   - Domain for the Steal site.
   - Port for connecting the node.
    - The panel's public key for the node.

### "All-in-one" Installation (panel + node)

1. Select **3) All-in-one Installation (panel + node)**.
2. The script will install the required dependencies (Docker and others).
3. You will need to enter:
   - Telegram bot token / Administrator ID and chat ID (if you enable Telegram integration)
   - Your **domain**, which will be used for the panel, subscriptions, and Self Steal
   - Port for connecting the node
   - SuperAdmin username and password (or generate them using the script)
4. The script will automatically configure and launch:
   - Remnawave control panel
   - Remnawave node with Xray
   - Caddy for handling HTTPS requests
   - Self Steal stub

## Panel Protection Based on URL Parameter

Caddy includes additional protection to prevent the panel from being discovered:

- To access the panel, you must open a page like:

  ```
  https://YOUR_PANEL_DOMAIN/auth/login?caddy=<SECRET_KEY>
  ```

- The `?caddy=<SECRET_KEY>` parameter sets a special cookie `caddy=<SECRET_KEY>` in your browser.
- If the cookie is not set or the parameter is missing from the request, the user will see either a blank page or a 404 error (depending on the requested path) when accessing the panel.

Thus, even if an attacker scans the host or tries different paths, without the exact parameter and/or cookie, the panel remains invisible.

## Service Management

After installation, you can manage services using the `make` command in the corresponding directories:

### For the "Two servers" option:

- **Panel directory**: `/opt/remnawave/panel`
- **Caddy directory**: `/opt/remnawave/caddy`
- **remnawave-subscription-page directory**: `/opt/remnawave/remnawave-subscription-page`

- **Node directory**: `/opt/remnanode/node`
- **Self Steal stub directory**: `/opt/remnanode/selfsteal`

### For the "All-in-one" option:

- **Panel directory**: `/opt/remnawave/panel`
- **Caddy directory**: `/opt/remnawave/caddy`
- **Node directory**: `/opt/remnawave/node`

Available commands:

- `make start` — Start and view logs
- `make stop` — Stop
- `make restart` — Restart
- `make logs` — View logs

## Notes

- Make sure you have configured DNS records for **all** specified domains, pointing to the IP address of the corresponding server.
- When using the "All-in-one" option, a single domain is used for all services (panel, subscriptions, Self Steal).