#!/bin/bash

MODULE="terminal"
MANIFEST="com.raggesilver.Terminal.json"
APP_ID="com.raggesilver.Terminal"

run=1

if [[ $# -ge 1 ]]; then

    case $1 in

        "update")
            echo "Run update";
            flatpak-builder --ccache --force-clean --download-only --stop-at=$MODULE app $MANIFEST || exit $?
            flatpak-builder --ccache --force-clean --disable-updates --disable-download --stop-at=$MODULE app $MANIFEST || exit $?
            exit 0;
            ;;

        "update-soft")
            echo "Run soft update";
            flatpak-builder --force-clean --ccache --stop-at=$MODULE app $MANIFEST || exit $?
            exit 0;
            ;;

        "--no-run")
            run=0
            ;;

        "export")
            echo "Run export";
            rm -rf app
            sh ${BASH_SOURCE[0]} --no-run || exit $?
            flatpak-builder --ccache --disable-download --disable-updates --finish-only --repo=repo app $MANIFEST || exit $?
            flatpak build-export repo app || exit $?
            flatpak build-bundle repo "${MODULE}.flatpak" $APP_ID || exit $?
            exit 0;
            ;;

        *)
            echo "Invalid option '$1'";
            exit 1;
            ;;
    esac
fi

if [ ! -d "app" ]; then
  flatpak-builder --stop-at=$MODULE app $MANIFEST || exit $?
fi

flatpak-builder --run app $MANIFEST meson --prefix=/app app_build || exit $?

flatpak-builder --run app $MANIFEST ninja -C app_build || exit $?
flatpak-builder --run app $MANIFEST ninja -C app_build install || exit $?

if [[ $run -eq 1 ]]; then
  flatpak-builder --env=GTK_DEBUG=interactive --run app $MANIFEST $MODULE || exit $?
fi
