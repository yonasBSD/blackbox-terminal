/* Terminal.vala
 *
 * Copyright 2020-2022 Paulo Queiroz <pvaqueiroz@gmail.com>
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

public class Terminal.Terminal : Vte.Terminal {

  /**
   * List of available drop targets for Terminal
   */
  private enum DropTargets {
    URILIST,
    STRING,
    TEXT,
  }

  static string[] blackbox_envv = {
    "TERM=xterm-256color",
    "COLORTERM=truecolor",
    "TERM_PROGRAM=%s".printf (APP_NAME),
    "BLACKBOX_THEMES_DIR=%s".printf (Constants.get_user_schemes_dir ()),
    "VTE_VERSION=%u".printf (
      Vte.MAJOR_VERSION * 10000 + Vte.MINOR_VERSION * 100 + Vte.MICRO_VERSION
    )
  };

  // Signals

  /**
   * This signal is emitted when the terminal process exits. Something should
   * listen for this signal and close the tab that contains this terminal.
   */
  public signal void exit ();

  public signal void spawn_failed (string? error_message);

  public signal void context_changed (ProcessContext context);

  // Properties

  public Scheme           scheme  { get; set; }
  public Pid              pid     { get; protected set; default = -1; }
  public Process?         process { get; protected set; default = null; }

  public uint user_scrollback_lines {
    get {
      var settings = Settings.get_default ();

      switch (settings.scrollback_mode) {
        case ScrollbackMode.FIXED:     return settings.scrollback_lines;
        case ScrollbackMode.UNLIMITED: return -1;
        case ScrollbackMode.DISABLED:  return 0;
        default:
          error ("Invalid scrollback-mode %u", settings.scrollback_mode);
      }
    }
  }

  // Fields

  public  Window            window;
  private uint              original_scrollback_lines;
  private GLib.Cancellable? fp_spawn_host_command_callback_cancellable = null;

  // FIXME: either get rid of this field, or stop creating a local copy of
  // settings every time we need to use it
  private Settings settings;

  public Terminal (Window window, string? command = null, string? cwd = null) {
    Object (
      allow_hyperlink: true,
      receives_default: true,
      scroll_unit_is_pixels: true
    );

    this.original_scrollback_lines = this.scrollback_lines;

    this.window = window;

    this.hexpand = true;
    this.vexpand = true;
    this.halign = Gtk.Align.FILL;
    this.valign = Gtk.Align.FILL;

    this.child_exited.connect (this.on_child_exited);

    this.settings = Settings.get_default ();
    ThemeProvider.get_default ().notify ["current-theme"].connect (this.on_theme_changed);
    this.settings.notify["font"].connect (this.on_font_changed);
    this.settings.notify["terminal-padding"].connect (this.on_padding_changed);
    this.settings.notify["opacity"].connect (this.on_theme_changed);

    this.setup_drag_drop ();
    this.setup_regexes ();
    this.connect_signals ();
    this.bind_data ();
    this.on_theme_changed ();
    this.on_font_changed ();
    this.on_padding_changed ();

    try {
      this.spawn (command, cwd);
    }
    catch (Error e) {
      warning ("%s", e.message);
    }
  }

#if BLACKBOX_DEBUG_MEMORY
  ~Terminal () {
    message ("Terminal destroyed");
  }
