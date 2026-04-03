rockspec_format = "3.0"
package = "tabgroups.nvim"
version = "scm-1"
source = {
	url = "git+https://github.com/carbon-steel/tabgroups.nvim",
}
dependencies = {}
test_dependencies = {
	"nlua",
}
build = {
	type = "builtin",
	copy_directories = {
		-- Add runtimepath directories, like
		-- 'plugin', 'ftplugin', 'doc'
		-- here. DO NOT add 'lua' or 'lib'.
	},
}
