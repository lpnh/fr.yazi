--- @since 25.5.31

local shell = os.getenv("SHELL"):match(".*/(.*)")
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

local get_custom_opts = ya.sync(function(self)
	local opts = self.custom_opts or {}

	return {
		fzf = fmt_opts(opts.fzf),
		rg = fmt_opts(opts.rg),
		bat = fmt_opts(opts.bat),
		rga = fmt_opts(opts.rga),
		rga_preview = fmt_opts(opts.rga_preview),
	}
end)

local fzf_from = function(job_args, opts_tbl)
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
				local lgc = logic[shell] or logic.default
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
		"--bind='start:reload:" .. cmd.grep .. " {q}'",
		"--bind='change:reload:sleep 0.1; " .. cmd.grep .. " {q} || true'",
		"--bind='ctrl-]:change-preview-window(80%|66%)'",
		"--bind='ctrl-\\:change-preview-window(right|up)'",
		"--bind='ctrl-r:clear-query+reload:" .. cmd.grep .. " {q} || true'",
		opts_tbl.fzf,
	}

	if cmd.extra then
		table.insert(fzf_tbl, cmd.extra(cmd.grep))
	end

	return table.concat(fzf_tbl, " ")
end

local function setup(self, opts)
	opts = opts or {}

	self.custom_opts = {
		fzf = opts.fzf,
		rg = opts.rg,
		bat = opts.bat,
		rga = opts.rga,
		rga_preview = opts.rga_preview,
	}
end

local function entry(_, job)
	local _permit = ya.hide()
	local custom_opts = get_custom_opts()
	local args = fzf_from(job.args[1], custom_opts)
	local cwd = tostring(get_cwd())

	local child, err = Command(shell)
		:arg({ "-c", args })
		:cwd(cwd)
		:stdin(Command.INHERIT)
		:stdout(Command.PIPED)
		:stderr(Command.INHERIT)
		:spawn()

	if not child then
		return fail("Command failed with error code %s", err)
	end

	local output, err = child:wait_with_output()
	if not output then -- unreachable?
		return fail("Cannot read command output, error code %s", err)
	elseif output.status.code == 130 then -- interrupted with <ctrl-c> or <esc>
		return
	elseif output.status.code == 1 then -- no match
		return ya.notify { title = "fr", content = "No file selected", timeout = 5 }
	elseif output.status.code ~= 0 then -- anything other than normal exit
		return fail("`fzf` exited with error code %s", output.status.code)
	end

	local target = output.stdout:gsub("\n$", "")
	if target ~= "" then
		local colon_pos = string.find(target, ":")
		local file_url = colon_pos and string.sub(target, 1, colon_pos - 1) or target

		ya.manager_emit("reveal", { file_url })
	end
end

return { entry = entry, setup = setup }
