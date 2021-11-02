<div align="center">
  <h1>Terminal</h1>
  <h4>A pretty and Flatpak'ed terminal for Linux</h4>
  <p>
    <a href="https://gitlab.com/raggesilver/terminal/pipelines">
      <img src="https://gitlab.com/raggesilver/terminal/badges/master/pipeline.svg" alt="Build Status" />
    </a>
    <a href="https://www.patreon.com/raggesilver">
      <img src="https://img.shields.io/badge/patreon-donate-orange.svg?logo=patreon" alt="Sponsor on Patreon" />
    </a>
  </p>
  <p>
    <a href="#install">Install</a> •
    <a href="#features">Features</a> •
    <!-- <a href="#features">Features</a> • -->
    <a href="https://gitlab.com/raggesilver/terminal/blob/master/COPYING">License</a>
  </p>
</div>

<div align="center">
  <img src="https://imgur.com/CHrYtRs.png" alt="Preview"/><br/>
  <small><i>
    Terminal 0.5.0 (theme <a href="https://github.com/storm119/Tilix-Themes/blob/master/Themes/japanesque.json" target="_blank">"Japanesque"</a>, fetch <a href="https://github.com/Rosettea/bunnyfetch">bunnyfetch</a>)
  </i></small>
  <br/><br/>
</div>

> This is work in progress. Feel free to use Terminal and report any bugs you
> find.

I created this project so that I could use a decent looking terminal app on
Linux. There are better alternatives out there.

## Features

- Theming ([Tilix](https://github.com/gnunn1/tilix) compatible color scheme support)
- Theme integration with the window decorations
- Custom fonts
- Tabs
- Headerbarless mode
- `Ctrl` + `click` to open links & files
- Drag files to paste their path

## Install

**Download**

[Flatpak](https://gitlab.com/raggesilver/terminal/-/jobs/artifacts/master/raw/terminal.flatpak?job=build) • [Zip](https://gitlab.com/raggesilver/terminal/-/jobs/artifacts/master/download?job=build)

*Note: these two links will not work if the latest pipeline failed/was skipped/is still running*

**Flathub**

<div align="center">
  <small>Will try to publish this once 1.0.0 is out.</small>
</div>

## Compile

**Flatpak**

```bash
# Clone the repo
git clone --recursive https://gitlab.com/raggesilver/terminal
# cd into the repo
cd terminal
# Assuming you have make, flatpak and flatpak-builder installed
# Makefile has a few useful rules that will build and install Terminal as a
# flatpak locally on ./app_build and ./app
make run
# You can also
# make [command]
#
#   update      - update outdated dependencies
#   hard-update - remove and update all dependencies
#   export      - export terminal as a flatpak. Generates ./terminal.flatpak
#   install     - runs `export` then `flatpak install --user terminal.flatpak`
#   clean       - cleans build files
#   fclean      - cleans build files and dependencies
#   ffclean     - cleans build files, dependencies and .flatpak-builder
```

## Some other screenshots

<div align="center">
  <img src="https://imgur.com/75C25vk.png" alt="Headerbar-less terminal"/><br/>
  <small><i>
    Terminal with "show headerbar" off.
  </i></small>
  <br/><br/>
</div>

## Credits

- Most of Terminal's themes come (straight out copied) from [Tilix](https://github.com/gnunn1/tilix)
- Most non-Tilix-default themes come (straight out copied) from [Tilix-Themes](https://github.com/storm119/Tilix-Themes)
