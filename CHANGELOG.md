# Changelog

## 0.15.0 - Unreleased

Features:

- Added shortcut for moving tabs Shift+Ctrl+PageDown/PageUp - #225
- Ctrl+PageDown/PageUp have been added as default keybindins for switching tabs,
  alongside (Shift)+Ctrl+Tab (yes, there are two default keybindings). You may
  need to reset keybindings for these two actions to see the new defaults.
- The window title is now set to the title of the active tab. This is noticeable
  when hovering Black Box in the GNOME Overview - #317
- Black Box will show a visual indicator on a tab when a command finishes in the
  background (similar to desktop notifications, but less noisy) - #345

Improvements:

- Command completion notifications have been improved. Clicking a notification
  will now focus the correct tab. Black Box will no longer emit two
  notifications for the same command. - !145 thanks to @her01n

## 0.14.0 - 2023-07-17

The Sandbox Conundrum.

Features:

- Added new default Adwaita and Adwaita Dark color schemes - #157 thanks
  to @vixalien
- You can now customize the working directory for new tabs. It can be set to
  persist the last tab's directory, the user's home directory, or an arbitrary
  location - #122
- Closing a tab or a window that still has a running process will now prompt you
  for confirmation - fixes #201
- Black Box now uses the default Adwaita tab style. As consequence, some header
  bar options, including "Show Borders" have been removed from the preferences
  window - #112, #253
- Added the option to disable terminal bell - #106
- Added the option to make bold text bright - #203
- You can now get a desktop notification when a process completes on an
  unfocussed tab - #146
- Context-aware header bar: the header bar can now have special colors when the
  active tab is running sudo or ssh - #239 - co-authored by @foxedb
- Added open and copy link options to the right-click menu - #141
- You can now rename tabs with the new tab right-click menu, or with a new
  shortcut `Shift + Control + R` - #242
- Added a quick application style switcher to the window menu - #147

Improvements:

- Some configuration options have been grouped together in the preferences
  window - #254
- Application title is now bold when there's a single tab open - #235
- Performance and bundle size optimizations - #283, #284
- Black Box now has more Flatpak permissions to overcome errors reported by
  users - #186, #215

Bug fixes:

- Fixed an issue that caused terminals not to be destroyed when their tabs were
  closed - #261
- The window title is now centered when there's only one tab - #199
- Improved keybinding validation, allowing more valid key combinations to be
  used - #245
- Sixel is now disabled for VTE builds that don't support it. This primarily
  affects non-Flatpak users, as all Flatpak builds ship VTE with Sixel
  support - #273
- Fixed an issue that caused windows launched with custom commands to not have a
  title - #237
- Black Box will now show an error banner if spawning a shell or custom
  command failed and will no longer close immediately - #97, #121, #259

## 0.13.2 - 2023-01-19

Second 0.13 patch release.

Features:

- Added support for setting multiple shortcuts for the same action - #212
- You can now reset one, or all custom shortcuts back to default - #211
- A warning is displayed if a user selects "Unlimited" scrollback mode - #228

Bug fixes:

- Added workaround for a Vala error that would cause Black Box to crash

## 0.13.1 - 2023-01-16

First 0.13 patch release.

Features:

- New Scrollback Mode allows you to set scrollback to a fixed number of lines,
  unlimited lines, or disable scrollback altogether - #197
- Allow setting font style (regular, light, bold, etc) - #170

Improvements:

- Updated French, Italian, and Turkish translations

Bug fixes:

- Added missing "Open Preferences" shortcut to help overlay - @sabriunal
- Header bar and tabs are now properly colored when the app is unfocussed
- Fixed regression in window border color when "Show Borders" is enabled
- Window border is no longer displayed when Black Box is docked left, right, or
  maximized #181
- Improved keybinding validation, allowing more valid key combinations to be
  used - #214
- Tab navigation shortcuts now work as expected - #217
- Fixed default "Reset Zoom" keybinding
- Fixed issue that prevented development builds of Black Box from running when
  installed via Flatpak - #210

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
