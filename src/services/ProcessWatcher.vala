/* ProcessWatcher.vala
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

public enum Terminal.ProcessContext {
  DEFAULT,
  ROOT,
  SSH
}

public class Terminal.Process : Object {
  /**
   * This signal is emitted when the foreground task of a shell finishes.
   */
  public signal void foreground_task_finished ();

  /**
   * This is the file descriptor used by the terminal we're tracking. This must
   * be set during instanciation of this class and may not be modified later.
   */
  public int terminal_fd { get; construct set; }

  /**
   * This is the controlling PID for a terminal session. It will point to the
   * user's shell, in most cases. If the terminal was created with a different
   * command (i.e., `blackbox --command "sleep 300"`), this will point to the
   * spawned process instead.
   */
  public Pid pid { get; set; default = -1; }

  /**
   * This is the PID of the process currently running at the top of the user's
   * shell (e.g., if the user opened a terminal with bash, then opened Neovim
   * with `nvim`, the foreground task for this session, and, consequently, this
   * PID, will point to Neovim).
   */
  public Pid foreground_pid { get; set; default = -1; }

  public string? last_foreground_task_command { get; set; default = null; }

  // TODO: we might want to keep track of background PIDs as well (if that's
  // even possible). That will allow us to alert the user of potential
  // background tasks that would be lost upon closing the tab.

  /***/
  public bool ended { get; set; default = false; }

  public ProcessContext context { get; set; default = ProcessContext.DEFAULT; }
}

namespace Terminal {
  const uint PROCESS_WATCHER_INTERVAL_MS = 500;
}

public class Terminal.ProcessWatcher : Object {

  private static ProcessWatcher? instance = null;
  private Gee.ArrayList<Process> process_list;
  private Gee.ArrayList<Process> pending_process_list;
  private bool watching = false;
  private Thread<void>? loop_thread = null;
  private Mutex mutex = Mutex ();

  private ProcessWatcher () {
    this.process_list = new Gee.ArrayList<Process> ();
    this.pending_process_list = new Gee.ArrayList<Process> ();
  }

  public static ProcessWatcher get_instance () {
    if (instance == null) {
      instance = new ProcessWatcher ();
    }
    return instance;
  }

  public bool watch (Process process) {
    lock (this.pending_process_list) {
      this.pending_process_list.add (process);
    }

    if (!this.watching) {
      this.start_watching ();
    }

    return true;
  }

  private void start_watching () {
    this.watching = true;
    this.loop_thread = new Thread<void> ("process-watcher", this.t_watch_loop);
    //  Timeout.add (PROCESS_WATCHER_INTERVAL_MS, this.watch_loop);
  }

  //  private void stop_watching () {
  //    this.mutex.@lock ();
  //    this.loop_thread.join ();
  //    this.watching = false;
  //    this.loop_thread = null;
  //    this.mutex.@unlock ();
  //  }

  // This is the watch function that runs in an infinite loop and checks for
  // process updates periodically. This function should be executed in a
  // separate thread.
  private void t_watch_loop () {
    // TODO: exit loop when there are no more processes on the list. This will
    // happen if:
    //
    // - We support having Black Box's main window open without any tabs
    // - The last tab in a window is closed but a preferences window remais
    //   open (in which case the app doesn't close)
    while (true) {
      this.mutex.@lock ();

      lock (this.pending_process_list) {
        if (this.pending_process_list.size > 0) {
          foreach (var process in this.pending_process_list) {
            if (!this.process_list.contains (process)) {
              this.process_list.add (process);
            }
          }
          this.pending_process_list.clear ();
        }
      }

      debug ("Watching %d processes", this.process_list.size);

      if (this.requires_process_watching ()) {
        foreach (var process in this.process_list) {
          this.check_process (process);
        }
      }
      else {
        foreach (var process in this.process_list) {
          process.context = ProcessContext.DEFAULT;
        }
      }
      
      for (int i = 0; i < this.process_list.size;) {
        if (this.process_list.get (i).ended) {
          this.process_list.remove_at (i);
        }
        else {
          i++;
        }
      }

      bool ret = this.process_list.size > 0;
      this.watching = ret;
      this.mutex.@unlock ();

      if (!ret) {
        break;
      }

      Thread.usleep (1000 * PROCESS_WATCHER_INTERVAL_MS);
    }
  }

  private bool requires_process_watching () {
    return Settings.get_default ().context_aware_header_bar
      && Settings.get_default ().show_headerbar;
  }

  private bool is_process_still_running (Pid pid) {
    try {
      return check_pid_running(pid);
    }
    catch (Error e) {
      warning ("%s", e.message);
    }
    return false;
  }

  private void check_process (Process process) {
    try {
      // TODO: check if we previously had a foreground process running. If so,
      // check that it still is and fire and event if not.

      {
        if (
          process.foreground_pid >= 0 &&
          !is_process_still_running (process.foreground_pid)
        ) {
          process.foreground_task_finished ();
          process.foreground_pid = -1;
        }
      }

      {
        get_foreground_process.begin (process.terminal_fd, null, (_, res) => {
          int foreground_pid = get_foreground_process.end (res);

          if (
            foreground_pid >= 0 &&
            foreground_pid != process.pid &&
            foreground_pid != process.foreground_pid
          ) {
            var cmdline = get_process_cmdline (foreground_pid);

            if (cmdline == null || cmdline == "") {
              // Why does this happen?
              debug ("Skipping process with empty cmdline");
              return;
            }

            process.foreground_pid = foreground_pid;
            process.last_foreground_task_command = cmdline;
          }
        });
      }

      // TODO: check that the main pid is still running
      {
        process.ended = !check_pid_running (process.pid);
        // Should we emit an event for process finished?
      }

      {
        if (!process.ended) {
          try {
            var source_pid = process.foreground_pid > -1
              ? process.foreground_pid
              : process.pid;

            var euid = get_euid_from_pid (source_pid, null);

            if (euid == 0) {
              process.context = ProcessContext.ROOT;
            }
            else {
              var command = get_process_cmdline (source_pid);

              if (command != null && command.has_prefix ("ssh")) {
                process.context = ProcessContext.SSH;
              }
              else {
                process.context = ProcessContext.DEFAULT;
              }
            }
          }
          catch (GLib.Error e) {
            warning (e.message);
          }
        }
      }
    }
    catch (GLib.Error e) {
      warning ("%s", e.message);
    }
  }
}
