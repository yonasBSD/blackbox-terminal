subdir('icons')

install_subdir('schemes',
    install_dir: join_paths(get_option('datadir'), 'blackbox'))

desktop_file = i18n.merge_file(
  input: 'com.raggesilver.BlackBox.desktop.in',
  output: 'com.raggesilver.BlackBox.desktop',
  type: 'desktop',
  po_dir: '../po',
  install: true,
  install_dir: join_paths(get_option('datadir'), 'applications')
)

desktop_utils = find_program('desktop-file-validate', required: false)
if desktop_utils.found()
  test('Validate desktop file', desktop_utils,
    args: [desktop_file]
  )
endif

appstream_file = i18n.merge_file(
  input: 'com.raggesilver.BlackBox.metainfo.xml.in',
  output: 'com.raggesilver.BlackBox.metainfo.xml',
  po_dir: '../po',
  install: true,
  install_dir: join_paths(get_option('datadir'), 'metainfo')
)

appstream_util = find_program('appstream-util', required: false)
if appstream_util.found()
  validate_args = ['validate-relax', appstream_file]
  if not get_option('network_tests')
    validate_args += '--nonet'
  endif
  test('Validate appstream file', appstream_util, args: validate_args)
endif

install_data('com.raggesilver.BlackBox.gschema.xml',
  install_dir: join_paths(get_option('datadir'), 'glib-2.0/schemas')
)

compile_schemas = find_program('glib-compile-schemas', required: false)
if compile_schemas.found()
  test('Validate schema file', compile_schemas,
    args: ['--strict', '--dry-run', meson.current_source_dir()]
  )
endif