#endif

  public override void dispose() {
#if BLACKBOX_DEBUG_MEMORY
    message ("Terminal dispose");
#endif
    this.fp_spawn_host_command_callback_cancellable?.cancel ();
    base.dispose ();
  }

  // Methods ===================================================================

  private void setup_drag_drop () {
    var target = new Gtk.DropTarget (Type.INVALID, Gdk.DragAction.COPY);

    target.set_gtypes ({
      typeof (Gdk.FileList),
      typeof (GLib.File),
      typeof (string),
    });

    target.on_drop.connect (this.on_drag_data_received);

    this.add_controller (target);
  }

  private bool on_drag_data_received (
    Gtk.DropTarget target,
    Value value,
    double x,
    double y
  ) {
    var vtype = value.type ();

    if (vtype == typeof (Gdk.FileList)) {
      var list = (Gdk.FileList) value.get_boxed ();

      foreach (unowned GLib.File file in list.get_files ()) {
        this.feed_child (Shell.quote (file.get_path ()).data);
        this.feed_child (" ".data);
      }

      return true;
    }
    else if (vtype == typeof (GLib.File)) {
      var file = (GLib.File) value.get_object ();
      var path = file?.get_path ();

      if (path != null) {
        this.feed_child (Shell.quote (path).data);
        this.feed_child (" ".data);
      }

      return true;
    }
    else if (vtype == typeof (string)) {
      var text = value.get_string ();

      if (text != null) {
        this.feed_child (text.data);
      }

      return true;
    }

    warning ("You dropped something Terminal can't handle yet :(");
    return false;
  }

  private void setup_regexes () {
    foreach (unowned string str in Constants.URL_REGEX_STRINGS) {
      try {
        var reg = new Vte.Regex.for_match (
          str, -1, PCRE2.Flags.MULTILINE
        );
        int id = this.match_add_regex (reg, 0);
        this.match_set_cursor_name (id, "pointer");
      }
      catch (Error e) {
        warning (e.message);
      }
    }
  }

  private void on_font_changed () {
    this.font_desc = Pango.FontDescription.from_string (
      this.settings.font
    );
  }

  private Gdk.RGBA get_background_color(Scheme theme) {
    var bg_transparent = theme.background_color.copy();
    bg_transparent.alpha = this.settings.opacity * 0.01f;
    return bg_transparent;
  }

  private void on_theme_changed () {
    var theme_provider = ThemeProvider.get_default ();
    var theme_name = theme_provider.current_theme;
    var theme = theme_provider.themes.get (theme_name);

    if (theme == null) {
      warning ("INVALID THEME '%s'", theme_name);
      return;
    }

    var bg = this.get_background_color (theme);
    this.set_colors (
      theme.foreground_color,
      bg,
      theme.palette.data
    );
  }

  private Gtk.CssProvider? padding_provider = null;
  private void on_padding_changed () {
    var pad = this.settings.get_padding ();

    if (this.padding_provider != null) {
      this.get_style_context ().remove_provider (this.padding_provider);
      this.padding_provider = null;
    }

    this.padding_provider = PQMarble.get_css_provider_for_data(
      "vte-terminal { padding: %upx %upx %upx %upx; }".printf(
        pad.top,
        pad.right,
        pad.bottom,
        pad.left
      )
    );

    this.get_style_context ().add_provider (
      this.padding_provider,
      Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    );
  }

  private void bind_data () {
    this.settings.schema.bind (
      "theme-bold-is-bright",
      this,
      "bold-is-bright",
      SettingsBindFlags.DEFAULT
    );

    this.settings.schema.bind (
      "terminal-bell",
      this,
      "audible-bell",
      SettingsBindFlags.DEFAULT
    );

    this.settings.schema.bind (
      "terminal-cell-width",
      this,
      "cell-width-scale",
      SettingsBindFlags.DEFAULT
    );

    this.settings.schema.bind (
      "terminal-cell-height",
      this,
      "cell-height-scale",
      SettingsBindFlags.DEFAULT
    );

    this.settings.bind_property (
      "cursor-shape",
      this,
      "cursor-shape",
      BindingFlags.SYNC_CREATE,
      null,
      null
    );

    this.settings.bind_property (
      "cursor-blink-mode",
      this,
      "cursor-blink-mode",
      BindingFlags.SYNC_CREATE,
      null,
      null
    );

    this.bind_property (
      "user-scrollback-lines",
      this,
      "scrollback-lines",
      BindingFlags.SYNC_CREATE,
      null,
      null
    );

    // Fallback scrolling makes it so that VTE handles scrolling on its own. We
    // want VTE to let GtkScrolledWindow take care of scrolling if the user
    // enabled "show scrollbars". Thus we set
    // `enable-fallback-scrolling = !show-scrollbars`
    //
    // See:
    // - https://gitlab.gnome.org/raggesilver/blackbox/-/issues/179
    // - https://gitlab.gnome.org/GNOME/vte/-/issues/336
    this.settings.bind_property (
      "show-scrollbars",
      this,
      "enable-fallback-scrolling",
      BindingFlags.SYNC_CREATE | BindingFlags.INVERT_BOOLEAN,
      null,
      null
    );
  }

  private void connect_signals () {
    var kpcontroller = new Gtk.EventControllerKey ();
    kpcontroller.key_pressed.connect (this.on_key_pressed);
    this.add_controller (kpcontroller);

    var left_click_controller = new Gtk.GestureClick () {
      button = Gdk.BUTTON_PRIMARY,
    };
    left_click_controller.pressed.connect ((gesture, n_clicked, x, y) => {
      var event = gesture.get_current_event ();
      var pattern = this.check_match_at (x, y, null);

      if (
        (event.get_modifier_state () & Gdk.ModifierType.CONTROL_MASK) == 0 ||
        pattern == null
      ) {
        return;
      }


      new Gtk.UriLauncher (pattern).launch.begin (this.window, null);
    });
    this.add_controller (left_click_controller);

    this.settings.notify ["scrollback-lines"]
      .connect (() => {
        this.notify_property ("user-scrollback-lines");
      });

    this.settings.notify ["scrollback-mode"]
      .connect (() => {
        this.notify_property ("user-scrollback-lines");
      });
  }

  private void spawn (string? command, string? cwd) throws Error {
    Array<string> argv = new Array<string> ();
    Array<string> envv = new Array<string> ();
    Vte.PtyFlags flags = Vte.PtyFlags.DEFAULT;

    var settings = Settings.get_default ();
    string[]? custom_shell_commandv = null;

    string shell;

    if (
      settings.use_custom_command &&
      settings.custom_shell_command != ""
    ) {
      Shell.parse_argv (settings.custom_shell_command, out custom_shell_commandv);
    }

    // Spawning works differently on host vs flatpak
#if BLACKBOX_IS_FLATPAK
    shell = fp_guess_shell () ?? "/usr/bin/bash";

    flags = Vte.PtyFlags.NO_CTTY;

    var tmp_envv = fp_get_env (null) ?? Environ.get ();

    foreach (string env in tmp_envv) {
      envv.append_val (env);
    }

    foreach (string env in Terminal.blackbox_envv) {
      envv.append_val (env);
    }
#else /* BLACKBOX_IS_FLATPAK */
    var tmp_envv = Environ.get ();

    foreach (string env in tmp_envv) {
      envv.append_val (env);
    }

    foreach (unowned string env in Terminal.blackbox_envv) {
      envv.append_val (env);
    }

    shell = Environ.get_variable (envv.data, "SHELL");
#endif /* BLACKBOX_IS_FLATPAK */

    if (custom_shell_commandv != null) {
      foreach (unowned string s in custom_shell_commandv) {
        argv.append_val (s);
      }
    }
    else {
      argv.append_val (shell);
      if (settings.command_as_login_shell && command == null) {
        argv.append_val ("--login");
      }
    }
    if (command != null) {
      argv.append_val ("-c");
      argv.append_val (command);
    }

#if BLACKBOX_IS_FLATPAK
    this.spawn_on_flatpak.begin (flags, cwd, argv, envv, (o, _) => {
      try {
        Pid ppid;
        var res = this.spawn_on_flatpak.end (_, out ppid);
        this.pid = ppid;

        if (!res) {
          // FIXME: translate this
          this.spawn_failed ("An unexpected error occurred while spawning a new terminal.");
        }
        else {
          this.on_spawn_finished ();
        }
      }
      catch (GLib.Error e) {
        this.pid = -1;
        this.spawn_failed (e.message);
      }
    });
#else /* BLACKBOX_IS_FLATPAK */
    this.spawn_async (
      flags,
      cwd,
      argv.data,
      envv.data,
      0,
      null,
      -1,
      null,
      this._on_spawn_finished
    );
#endif /* BLACKBOX_IS_FLATPAK */
  }

