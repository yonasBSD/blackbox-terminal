project('blackbox', ['c', 'vala'],
          version: '0.14.0',
    meson_version: '>= 0.50.0',
  default_options: [ 'warning_level=2',
                   ],
)

i18n = import('i18n')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language:'c')

subdir('data')
subdir('src')
subdir('po')

if get_option('blackbox_is_flatpak')
  subdir('toolbox')
endif

meson.add_install_script('build-aux/meson/postinstall.py')
