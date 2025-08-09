local M = {}

-- state for currently speaking process
local state = {
	pid = nil, -- number (job pid)
	handle = nil, -- vim.system handle (0.10+)
	backend = nil, -- "system" | "jobstart"
}

local function has(cmd)
	return vim.fn.executable(cmd) == 1
end

-- Stop currently speaking
function M.stop()
	if not state.pid and not state.handle then
		return false
	end

	-- Prefer using the saved handle if available (0.10+)
	if state.handle and state.handle.kill then
		pcall(state.handle.kill, state.handle, 15) -- SIGTERM
		state.handle = nil
		state.pid = nil
		state.backend = nil
		return true
	end

	-- Fall back to jobstop if we started with jobstart
	if state.backend == "jobstart" and state.pid then
		local ok = (vim.fn.jobstop(state.pid) == 1)
		state.pid = nil
		state.backend = nil
		return ok
	end

	-- Last resort: try killing by pid
	if state.pid then
		pcall(vim.fn.system, { "kill", "-TERM", tostring(state.pid) })
		state.pid = nil
		state.backend = nil
		return true
	end

	return false
end

-- Speak text; if something is already speaking, stop instead (toggle)
function M.toggle_say(text)
	if not text or text == "" then
		vim.notify("sayit.nvim: no text to speak", vim.log.levels.WARN)
		return
	end

	if state.pid or state.handle then
		local stopped = M.stop()
		if stopped then
			vim.notify("sayit.nvim: stopped", vim.log.levels.TRACE)
		end
	end

	if not (has("say") or has("osascript")) then
		vim.notify("sayit.nvim: need `say` or `osascript` on macOS", vim.log.levels.ERROR)
		return
	end

	M.start(text)
end

-- Always speak (don’t toggle); useful for commands
function M.start(text)
	vim.notify("sayit.nvim: saying" .. text, vim.log.levels.TRACE)
	if not text or text == "" then
		vim.notify("sayit.nvim: no text to speak", vim.log.levels.WARN)
		return
	end
	-- stop any existing first
	if state.pid or state.handle then
		M.stop()
	end

	if not (has("say") or has("osascript")) then
		vim.notify("sayit.nvim: need `say` or `osascript` on macOS", vim.log.levels.ERROR)
		return
	end

	if vim.system then
		if has("say") then
			state.handle = vim.system({ "say", text }, { detach = true })
		else
			local script = string.format([[say %q]], text)
			state.handle = vim.system({ "osascript", "-e", script }, { detach = true })
		end
		state.pid = state.handle and state.handle.pid or nil
		state.backend = "system"
	else
		if has("say") then
			state.pid = vim.fn.jobstart({ "say", text }, { detach = true })
		else
			local script = string.format([[say %s]], vim.fn.shellescape(text))
			state.pid = vim.fn.jobstart({ "osascript", "-e", script }, { detach = true })
		end
		state.backend = "jobstart"
	end
end

-- Visual selection that handles char, line, and block modes
local function get_visual_selection()
	local mode = vim.fn.mode() -- 'v', 'V', or '\022'
	local s = vim.fn.getpos("v")
	local e = vim.fn.getpos(".")

	if mode == "V" then
		local l1 = math.min(s[2], e[2])
		local l2 = math.max(s[2], e[2])
		return table.concat(vim.fn.getline(l1, l2), "\n")
	else
		return table.concat(vim.fn.getregion(s, e), "\n")
	end
end

-- Public helpers for mappings
function M.say_word()
	local word = vim.fn.expand("<cword>")
	M.toggle_say(word)
end

function M.say_visual()
	-- keep selection text before exiting visual
	local txt = get_visual_selection()
	-- optional: exit visual so user sees normal mode
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
	M.toggle_say(txt)
end

local default_config = {
	mappings = {
		normal = "<leader>v",
		visual = "<leader>v",
		stop = false, -- or a keybinding, e.g. "<leader>V"
	},
	exit_visual = true, -- exit visual mode after speaking
}

function M.setup(opts)
	local config = vim.tbl_deep_extend("force", default_config, opts or {})

	-- Normal mode mapping
	if config.mappings.normal then
		vim.keymap.set("n", config.mappings.normal, M.say_word, { desc = "speak word (toggle)", silent = true })
	end

	-- Visual mode mapping
	if config.mappings.visual then
		vim.keymap.set("v", config.mappings.visual, function()
			M.say_visual(config.exit_visual)
		end, { desc = "speak selection (toggle)", silent = true })
	end

	-- Stop mapping
	if config.mappings.stop then
		vim.keymap.set({ "n", "v" }, config.mappings.stop, M.stop, { desc = "stop speaking", silent = true })
	end

	-- Commands
	vim.api.nvim_create_user_command("SayWord", function()
		M.say_word()
	end, {})

	vim.api.nvim_create_user_command("SaySelection", function()
		M.say_visual(config.exit_visual)
	end, { range = true })

	vim.api.nvim_create_user_command("SayStart", function(opts_)
		M.start(opts_.args)
	end, { nargs = 1 })

	vim.api.nvim_create_user_command("SayStop", function()
		M.stop()
	end, {})

	vim.api.nvim_create_user_command("SayToggle", function(opts_)
		local arg = opts_.args ~= "" and opts_.args or nil
		if arg then
			M.toggle_say(arg)
		else
			M.say_word()
		end
	end, { nargs = "?" })
end

return M
