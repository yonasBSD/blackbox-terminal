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
    public string theme { get; set; }

    public Settings()
    {
        base("com.raggesilver.Terminal");
    }
}

public class Terminal.Window : Gtk.ApplicationWindow
{
    private Gtk.CssProvider? provider = null;
    private Terminal t;
    private Gtk.EventBox eb;
    private Gtk.Popover? pop = null;
    private PreferencesWindow? pref_window = null;

    public Settings settings { get; private set; }
    public ThemeProvider theme_provicer { get; private set; }

    public Window(Gtk.Application app)
    {
        Object(application: app);

        Marble.add_css_provider_from_resource(
            "/com/raggesilver/Terminal/resources/style.css");
        Gtk.Settings.get_default().gtk_application_prefer_dark_theme = true;

        this.settings = new Settings();
        this.get_style_context().add_class("ragged-terminal");

        this.theme_provicer = new ThemeProvider(this.settings);

        t = new Terminal(this);

        t.destroy.connect(() => {
            this.destroy();
        });

        t.ui_updated.connect(this.on_ui_updated);

        t.new_window.connect(() => {
            var w = new Window(this.application);
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

        this.settings.notify.connect(this.apply_settings);
        this.apply_settings();

        add(eb);
        show_all();
    }

    private bool show_menu(Gdk.Event e)
    {
        if (e.button.button != 3)
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

    private void on_ui_updated()
    {
        if (!this.settings.pretty)
        {
            if (this.provider != null)
            {
                Gtk.StyleContext.remove_provider_for_screen(
                    Gdk.Screen.get_default(), this.provider);
                this.provider = null;
            }
            return;
        }

        if (this.provider != null)
        {
            Gtk.StyleContext.remove_provider_for_screen(
                Gdk.Screen.get_default(), this.provider);
            this.provider = null;
        }

        this.provider = Marble.get_css_provider_for_data("""
            window.ragged-terminal .titlebar {
                background: %1$s;
                color: %2$s;
                border-bottom: none;
                box-shadow: none;
            }

            window.ragged-terminal .background {
                background: lighter(%1$s);
            }
        """.printf(t.bg.to_string(), t.fg.to_string()));

        if (this.provider == null)
            return;

        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            this.provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    }
}
