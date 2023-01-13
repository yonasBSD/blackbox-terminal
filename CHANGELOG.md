# Changelog

## 0.13.0 - 2023-01-13

The latest version of Black Box brings much-awaited new features and bug fixes.

Features:

- Customizable keyboard shortcuts
- Background transparency - thanks to @bennyp
- Customizable cursor blinking mode - thanks to @knuxify
- Experimental Sixel support - thanks to @PJungkamp

Bug fixes:

- Manually set VTE_VERSION environment variable - fixes compatibility with a few terminal programs - #208
- Copying text outside the current scroll view now works correctly - #166
- Scrolling with a touchpad or touchscreen now works as intended - #179

## 0.12.2 - 2022.11.16

Features:

- Added Turkish translation - thanks to @sabriunal

Improvements:

- UI consistency - thanks to @sabriunal
- Clear selection after copying text with easy copy/paste - thanks to @1player

Bug fixes:

- Text selection was broken - #177

## 0.12.1 - 2022.09.28

Features:

- Added Brazilian Portuguese translation - thanks to @ciro-mota

Improvements:

- Updated French, Russian, Italian, Czech, and Swedish translations

Bug fixes:

- Flatpak CLI `1.13>=` had weird output - #165

## 0.12.0 - 2022.08.16

Features:

- Added support for searching text from terminal output - #93
- Open a new tab by clicking on the header bar with the middle mouse button - #88
- Customizable number of lines to keep buffered - #92
- Added option to reserve an area in the header bar to drag the window
- Added Spanish translation - thanks @oscfdezdz

Improvements:

- Greatly improved performance, thanks to an update in VTE
- Theme integration now uses red, green, blue, and yellow from your terminal
  theme to paint the rest of the app
- Theme integration now uses a different approach to calculate colors based on
  your terminal theme's background color. This results in more aesthetically
  pleasing header bar colors

Bug fixes:

- The primary clipboard now works as intended - #46
- The "Reset Preferences" button is now translatable - #117
- High CPU usage - #21
- Fix right-click menu spawn position - closes #52
- Fix long loading times - fixes #135

## 0.11.3 - 2022.07.21

- Ctrl + click can now be used to open URLs - #25

## 0.11.2 - 2022.07.17

- Updated translations
- Added Simplified Chinese translation
- Black Box now sets the COLORTERM env variable to `truecolor` - #98

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
