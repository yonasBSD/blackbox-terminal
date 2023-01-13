namespace Terminal.Constants {
  // Copyright (c) 2011-2017 elementary LLC. (https://elementary.io)
  // From: https://github.com/elementary/terminal/blob/c3e36fb2ab64c18028ff2b4a6da5bfb2171c1c04/src/Widgets/TerminalWidget.vala
  const string USERCHARS = "-[:alnum:]";
  const string USERCHARS_CLASS = "[" + USERCHARS + "]";
  const string PASSCHARS_CLASS = "[-[:alnum:]\\Q,?;.:/!%$^*&~\"#'\\E]";
  const string HOSTCHARS_CLASS = "[-[:alnum:]]";
  const string HOST = HOSTCHARS_CLASS + "+(\\." + HOSTCHARS_CLASS + "+)*";
  const string PORT = "(?:\\:[[:digit:]]{1,5})?";
  const string PATHCHARS_CLASS = "[-[:alnum:]\\Q_$.+!*,;:@&=?/~#%\\E]";
  const string PATHTERM_CLASS = "[^\\Q]'.}>) \t\r\n,\"\\E]";
  const string SCHEME =
    "(?:news:|telnet:|nntp:|file:\\/|https?:|ftps?:|sftp:|webcal:" +
    "|irc:|sftp:|ldaps?:|nfs:|smb:|rsync:|ssh:|rlogin:|telnet:|git:" +
    "|git\\+ssh:|bzr:|bzr\\+ssh:|svn:|svn\\+ssh:|hg:|mailto:|magnet:)";

  const string USERPASS = USERCHARS_CLASS + "+(?:" + PASSCHARS_CLASS + "+)?";
  const string URLPATH = "(?:(/" + PATHCHARS_CLASS +
                         "+(?:[(]" + PATHCHARS_CLASS +
                         "*[)])*" + PATHCHARS_CLASS +
                         "*)*" + PATHTERM_CLASS +
                         ")?";

  const string[] URL_REGEX_STRINGS = {
    SCHEME + "//(?:" + USERPASS + "\\@)?" + HOST + PORT + URLPATH,
    "(?:www|ftp)" + HOSTCHARS_CLASS + "*\\." + HOST + PORT + URLPATH,
    "(?:callto:|h323:|sip:)" + USERCHARS_CLASS + "[" + USERCHARS + ".]*(?:"
    + PORT + "/[a-z0-9]+)?\\@" + HOST,
    "(?:mailto:)?" + USERCHARS_CLASS + "[" + USERCHARS + ".]*\\@"
    + HOSTCHARS_CLASS + "+\\." + HOST,
    "(?:news:|man:|info:)[[:alnum:]\\Q^_{|}~!\"#$%&'()*+,./;:=?`\\E]+"
  };

  const string MENU_BUTTON_ALTERNATIVE = _("You can still access the menu by right-clicking any terminal.");

  const string COPYING_NOT_IMPLEMENTED_WARNING_FMT = _("%s uses an early Gtk 4 port of VTE as a terminal widget. While a lot of progress has been made on this port, copying has yet to be implemented. This means there's currently no way to copy text in %s.");

  public string get_user_schemes_dir () {
    return Path.build_path(
      Path.DIR_SEPARATOR_S, Environment.get_user_data_dir (), "blackbox", "schemes"
    );
  }

  public string get_user_keybindings_path () {
    return Path.build_path(
      Path.DIR_SEPARATOR_S, Environment.get_user_data_dir (), "blackbox", "user-keymap.json"
    );
  }

  public string get_app_schemes_dir () {
    return Path.build_path (
      Path.DIR_SEPARATOR_S, DATADIR, "blackbox", "schemes"
    );
  }
}
