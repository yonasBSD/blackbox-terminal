/* Window.vala
 *
 * Copyright 2020-2022 Paulo Queiroz
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

// FIXME: move this somewhere else
public struct Terminal.Padding {
  uint top;
  uint right;
  uint bottom;
  uint left;

  public Variant to_variant () {
    return new Variant (
      "(uuuu)",
      this.top,
      this.right,
      this.bottom,
      this.left
    );
  }

  public static Padding zero () {
    return { 0 };
  }

  public static Padding from_variant (Variant vari) {
    if (!vari.check_format_string ("(uuuu)", false)) return Padding.zero ();

    var iter = vari.iterator ();
    uint top = 0, right = 0, bottom = 0, left = 0;

    iter.next ("u", &top);
    iter.next ("u", &right);
    iter.next ("u", &bottom);
    iter.next ("u", &left);

    return Padding () {
      top = top,
      right = right,
      bottom = bottom,
      left = left,
    };
  }

  public string to_string () {
    return "Padding { %u, %u, %u, %u }".printf (
      this.top,
      this.right,
      this.bottom,
      this.left
    );
  }

  /**
   * Whether padding on all sides is the same.
   */
  public bool is_equilateral () {
    return (
      this.top == this.right &&
      this.right == this.bottom &&
      this.bottom == this.left
    );
  }
}

public class Terminal.Window : Adw.ApplicationWindow {

  // Signals

  private signal void header_bar_animation_finished ();

  // Properties

  public ThemeProvider  theme_provider        { get; private set; }
  public Adw.TabView    tab_view              { get; private set; }
  public Adw.TabBar     tab_bar               { get; private set; }
  public Terminal?      active_terminal       { get; private set; }
  public TerminalTab?   active_terminal_tab   { get; private set; default = null; }
  public string         active_terminal_title { get; private set; default = ""; }
  public uint           id                    { get; private set; }

  // Terminal tabs set this to any link clicked by the user. The value is then
  // consumed by the open-link and copy-link actions.
  public string? link  { get; set; default = null; }

  // Fields

  Array<ulong>  active_terminal_signal_handlers = new Array<ulong> ();
  Array<ulong>  active_terminal_tab_signal_handlers = new Array<ulong> ();
  bool          force_close = false;
  const uint    header_bar_revealer_duration_ms = 250;
  Gtk.Revealer  header_bar_revealer;
  HeaderBar     header_bar;
  Settings      settings = Settings.get_default ();
  uint          header_bar_waiting_floating_animation = 0;
  uint          header_bar_waiting_floating_delay = 0;
  Gtk.Box       layout_box;
  Gtk.Overlay   overlay;
  private static uint next_id = 0;

  weak Adw.TabPage? tab_menu_target = null;

  // Actions

  SimpleAction copy_action;
  SimpleAction copy_link_action;
  SimpleAction open_link_action;
  SimpleAction move_tab_left_action;
  SimpleAction move_tab_right_action;
  SimpleAction close_specific_tab_action;
  SimpleAction detatch_tab_action;
  SimpleAction rename_tab_action;

  // TODO: bring all SimpleActions over here
  private const ActionEntry[] ACTION_ENTRIES = {
    { "new_tab", on_new_tab },
  };

  static PreferencesWindow? preferences_window = null;

  construct {
    this.id = next_id;
    next_id++;
    if (DEVEL) {
      this.add_css_class ("devel");
    }

    // FIXME: move this over to an ui file

    this.layout_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

    this.tab_view = new Adw.TabView () {
      // Disable Adw.TabView shortcuts
      shortcuts = Adw.TabViewShortcuts.NONE,
    };

    this.header_bar = new HeaderBar (this);

    this.tab_bar = this.header_bar.tab_bar;
    this.tab_bar.view = this.tab_view;

    this.header_bar_revealer = new Gtk.Revealer () {
      transition_duration = Window.header_bar_revealer_duration_ms,
      child = this.header_bar,
      valign = Gtk.Align.START,
    };

    var builder = new Gtk.Builder.from_resource ("/com/raggesilver/BlackBox/gtk/tab-menu.ui");
    this.tab_view.menu_model = builder.get_object ("tab-menu") as GLib.Menu;

    this.layout_box.append (this.header_bar_revealer);
    this.layout_box.append (this.tab_view);

    this.overlay = new Gtk.Overlay ();
    this.overlay.child = this.layout_box;

    this.content = this.overlay;

    this.set_name ("blackbox-main-window");
  }