#if !BLACKBOX_IS_FLATPAK
  private void _on_spawn_finished (Vte.Terminal t, Pid pid, GLib.Error? error) {
    if (error == null) {
      this.pid = pid;
      this.on_spawn_finished ();
    }
    else {
      this.spawn_failed (error.message);
    }
  }
#endif

  private void on_spawn_finished () {
    if (_pid < 0) {
      return;
    }

    this.process = new Process () {
      terminal_fd = this.pty.get_fd (),
      pid = this.pid,
      foreground_pid = -1,
    };

    this.process.foreground_task_finished.connect ((_process) => {
      var desktop_notifications_enabled =
        Settings.get_default ().notify_process_completion;

      if (
        desktop_notifications_enabled &&
        !this.has_focus &&
        _process.last_foreground_task_command != null
      ) {
        var n = new GLib.Notification (_("Command completed"));
        n.set_body (_process.last_foreground_task_command);

        // TODO: improve this notification system so that when a user clicks
        // the notification, Black Box focuses the right terminal window and
        // automatically focusses the tab that just completed.
        //
        // https://valadoc.org/gio-2.0/GLib.Notification.set_default_action.html
        // https://valadoc.org/gio-2.0/GLib.Action.parse_detailed_name.html

        this.window.application.send_notification (null, n);

        // GNOME seems to be showing the same notification twice. I am sure we
        // are not calling this twice. This may be an upstream bug.
        GLib.Application.get_default ().send_notification (null, n);
      }
    });

    this.process.notify ["context"].connect ((__process, spec) => {
      var context = (_process as Process)?.context ?? ProcessContext.DEFAULT;

      this.context_changed.emit (context);
      //  string context_str =
      //    context == ProcessContext.SSH
      //      ? "ssh"
      //      : context == ProcessContext.ROOT
      //        ? "root"
      //        : "default";
      //  message ("New context for process: %s", context_str);
    });

    ProcessWatcher.get_instance ().watch (this.process);

    this.context_changed.emit (this.process.context);
  }

  private async bool spawn_on_flatpak (Vte.PtyFlags flags,
                                       string? cwd,
                                       Array<string> argv,
                                       Array<string> envv,
                                       out Pid p) throws GLib.Error
  {
    p = -1;
    Vte.Pty _ppty;

    try {
      _ppty = new Vte.Pty.sync (flags, null);
    }
    catch (GLib.Error e) {
      warning ("%s", e.message);
      return false;
    }

    int pty_master = _ppty.get_fd ();

    if (Posix.grantpt (pty_master) != 0) {
      warning ("Failed granting access to slave pseudoterminal device");
      return false;
    }

    if (Posix.unlockpt (pty_master) != 0) {
      warning ("Failed unlocking slave pseudoterminal device");
      return false;
    }

    int[] pty_slaves = {};

    pty_slaves += Posix.open (Posix.ptsname (pty_master), Posix.O_RDWR | Posix.O_CLOEXEC);

    if (pty_slaves [0] < 0) {
      warning ("Failed opening slave pseudoterminal device");
      return false;
    }

    pty_slaves += Posix.dup (pty_slaves [0]);
    pty_slaves += Posix.dup (pty_slaves [0]);

    this.fp_spawn_host_command_callback_cancellable = new GLib.Cancellable ();

    var res = yield send_host_command (
      cwd,
      argv,
      envv,
      pty_slaves,
      this.on_host_command_exited,
      this.fp_spawn_host_command_callback_cancellable,
      out p
    );

    this.pty = _ppty;

    return res;
  }

  void on_host_command_exited (uint _pid, uint status) {
    this.child_exited ((int) status);
  }

  // Signal callbacks ==========================================================

  private void on_child_exited (int status) {
    debug ("Child exited with code %d", status);
    this.pid = -1;
    //  This is not a good idea. Another thread might be modifying this field
    //  as well.
    //  this.process.ended = true;
    this.process = null;
    this.exit ();
  }

  private bool on_key_pressed (
    uint keyval,
    uint keycode,
    Gdk.ModifierType state
  ) {
    if ((state & Gdk.ModifierType.CONTROL_MASK) == 0) {
      return false;
    }

    switch (Gdk.keyval_name (keyval)) {
      case "c": {
        if (
          this.get_has_selection () &&
          Settings.get_default ().easy_copy_paste
        ) {
          this.do_copy_clipboard ();
          this.unselect_all ();
          return true;
        }
        return false;
      }
      case "v": {
        if (Settings.get_default ().easy_copy_paste) {
          this.do_paste_clipboard ();
          return true;
        }
        return false;
      }
    }

    return false;
  }

  public async bool get_can_close (out string command = null) {
    command = null;

    if (this.pid < 0 || this.pty == null) {
      return true;
    }

    var fd = this.pty.fd;
    if (fd == -1) {
      return true;
    }

    // Get terminal's foreground process
    var fgpid = yield get_foreground_process (fd);
    if (fgpid == -1) {
      return false;
    }

    if (fgpid == this.pid) {
      return true;
    }

    command = get_process_cmdline (fgpid);

    return command == null;
  }

  public void zoom_in () {
    this.font_scale = double.min (10, this.font_scale + 0.1);
  }

  public void zoom_out () {
    this.font_scale = double.max (0.1, this.font_scale - 0.1);
  }

  public void zoom_default () {
    this.font_scale = 1.0;
  }

  public void do_paste_clipboard () {
    this.paste_clipboard ();
  }

  public void do_copy_clipboard () {
    this.copy_clipboard ();
  }

  public async void do_paste_from_selection_clipboard () {
    //  This function does not seem to be working in GTK 4 yet.
    //  this.paste_primary ();

    var clipboard = Gdk.Display.get_default ().get_primary_clipboard ();
    try {
      var text = yield clipboard.read_text_async (null);
      this.paste_text (text);
    }
    catch (Error e) {
      warning ("%s", e.message);
    }
  }

  public string? get_current_working_directory () {
    string? cwd = this.get_current_directory_uri ();

    if (cwd != null) {
      try {
        string path = GLib.Filename.from_uri (cwd, null);
        cwd = path;
      }
      catch (GLib.ConvertError e) {
        warning ("%s", e.message);
        cwd = null;
      }
    }

    return cwd;
  }

  public static string? get_current_working_directory_for_new_session (
    Terminal? previous_terminal = null
  ) {
    var settings = Settings.get_default ();
    var mode = settings.working_directory_mode;
    var custom_working_directory = settings.custom_working_directory;

    switch (mode) {
      case WorkingDirectoryMode.CUSTOM:
        return custom_working_directory;
      case WorkingDirectoryMode.HOME_DIRECTORY:
        return GLib.Environment.get_home_dir ();
      case WorkingDirectoryMode.PREVIOUS_SESSION: {
        if (previous_terminal != null) {
          return previous_terminal.get_current_working_directory ();
        }
        break;
      }
    }

    return null;
  }
}
