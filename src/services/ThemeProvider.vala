/* ThemeProvider.vala
 *
 * Copyright 2020 Paulo Queiroz
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
}

public class Terminal.ThemeProvider : Object {
    private weak Settings settings;
    private Gtk.CssProvider? provider = null;

    public HashTable<string, Scheme?> themes;

    public ThemeProvider(Settings settings) {
        this.settings = settings;
        this.themes = new HashTable<string, Scheme?>(str_hash, str_equal);

        debug("Selected theme %s", settings.theme);

        try {
            this.load_themes();
        }
        catch (Error e) {
            warning(e.message);
        }

        this.settings.notify["theme"].connect(this.apply_theming);
        this.settings.notify["pretty"].connect(this.apply_theming);
        this.apply_theming();
    }

    private void load_themes() throws Error
    {
        string? fname = null;
        string path = Path.build_path(
            Path.DIR_SEPARATOR_S, DATADIR, "terminal", "schemes", null
        );
        var d = Dir.open(path);

        while ((fname = d.read_name()) != null)
        {
            if (!fname.has_suffix(".json"))
                continue;
            debug("Found possible theme file '%s'", fname);
            this.load_theme(File.new_build_filename(path, fname, null));
        }
    }

    private void load_theme(File f) throws Error
    {
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

        s.background = (bg != null) ? rgba_from_string(bg) : null;
        s.foreground = (fg != null) ? rgba_from_string(fg) : null;

        for (int i = 0; i < 16; i++)
        {
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
        if (this.provider != null) {
            Gtk.StyleContext.remove_provider_for_screen(
                Gdk.Screen.get_default(),
                this.provider
            );
            this.provider = null;
        }

        var theme = this.themes[this.settings.theme];

        if (!this.settings.pretty || theme == null) return;

        var foreground = theme.foreground;
        var background = theme.background;

        if (foreground == null || background == null) return;

        bool is_dark_theme = this.get_brightness(foreground) > 0.5;
        string inv_mode = is_dark_theme ? "lighter" : "darker";

        Gtk.Settings.get_default()
            .gtk_application_prefer_dark_theme = is_dark_theme;

        debug("This theme is %s", is_dark_theme ? "dark" : "light");

        this.provider = Marble.get_css_provider_for_data("""
            @define-color rg_theme_fg_color %2$s;
            @define-color rg_theme_bg_color %3$s(%1$s);
            @define-color rg_theme_base_color %1$s;
        """.printf(
                background.to_string(),
                foreground.to_string(),
                inv_mode
            )
        );

        if (this.provider == null) return;

        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            this.provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    }
}
