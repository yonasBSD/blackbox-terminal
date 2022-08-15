<div align="center">
  <h1><img src="./data/icons/hicolor/scalable/apps/com.raggesilver.BlackBox.svg" height="64"/>Black Box</h1>
  <h4>A beautiful GTK 4 terminal.</h4>
  <p>
    <a href="#features">Features</a> •
    <a href="#install">Install</a> •
    <a href="./CHANGELOG.md">Changelog</a> •
    <a href="./COPYING">License</a> •
    <a href="./CONTRIBUTING.md">Contributing</a>
  </p>
</div>

<div align="center">
  <img src="https://i.imgur.com/bBk8jKc.png" alt="Preview"/><br/>
  <small><i>
    Black Box 0.12.0 (theme <a href="https://github.com/storm119/Tilix-Themes/blob/master/Themes/japanesque.json" target="_blank">"Japanesque"</a>, fetch <a href="https://github.com/Rosettea/bunnyfetch">bunnyfetch</a>)
  </i></small>
  <br/><br/>
</div>

> This is work in progress. Feel free to use Black Box and report any bugs you
> find.

I created this project so that I could use a decent-looking terminal app on
Linux. There are more featureful alternatives out there.

## Features

- Theming ([Tilix](https://github.com/gnunn1/tilix) compatible color scheme support)
- Theme integration with the window decorations
- Custom fonts
- Various customizable UI settings
- Tabs
- Toggleable header bar
- Click to open links
- Files drag-n-drop support

## Install

**Flathub**

<a href='https://flathub.org/apps/details/com.raggesilver.BlackBox'><img width='240' alt='Download on Flathub' src='https://flathub.org/assets/badges/flathub-badge-en.svg'/></a>

```bash
flatpak install flathub com.raggesilver.BlackBox
```

**Download**

- [Flatpak](https://gitlab.gnome.org/raggesilver/blackbox/-/jobs/artifacts/main/raw/blackbox.flatpak?job=flatpak)
- [Zip](https://gitlab.gnome.org/raggesilver/blackbox/-/jobs/artifacts/main/download?job=flatpak)

*Note: these two links will not work if the latest pipeline failed/was skipped/is still running*

**Looking for an older release?**

Check out the [releases page](https://gitlab.gnome.org/raggesilver/blackbox/-/releases).

## Compile

**Flatpak**

To build and run Black Box, use GNOME Builder or VS Code along with [Vala](https://marketplace.visualstudio.com/items?itemName=prince781.vala) and [Flatpak](https://marketplace.visualstudio.com/items?itemName=bilelmoussaoui.flatpak-vscode) extensions.

If you want to build Black Box manually, look at the build script in [.gitlab-ci.yml](./.gitlab-ci.yml).

## Some other screenshots

<div align="center">
  <img src="https://i.imgur.com/O7Nblz8.png" alt="Black Box with 'Show Header bar' off"/><br/>
  <small><i>
    Black Box with "show header bar" off.
  </i></small>
  <br/><br/>
</div>

## Credits

- Most of Black Box's themes come (straight out copied) from [Tilix](https://github.com/gnunn1/tilix)
- Most non-Tilix-default themes come (straight out copied) from [Tilix-Themes](https://github.com/storm119/Tilix-Themes)
- Thank you, @linuxllama, for QA testing and creating Black Box's app icon
- Thank you, @predvodnik, for coming up with the name "Black Box"
- Source code that derives from other projects is properly attributed in the code itself
