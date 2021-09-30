/* Window.vala
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

public class Terminal.Settings : Marble.Settings
{
    public string font { get; set; }
    public bool pretty { get; set; }
    public bool show_headerbar { get; set; }
    public string theme { get; set; }

    public Settings()
    {
        base("com.raggesilver.Terminal");
    }
}

[GtkTemplate (ui = "/com/raggesilver/Terminal/layouts/window.ui")]
public class Terminal.Window : Hdy.ApplicationWindow
{
    private Gtk.CssProvider? provider = null;
    private Terminal t;
    private Gtk.EventBox eb;
    private Gtk.Popover? pop = null;
    private PreferencesWindow? pref_window = null;

    [GtkChild] Gtk.Box content_box;
    [GtkChild] Gtk.Revealer revealer;
    [GtkChild] Hdy.HeaderBar header_bar;

    public Settings settings { get; private set; }
    public ThemeProvider theme_provicer { get; private set; }

    public Window(Gtk.Application app, string? cwd = null)
    {
        Object(application: app);

        Gtk.Settings.get_default().gtk_application_prefer_dark_theme = true;
        Marble.add_css_provider_from_resource(
            "/com/raggesilver/Terminal/resources/style.css");

        this.settings = new Settings();
        this.get_style_context().add_class("ragged-terminal");

        this.settings.schema.bind("show-headerbar", this.revealer,
            "reveal-child", SettingsBindFlags.GET);

        this.settings.notify["pretty"].connect(() => {
            this.on_ui_updated();
        });

        this.theme_provicer = new ThemeProvider(this.settings);

        t = new Terminal(this, null, cwd);

        t.notify["window-title"].connect(() => {
            this.header_bar.title = t.window_title;
        });

        t.destroy.connect(() => {
            this.destroy();
        });

        t.ui_updated.connect(this.on_ui_updated);

        t.new_window.connect(() => {
            message("CWD %s", this.t.get_current_directory_uri());
            message("CWD %s", this.t.get_current_file_uri());
            var w = new Window(this.application, this.t.get_current_directory_uri());
            w.show();
        });

        eb = new Gtk.EventBox();
        eb.add(t);

        eb.button_press_event.connect(this.show_menu);

        var sa = new SimpleAction("new_window", null);
        sa.activate.connect(() => {
            var w = new Window(this.application);
            w.show();
        });
        this.add_action(sa);

        sa = new SimpleAction("edit_preferences", null);
        sa.activate.connect(() => {
            if (this.pref_window == null)
            {
                this.pref_window = new PreferencesWindow(this.application,
                                                         this);
                this.pref_window.destroy.connect(() => {
                    this.pref_window = null;
                });
            }
            this.pref_window.show();
        });
        this.add_action(sa);

        sa = new SimpleAction("about", null);
        sa.activate.connect(() => {
            var win = new AboutDialog();
            win.set_transient_for(this);
            win.present();
        });
        this.add_action(sa);

        this.settings.notify.connect(this.apply_settings);
        this.apply_settings();

        this.content_box.pack_start(eb, true, true, 0);

        this.on_ui_updated();
        show_all();
    }

    private bool show_menu(Gdk.Event e)
    {
        if (e.button.button != Gdk.BUTTON_SECONDARY)
            return (false);

        if (this.pop == null)
        {
            var b = new Gtk.Builder.from_resource("/com/raggesilver/Terminal/layouts/menu.ui");
            this.pop = b.get_object("popover") as Gtk.Popover;
            this.pop.set_relative_to(eb);
        }

        Gdk.Rectangle r = {0};
        r.x = (int)e.button.x;
        r.y = (int)e.button.y;

        this.pop.set_pointing_to(r);
        this.pop.popup();

        return (true);
    }

    private void apply_settings()
    {
        this.t.font_desc =
            Pango.FontDescription.from_string(this.settings.font);
    }

    private double get_brightness(Gdk.RGBA c) {
        return ((c.red * 299) + (c.green * 587) + (c.blue * 114)) / 1000;
    }

    private void on_ui_updated()
    {
        if (this.provider != null)
        {
            Gtk.StyleContext.remove_provider_for_screen(
                Gdk.Screen.get_default(), this.provider);
            this.provider = null;
        }

        if (!this.settings.pretty) return;

        //  message("Bg brightness: %lf", get_brightness(t.bg));
        //  message("Fg brightness: %lf", get_brightness(t.fg));

        bool is_dark_theme = get_brightness(t.fg) > 0.5;
        string inv_mode = is_dark_theme ? "lighter" : "darker";

        Gtk.Settings.get_default().gtk_application_prefer_dark_theme = is_dark_theme;

        message("This theme is %s", is_dark_theme ? "dark" : "light");

        this.provider = Marble.get_css_provider_for_data("""
            @define-color rg_theme_fg_color %2$s;
            @define-color rg_theme_bg_color %3$s(%1$s);
            @define-color rg_theme_base_color %1$s;
        """.printf(t.bg.to_string(), t.fg.to_string(), inv_mode));

        if (this.provider == null)
            return;

        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            this.provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    }
}
