# Changelog

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