  public Window (
    Gtk.Application app,
    string? command = null,
    string? cwd = null,
    bool skip_initial_tab = false
  ) {
    var sett = Settings.get_default ();
    var wwidth = (int) (sett.remember_window_size ? sett.window_width : 700);
    var wheight = (int) (sett.remember_window_size ? sett.window_height : 450);

    Object (
      application: app,
      default_width: wwidth,
      default_height: wheight,
      fullscreened: sett.remember_window_size && sett.was_fullscreened,
      maximized: sett.remember_window_size && sett.was_maximized
    );

    this.theme_provider = ThemeProvider.get_default ();

    this.add_actions ();
    this.connect_signals ();

    if (!skip_initial_tab) {
      this.new_tab (command, cwd);
    }
  }

  private void connect_signals () {
    this.bind_property (
      "active-terminal-title",
      this,
      "title",
      GLib.BindingFlags.SYNC_CREATE,
      null,
      null
    );

    this.settings.schema.bind (
      "fill-tabs",
      this.tab_bar,
      "expand-tabs",
      SettingsBindFlags.GET
    );

    this.settings.schema.bind (
      "show-headerbar",
      this.header_bar_revealer,
      "reveal-child",
      SettingsBindFlags.GET
    );

    this.settings.notify ["context-aware-header-bar"].connect (() => {
      this.on_active_terminal_context_changed ();
    });

    this.header_bar_revealer.notify ["reveal-child"]
      .connect (this.on_reveal_header_bar_changed);

    settings.notify ["show-headerbar"].connect (() => {
      if (Settings.get_default ().show_headerbar) {
        this.on_show_header_bar_changed ();
      }
    });

    settings.notify ["show-headerbar"].connect_after (() => {
      if (!Settings.get_default ().show_headerbar) {
        this.on_show_header_bar_changed ();
      }
    });

    this.on_show_header_bar_changed ();

    settings.notify ["floating-controls"]
      .connect (this.on_floating_controls_changed);

    this.tab_view.create_window.connect (() => {
      var w = this.new_window (null, true);
      return w.tab_view;
    });

    this.tab_view.close_page.connect ((page) => {
      this.try_closing_tab.begin (page);
      return true;
    });

    // Close the window if all tabs were closed
    this.tab_view.notify["n-pages"].connect (() => {
      if (this.tab_view.n_pages < 1) {
        this.close ();
      }
    });

    this.tab_view.notify["selected-page"].connect (() => {
      this.on_tab_selected ();
    });

    this.tab_view.setup_menu.connect (this.on_setup_menu);

    this.notify["default-width"].connect (() => {
      this.settings.window_width = this.default_width;
    });

    this.notify["default-height"].connect (() => {
      this.settings.window_height = this.default_height;
    });

    this.notify ["active-terminal"]
      .connect (this.on_active_terminal_tab_changed);

    var motion_controller = new Gtk.EventControllerMotion ();
    motion_controller.motion.connect (this.on_mouse_motion);

    (this as Gtk.Widget)?.add_controller (motion_controller);

    this.close_request.connect (this.on_close_request);

    this.notify ["link"].connect (() => {
      var enabled = this.link != null;

      message ("Setting link actions to %s", enabled.to_string ());
      this.copy_link_action.set_enabled (this.link != null);
      this.open_link_action.set_enabled (this.link != null);
    });
  }

  private void on_mouse_motion (
    Gtk.EventControllerMotion _,
    double _mouseX,
    double mouseY
  ) {
    // Ignore mouse motion if standard header bar is shown or if floating
    // controls are disabled
    if (this.settings.show_headerbar || !this.settings.floating_controls) {
      return;
    }

    var hb_height = this.header_bar.get_height ();
    var is_shown = this.header_bar_revealer.reveal_child;

    var trigger_area = settings.floating_controls_hover_area;

    bool is_hovering_trigger_area =
      mouseY >= 0 && mouseY <= (is_shown ? hb_height : trigger_area);

    if (is_hovering_trigger_area && !is_shown) {
      // Only schedule animation if there aren't any scheduled
      if (this.header_bar_waiting_floating_delay == 0) {
        // Wait for delay to show floating controls
        this.header_bar_waiting_floating_delay = Timeout.add (
          settings.delay_before_showing_floating_controls,
          () => {
            this.header_bar_waiting_floating_delay = 0;

            this.header_bar_revealer.reveal_child = true;

            return false;
          }
        );
      }
    }
    else if (
      !is_hovering_trigger_area &&
      (is_shown || this.header_bar_waiting_floating_delay != 0)
    ) {
      if (this.header_bar_waiting_floating_delay != 0) {
        Source.remove (this.header_bar_waiting_floating_delay);
        this.header_bar_waiting_floating_delay = 0;
      }
      this.header_bar_revealer.reveal_child = false;
    }
  }

