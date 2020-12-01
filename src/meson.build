terminal_sources = [
  'main.vala',
]

subdir('widgets')
subdir('services')
subdir('utils')

conf_data = configuration_data()
conf_data.set_quoted('PROJECT_NAME', meson.project_name())
conf_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf_data.set_quoted('VERSION', meson.project_version())
conf_data.set_quoted('PREFIX', get_option('prefix'))
conf_data.set_quoted('DATADIR', join_paths (get_option('prefix'), get_option('datadir')))

config_header = configure_file(
            input: 'config.vala.in',
           output: 'config.vala',
    configuration: conf_data
    )

terminal_deps = [
  dependency('gio-2.0', version: '>= 2.50'),
  dependency('gtk+-3.0', version: '>= 3.22'),
  dependency('vte-2.91', version: '>= 0.57.0'),
  dependency('marble', version: '>= 1.2.2'),
  dependency('json-glib-1.0', version: '>= 1.4.4'),
]

gnome = import('gnome')

terminal_sources += gnome.compile_resources('terminal-resources',
  'terminal.gresource.xml',
  c_name: 'terminal'
)

executable('terminal', terminal_sources, config_header,
  vala_args: '--target-glib=2.50',  dependencies: terminal_deps,
  install: true,
)
