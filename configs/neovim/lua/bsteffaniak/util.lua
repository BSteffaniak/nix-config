local M = {}

function M.get_home_directory()
	local home_dir = os.getenv("HOME")

	if home_dir == nil or home_dir == "" then
		home_dir = os.getenv("userprofile")
	end

	return home_dir
end

M.home_dir = M.get_home_directory()

function M.split(inputstr, sep)
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end

function M.get_range()
	local start_sel_row = vim.api.nvim_eval('getpos("v")[1]')
	local start_sel_col = vim.api.nvim_eval('getpos("v")[2]')
	local end_sel_row = vim.api.nvim_eval('getpos(".")[1]')
	local end_sel_col = vim.api.nvim_eval('getpos(".")[2]')

	return {
		start = { start_sel_row, start_sel_col },
		["end"] = { end_sel_row, end_sel_col },
	}
end

function M.sanitize_location(location)
	return location:gsub(":", "_"):gsub("/", "_"):gsub("\\", "_")
end

function M.file_exists(name)
	local f = io.open(name, "r")

	if f ~= nil then
		io.close(f)
		return true
	else
		return false
	end
end

M.separator = package.config:sub(1, 1)
M.is_windows = M.separator == "\\"

if M.is_windows and vim.o.shellslash then
	M.use_shellslash = true
else
	M.use_shallslash = false
end

M.get_separator = function()
	if M.is_windows and not M.use_shellslash then
		return "\\"
	end
	return "/"
end

M.strip_trailing_sep = function(path)
	local res, _ = string.gsub(path, M.get_separator() .. "$", "", 1)
	return res
end

M.join_paths = function(...)
	local separator = M.get_separator()
	return table.concat({ ... }, separator)
end

M.executable_ext = ".sh"

if M.is_windows then
	M.executable_ext = ".bat"
end

local function get_home_directory()
	local home_dir = os.getenv("HOME")

	if home_dir == nil or home_dir == "" then
		home_dir = os.getenv("userprofile")
	end

	return home_dir
end

M.home_dir = get_home_directory()
M.cwd = vim.fn.getcwd()

function M.regex_escape(str)
	return str:gsub("[%(%)%.%%%+%-%*%?%[%^%$%]]", "%%%1")
end

string.replace = function(str, this, that)
	local pattern = M.regex_escape(this)
	local replacement = that:gsub("%%", "%%%%") -- only % needs to be escaped for 'that'

	return str:gsub(pattern, replacement)
end

M.table_to_toml = function(val)
	local tmp = ""

	if type(val) == "table" then
		for k, v in pairs(val) do
			tmp = tmp .. k .. " = " .. M.table_to_toml(v) .. "\n"
		end
	elseif type(val) == "number" then
		tmp = tmp .. tostring(val)
	elseif type(val) == "string" then
		tmp = tmp .. string.format("%q", val)
	elseif type(val) == "boolean" then
		tmp = tmp .. (val and "true" or "false")
	else
		tmp = tmp .. '"[inserializeable datatype:' .. type(val) .. ']"'
	end

	return tmp
end

M.parse_value = function(str)
	if str == "true" then
		return true
	elseif str == "false" then
		return false
	end

	local num = tonumber(str)

	if num ~= nil then
		return num
	end

	return str
end

M.table_from_toml = function(str)
	local val = {}

	local lines = M.split(str, "\n")

	for _, line in pairs(lines) do
		local props = M.split(line, " = ")
		local key = props[1]
		local value = M.parse_value(props[2])
		val[key] = value
	end

	return val
end

M.serialize_table = function(val, name, skipnewlines, depth)
	skipnewlines = skipnewlines or false
	depth = depth or 0

	local tmp = string.rep(" ", depth)

	if name then
		tmp = tmp .. name .. " = "
	end

	if type(val) == "table" then
		tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")

		for k, v in pairs(val) do
			tmp = tmp .. M.serialize_table(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
		end

		tmp = tmp .. string.rep(" ", depth) .. "}"
	elseif type(val) == "number" then
		tmp = tmp .. tostring(val)
	elseif type(val) == "string" then
		tmp = tmp .. string.format("%q", val)
	elseif type(val) == "boolean" then
		tmp = tmp .. (val and "true" or "false")
	else
		tmp = tmp .. '"[inserializeable datatype:' .. type(val) .. ']"'
	end

	return tmp
end

M.dump_table = function(o)
	if type(o) == "table" then
		local s = "{ "
		for k, v in pairs(o) do
			if type(k) ~= "number" then
				k = '"' .. k .. '"'
			end
			s = s .. "[" .. k .. "] = " .. M.dump_table(v) .. ","
		end
		return s .. "} "
	else
		return tostring(o)
	end
end

return M