  private void on_setup_menu (Adw.TabPage? page) {
    this.tab_menu_target = page;

    this.move_tab_left_action.set_enabled (page != null && this.tab_view.get_page_position (page) > 0);
    this.move_tab_right_action.set_enabled (page != null && this.tab_view.get_page_position (page) < this.tab_view.n_pages - 1);
    this.close_specific_tab_action.set_enabled (page != null);
    this.detatch_tab_action.set_enabled (page != null && this.tab_view.n_pages > 1);
  }

  private void on_reveal_header_bar_changed () {
    this.header_bar_waiting_floating_animation = Timeout
      .add (header_bar_revealer_duration_ms, () => {
        this.header_bar_waiting_floating_animation = 0;
        this.header_bar_animation_finished ();
        return false;
      });
  }

  private void on_floating_controls_changed () {
    this.set_header_bar_to_floating.begin (
      !this.settings.show_headerbar && this.settings.floating_controls
    );
  }

  private void on_show_header_bar_changed () {
    this.set_header_bar_to_floating.begin (
      !this.settings.show_headerbar && this.settings.floating_controls
    );
  }

  private async void wait_for_header_bar_animation () {
    if (this.header_bar_waiting_floating_animation == 0) {
      return;
    }

    SourceFunc callback = this.wait_for_header_bar_animation.callback;

    ulong hid = 0;

    hid = this.header_bar_animation_finished.connect_after (() => {
      callback ();
      this.disconnect (hid);
    });

    yield;
  }

  private bool setting_header_bar_to_floating = false;
  private async void set_header_bar_to_floating (bool should_float) {
    if (this.setting_header_bar_to_floating) {
      return;
    }

    this.setting_header_bar_to_floating = true;

    if (should_float && this.header_bar_revealer.parent != this.overlay) {
      // ...
      yield this.wait_for_header_bar_animation ();
      this.layout_box.remove (this.header_bar_revealer);
      this.overlay.add_overlay (this.header_bar_revealer);
    }
    else if (!should_float && this.header_bar_revealer.parent != this.layout_box) {
      // ...
      this.overlay.remove_overlay (this.header_bar_revealer);
      this.layout_box.prepend (this.header_bar_revealer);
    }

    this.setting_header_bar_to_floating = false;
  }

  // This method is called right before the window is closed. Use it to store
  // window-related state such as position and size.
  private void on_before_close () {
    var settings = Settings.get_default ();

    settings.was_fullscreened = this.fullscreened;
    settings.was_maximized = this.maximized;

    for (int i = 0; i < this.tab_view.n_pages; i++) {
      var page = this.tab_view.get_nth_page (i);
      (page.get_child () as TerminalTab)?.on_before_close ();
    }
  }

  // This method is called when this window emits a "close_request" event. It
  // dispatches an asynchronous call to verify that the window may be closed
  // (i.e. prompt user to confirm closing tabs with running processes). Before
  // this check is completed, this function returns `true`, which tells GTK not
  // to close the window. If the user confirms closing the window, or if there
  // are no running processes, the dispatched function will fire a new
  // close_request event and this function will finally close the window.
  private bool on_close_request () {
    if (this.force_close) {
      this.on_before_close ();
      return false; // Allow closing
    }

    this.try_closing_window.begin (on_close_request_resolver);

    return true; // Block closing for now
  }

  private static void on_close_request_resolver (GLib.Object? _window, GLib.AsyncResult obj) {
    if (_window != null && _window is Window) {
      var window = _window as Window;
      window.try_closing_window.end (obj);
      if (window.force_close) {
        window.close ();
      }
    }
  }

  private async void try_closing_tab (Adw.TabPage page) {
    var tab = page.child as TerminalTab;
    var terminal = tab?.terminal;
    bool can_close = true;
    string? command = null;

    if (terminal != null) {
      if (!(yield terminal.get_can_close (out command))) {
        can_close = yield confirm_closing ({ command });
      }
    }

    if (can_close) {
      tab?.on_before_close ();
    }

    this.tab_view.close_page_finish (page, can_close);
    if (can_close && terminal == this.active_terminal) {
      this.active_terminal = null;
    }
  }

