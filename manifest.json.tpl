{
    "display_information": {
        "name": "${app_name}"
    },
    "features": {
        "app_home": {
            "home_tab_enabled": false,
            "messages_tab_enabled": true,
            "messages_tab_read_only_enabled": false
        },
        "bot_user": {
            "display_name": "${app_name}",
            "always_online": false
        },
        "slash_commands": [
            {
                "command": "${slash_command}",
                "url": "${api_gateway_url}",
                "description": "${slash_command_description}",
                "should_escape": false
            }
        ],
        "assistant_view": {
            "assistant_description": "${app_description}",
            "suggested_prompts": []
        }
    },
    "oauth_config": {
        "redirect_urls": [
            "${api_gateway_url}slack/oauth_redirect"
        ],
        "scopes": {
            "bot": [
                "assistant:write",
                "channels:join",
                "im:history",
                "channels:history",
                "groups:history",
                "chat:write",
                "commands"
            ]
        }
    },
    "settings": {
        "event_subscriptions": {
            "request_url": "${api_gateway_url}",
            "bot_events": [
                "assistant_thread_context_changed",
                "assistant_thread_started",
                "message.im"
            ]
        },
        "org_deploy_enabled": false,
        "socket_mode_enabled": false,
        "token_rotation_enabled": false
    }
}
