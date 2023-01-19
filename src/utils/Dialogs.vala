/* Dialogs.vala
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
  public enum ConfirmActionType {
    NO_YES,
    CANCEL_OK,
    KEEP_REPLACE;

    public string[] get_labels () {
      switch (this) {
        case NO_YES: return { _("No"), _("Yes") };
        case CANCEL_OK: return { _("Cancel"), _("Ok") };
        case KEEP_REPLACE: return { _("Keep"), _("Replace") };
      }
      error ("Invalid ConfirmActionType %d", this);
    }

    public string[] get_values () {
      switch (this) {
        case NO_YES: return { "no", "yes" };
        case CANCEL_OK: return { "cancel", "ok" };
        case KEEP_REPLACE: return { "keep", "replace" };
      }
      error ("Invalid ConfirmActionType %d", this);
    }
  }

  public async bool confirm_action (
    string title,
    string body,
    ConfirmActionType confirm_type = ConfirmActionType.CANCEL_OK,
    Adw.ResponseAppearance appearance1 = Adw.ResponseAppearance.DEFAULT,
    Adw.ResponseAppearance appearance2 = Adw.ResponseAppearance.DEFAULT
  ) {
    bool response = false;
    SourceFunc callback = confirm_action.callback;

    string[] labels = confirm_type.get_labels ();
    string[] values = confirm_type.get_values ();

    var d = new Adw.MessageDialog (
      (GLib.Application.get_default () as Gtk.Application)?.get_active_window (),
      title,
      body
    ) {
      default_response = values [1],
      close_response = values [0],
    };

    d.add_response (values [0], labels [0]);
    d.add_response (values [1], labels [1]);

    d.set_response_appearance (values [0], appearance1);
    d.set_response_appearance (values [1], appearance2);

    d.response.connect ((_response) => {
      response = _response == values [1];
      callback ();
    });

    d.show ();

    yield;

    return response;
  }
}