  private async void try_closing_window () {
    uint n_pages = this.tab_view.n_pages;
    string?[] commands = {};
    bool can_close = true;

    for (uint i = 0; i < n_pages; i++) {
      string? command = null;
      var page = this.tab_view.get_nth_page ((int) i);
      var terminal = (page.get_child () as TerminalTab)?.terminal;

      if (terminal != null && !(yield terminal.get_can_close (out command))) {
        commands += command;
      }
    }

    if (commands.length > 0) {
      can_close = yield confirm_closing (
        commands,
        ConfirmClosingContext.WINDOW
      );
    }

    if (can_close) {
      this.force_close = can_close;
    }
  }

  private void add_actions () {
    this.add_action_entries (ACTION_ENTRIES, this);

    var sa = new SimpleAction ("edit_preferences", null);
    sa.activate.connect (() => {
      if (preferences_window == null) {
        preferences_window = new PreferencesWindow (this, this.application);
      }

      preferences_window.present (this);
    });
    this.add_action (sa);

    sa = new SimpleAction ("paste", null);
    sa.activate.connect (() => {
      this.on_paste_activated ();
    });
    this.add_action (sa);

    this.copy_action = new SimpleAction ("copy", null);
    copy_action.activate.connect (() => {
      this.on_copy_activated ();
    });
    this.copy_action.set_enabled (false);
    this.add_action (this.copy_action);

    sa = new SimpleAction ("switch-headerbar-mode", null);
    sa.activate.connect (() => {
      this.settings.show_headerbar = !this.settings.show_headerbar;
    });
    this.add_action (sa);

    sa = new SimpleAction ("fullscreen", null);
    sa.activate.connect (this.toggle_fullscreen);
    this.add_action (sa);

    sa = new SimpleAction ("search", null);
    sa.activate.connect (this.search);
    this.add_action (sa);

    sa = new SimpleAction ("zoom-in", null);
    sa.activate.connect (this.zoom_in);
    this.add_action (sa);

    sa = new SimpleAction ("zoom-out", null);
    sa.activate.connect (this.zoom_out);
    this.add_action (sa);

    sa = new SimpleAction ("zoom-default", null);
    sa.activate.connect (this.zoom_default);
    this.add_action (sa);

    sa = new SimpleAction ("close-tab", null);
    sa.activate.connect (this.close_active_tab);
    this.add_action (sa);

    for (int i = 1; i < 10; i++) {
      var tab = i;
      sa = new SimpleAction ("switch-tab-%d".printf (tab), null);
      sa.activate.connect (() => {
        this.focus_nth_tab (tab);
      });
      this.add_action (sa);
    }

    sa = new SimpleAction ("switch-tab-last", null);
    sa.activate.connect (() => {
      this.focus_nth_tab (-1);
    });
    this.add_action (sa);

    this.copy_link_action = new SimpleAction ("copy-link", null);
    this.copy_link_action.activate.connect (this.on_copy_link);
    this.copy_link_action.set_enabled (false);

    this.open_link_action = new SimpleAction ("open-link", null);
    this.open_link_action.activate.connect (this.on_open_link);
    this.open_link_action.set_enabled (false);

    this.add_action (this.copy_link_action);
    this.add_action (this.open_link_action);

    this.move_tab_left_action = new SimpleAction ("move-tab-left", null);
    this.move_tab_left_action.activate.connect (this.move_tab_left);
    this.add_action (this.move_tab_left_action);

    this.move_tab_right_action = new SimpleAction ("move-tab-right", null);
    this.move_tab_right_action.activate.connect (this.move_tab_right);
    this.add_action (this.move_tab_right_action);

    this.close_specific_tab_action = new SimpleAction ("close-specific-tab", null);
    this.close_specific_tab_action.activate.connect (this.close_specific_tab);
    this.add_action (this.close_specific_tab_action);

    this.detatch_tab_action = new SimpleAction ("detatch-tab", null);
    this.detatch_tab_action.activate.connect (this.detatch_tab);
    this.add_action (this.detatch_tab_action);

    this.rename_tab_action = new SimpleAction ("rename-tab", null);
    this.rename_tab_action.activate.connect (this.rename_tab);
    this.add_action (this.rename_tab_action);
  }

