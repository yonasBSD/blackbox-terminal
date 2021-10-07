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
    private Gtk.Popover? pop = null;
    private PreferencesWindow? pref_window = null;
    private Hdy.TabView tab_view;

    [GtkChild] Gtk.Box content_box;
    [GtkChild] Gtk.Revealer revealer;
    [GtkChild] Hdy.TabBar tab_bar;

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

        this.theme_provicer = new ThemeProvider(this.settings);

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

        this.tab_view = new Hdy.TabView();
        this.content_box.pack_start(this.tab_view, true, true, 0);
        this.tab_bar.set_view(this.tab_view);

        var b = new Gtk.Button.from_icon_name("list-add-symbolic", Gtk.IconSize.BUTTON);
        b.clicked.connect(this.new_tab);
        this.tab_bar.end_action_widget = b;

        this.new_tab();
        this.new_tab();

        show_all();
    }

    public void new_tab() {
        var tab = new TerminalTab(this, null);
        var page = this.tab_view.add_page(tab, null);
        page.title = @"tab $(this.tab_view.n_pages)";
        tab.notify["title"].connect(() => {
            page.title = tab.title;
        });
    }

    public bool show_menu(Gdk.Event e)
    {
        message("Called");

        if (e.button.button != Gdk.BUTTON_SECONDARY)
            return (false);

        if (this.pop == null)
        {
            var b = new Gtk.Builder.from_resource("/com/raggesilver/Terminal/layouts/menu.ui");
            this.pop = b.get_object("popover") as Gtk.Popover;
            this.pop.set_relative_to(this.content_box);
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
        //  this.t.font_desc =
        //      Pango.FontDescription.from_string(this.settings.font);
    }
}
