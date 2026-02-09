--- @since 25.12.29

local is_windows = ya.target_family() == "windows"

local function get_shell_info()
	if is_windows then
		return "cmd", "/c", "cmd"
	else
		local shell_path = os.getenv("SHELL") or "/bin/sh"
		local shell_name = shell_path:match(".*/(.*)")
		return shell_path, "-c", shell_name
	end
end

local shell, shell_flag, shell_name = get_shell_info()

local get_cwd = ya.sync(function() return cx.active.current.cwd end)
local fail = function(s, ...) ya.notify { title = "fr", content = string.format(s, ...), timeout = 5, level = "error" } end

local fmt_opts = function(opt)
	if type(opt) == "string" then
		return " " .. opt
	elseif type(opt) == "table" then
		return " " .. table.concat(opt, " ")
	end
	return ""
end

local get_custom_opts = ya.sync(function(state)
	local opts = state.custom_opts or {}

	return {
		fzf = fmt_opts(opts.fzf),
		rg = fmt_opts(opts.rg),
		bat = fmt_opts(opts.bat),
		rga = fmt_opts(opts.rga),
		rga_preview = fmt_opts(opts.rga_preview),
	}
end)

-- Unix (bash/zsh/fish) fzf command builder (original logic)
local function fzf_from_unix(job_args, opts_tbl, major, minor)
	local cmd_tbl = {
		rg = {
			grep = "rg --color=always --line-number --smart-case" .. opts_tbl.rg,
			prev = "--preview='bat --color=always "
				.. opts_tbl.bat
				.. " --highlight-line={2} {1}' --preview-window=~3,+{2}+3/2,up,66%",
			prompt = "--prompt='rg> '",
			extra = function(cmd_grep)
				local logic = {
					default = { cond = "[[ ! $FZF_PROMPT =~ rg ]] &&", op = "||" },
					fish = { cond = 'not string match -q "*rg*" $FZF_PROMPT; and', op = "; or" },
				}
				local lgc = logic[shell_name] or logic.default
				local extra_bind = "--bind='ctrl-s:transform:%s "
					.. [[echo "rebind(change)+change-prompt(rg> )+disable-search+clear-query+reload(%s {q} || true)" %s ]]
					.. [[echo "unbind(change)+change-prompt(fzf> )+enable-search+clear-query"']]
				return string.format(extra_bind, lgc.cond, cmd_grep, lgc.op)
			end,
		},
		rga = {
			grep = "rga --color=always --files-with-matches --smart-case" .. opts_tbl.rga,
			prev = "--preview='rga --context 5 --no-messages --pretty "
				.. opts_tbl.rga_preview
				.. " {q} {}' --preview-window=up,66%",
			prompt = "--prompt='rga> '",
		},
	}

	local cmd = cmd_tbl[job_args]
	if not cmd then
		return fail("`%s` is not a valid argument. Use `rg` or `rga` instead", job_args)
	end

	local fzf_tbl = {
		"fzf",
		"--ansi",
		"--delimiter=:",
		"--disabled",
		"--layout=reverse",
		"--no-multi",
		"--nth=3..",
		cmd.prev,
		cmd.prompt,
		"--bind='change:reload:sleep 0.1; " .. cmd.grep .. " {q} || true'",
		"--bind='ctrl-]:change-preview-window(80%|66%)'",
		"--bind='ctrl-\\:change-preview-window(right|up)'",
		"--bind='ctrl-r:clear-query+reload:" .. cmd.grep .. " {q} || true'",
		opts_tbl.fzf,
	}

	-- start event requires fzf v0.35 or above
	if major > 0 or minor >= 35 then
		table.insert(fzf_tbl, "--bind='start:reload:" .. cmd.grep .. " {q}'")
	end

	-- transform action requires fzf v0.45 or above
	if (major > 0 or minor >= 45) and cmd.extra then
		table.insert(fzf_tbl, cmd.extra(cmd.grep))
	end

	return table.concat(fzf_tbl, " ")
end

local function setup(state, opts)
	opts = opts or {}

	state.custom_opts = {
		fzf = opts.fzf,
		rg = opts.rg,
		bat = opts.bat,
		rga = opts.rga,
		rga_preview = opts.rga_preview,
	}
end

local function entry(_, job)
	local _permit = ui.hide()

	local fzf_version, err = Command("fzf"):arg("--version"):output()
	if err then
		return fail("`fzf` was not found")
	end
	local major, minor = fzf_version.stdout:match("(%d+)%.(%d+)")

	local custom_opts = get_custom_opts()
	local cwd = get_cwd()

	local child, spawn_err

	if is_windows then
		-- On Windows, spawn fzf directly with individual arguments
		-- This mirrors the Unix behavior: --disabled + reload for live search
		-- Default to rga on Windows if available, fallback to rg
		local job_arg = job.args[1]
		if not job_arg then
			-- Check if rga is available
			local rga_check = Command("rga"):arg("--version"):output()
			job_arg = rga_check and "rga" or "rg"
		end

		local rg_cmd = "rg --color=always --line-number --smart-case --hidden" .. custom_opts.rg
		local rga_cmd = "rga --color=always --line-number --smart-case --hidden" .. custom_opts.rga
		local grep = (job_arg == "rga") and rga_cmd or rg_cmd

		child, spawn_err = Command("fzf")
			:arg("--ansi")
			:arg("--disabled")
			:arg("--layout=reverse")
			:arg("--delimiter=:")
			:arg("--nth=3..")
			:arg("--preview"):arg("bat --color=always --highlight-line={2} {1}")
			:arg("--preview-window=up,60%")
			:arg("--bind"):arg("start:reload:" .. grep .. " .")
			:arg("--bind"):arg("change:reload:" .. grep .. " {q}")
			:arg("--bind"):arg("ctrl-r:clear-query+reload:" .. grep .. " {q}")
			:arg("--bind"):arg("ctrl-]:change-preview-window(80%|66%)")
			:arg("--bind"):arg("ctrl-\\:change-preview-window(right|up)")
			:cwd(tostring(cwd))
			:stdin(Command.INHERIT)
			:stdout(Command.PIPED)
			:stderr(Command.INHERIT)
			:spawn()
	else
		-- On Unix, use shell to run the command
		local args = fzf_from_unix(job.args[1] or "rg", custom_opts, tonumber(major), tonumber(minor))

		child, spawn_err = Command(shell)
			:arg({ shell_flag, args })
			:cwd(tostring(cwd))
			:stdin(Command.INHERIT)
			:stdout(Command.PIPED)
			:stderr(Command.INHERIT)
			:spawn()
	end

	if not child then
		return fail("Failed to spawn fzf, error: %s", spawn_err)
	end

	local output, wait_err = child:wait_with_output()
	if not output then
		return fail("Cannot read command output, error: %s", wait_err)
	elseif output.status.code == 130 then -- interrupted with <ctrl-c> or <esc>
		return
	elseif output.status.code == 1 then -- no match
		return ya.notify { title = "fr", content = "No file selected", timeout = 5 }
	elseif output.status.code ~= 0 then -- anything other than normal exit
		return fail("`fzf` exited with error code %s", output.status.code)
	end

	local target = output.stdout:gsub("\n$", ""):gsub("\r\n$", "")
	if target ~= "" then
		-- Parse output format: file:line:col:content or file:line:content
		local file_path, line_num = target:match("^(..-):(%d+):")
		if not file_path then
			-- Fallback: just get file path
			local colon_pos = string.find(target, ":")
			file_path = colon_pos and string.sub(target, 1, colon_pos - 1) or target
		end

		local url = Url(file_path)
		if not url.is_absolute then
			url = cwd:join(url)
		end

		if line_num then
			-- Open in editor at specific line
			local editor = os.getenv("EDITOR") or "nvim"
			local cmd = editor .. " +" .. line_num .. ' "' .. tostring(url) .. '"'
			os.execute(cmd)
		else
			-- No line number, just reveal in yazi
			ya.emit("reveal", { url })
		end
	end
end

return { entry = entry, setup = setup }
