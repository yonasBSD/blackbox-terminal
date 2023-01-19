/* Shortcuts.vala
 *
 * Copyright 2023 Paulo Queiroz <pvaqueiroz@gmail.com>
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
  public string get_accel_as_label (string accel) {
    Gdk.ModifierType mods;
    uint key;

    if (Gtk.accelerator_parse (accel, out key, out mods)) {
       var kt = new Gtk.KeyvalTrigger (key, mods);

       return kt.to_label (Gdk.Display.get_default ());
    }
    else {
      return _("invalid keybinding");
    }
  }
}
