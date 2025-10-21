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
  public enum ConfirmClosingContext {
    TAB,
    WINDOW,
  }

  public enum ConfirmActionType {
    NO_YES,
    CANCEL_OK,
    KEEP_REPLACE,
    CANCEL_CLOSE;

    public string[] get_labels () {
      switch (this) {
        case NO_YES: return { _("No"), _("Yes") };
        case CANCEL_OK: return { _("Cancel"), _("OK") };
        case KEEP_REPLACE: return { _("Keep"), _("Replace") };
        case CANCEL_CLOSE: return { _("Cancel"), _("Close") };
      }
      error ("Invalid ConfirmActionType %d", this);
    }

    public string[] get_values () {
      switch (this) {
        case NO_YES: return { "no", "yes" };
        case CANCEL_OK: return { "cancel", "ok" };
        case KEEP_REPLACE: return { "keep", "replace" };
        case CANCEL_CLOSE: return { "cancel", "close" };
      }
      error ("Invalid ConfirmActionType %d", this);
    }
  }

  public async bool confirm_action (
    string title,
    string body,
    ConfirmActionType confirm_type = ConfirmActionType.CANCEL_OK,
    Adw.ResponseAppearance appearance1 = Adw.ResponseAppearance.DEFAULT,
    Adw.ResponseAppearance appearance2 = Adw.ResponseAppearance.DEFAULT,
    Gtk.Widget? extra_child = null
  ) {
    bool response = false;
    SourceFunc callback = confirm_action.callback;

    string[] labels = confirm_type.get_labels ();
    string[] values = confirm_type.get_values ();

    var d = new Adw.AlertDialog (
      title,
      body
    ) {
      default_response = values [1],
      close_response = values [0],
      extra_child = extra_child
    };

    d.add_response (values [0], labels [0]);
    d.add_response (values [1], labels [1]);

    d.set_response_appearance (values [0], appearance1);
    d.set_response_appearance (values [1], appearance2);

    d.response.connect ((_response) => {
      response = _response == values [1];
      callback ();
    });

    d.present ((GLib.Application.get_default () as Gtk.Application)?.get_active_window ());

    yield;

    return response;
  }

  public async bool confirm_closing (
    string?[]? commands,
    ConfirmClosingContext context = ConfirmClosingContext.TAB
  ) {
    Gtk.Widget? child = null;

    if (commands != null && commands.length > 0) {
      var list = new Gtk.ListBox () {
        css_classes = { "boxed-list" },
        selection_mode = Gtk.SelectionMode.NONE,
      };

      foreach (unowned string command in commands) {
        var row = new Adw.ActionRow () {
          title = command ?? "",
          css_classes = { "monospace" },
          can_focus = false,
        };
        list.append (row);
      }
      child = list;
    }

    string title = context == ConfirmClosingContext.TAB
      ? _("Close Tab?")
      : _("Close Window?");

    string body = context == ConfirmClosingContext.TAB
      ? _("Some commands are still running. Closing this tab will kill them and may lead to unexpected outcomes.")
      : _("Some commands are still running. Closing this window will kill them and may lead to unexpected outcomes.");

    var response = yield confirm_action (
      title,
      body,
      ConfirmActionType.CANCEL_CLOSE,
      Adw.ResponseAppearance.DEFAULT,
      Adw.ResponseAppearance.DESTRUCTIVE,
      child
    );

    return response;
  }
}
