/* ShortcutDialog.vala
 *
 * Copyright 2022 Paulo Queiroz <pvaqueiroz@gmail.com>
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

[GtkTemplate (ui = "/com/raggesilver/BlackBox/gtk/shortcut-dialog.ui")]
public class Terminal.ShortcutDialog : Adw.Window {

  static Gtk.KeyvalTrigger JUST_ESCAPE = new Gtk.KeyvalTrigger (
    Gdk.Key.Escape,
    0
  );

  static Gtk.KeyvalTrigger JUST_BACKSPACE = new Gtk.KeyvalTrigger (
    Gdk.Key.BackSpace,
    0
  );

  public signal void response (Gtk.ResponseType response);
  public signal void shortcut_set (string? shortcut);

  public string?  shortcut_name   { get; set; default = null; }
  public string?  current_accel   { get; set; default = null; }
  public string?  new_accel       { get; private set; default = null; }
  public bool     is_in_use       { get; private set; default = false; }
  public bool     is_shortcut_set { get; protected set; default = false; }

  public string   heading_text {
    owned get {
      return this.shortcut_name == null
        ? _("Enter new shortcut")
        : _("Enter new shortcut for \"%s\"").printf (this.shortcut_name);
    }
  }

  [GtkChild] unowned Gtk.ShortcutLabel shortcut_label;

  construct {
    if (DEVEL) {
      this.add_css_class ("devel");
    }

    this.response.connect_after (this.close);

    this.notify ["shortcut-name"].connect (() => {
      this.notify_property ("heading-text");
    });

    // bind this.current-accel -> this.shortcut_label.accelerator
    this.bind_property (
      "current-accel",
      this.shortcut_label,
      "accelerator",
      BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE,
      // current-accel -> accelerator
      (_binding, from_value, ref to_value_ref) => {
        string? current = from_value.get_string ();
        to_value_ref = current ?? "";
        return true;
      },
      null
    );

    this.setup_key_controller ();
  }

  private void setup_key_controller () {
    var kpc = new Gtk.EventControllerKey ();

    kpc.key_pressed.connect ((event, keyval, _keycode, modifier) => {
      int[] masks = {
        Gdk.ModifierType.CONTROL_MASK,
        Gdk.ModifierType.SHIFT_MASK,
        Gdk.ModifierType.ALT_MASK
      };

      var real_modifiers = 0;

      foreach (unowned int mask in masks) {
        if ((modifier & mask) == mask) {
          real_modifiers |= mask;
        }
      }

      var k = new Gtk.KeyvalTrigger (keyval, real_modifiers);

      if (k.compare (JUST_ESCAPE) == 0) {
        this.cancel ();
        return false;
      }
      else if (k.compare (JUST_BACKSPACE) == 0) {
        this.shortcut_set (null);
        this.apply ();
        return true;
      }

      bool is_valid =
        // This is a very stupid way to check if the keyval is not Control_L,
        // Shift_L, or Alt_L. We don't want these keys to be valid.
        Gdk.keyval_name (keyval).index_of ("_", 0) == -1 &&
        // Unless keyval is one of the Function keys, shortcuts need either
        // Control or Alt.
        (
          (keyval >= Gdk.Key.F1 && keyval <= Gdk.Key.F35) ||
          (real_modifiers & Gdk.ModifierType.CONTROL_MASK) != 0 ||
          (real_modifiers & Gdk.ModifierType.ALT_MASK) != 0
        );

      this.shortcut_label.set_accelerator (k.to_string ());

      // TODO: since we can get the name of the action that is currently using
      // this shortcut we should show it to the user
      //
      // E.g.: This shortcut is currently assigned to "Reset Zoom"
      this.is_in_use = Keymap
        .get_default ()
        .get_action_for_shortcut (k.to_string ()) != null;

      this.is_shortcut_set = is_valid && !this.is_in_use;
      this.shortcut_set (this.is_shortcut_set ? k.to_string () : null);

      return true;
    });

    (this as Gtk.Widget)?.add_controller (kpc);
  }

  [GtkCallback]
  void cancel () {
    this.response (Gtk.ResponseType.CANCEL);
  }

  [GtkCallback]
  void apply () {
    this.response (Gtk.ResponseType.APPLY);
  }
}
