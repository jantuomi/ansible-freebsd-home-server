# Trap route
location ^~ /wp-admin/ {
    proxy_set_header X-IP $remote_addr;
    proxy_method POST;
    proxy_pass http://unix:/var/run/pfban/ban.sock:/ban;

    proxy_connect_timeout 50ms;
    proxy_send_timeout    50ms;
    proxy_read_timeout    50ms;

    # If the socket isn't up yet, still return something
    error_page 500 502 503 504 = @ban_fallback;
}

location @ban_fallback {
    return 204;
}
