terminal_sources = [
  'main.vala',
]

subdir('widgets')

terminal_deps = [
  dependency('gio-2.0', version: '>= 2.50'),
  dependency('gtk+-3.0', version: '>= 3.22'),
  dependency('vte-2.91', version: '>= 0.57.0'),
  dependency('marble', version: '>= 1.2.2'),
]

gnome = import('gnome')

terminal_sources += gnome.compile_resources('terminal-resources',
  'terminal.gresource.xml',
  c_name: 'terminal'
)

executable('terminal', terminal_sources,
  vala_args: '--target-glib=2.50',  dependencies: terminal_deps,
  install: true,
)
