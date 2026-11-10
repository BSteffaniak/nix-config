if not require("bsteffaniak.host").plugins.jdtls or require("bsteffaniak.performance").is_large(0) then
	return
end
local root_dir = vim.fs.root(0, { "mvnw", "gradlew", "pom.xml", "build.gradle", "build.gradle.kts", ".git" })
if not root_dir or vim.fn.executable("jdtls") ~= 1 then
	return
end
local workspace = vim.fn.stdpath("cache") .. "/jdtls/" .. vim.fn.sha256(root_dir)
require("jdtls").start_or_attach({
	cmd = { "jdtls", "-data", workspace },
	root_dir = root_dir,
	settings = {
		java = {
			autobuild = { enabled = false },
			eclipse = { downloadSources = false },
			maven = { downloadSources = false },
			configuration = { updateBuildConfiguration = "interactive" },
			format = {
				enabled = true,
				settings = {
					url = vim.fn.stdpath("config") .. "/lang-servers/eclipse-java-google-style.xml",
					profile = "GoogleStyle",
				},
			},
		},
	},
})
