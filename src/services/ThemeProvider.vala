/* ThemeProvider.vala
 *
 * Copyright 2020-2022 Paulo Queiroz
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public Gdk.RGBA? rgba_from_string(string color) {
  Gdk.RGBA c = {0};

  if (c.parse(color)) return c;
  return null;
}

public struct Terminal.Scheme {
  public string name;
  public Gdk.RGBA colors[16];
  public Gdk.RGBA? background;
  public Gdk.RGBA? foreground;
  public bool is_dark;
}

public class Terminal.ThemeProvider : Object {
  private Settings settings;
  private Gtk.CssProvider? theme_provider = null;

  public HashTable<string, Scheme?> themes;

  public string current_theme {
    get {
      return this.is_dark_style_active
        ? Settings.get_default ().theme_dark
        : Settings.get_default ().theme_light;
    }
  }

  public bool is_dark_style_active { get; private set; }

  private static ThemeProvider instance = null;

  private ThemeProvider (Settings settings) {
    this.settings = settings;
    this.themes = new HashTable<string, Scheme?>(str_hash, str_equal);

    try {
      this.ensure_user_schemes_dir_exists ();
      this.load_themes();
    }
    catch (Error e) {
      warning(e.message);
    }

    this.is_dark_style_active = Adw.StyleManager.get_default ().dark;
    Adw.StyleManager.get_default ().notify ["dark"].connect (() => {
      this.is_dark_style_active = Adw.StyleManager.get_default ().dark;
    });

    this.notify ["current-theme"].connect (() => {
      this.apply_theming ();
    });
    this.settings.notify ["pretty"].connect(this.apply_theming);

    this.notify["is-dark-style-active"].connect (() => {
      this.notify_property ("current-theme");
    });

    this.settings.notify["theme-light"].connect (() => {
      if (!this.is_dark_style_active) {
        this.notify_property ("current-theme");
      }
    });

    this.settings.notify["theme-dark"].connect (() => {
      if (this.is_dark_style_active) {
        this.notify_property ("current-theme");
      }
    });

    // React to style-preference changes
    this.settings.schema.bind_with_mapping (
      "style-preference",
      Adw.StyleManager.get_default (),
      "color-scheme",
      SettingsBindFlags.GET,
      // From settings to Adw.StyleManager
      (to_val, settings_vari) => {
        var style_pref = settings_vari.get_uint32 ();
        to_val = style_pref == 0
              ? Adw.ColorScheme.DEFAULT
              : style_pref == 1
                ? Adw.ColorScheme.FORCE_LIGHT
                : Adw.ColorScheme.FORCE_DARK;
        return true;
      },
      null,
      null,
      null
    );

    this.apply_theming();
  }

  public static ThemeProvider get_default () {
    if (instance == null) {
      instance = new ThemeProvider (Settings.get_default ());
    }
    return instance;
  }

  private void load_themes() throws Error {
    string[] paths = {
      Constants.get_user_schemes_dir (),
      Constants.get_app_schemes_dir (),
    };

    foreach (unowned string path in paths) {
      if (!FileUtils.test (path, FileTest.IS_DIR)) {
        continue;
      }

      var d = Dir.open(path);
      string? fname = null;

      while ((fname = d.read_name()) != null) {
        if (!fname.has_suffix(".json"))
          continue;
        debug("Found possible theme file '%s'", fname);
        this.load_theme(File.new_build_filename(path, fname, null));
      }
    }
  }

  private void load_theme(File f) throws Error {
    Json.Parser p = new Json.Parser();
    Json.Node? n = null;
    Json.Object? root = null;
    Json.Array? arr = null;
    string? name = null,
      bg = null,
      fg = null;

    p.load_from_file(f.get_path());
    n = p.get_root();

    return_if_fail(n != null);
    return_if_fail(n.get_node_type() == Json.NodeType.OBJECT);

    root = n.get_object();
    n = root.get_member("palette");

    return_if_fail(n != null);
    return_if_fail(n.get_node_type() == Json.NodeType.ARRAY);

    arr = n.get_array();

    return_if_fail(arr.get_length() == 16);

    n = root.get_member("background-color");
    // Background may be null, in that case we use the GTK theme's colors
    if (n != null)
      bg = n.get_string();

    n = root.get_member("foreground-color");
    // Foreground may be null, in that case we use the GTK theme's colors
    if (n != null)
      fg = n.get_string();

    n = root.get_member("name");
    name = n.get_string();

    return_if_fail(name != null);

    Scheme s = Scheme();

    s.name = name;

    // FIXME: deprecate support for themes without background/foreground
    s.background = (bg != null) ? rgba_from_string(bg) : null;
    s.foreground = (fg != null) ? rgba_from_string(fg) : null;
    s.is_dark = s.foreground != null
      ? get_brightness(s.foreground) > 0.5
      : false;

    for (int i = 0; i < 16; i++) {
      Gdk.RGBA? c = rgba_from_string(arr.get_string_element(i));
      return_if_fail(c != null);
      s.colors[i] = c;
    }

    this.themes.set(name, s);

    debug("Theme '%s' is OK", name);
  }

  private double get_brightness(Gdk.RGBA c) {
    return ((c.red * 299) + (c.green * 587) + (c.blue * 114)) / 1000;
  }

  public void apply_theming() {
    if (this.theme_provider != null) {
      Gtk.StyleContext.remove_provider_for_display(
        Gdk.Display.get_default(),
        this.theme_provider
      );
      this.theme_provider = null;
    }

    var theme = this.themes[this.current_theme];

    if (
      theme == null ||
      !this.settings.pretty ||
      !this.is_safe_to_be_pretty(theme)
    ) {
      return;
    }

    var foreground = theme.foreground;
    var background = theme.background;

    if (foreground == null || background == null) return;

    bool is_dark_theme = this.is_dark_style_active;
    string inv_mode = is_dark_theme ? "lighter" : "darker";

    this.theme_provider = Marble.get_css_provider_for_data("""
      @define-color window_bg_color %1$s;
      @define-color window_fg_color %2$s;
      @define-color headerbar_bg_color %3$s(%1$s);
    """.printf(
        background.to_string(),
        foreground.to_string(),
        inv_mode
      )
    );

    if (this.theme_provider == null) return;

    Gtk.StyleContext.add_provider_for_display(
      Gdk.Display.get_default(),
      this.theme_provider,
      Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    );
  }

  // If the current style is dark and a light theme is loaded, all window text
  // and icons will be illegible. Same goes for light style with dark theme
  // selected. In those cases, we need to disable theme integration.
  private bool is_safe_to_be_pretty (Scheme theme) {
    return this.is_dark_style_active == theme.is_dark;
  }

  private void ensure_user_schemes_dir_exists () {
    var path = Constants.get_user_schemes_dir ();

    if (!FileUtils.test (path, FileTest.IS_DIR)) {
      var f = File.new_for_path (path);

      try {
        f.make_directory ();
      }
      catch (Error e) {
        warning ("%s", e.message);
      }
    }
  }
}
