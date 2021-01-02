/* PreferencesWindow.vala
 *
 * Copyright 2020 Paulo Queiroz <pvaqueiroz@gmail.com>
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
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

[GtkTemplate (ui = "/com/raggesilver/Terminal/layouts/preferences-window.ui")]
public class Terminal.PreferencesWindow : Gtk.ApplicationWindow
{
    [GtkChild] Gtk.Switch pretty_switch;
    [GtkChild] Gtk.Switch show_headerbar_switch;
    [GtkChild] Gtk.FontButton font_button;
    [GtkChild] Gtk.ComboBoxText theme_combo;

    weak Settings settings;
    weak Window window;

    public PreferencesWindow(Gtk.Application app, Window window)
    {
        Object(application: app);

        this.window = window;
        this.settings = window.settings;

        this.settings.schema.bind("pretty", this.pretty_switch,
            "active", SettingsBindFlags.DEFAULT);

        this.settings.schema.bind("show-headerbar", this.show_headerbar_switch,
            "active", SettingsBindFlags.DEFAULT);

        this.settings.schema.bind("font", this.font_button,
            "font", SettingsBindFlags.DEFAULT);

        this.window.theme_provicer.themes.foreach((key) => {
            this.theme_combo.insert(-1, key, key);
        });

        this.theme_combo.set_active_id(this.settings.theme);

        this.settings.schema.bind("theme", this.theme_combo,
            "active-id", SettingsBindFlags.DEFAULT);
    }
}