  private void rename_tab () {
    // If this was a strong ref, the dialog would keep the terminal alive after
    // it exited until the user fired a response. We don't want that. Instead,
    // we just need to check when we get the response if the page still exists.
    weak Adw.TabPage? target =
      this.tab_menu_target ?? this.tab_view.selected_page;

    if (target == null) return;

    var d = new Adw.AlertDialog (_("Rename Tab"),
                                 _("Set a custom title for this tab"));

    var entry = new Gtk.Entry () {
      placeholder_text = _("Enter a custom tab title"),
      text = (target.child as TerminalTab)?.title_override ?? ""
    };

    d.extra_child = entry;

    d.add_response ("cancel", _("Cancel"));
    d.add_response ("reset", _("Reset Title"));
    d.add_response ("override", _("Set Title"));

    d.set_response_appearance ("cancel", Adw.ResponseAppearance.DEFAULT);
    d.set_response_appearance ("reset", Adw.ResponseAppearance.DESTRUCTIVE);
    d.set_response_appearance ("override", Adw.ResponseAppearance.SUGGESTED);

    d.set_response_enabled ("override", entry.text.strip () != "");
    d.set_default_response ("override");
    d.set_close_response ("cancel");

    entry.changed.connect ((_entry) => {
      d.set_response_enabled ("override", _entry.text.strip () != "");
    });

    entry.activate.connect (() => {
      if (d.get_response_enabled ("override")) {
        d.response.emit ("override");
        d.close ();
      }
    });

    d.response.connect ((response) => {
      if (target is Adw.TabPage) {
        if (response == "reset") {
          (target.child as TerminalTab)?.override_title (null);
        }
        else if (response == "override" && entry.text != "") {
          (target.child as TerminalTab)?.override_title (entry.text);
        }
      }

      d.destroy ();
      entry = null;
      target = null;
      d = null;
    });

    d.present (this);
  }

  private void move_tab_left () {
    var target = this.tab_menu_target ?? this.tab_view.selected_page;
    if (target == null) return;

    var pos = this.tab_view.get_page_position (target);
    if (pos == 0) return;
    this.tab_view.reorder_page (target, pos - 1);
  }

  private void move_tab_right () {
    var target = this.tab_menu_target ?? this.tab_view.selected_page;
    if (target == null) return;

    var pos = this.tab_view.get_page_position (target);
    if (pos >= this.tab_view.n_pages - 1) return;
    this.tab_view.reorder_page (target, pos + 1);
  }

  private void close_specific_tab () {
    var target = this.tab_menu_target ?? this.tab_view.selected_page;
    if (target == null) return;

    this.tab_view.close_page (target);
  }

  private void detatch_tab () {
    var target = this.tab_menu_target ?? this.tab_view.selected_page;
    if (target == null) return;

    var w = new Window (this.application, null, null, true);
    this.tab_view.transfer_page (target, w.tab_view, 0);
    w.present ();
  }

  public void search () {
    (this.tab_view.selected_page?.child as TerminalTab)?.search ();
  }

  public void zoom_in () {
    this.active_terminal?.zoom_in ();
  }

  public void zoom_out () {
    this.active_terminal?.zoom_out ();
  }

  public void zoom_default () {
    this.active_terminal?.zoom_default ();
  }

  public void close_active_tab () {
    this.tab_view.close_page (this.tab_view.selected_page);
  }

  private void on_open_link () {
    if (this.link == null) return;

    try {
      GLib.AppInfo.launch_default_for_uri (this.link, null);
    }
    catch (Error e) {
      warning ("Failed to open link %s", e.message);
    }
  }

  private void on_copy_link () {
    if (this.link == null) return;

    Gdk.Display.get_default ().get_clipboard ().set_text (this.link);
  }

  public void on_new_tab () {
    string? cwd = Terminal
      .get_current_working_directory_for_new_session (this.active_terminal);

    this.new_tab (null, cwd);
  }

  public void new_tab (string? command, string? cwd) {
    var tab = new TerminalTab (this, this.tab_view.n_pages + 1, command, cwd);
    var page = this.tab_view.add_page (tab, null);

    tab.terminal.bind_property ("needs-attention",
                                page,
                                "needs-attention",
                                GLib.BindingFlags.SYNC_CREATE,
                                null,
                                null);

    tab.bind_property ("title",
                       page,
                       "title",
                       GLib.BindingFlags.SYNC_CREATE,
                       null,
                       null);

    tab.close_request.connect ((_tab) => {
      var _page = this.tab_view.get_page (_tab);
      if (_page != null) {
        this.tab_view.close_page (_page);
      }
    });

    this.tab_view.set_selected_page (page);
  }

