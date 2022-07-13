# Changelog

## 0.11.1 - 2022.07.13

Features:

- Black Box will set the BLACKBOX_THEMES_DIR env variable to the user's theme
  folder - #82

Bug fixes:

- Fix opaque floating header bar
- User themes dir is no longer hard-coded and will be different for host vs
  Flatpak - #90 thanks @nahuelwexd

## 0.11.0 - 2022.07.13

Features:

- The preferences window has a new layout that allows for more
  features/customization to be added
- Added support for the system-wide dark style preference - #17
- Users can now set a terminal color scheme for dark style and another for light
  style
- Black Box now uses the new libadwaita about window
- New themes included with Black Box: one-dark, pencil-dark, pencil-light,
  tomorrow, and tommorrow-night
- Black Box will also load themes from `~/.var/app/com.raggesilver.BlackBox/schemes` - #54
- You can customize which and how your shell is spawned in Black Box - #43
  - Run command as login shell
  - Set custom command instead of the default shell

Deprecations:

- The Linux and Tango color schemes have been removed
- All color schemes must now set `background-color` and `foreground-color`

Bug fixes:

- Fixed a bug that prevented users from typing values in the preferences window - #13
- Middle-click paste will now paste from user selection - #46
- Color scheme sorting is now case insensitive
- Long window title resizes window in single tab mode - #77
- Drag-n-drop now works with multiple files - #67
- Improved theme integration. Popovers, menus, and lists are now properly styled
  according to the user's terminal color scheme - #42

## 0.10.1 - 2022.07.08

Features:

- Improved German translation - thanks @konstantin.tch
- Added Czech translation - thanks @panmourovaty
- Added Russian translation - thanks @acephale
- Added Swedish translation - thanks @droidbittin

Bug fixes:

- Black Box now sets the TERM_PROGRAM env variable. This makes apps like
  neofetch report a correct terminal app in Flatpak - #53
- "Remember window size" will now remember fullscreen and maximized state too - #55

## 0.10.0 - 2022.07.04

Features:

- New single tab mode makes it easier to drag the window and the UI more
  aesthetically pleasing when there's a single tab open - #31
- Added middle-click paste (only if enabled system-wide) - #46
- Added French translation - thanks @rene-coty
- Added Dutch translation - thanks @Vistaus
- Added German translation - thanks @ktutsch

Bug fixes:

- Buttons in headerbar are no longer focusable - #49
- Labels and titles in preferences window now follow GNOME HIG for typography -
  !21 thanks @TheEvilSkeleton
- Disable unimplemented `app.quit` accelerator - #44

## 0.9.1 - 2022.07.02

Use patched VTE to enable copying.

## 0.9.0 - 2022.07.01

Features:

- Added cell spacing option #36
- i18n support #27 - thanks @yilozt

Bug fixes:

- Fixed floating controls action row cannot be activated (!19) - thanks @TheEvilSkeleton
- New custom headerbar fixes unwanted spacing with controls on left side #38
- Flathub builds will no longer have "striped headerbar" #40
- A button is now displayed in the headerbar to leave fullscreen #39
