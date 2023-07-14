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
  public Adw.AboutWindow create_about_dialog () {
    var window = new Adw.AboutWindow () {
      developer_name = "Paulo Queiroz",
      copyright = "© 2022-2023 Paulo Queiroz",
      license_type = Gtk.License.GPL_3_0,
      application_icon = APP_ID,
      application_name = APP_NAME,
      version = VERSION,
      website = "https://gitlab.gnome.org/raggesilver/blackbox",
      issue_url = "https://gitlab.gnome.org/raggesilver/blackbox/-/issues",
      debug_info = get_debug_information (),
      release_notes = """
        <p>The Sandbox Conundrum.</p>
        <p>Features</p>
        <ul>
          <li>You can now customize the working directory for new tabs. It can be set to persist the last tab's directory, the user's home directory, or an arbitrary location</li>
          <li>Closing a tab or a window that still has a running process will now prompt you for confirmation</li>
          <li>Black Box now uses the default Adwaita tab style. As consequence, some header bar options, including "Show Borders" have been removed from the preferences window</li>
          <li>Added the option to disable terminal bell</li>
          <li>Added option to use bright colors for bold text</li>
          <li>You can now get a desktop notification when a process completes on an unfocussed tab</li>
          <li>Context-aware header bar: the header bar can now have special colors when the active tab is running sudo or ssh</li>
          <li>Added open and copy link options to the right-click menu</li>
        </ul>
        <p>Improvements</p>
        <ul>
          <li>Some configuration options have been grouped together in the preferences
  window</li>
          <li>Application title is now bold when there's a single tab open</li>
        </ul>
        <p>Bug fixes</p>
        <ul>
          <li>Improved keybinding validation, allowing more valid key combinations to be used</li>
          <li>The window title is now centered when there's only one tab</li>
          <li>Sixel is now disabled for VTE builds that don't support it. This primarily affects non-Flatpak users, as all Flatpak builds ship VTE with Sixel support</li>
        </ul>
      """
    };

    if (DEVEL) {
      window.add_css_class ("devel");
    }

    window.add_link (_("Donate"), "https://www.patreon.com/raggesilver");
    window.add_link (_("Full Changelog"), "https://gitlab.gnome.org/raggesilver/blackbox/-/blob/main/CHANGELOG.md");

    return window;
  }

  private string get_debug_information () {
    var app = "Black Box: %s\n".printf (VERSION);
    var backend = "Backend: %s\n".printf (get_gtk_backend ());
    var renderer = "Renderer: %s\n".printf (get_renderer ());
    var flatpak = get_flatpak_info ();
    var os_info = get_os_info ();
    var libs = get_libraries_info ();

    return app + backend + renderer + flatpak + os_info + libs;
  }

  private string get_gtk_backend () {
    var display = Gdk.Display.get_default ();
    switch (display.get_class ().get_name ()) {
      case "GdkX11Display": return "X11";
      case "GdkWaylandDisplay": return "Wayland";
      case "GdkBroadwayDisplay": return "Broadway";
      case "GdkWin32Display": return "Windows";
      case "GdkMacosDisplay": return "macOS";
      default: return display.get_class ().get_name ();
    }
  }

  private string get_renderer () {
    var display = Gdk.Display.get_default ();
    var surface = new Gdk.Surface.toplevel (display);
    var renderer = Gsk.Renderer.for_surface (surface);

    var name = renderer.get_class ().get_name ();
    renderer.unrealize ();

    switch (name) {
      case "GskVulkanRenderer": return "Vulkan";
      case "GskGLRenderer": return "GL";
      case "GskCairoRenderer": return "Cairo";
      default: return name;
    }
  }

  static KeyFile? flatpak_keyfile = null;

  private string? get_flatpak_value (string group, string key) {
    try {
      if (flatpak_keyfile == null) {
        flatpak_keyfile = new KeyFile ();
        flatpak_keyfile.load_from_file ("/.flatpak-info", 0);
      }
      return flatpak_keyfile.get_string (group, key);
    }
    catch (Error e) {
      warning ("%s", e.message);
      return null;
    }
  }

  private string get_flatpak_info () {
#if BLACKBOX_IS_FLATPAK
    string res = "Flatpak:\n";

    res += " - Runtime: %s\n".printf (get_flatpak_value ("Application", "runtime"));
    res += " - Runtime commit: %s\n".printf (get_flatpak_value ("Instance", "runtime-commit"));
    res += " - Arch: %s\n".printf (get_flatpak_value ("Instance", "arch"));
    res += " - Flatpak version: %s\n".printf (get_flatpak_value ("Instance", "flatpak-version"));
    res += " - Devel: %s\n".printf (get_flatpak_value ("Instance", "devel") != null ? "yes" : "no");

    return res;
#else
    return "Flatpak: No\n";
#endif
  }

  private string get_libraries_info () {
    string res = "Libraries:\n";

    res += " - Gtk: %d.%d.%d\n".printf (Gtk.MAJOR_VERSION, Gtk.MINOR_VERSION, Gtk.MICRO_VERSION);
    res += " - VTE: %d.%d.%d\n".printf (Vte.MAJOR_VERSION, Vte.MINOR_VERSION, Vte.MICRO_VERSION);
    res += " - Libadwaita: %s\n".printf (Adw.VERSION_S);
    res += " - JSON-glib: %s\n".printf (Json.VERSION_S);

    return res;
  }

  private string get_os_info () {
    string res = "OS:\n";

    res += " - Name: %s\n".printf (Environment.get_os_info (OsInfoKey.NAME));
    res += " - Version: %s\n".printf (Environment.get_os_info (OsInfoKey.VERSION));

    return res;
  }
}
