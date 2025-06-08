#!/bin/bash

JUNK_CSS_RULE_COUNT=300
JUNK_HTML_MAX_DEPTH=6
JUNK_HTML_MAX_CHILDREN=4

command -v shuf >/dev/null || {
    echo "Error: 'shuf' not found. Please install 'coreutils'." >&2
    exit 1
}

generate_realistic_identifier() {
    local style=$((RANDOM % 4))
    local words=("app" "ui" "form" "input" "btn" "wrap" "grid" "item" "box" "nav" "main" "user" "data" "auth" "login" "pass" "field" "group" "widget" "view" "icon" "control" "container" "wrapper" "avatar" "link")
    case $style in
    0)
        local prefixes=("ui" "app" "js" "mod" "el")
        local p1=${prefixes[$RANDOM % ${#prefixes[@]}]}
        local w1=${words[$RANDOM % ${#words[@]}]}
        local w2=${words[$RANDOM % ${#words[@]}]}
        echo "${p1}-${w1}-${w2}"
        ;;
    1)
        local w1=${words[$RANDOM % ${#words[@]}]}
        local w2=${words[$RANDOM % ${#words[@]}]}
        local w3=${words[$RANDOM % ${#words[@]}]}
        echo "${w1}${w2^}${w3^}"
        ;;
    2)
        local len=$((RANDOM % 12 + 8))
        cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c $len
        ;;
    *)
        local w1=${words[$RANDOM % ${#words[@]}]}
        local hash=$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 6)
        echo "${w1}-${hash}"
        ;;
    esac
}
generate_random_var_name() {
    local len=$((RANDOM % 10 + 6))
    echo "--$(cat /dev/urandom | tr -dc 'a-z' | head -c $len)"
}
url_encode_svg() { echo "$1" | sed 's/"/\x27/g' | sed 's/</%3C/g' | sed 's/>/%3E/g' | sed 's/#/%23/g' | sed 's/{/%7B/g' | sed 's/}/%7D/g'; }

generate_junk_html_nodes() {
    local current_depth=$1
    if ((current_depth >= JUNK_HTML_MAX_DEPTH)); then return; fi
    local tags=("div" "p" "span")
    local num_children=$((RANDOM % JUNK_HTML_MAX_CHILDREN + 1))
    for ((i = 0; i < num_children; i++)); do
        local tag=${tags[$RANDOM % ${#tags[@]}]}
        local class=$(generate_realistic_identifier)
        echo "<${tag} class=\"${class}\">$(generate_junk_html_nodes $((current_depth + 1)))</${tag}>"
    done
}
generate_junk_css() {
    local count=$1
    local rules=()
    local colors=("#f44336" "#e91e63" "#9c27b0" "#673ab7" "#3f51b5")
    local units=("px" "rem" "em" "%")
    for ((i = 0; i < count; i++)); do
        local junk_class=$(generate_realistic_identifier)
        local prop1="color: ${colors[$RANDOM % ${#colors[@]}]};"
        local prop2="font-size: $((RANDOM % 14 + 10))px;"
        local prop3="margin: $((RANDOM % 20))${units[$RANDOM % ${#units[@]}]};"
        local prop4="opacity: 0.$((RANDOM % 9 + 1));"
        local props_array=("$prop1" "$prop2" "$prop3" "$prop4")
        local shuffled_props=$(printf "%s\n" "${props_array[@]}" | shuf | tr '\n' ' ')
        rules+=(".${junk_class} { ${shuffled_props} }")
    done
    printf "%s\n" "${rules[@]}"
}

setup_random_theme() {
    local palettes=(
        "#5e72e4;#324cdd;#f6f9fc;#ffffff;#32325d;#8898aa;#dee2e6"
        "#2dce89;#24a46d;#f6f9fc;#ffffff;#32325d;#8898aa;#dee2e6"
        "#11cdef;#0b8ba3;#f6f9fc;#ffffff;#32325d;#8898aa;#dee2e6"
        "#fb6340;#fa3a0e;#f6f9fc;#ffffff;#32325d;#8898aa;#dee2e6"
        "#6772e5;#5469d4;#f6f9fc;#ffffff;#32325d;#8898aa;#dee2e6"
    )
    local font_stacks=(
        "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, 'Noto Sans', sans-serif"
        "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, 'Noto Sans', sans-serif"
        "'Source Sans Pro', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif"
    )

    local selected_palette=${palettes[$RANDOM % ${#palettes[@]}]}
    IFS=';' read -r VAR_PRIMARY_COLOR VAR_HOVER_COLOR VAR_BG_COLOR VAR_CARD_COLOR VAR_TEXT_COLOR VAR_TEXT_LIGHT_COLOR VAR_BORDER_COLOR <<<"$selected_palette"
    VAR_FONT_SANS_SERIF=${font_stacks[$RANDOM % ${#font_stacks[@]}]}

    CSS_VAR_PRIMARY=$(generate_random_var_name)
    CSS_VAR_HOVER=$(generate_random_var_name)
    CSS_VAR_BG=$(generate_random_var_name)
    CSS_VAR_CARD_BG=$(generate_random_var_name)
    CSS_VAR_TEXT=$(generate_random_var_name)
    CSS_VAR_TEXT_LIGHT=$(generate_random_var_name)
    CSS_VAR_BORDER=$(generate_random_var_name)
    CSS_VAR_FONT=$(generate_random_var_name)
}

generate_selfsteal_form() {
    setup_random_theme

    local html_filename="index.html"
    local css_filename="$(generate_realistic_identifier).css"
    local class_container=$(generate_realistic_identifier)
    local class_form_wrapper=$(generate_realistic_identifier)
    local class_title=$(generate_realistic_identifier)
    local class_input_email=$(generate_realistic_identifier)
    local class_input_pass=$(generate_realistic_identifier)
    local class_button=$(generate_realistic_identifier)
    local class_junk_wrapper=$(generate_realistic_identifier)
    local name_user=$(generate_realistic_identifier)
    local name_pass=$(generate_realistic_identifier)
    local action_url="/gateway/$(generate_realistic_identifier)/auth"
    local class_extra_links=$(generate_realistic_identifier)
    local class_forgot_link=$(generate_realistic_identifier)

    local svg_email_icon_raw='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="'${VAR_TEXT_LIGHT_COLOR}'"><path d="M20 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4l-8 5-8-5V6l8 5 8-5v2z"/></svg>'
    local svg_lock_icon_raw='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="'${VAR_TEXT_LIGHT_COLOR}'"><path d="M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z"/></svg>'
    local encoded_email_icon=$(url_encode_svg "$svg_email_icon_raw")
    local encoded_lock_icon=$(url_encode_svg "$svg_lock_icon_raw")

    local main_content_html="<div class=\"${class_container}\"><div class=\"${class_form_wrapper}\"><h2 class=\"${class_title}\">Login</h2><form action=\"${action_url}\" method=\"post\"><input type=\"email\" name=\"${name_user}\" class=\"${class_input_email}\" placeholder=\"Email\" required><input type=\"password\" name=\"${name_pass}\" class=\"${class_input_pass}\" placeholder=\"Password\" required><div class=\"${class_extra_links}\"><a href=\"#\" class=\"${class_forgot_link}\">Forgot Password?</a></div><button type=\"submit\" class=\"${class_button}\">Login</button></form></div></div>"
    local junk_html_block="<div class=\"${class_junk_wrapper}\">$(generate_junk_html_nodes 0)</div>"

    local core_css="
:root { ${CSS_VAR_PRIMARY}: ${VAR_PRIMARY_COLOR}; ${CSS_VAR_HOVER}: ${VAR_HOVER_COLOR}; ${CSS_VAR_BG}: ${VAR_BG_COLOR}; ${CSS_VAR_CARD_BG}: ${VAR_CARD_COLOR}; ${CSS_VAR_TEXT}: ${VAR_TEXT_COLOR}; ${CSS_VAR_TEXT_LIGHT}: ${VAR_TEXT_LIGHT_COLOR}; ${CSS_VAR_BORDER}: ${VAR_BORDER_COLOR}; ${CSS_VAR_FONT}: ${VAR_FONT_SANS_SERIF}; }
html { font-family: var(${CSS_VAR_FONT}); font-size: 16px; }
body { margin: 0; background-color: var(${CSS_VAR_BG}); display: flex; align-items: center; justify-content: center; min-height: 100vh; }
"
    local component_pool=()
    component_pool+=(".${class_container} { width: 100%; max-width: 450px; padding: 1rem; }")
    component_pool+=(".${class_form_wrapper} { background-color: var(${CSS_VAR_CARD_BG}); padding: 3rem; border-radius: 12px; box-shadow: 0 7px 30px rgba(50, 50, 93, 0.1), 0 3px 8px rgba(0, 0, 0, 0.07); text-align: center; }")
    component_pool+=(".${class_title} { font-size: 1.5rem; font-weight: 600; color: var(${CSS_VAR_TEXT_LIGHT}); margin: 0 0 2.5rem 0; text-transform: uppercase; letter-spacing: 1px; }")
    component_pool+=(".${class_input_email}, .${class_input_pass} { width: 100%; box-sizing: border-box; font-size: 1rem; padding: 0.9rem 1rem 0.9rem 3.2rem; margin-bottom: 1.25rem; border: 1px solid var(${CSS_VAR_BORDER}); border-radius: 8px; background-repeat: no-repeat; background-position: left 1.2rem center; background-size: 20px; transition: all 0.15s ease; }")
    component_pool+=(".${class_input_email}:focus, .${class_input_pass}:focus { outline: none; border-color: var(${CSS_VAR_PRIMARY}); box-shadow: 0 0 0 3px color-mix(in srgb, var(${CSS_VAR_PRIMARY}) 20%, transparent); }")
    component_pool+=(".${class_input_email} { background-image: url('data:image/svg+xml,${encoded_email_icon}'); }")
    component_pool+=(".${class_input_pass} { background-image: url('data:image/svg+xml,${encoded_lock_icon}'); }")
    component_pool+=(".${class_extra_links} { text-align: right; margin-bottom: 1.5rem; }")
    component_pool+=(".${class_forgot_link} { color: var(${CSS_VAR_PRIMARY}); text-decoration: none; font-size: 0.9rem; }")
    component_pool+=(".${class_forgot_link}:hover { text-decoration: underline; }")
    component_pool+=(".${class_button} { width: 100%; box-sizing: border-box; padding: 1rem; font-size: 1rem; font-weight: 600; color: #fff; background-image: linear-gradient(35deg, var(${CSS_VAR_PRIMARY}), var(${CSS_VAR_HOVER})); border: none; border-radius: 8px; cursor: pointer; transition: transform 0.2s, box-shadow 0.2s; box-shadow: 0 4px 15px color-mix(in srgb, var(${CSS_VAR_PRIMARY}) 40%, transparent); }")
    component_pool+=(".${class_button}:hover { transform: translateY(-2px); box-shadow: 0 7px 25px color-mix(in srgb, var(${CSS_VAR_PRIMARY}) 50%, transparent); }")
    component_pool+=(".${class_junk_wrapper} { display: none !important; }")

    local junk_css_rules=$(generate_junk_css $JUNK_CSS_RULE_COUNT)

    echo "${core_css}" >"${css_filename}"
    printf "%s\n%s" "$(printf "%s\n" "${component_pool[@]}")" "$junk_css_rules" | shuf >>"${css_filename}"

    cat <<EOF >"$html_filename"
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Login</title><link rel="stylesheet" href="${css_filename}"></head><body>$(if ((RANDOM % 2 == 0)); then echo "$main_content_html $junk_html_block"; else echo "$junk_html_block $main_content_html"; fi)</body></html>
EOF
}
