-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices
-- Spawn a fish shell in login mode
config.default_prog = { "fish" }

-- For example, changing the color scheme:
config.color_scheme = "Gruvbox Material (Gogh)"
-- config.color_scheme = 'Everforest Dark Soft (Gogh)'
-- config.color_scheme = 'Nord (base16)'

config.font = wezterm.font("RobotoMono Nerd Font Mono")

config.enable_wayland = false

config.audible_bell = "Disabled"

wezterm.on("gui-startup", function(cmd)
	local _, _, window = wezterm.mux.spawn_window(cmd or {})
	local gui_window = window:gui_window()
	gui_window:maximize()
end)

return config
