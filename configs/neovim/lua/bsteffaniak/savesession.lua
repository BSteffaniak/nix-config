local util = require("bsteffaniak.util")

local function get_session_directory()
	local sessions_home_directory = vim.g.sessions_home_directory

	if sessions_home_directory == nil then
		sessions_home_directory = util.join_paths(util.home_dir, ".nvim_sessions")
	end

	local session_directory = util.join_paths(sessions_home_directory, util.sanitize_location(util.cwd) .. "_session")

	if util.is_windows then
		os.execute("if not exist " .. session_directory .. " mkdir " .. session_directory)
	else
		os.execute("mkdir -p " .. session_directory)
	end

	return session_directory
end

local function get_session_file()
	return util.join_paths(get_session_directory(), "session.vim")
end

local function get_session_props_file()
	return util.join_paths(get_session_directory(), "props.toml")
end

local function write_props(props)
	local file = io.open(get_session_props_file(), "w")

	if file == nil then
		return
	end

	file:write(util.table_to_toml(props))
	file:close()
end

local function read_props()
	local file = io.open(get_session_props_file(), "r")

	if file == nil then
		return
	end

	local props_str = file:read("a")
	file:close()

	return util.table_from_toml(props_str)
end

local function focus_buffer(desired_buf)
	-- get all the windows from all the tabs
	local all_tab_pages = vim.api.nvim_list_tabpages()
	local buf_found = false
	for _, tab_page in ipairs(all_tab_pages) do
		local win_list = vim.api.nvim_tabpage_list_wins(tab_page)
		-- for each window, check its bufer
		for _, win in ipairs(win_list) do
			local buf = vim.api.nvim_win_get_buf(win)
			-- move to it if it's what you want
			if buf == desired_buf then
				buf_found = true
				vim.api.nvim_set_current_win(win)
				break
			end
		end
		if buf_found then
			break
		end
	end
end

function Handle_save_session()
	local focused_buf = vim.fn.bufnr("%")

	vim.cmd("mksession! " .. get_session_file())
	write_props({
		focused_buf = focused_buf,
	})

	focus_buffer(focused_buf)
end

function Handle_load_session()
	local session_file = get_session_file()

	if util.file_exists(session_file) ~= true then
		print("No session exists for " .. util.cwd)

		return
	end

	vim.cmd("source " .. session_file)

	local props = read_props()

	if props == nil then
		return
	end

	if props.focused_buf then
		focus_buffer(props.focused_buf)
	end
end

function Handle_save_and_quit()
	local unsaved = ""

	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_get_option(buf, "modified") then
			if #unsaved > 0 then
				unsaved = unsaved .. ", "
			end

			local full_buf_name = vim.api.nvim_buf_get_name(buf)
			local buf_name = string.replace(full_buf_name, util.cwd .. util.get_separator(), "")

			unsaved = unsaved .. buf_name
		end
	end

	if #unsaved > 0 then
		print("Unsaved buffers: " .. unsaved .. ". Save them before you quit!")

		return
	end

	Handle_save_session()
	vim.cmd("qa")
end

function Handle_force_save_and_quit()
	Handle_save_session()
	vim.cmd("qa!")
end