  private void on_paste_activated () {
    (this.tab_view.selected_page?.child as TerminalTab)?.terminal
      .do_paste_clipboard ();
  }

  private void on_copy_activated () {
    (this.tab_view.selected_page?.child as TerminalTab)?.terminal
      .do_copy_clipboard ();
  }

  private void on_tab_selected () {
    if (this.active_terminal_tab != null) {
      foreach (unowned ulong id in this.active_terminal_tab_signal_handlers) {
        this.active_terminal_tab.disconnect (id);
      }
      this.active_terminal_tab_signal_handlers.remove_range (
        0,
        this.active_terminal_tab_signal_handlers.length
      );
    }
    if (this.active_terminal != null) {
      foreach (unowned ulong id in this.active_terminal_signal_handlers) {
        this.active_terminal.disconnect (id);
      }
      this.active_terminal_signal_handlers.remove_range (
        0,
        this.active_terminal_signal_handlers.length
      );
    }
    this.freeze_notify ();
    this.active_terminal_tab = this.tab_view.selected_page?.child as TerminalTab;
    this.active_terminal = this.active_terminal_tab?.terminal;
    this.active_terminal?.grab_focus ();
    this.thaw_notify ();
  }

  private void on_active_terminal_tab_changed () {
    if (this.active_terminal_tab == null) {
      return;
    }

    ulong handler;

    this.on_active_terminal_selection_changed ();
    handler = this.active_terminal
      .selection_changed
      .connect (this.on_active_terminal_selection_changed);

    this.active_terminal_signal_handlers.append_val (handler);

    // FIXME: this should be watching the TerminalTab's `title`
    this.on_active_terminal_title_changed ();
    handler = this.active_terminal_tab
      .notify ["title"]
      .connect (this.on_active_terminal_title_changed);

    this.active_terminal_tab_signal_handlers.append_val (handler);

    this.on_active_terminal_context_changed ();
    handler = this.active_terminal
      .context_changed
      .connect (this.on_active_terminal_tab_changed);
  }

  private void on_active_terminal_context_changed () {
    var context = this.active_terminal?.process?.context;
    var is_context_aware_enabled =
      Settings.get_default ().context_aware_header_bar;

    widget_set_css_class (
      this,
      "context-root",
      context == ProcessContext.ROOT && is_context_aware_enabled
    );

    widget_set_css_class (
      this,
      "context-ssh",
      context == ProcessContext.SSH && is_context_aware_enabled
    );
  }

  private void on_active_terminal_title_changed () {
    this.active_terminal_title = this.tab_view.get_selected_page ().title;
  }

  private void on_active_terminal_selection_changed () {
    bool enabled = false;
    if (this.active_terminal?.get_has_selection ()) {
      enabled = true;
    }
    this.copy_action.set_enabled (enabled);
  }

  private void toggle_fullscreen () {
    if (this.fullscreened) {
      this.unfullscreen ();
    } else {
      this.fullscreen ();
    }
  }

  public Window new_window (
    string? cwd = null,
    bool skip_initial_tab = false
  ) {
    var w = new Window (this.application, null, cwd, skip_initial_tab);
    w.show ();
    return w;
  }

  public void focus_next_tab () {
    if (!this.tab_view.select_next_page ()) {
      this.tab_view.set_selected_page (this.tab_view.get_nth_page (0));
    }
  }

  public void focus_previous_tab () {
    if (!this.tab_view.select_previous_page ()) {
      this.tab_view.set_selected_page (this.tab_view.get_nth_page (this.tab_view.n_pages - 1));
    }
  }

  public void focus_nth_tab (int index) {
    if (this.tab_view.n_pages <= 1) {
      return;
    }
    if (index < 0) {
      // Go to last tab
      this.tab_view.set_selected_page (
        this.tab_view.get_nth_page (this.tab_view.n_pages - 1)
      );
      return;
    }
    if (index > this.tab_view.n_pages) {
      return;
    }
    else {
      this.tab_view.set_selected_page (this.tab_view.get_nth_page (index - 1));
      return;
    }
  }

  public void focus_tab_with_id (uint tab_id) {
    for (int i = 0; i != this.tab_view.get_n_pages (); i++) {
      var page = this.tab_view.get_nth_page (i);
      var tab = page.get_child () as TerminalTab;
      if (tab != null && tab.get_id () == tab_id) {
        this.tab_view.set_selected_page (page);
        this.present ();
        return;
      }
    }
  }
}
