-- Run from the repo root: nvim --headless -l configs/neovim/tests/run.lua
local source = vim.fn.getcwd() .. "/configs/neovim"
local plugins = vim.fn.stdpath("data") .. "/lazy"
assert(vim.fn.isdirectory(plugins .. "/lazy.nvim") == 1, "Restore plugins first")
local temp = vim.uv.fs_realpath(vim.env.TMPDIR or "/tmp") .. "/nvim-cleanup-tests-" .. vim.fn.getpid()
vim.fn.mkdir(temp, "p")
local function command(args)
	local result = vim.system(args, { text = true }):wait()
	assert(result.code == 0, result.stderr)
end
local function write(path, text)
	vim.fn.writefile(vim.split(text, "\n", { plain = true }), path)
end
for _, mode in ipairs({ "light", "off" }) do
	local base = temp .. "/" .. mode
	for _, dir in ipairs({ "/config", "/data/nvim", "/state", "/cache", "/bin", "/project/src" }) do
		vim.fn.mkdir(base .. dir, "p")
	end
	command({ "cp", "-R", source, base .. "/config/nvim" })
	assert(vim.uv.fs_symlink(plugins, base .. "/data/nvim/lazy"))
	write(
		base .. "/config/nvim/lua/host-config.lua",
		[[return { tool_provider = "nix", plugins = {
 supermaven=false, copilot=false, avante=false, jdtls=false, elixir=false, ionide=false, dadbod=false,
} }]]
	)
	for _, tool in ipairs({
		"cargo",
		"rust-analyzer",
		"lua-language-server",
		"bash-language-server",
		"nil",
		"gopls",
		"go",
		"typescript-language-server",
		"pyright-langserver",
		"ty",
		"biome",
	}) do
		local lines = vim.fn.readfile(source .. "/tests/fake-tool.py")
		lines[1] = "#!" .. vim.fn.exepath("python3")
		vim.fn.writefile(lines, base .. "/bin/" .. tool)
		assert(vim.uv.fs_chmod(base .. "/bin/" .. tool, 493))
	end
	-- An environment outside each fixture's Git boundary must never be selected.
	vim.fn.mkdir(base .. "/project/.venv/bin", "p")
	assert(vim.uv.fs_symlink(vim.fn.exepath("python3"), base .. "/project/.venv/bin/python"))
	for _, project in ipairs({ "python-a", "python-b", "python-missing", "python-broken" }) do
		local path = base .. "/project/" .. project
		vim.fn.mkdir(path .. "/pkg/nested", "p")
		vim.fn.mkdir(path .. "/.git", "p")
		write(path .. "/pkg/pyproject.toml", '[project]\nname="nested"\nversion="0.1.0"')
		write(path .. "/pkg/nested/test.py", "import pydantic")
		if project ~= "python-missing" then
			vim.fn.mkdir(path .. "/.venv/bin", "p")
			local target = project == "python-broken" and path .. "/nonexistent" or vim.fn.exepath("python3")
			assert(vim.uv.fs_symlink(target, path .. "/.venv/bin/python"))
			if project == "python-a" then
				-- The project's own ty must win over the one on PATH.
				command({ "cp", base .. "/bin/ty", path .. "/.venv/bin/ty" })
			end
		end
	end
	write(base .. "/project/python-a/pkg/nested/large.py", string.rep("# large file\n", 21000))
	write(base .. "/project/Cargo.toml", '[package]\nname="fixture"\nversion="0.1.0"\nedition="2024"')
	write(base .. "/project/src/main.rs", "fn main() {}")
	write(base .. "/project/src/other.rs", "fn other() {}")
	write(base .. "/project/large.rs", string.rep("// large file\n", 21000))
	write(base .. "/project/file.java", "class File {}")
	write(base .. "/project/test.lua", "local answer = 42")
	write(base .. "/project/test.sh", "echo hello")
	write(base .. "/project/test.nix", "{}")
	write(base .. "/project/test.go", "package fixture")
	write(base .. "/project/package.json", "{}")
	write(base .. "/project/test.tsx", "export const C = () => <div />;")
	write(base .. "/project/test.astro", "<div />")
	write(base .. "/project/test.md", "# Example")
	local result = vim.system({
		vim.v.progpath,
		"--headless",
		"--startuptime",
		base .. "/startup.log",
		"+lua dofile(" .. string.format("%q", source .. "/tests/scenarios.lua") .. ")",
	}, {
		text = true,
		env = {
			XDG_CONFIG_HOME = base .. "/config",
			XDG_DATA_HOME = base .. "/data",
			XDG_STATE_HOME = base .. "/state",
			XDG_CACHE_HOME = base .. "/cache",
			PATH = base .. "/bin:/usr/bin:/bin",
			NVIM_RUST_MODE = mode,
			NVIM_PYTHON_LSP = mode == "off" and "pyright" or "ty",
			NVIM_TEST_EVENTS = base .. "/events.jsonl",
			NVIM_TEST_PROJECT = base .. "/project",
			NVIM_SESSIONS_HOME_DIRECTORY = base .. "/state/sessions",
		},
	}):wait(30000)
	print(mode .. ": " .. (result.stdout or "") .. (result.stderr or ""))
	assert(result.code == 0, "Scenario failed; artifacts: " .. base)
end
print("All tests passed. Artifacts: " .. temp)
