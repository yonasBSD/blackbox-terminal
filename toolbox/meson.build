toolbox_sources = files(
  'main.c',
)

toolbox_deps = []

toolbox_build_args = ['-Werror', '-Wextra', '-Wall']

executable('terminal-toolbox',
  toolbox_sources,
  c_args: toolbox_build_args,
  dependencies: toolbox_deps,
  install: true,
)
