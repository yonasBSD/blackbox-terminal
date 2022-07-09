icondir = join_paths(get_option('datadir'), 'icons/hicolor')
pkgicondir = join_paths(get_option('datadir'), 'blackbox/icons/hicolor')

install_subdir('hicolor/scalable', install_dir: pkgicondir)

install_data(['hicolor/scalable/apps/com.raggesilver.BlackBox.svg'],
             install_dir: join_paths(icondir, 'scalable/apps'))

install_data(['hicolor/scalable/actions/com.raggesilver.BlackBox-fullscreen-symbolic.svg',
              'hicolor/scalable/actions/com.raggesilver.BlackBox-show-headerbar-symbolic.svg',
              'hicolor/scalable/actions/settings-symbolic.svg',
              'hicolor/scalable/actions/external-link-symbolic.svg',
             ], install_dir: join_paths(icondir, 'scalable/actions'))
