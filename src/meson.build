terminal_sources = files(
  'Application.vala',
  'main.vala',
)

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
  dependency('gtk4', version: '>= 4.6.2'),
  dependency('libadwaita-1'),
  dependency('marble', version: '>= 42'),
  dependency('vte-2.91-gtk4', version: '>= 0.68.0'),
  dependency('json-glib-1.0', version: '>= 1.4.4'),
  dependency('libpcre2-8'),
  dependency('libxml-2.0', version: '>= 2.9.12'),
  dependency('librsvg-2.0', version: '>= 2.54.0')
]

if meson.get_compiler('vala').version().version_compare('>=0.56.1')
  # This is needed because X11 needs special attention in some areas
  terminal_deps += dependency('gtk4-x11')
endif

# https://github.com/elementary/terminal/blob/d9620eb12331a28c658f97ac9a1bdb809aa90089/meson.build
vapi_dir = meson.current_source_dir() / 'vapi'
add_project_arguments('--vapidir=' + vapi_dir, language: 'vala')
add_project_arguments('-DPCRE2_CODE_UNIT_WIDTH=0', language: 'c')

gnome = import('gnome')

terminal_sources += gnome.compile_resources('terminal-resources',
  'terminal.gresource.xml',
  c_name: 'terminal'
)

executable('terminal', terminal_sources, config_header,
  vala_args: '--target-glib=2.50',  dependencies: terminal_deps,
  install: true,
)
