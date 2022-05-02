/* AboutDialog.vala
 *
 * Copyright 2021-2022 Paulo Queiroz <pvaqueiroz@gmail.com>
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

namespace Terminal {
  public Gtk.AboutDialog create_about_dialog () {
    var dialog = new Gtk.AboutDialog () {
      authors = { "Paulo Queiroz <pvaqueiroz@gmail.com>" },
      destroy_with_parent = true,
      license_type = Gtk.License.GPL_3_0,
      logo_icon_name = "com.raggesilver.BlackBox",
      modal = true,
      program_name = "Black Box",
      version = VERSION,
      website = "https://gitlab.gnome.org/raggesilver/terminal",
      website_label = "Repo",
    };

    dialog.titlebar.add_css_class ("flat");
    dialog.titlebar.add_css_class ("background");

    return dialog;
  }
}
