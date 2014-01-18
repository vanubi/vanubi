/* gspawn.c - Process launching
 *
 *  Copyright 2000-2014 Red Hat, Inc.
 *  g_execvpe implementation based on GNU libc execvp:
 *   Copyright 1991, 92, 95, 96, 97, 98, 99 Free Software Foundation, Inc.
 *
 * GLib is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * GLib is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with GLib; see the file COPYING.LIB.  If not, write
 * to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

/* Real async version of g_spawn_async_with_pipes.
 * The function has been renamed with a vanubi_ prefix to avoid conflict.
 * See bug: https://bugzilla.gnome.org/show_bug.cgi?id=722401 
 */
 
#include "config.h"

#include <sys/time.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <string.h>
#include <stdlib.h>   /* for fdwalk */
#include <dirent.h>

#ifdef HAVE_SYS_SELECT_H
#include <sys/select.h>
#endif /* HAVE_SYS_SELECT_H */

#ifdef HAVE_SYS_RESOURCE_H
#include <sys/resource.h>
#endif /* HAVE_SYS_RESOURCE_H */

#include <glib.h>
#include <glib-object.h>
#include <gio/gio.h>
#include <gio/gunixinputstream.h>
#include <stdlib.h>
#include <string.h>

/**
 * SECTION:spawn
 * @Short_description: process launching
 * @Title: Spawning Processes
 */

typedef struct {
	// Vanubi specific
	int _state_;
	GObject* _source_object_;
	GAsyncResult* _res_;
	GSimpleAsyncResult* _async_result;
	GDataInputStream* read_stream;
	gint io_priority;
	GCancellable* cancellable;

	// Parameters to fork_exec_with_pipes
	gboolean              intermediate_child;
	const gchar          *working_directory;
	gchar               **argv;
	gchar               **envp;
	gboolean              close_descriptors;
	gboolean              search_path;
	gboolean              search_path_from_envp;
	gboolean              stdout_to_null;
	gboolean              stderr_to_null;
	gboolean              child_inherits_stdin;
	gboolean              file_and_argv_zero;
	gboolean              cloexec_pipes;
	GSpawnChildSetupFunc  child_setup;
	gpointer              user_data;
	GPid                 child_pid;
	gint                 standard_input;
	gint                 standard_output;
	gint                 standard_error;
	
	// Temporary variables of fork_exec_with_pipes
	GPid pid;
	gint stdin_pipe[2];
	gint stdout_pipe[2];
	gint stderr_pipe[2];
	gint child_err_report_pipe[2];
	gint child_pid_report_pipe[2];
	guint pipe_flags;
	gint status;
} VanubiSpawnAsyncWithPipesData;


static gint g_execute (const gchar  *file,
                       gchar **argv,
                       gchar **envp,
                       gboolean search_path,
                       gboolean search_path_from_envp);

static gboolean fork_exec_with_pipes (VanubiSpawnAsyncWithPipesData* _data_);


static void vanubi_spawn_async_with_pipes_data_free (gpointer _data) {
	VanubiSpawnAsyncWithPipesData* _data_;
	_data_ = _data;
	g_slice_free (VanubiSpawnAsyncWithPipesData, _data_);
}

/* Avoids a danger in threaded situations (calling close()
 * on a file descriptor twice, and another thread has
 * re-opened it since the first close)
 */
static void
close_and_invalidate (gint *fd)
{
  if (*fd < 0)
    return;
  else
    {
      (void) g_close (*fd, NULL);
      *fd = -1;
    }
}

/* Some versions of OS X define READ_OK in public headers */
#undef READ_OK

typedef enum
{
  READ_FAILED = 0, /* FALSE */
  READ_OK,
  READ_EOF
} ReadResult;

static ReadResult
read_data (GString *str,
           gint     fd,
           GError **error)
{
  gssize bytes;
  gchar buf[4096];

 again:
  bytes = read (fd, buf, 4096);

  if (bytes == 0)
    return READ_EOF;
  else if (bytes > 0)
    {
      g_string_append_len (str, buf, bytes);
      return READ_OK;
    }
  else if (errno == EINTR)
    goto again;
  else
    {
      int errsv = errno;

      g_set_error (error,
                   G_SPAWN_ERROR,
                   G_SPAWN_ERROR_READ,
                   ("Failed to read data from child process (%s)"),
                   g_strerror (errsv));

      return READ_FAILED;
    }
}

static void
vanubi_spawn_async_with_pipes_ready (GObject* source_object, GAsyncResult* _res_, gpointer _user_data_) {
	VanubiSpawnAsyncWithPipesData* _data_;
	_data_ = _user_data_;
	_data_->_source_object_ = source_object;
	_data_->_res_ = _res_;
	fork_exec_with_pipes (_data_);
}

void
vanubi_spawn_async_with_pipes (const gchar          *working_directory,
							   gchar               **argv,
							   gchar               **envp,
							   GSpawnFlags           flags,
							   GSpawnChildSetupFunc  child_setup,
							   gpointer              user_data,
							   int io_priority,
							   GCancellable* cancellable,
							   GAsyncReadyCallback _callback_, gpointer _user_data_) {
	g_return_val_if_fail (argv != NULL, FALSE);
  
	VanubiSpawnAsyncWithPipesData* _data_;
	_data_ = g_slice_new0 (VanubiSpawnAsyncWithPipesData);
	_data_->_async_result = g_simple_async_result_new (NULL, _callback_, _user_data_, vanubi_spawn_async_with_pipes);
	g_simple_async_result_set_op_res_gpointer (_data_->_async_result, _data_, vanubi_spawn_async_with_pipes_data_free);
	
	_data_->pid = -1;
	_data_->stdin_pipe[0] = _data_->stdin_pipe[1] = _data_->stdout_pipe[0] = _data_->stdout_pipe[1] = _data_->stderr_pipe[0] = _data_->stderr_pipe[1] = _data_->child_err_report_pipe[0] = _data_->child_err_report_pipe[1] = _data_->child_pid_report_pipe[0] = _data_->child_pid_report_pipe[1] = -1;
	_data_->intermediate_child = !(flags & G_SPAWN_DO_NOT_REAP_CHILD);
	_data_->working_directory = working_directory;
	_data_->argv = argv;
	_data_->envp = envp;
	_data_->close_descriptors = !(flags & G_SPAWN_LEAVE_DESCRIPTORS_OPEN);
	_data_->search_path = (flags & G_SPAWN_SEARCH_PATH);
	_data_->search_path_from_envp = (flags & G_SPAWN_SEARCH_PATH_FROM_ENVP) != 0;
	_data_->stdout_to_null = (flags & G_SPAWN_STDOUT_TO_DEV_NULL) != 0;
	_data_->stderr_to_null = (flags & G_SPAWN_STDERR_TO_DEV_NULL) != 0;
	_data_->child_inherits_stdin = (flags & G_SPAWN_CHILD_INHERITS_STDIN) != 0;
	_data_->file_and_argv_zero = (flags & G_SPAWN_FILE_AND_ARGV_ZERO) != 0;
	_data_->cloexec_pipes = FALSE; // (flags & G_SPAWN_CLOEXEC_PIPES) != 0;
	_data_->child_setup = child_setup;
	_data_->user_data = user_data;
	_data_->io_priority = io_priority;
	_data_->cancellable = cancellable;
	
	fork_exec_with_pipes (_data_);
}

gboolean vanubi_spawn_async_with_pipes_finish (GAsyncResult* _res_,
										   GPid                 *child_pid,
										   gint                 *standard_input,
										   gint                 *standard_output,
										   gint                 *standard_error,
										   GError** error) {
	VanubiSpawnAsyncWithPipesData* _data_;
	if (g_simple_async_result_propagate_error (G_SIMPLE_ASYNC_RESULT (_res_), error)) {
		return FALSE;
	}
	_data_ = g_simple_async_result_get_op_res_gpointer (G_SIMPLE_ASYNC_RESULT (_res_));
	if (child_pid != NULL)
		*child_pid = _data_->child_pid;
	if (standard_input != NULL)
		*standard_input = _data_->standard_input;
	if (standard_output != NULL)
		*standard_output = _data_->standard_output;
	if (standard_error != NULL)
		*standard_error = _data_->standard_error;
		
	return TRUE;
}

static gint
exec_err_to_g_error (gint en)
{
  switch (en)
    {
#ifdef EACCES
    case EACCES:
      return G_SPAWN_ERROR_ACCES;
      break;
#endif

#ifdef EPERM
    case EPERM:
      return G_SPAWN_ERROR_PERM;
      break;
#endif

#ifdef E2BIG
    case E2BIG:
      return G_SPAWN_ERROR_TOO_BIG;
      break;
#endif

#ifdef ENOEXEC
    case ENOEXEC:
      return G_SPAWN_ERROR_NOEXEC;
      break;
#endif

#ifdef ENAMETOOLONG
    case ENAMETOOLONG:
      return G_SPAWN_ERROR_NAMETOOLONG;
      break;
#endif

#ifdef ENOENT
    case ENOENT:
      return G_SPAWN_ERROR_NOENT;
      break;
#endif

#ifdef ENOMEM
    case ENOMEM:
      return G_SPAWN_ERROR_NOMEM;
      break;
#endif

#ifdef ENOTDIR
    case ENOTDIR:
      return G_SPAWN_ERROR_NOTDIR;
      break;
#endif

#ifdef ELOOP
    case ELOOP:
      return G_SPAWN_ERROR_LOOP;
      break;
#endif
      
#ifdef ETXTBUSY
    case ETXTBUSY:
      return G_SPAWN_ERROR_TXTBUSY;
      break;
#endif

#ifdef EIO
    case EIO:
      return G_SPAWN_ERROR_IO;
      break;
#endif

#ifdef ENFILE
    case ENFILE:
      return G_SPAWN_ERROR_NFILE;
      break;
#endif

#ifdef EMFILE
    case EMFILE:
      return G_SPAWN_ERROR_MFILE;
      break;
#endif

#ifdef EINVAL
    case EINVAL:
      return G_SPAWN_ERROR_INVAL;
      break;
#endif

#ifdef EISDIR
    case EISDIR:
      return G_SPAWN_ERROR_ISDIR;
      break;
#endif

#ifdef ELIBBAD
    case ELIBBAD:
      return G_SPAWN_ERROR_LIBBAD;
      break;
#endif
      
    default:
      return G_SPAWN_ERROR_FAILED;
      break;
    }
}

static gssize
write_all (gint fd, gconstpointer vbuf, gsize to_write)
{
  gchar *buf = (gchar *) vbuf;
  
  while (to_write > 0)
    {
      gssize count = write (fd, buf, to_write);
      if (count < 0)
        {
          if (errno != EINTR)
            return FALSE;
        }
      else
        {
          to_write -= count;
          buf += count;
        }
    }
  
  return TRUE;
}

G_GNUC_NORETURN
static void
write_err_and_exit (gint fd, gint msg)
{
  gint en = errno;
  
  write_all (fd, &msg, sizeof(msg));
  write_all (fd, &en, sizeof(en));
  
  _exit (1);
}

static int
set_cloexec (void *data, gint fd)
{
  if (fd >= GPOINTER_TO_INT (data))
    fcntl (fd, F_SETFD, FD_CLOEXEC);

  return 0;
}

#ifndef HAVE_FDWALK
static int
fdwalk (int (*cb)(void *data, int fd), void *data)
{
  gint open_max;
  gint fd;
  gint res = 0;
  
#ifdef HAVE_SYS_RESOURCE_H
  struct rlimit rl;
#endif

#ifdef __linux__  
  DIR *d;

  if ((d = opendir("/proc/self/fd"))) {
      struct dirent *de;

      while ((de = readdir(d))) {
          glong l;
          gchar *e = NULL;

          if (de->d_name[0] == '.')
              continue;
            
          errno = 0;
          l = strtol(de->d_name, &e, 10);
          if (errno != 0 || !e || *e)
              continue;

          fd = (gint) l;

          if ((glong) fd != l)
              continue;

          if (fd == dirfd(d))
              continue;

          if ((res = cb (data, fd)) != 0)
              break;
        }
      
      closedir(d);
      return res;
  }

  /* If /proc is not mounted or not accessible we fall back to the old
   * rlimit trick */

#endif
  
#ifdef HAVE_SYS_RESOURCE_H
      
  if (getrlimit(RLIMIT_NOFILE, &rl) == 0 && rl.rlim_max != RLIM_INFINITY)
      open_max = rl.rlim_max;
  else
#endif
      open_max = sysconf (_SC_OPEN_MAX);

  for (fd = 0; fd < open_max; fd++)
      if ((res = cb (data, fd)) != 0)
          break;

  return res;
}
#endif

static gint
sane_dup2 (gint fd1, gint fd2)
{
  gint ret;

 retry:
  ret = dup2 (fd1, fd2);
  if (ret < 0 && errno == EINTR)
    goto retry;

  return ret;
}

static gint
sane_open (const char *path, gint mode)
{
  gint ret;

 retry:
  ret = open (path, mode);
  if (ret < 0 && errno == EINTR)
    goto retry;

  return ret;
}

enum
{
  CHILD_CHDIR_FAILED,
  CHILD_EXEC_FAILED,
  CHILD_DUP2_FAILED,
  CHILD_FORK_FAILED
};

static void
do_exec (gint                  child_err_report_fd,
         gint                  stdin_fd,
         gint                  stdout_fd,
         gint                  stderr_fd,
         const gchar          *working_directory,
         gchar               **argv,
         gchar               **envp,
         gboolean              close_descriptors,
         gboolean              search_path,
         gboolean              search_path_from_envp,
         gboolean              stdout_to_null,
         gboolean              stderr_to_null,
         gboolean              child_inherits_stdin,
         gboolean              file_and_argv_zero,
         GSpawnChildSetupFunc  child_setup,
         gpointer              user_data)
{
  if (working_directory && chdir (working_directory) < 0)
    write_err_and_exit (child_err_report_fd,
                        CHILD_CHDIR_FAILED);

  /* Close all file descriptors but stdin stdout and stderr as
   * soon as we exec. Note that this includes
   * child_err_report_fd, which keeps the parent from blocking
   * forever on the other end of that pipe.
   */
  if (close_descriptors)
    {
      fdwalk (set_cloexec, GINT_TO_POINTER(3));
    }
  else
    {
      /* We need to do child_err_report_fd anyway */
      set_cloexec (GINT_TO_POINTER(0), child_err_report_fd);
    }
  
  /* Redirect pipes as required */
  
  if (stdin_fd >= 0)
    {
      /* dup2 can't actually fail here I don't think */
          
      if (sane_dup2 (stdin_fd, 0) < 0)
        write_err_and_exit (child_err_report_fd,
                            CHILD_DUP2_FAILED);

      /* ignore this if it doesn't work */
      close_and_invalidate (&stdin_fd);
    }
  else if (!child_inherits_stdin)
    {
      /* Keep process from blocking on a read of stdin */
      gint read_null = open ("/dev/null", O_RDONLY);
      g_assert (read_null != -1);
      sane_dup2 (read_null, 0);
      close_and_invalidate (&read_null);
    }

  if (stdout_fd >= 0)
    {
      /* dup2 can't actually fail here I don't think */
          
      if (sane_dup2 (stdout_fd, 1) < 0)
        write_err_and_exit (child_err_report_fd,
                            CHILD_DUP2_FAILED);

      /* ignore this if it doesn't work */
      close_and_invalidate (&stdout_fd);
    }
  else if (stdout_to_null)
    {
      gint write_null = sane_open ("/dev/null", O_WRONLY);
      g_assert (write_null != -1);
      sane_dup2 (write_null, 1);
      close_and_invalidate (&write_null);
    }

  if (stderr_fd >= 0)
    {
      /* dup2 can't actually fail here I don't think */
          
      if (sane_dup2 (stderr_fd, 2) < 0)
        write_err_and_exit (child_err_report_fd,
                            CHILD_DUP2_FAILED);

      /* ignore this if it doesn't work */
      close_and_invalidate (&stderr_fd);
    }
  else if (stderr_to_null)
    {
      gint write_null = sane_open ("/dev/null", O_WRONLY);
      sane_dup2 (write_null, 2);
      close_and_invalidate (&write_null);
    }
  
  /* Call user function just before we exec */
  if (child_setup)
    {
      (* child_setup) (user_data);
    }

  g_execute (argv[0],
             file_and_argv_zero ? argv + 1 : argv,
             envp, search_path, search_path_from_envp);

  /* Exec failed */
  write_err_and_exit (child_err_report_fd,
                      CHILD_EXEC_FAILED);
}

static gboolean
read_ints (int      fd,
           gint*    buf,
           gint     n_ints_in_buf,    
           gint    *n_ints_read,      
           GError **error)
{
  gsize bytes = 0;    
  
  while (TRUE)
    {
      gssize chunk;    

      if (bytes >= sizeof(gint)*2)
        break; /* give up, who knows what happened, should not be
                * possible.
                */
          
    again:
      chunk = read (fd,
                    ((gchar*)buf) + bytes,
                    sizeof(gint) * n_ints_in_buf - bytes);
      if (chunk < 0 && errno == EINTR)
        goto again;
          
      if (chunk < 0)
        {
          int errsv = errno;

          /* Some weird shit happened, bail out */
          g_set_error (error,
                       G_SPAWN_ERROR,
                       G_SPAWN_ERROR_FAILED,
                       ("Failed to read from child pipe (%s)"),
                       g_strerror (errsv));

          return FALSE;
        }
      else if (chunk == 0)
        break; /* EOF */
      else /* chunk > 0 */
	bytes += chunk;
    }

  *n_ints_read = (gint)(bytes / sizeof(gint));

  return TRUE;
}
			  
static void set_error (VanubiSpawnAsyncWithPipesData* _data_, GError *error) {
	if (error != NULL) {
		g_simple_async_result_set_from_error (_data_->_async_result, error);
		g_error_free (error);
	}
}

static void complete (VanubiSpawnAsyncWithPipesData* _data_) {
	if (_data_->_state_ == 0) {
		g_simple_async_result_complete_in_idle (_data_->_async_result);
	} else {
		g_simple_async_result_complete (_data_->_async_result);
	}
	g_object_unref (_data_->_async_result);
}

static gboolean
fork_exec_with_pipes (VanubiSpawnAsyncWithPipesData* _data_) {
	switch (_data_->_state_) {
	case 0:
		goto _state_0;
	case 1:
		goto _state_1;
	case 2:
		goto _state_2;
	default:
		g_assert_not_reached ();
	}
	GError *error = NULL;
	 
_state_0: 
  if (!g_unix_open_pipe (_data_->child_err_report_pipe, _data_->pipe_flags, &error)) {
	  set_error (_data_, error);
	  complete (_data_);
	  return FALSE;
  }

  if (_data_->intermediate_child && !g_unix_open_pipe (_data_->child_pid_report_pipe, _data_->pipe_flags, &error))
	  goto cleanup_and_fail;
  
  if (!g_unix_open_pipe (_data_->stdin_pipe, _data_->pipe_flags, &error))
    goto cleanup_and_fail;
  
  if (!g_unix_open_pipe (_data_->stdout_pipe, _data_->pipe_flags, &error))
    goto cleanup_and_fail;

  if (!g_unix_open_pipe (_data_->stderr_pipe, FD_CLOEXEC, &error))
    goto cleanup_and_fail;

  _data_->pid = fork ();

  if (_data_->pid < 0)
    {
      int errsv = errno;

      g_set_error (&error,
                   G_SPAWN_ERROR,
                   G_SPAWN_ERROR_FORK,
                   ("Failed to fork (%s)"),
                   g_strerror (errsv));

      goto cleanup_and_fail;
    }
  else if (_data_->pid == 0)
    {
      /* Immediate child. This may or may not be the child that
       * actually execs the new process.
       */

      /* Reset some signal handlers that we may use */
      signal (SIGCHLD, SIG_DFL);
      signal (SIGINT, SIG_DFL);
      signal (SIGTERM, SIG_DFL);
      signal (SIGHUP, SIG_DFL);
      
      /* Be sure we crash if the parent exits
       * and we write to the err_report_pipe
       */
      signal (SIGPIPE, SIG_DFL);

      /* Close the parent's end of the pipes;
       * not needed in the close_descriptors case,
       * though
       */
      close_and_invalidate (&_data_->child_err_report_pipe[0]);
      close_and_invalidate (&_data_->child_pid_report_pipe[0]);
      close_and_invalidate (&_data_->stdin_pipe[1]);
      close_and_invalidate (&_data_->stdout_pipe[0]);
      close_and_invalidate (&_data_->stderr_pipe[0]);
      
      if (_data_->intermediate_child)
        {
          /* We need to fork an intermediate child that launches the
           * final child. The purpose of the intermediate child
           * is to exit, so we can waitpid() it immediately.
           * Then the grandchild will not become a zombie.
           */
          GPid grandchild_pid;

          grandchild_pid = fork ();

          if (grandchild_pid < 0)
            {
              /* report -1 as child PID */
              write_all (_data_->child_pid_report_pipe[1], &grandchild_pid,
                         sizeof(grandchild_pid));
              
              write_err_and_exit (_data_->child_err_report_pipe[1],
                                  CHILD_FORK_FAILED);              
            }
          else if (grandchild_pid == 0)
            {
              close_and_invalidate (&_data_->child_pid_report_pipe[1]);
              do_exec (_data_->child_err_report_pipe[1],
                       _data_->stdin_pipe[0],
                       _data_->stdout_pipe[1],
                       _data_->stderr_pipe[1],
                       _data_->working_directory,
                       _data_->argv,
                       _data_->envp,
                       _data_->close_descriptors,
                       _data_->search_path,
                       _data_->search_path_from_envp,
                       _data_->stdout_to_null,
                       _data_->stderr_to_null,
                       _data_->child_inherits_stdin,
                       _data_->file_and_argv_zero,
                       _data_->child_setup,
                       _data_->user_data);
            }
          else
            {
              write_all (_data_->child_pid_report_pipe[1], &grandchild_pid, sizeof(grandchild_pid));
              close_and_invalidate (&_data_->child_pid_report_pipe[1]);
              
              _exit (0);
            }
        }
      else
        {
          /* Just run the child.
           */

          do_exec (_data_->child_err_report_pipe[1],
                   _data_->stdin_pipe[0],
                   _data_->stdout_pipe[1],
                   _data_->stderr_pipe[1],
                   _data_->working_directory,
                   _data_->argv,
                   _data_->envp,
                   _data_->close_descriptors,
                   _data_->search_path,
                   _data_->search_path_from_envp,
                   _data_->stdout_to_null,
                   _data_->stderr_to_null,
                   _data_->child_inherits_stdin,
                   _data_->file_and_argv_zero,
                   _data_->child_setup,
                   _data_->user_data);
        }
    }
  else
    {
      /* Parent */
      
      gint buf[2];
      gssize n_ints = 0;    

      /* Close the uncared-about ends of the pipes */
      close_and_invalidate (&_data_->child_err_report_pipe[1]);
      close_and_invalidate (&_data_->child_pid_report_pipe[1]);
      close_and_invalidate (&_data_->stdin_pipe[0]);
      close_and_invalidate (&_data_->stdout_pipe[1]);
      close_and_invalidate (&_data_->stderr_pipe[1]);

      /* If we had an intermediate child, reap it */
      if (_data_->intermediate_child)
        {
        wait_again:
          if (waitpid (_data_->pid, &_data_->status, 0) < 0)
            {
              if (errno == EINTR)
                goto wait_again;
              else if (errno == ECHILD)
                ; /* do nothing, child already reaped */
              else
                g_warning ("waitpid() should not fail in "
			   "'fork_exec_with_pipes'");
            }
        }
      
		GInputStream *unix_stream = g_unix_input_stream_new (_data_->child_err_report_pipe[0], FALSE);
		_data_->read_stream = g_data_input_stream_new (unix_stream);
		g_object_unref (unix_stream);
		
		_data_->_state_ = 1;
		g_buffered_input_stream_fill_async (G_BUFFERED_INPUT_STREAM (_data_->read_stream), sizeof(int)*2, _data_->io_priority, _data_->cancellable, vanubi_spawn_async_with_pipes_ready, _data_);
		return FALSE;
		
	_state_1:
		n_ints = g_buffered_input_stream_fill_finish (G_BUFFERED_INPUT_STREAM (_data_->read_stream), _data_->_res_, &error);
		if (error != NULL) {
			goto cleanup_and_fail;
		}
		n_ints = n_ints / sizeof(int);

      if (n_ints >= 2)
        {
          /* Error from the child. */
		  buf[0] = g_data_input_stream_read_int32 (_data_->read_stream, _data_->cancellable, &error);
		  if (error != NULL) {
			  goto cleanup_and_fail;
		  }
		  buf[1] = g_data_input_stream_read_int32 (_data_->read_stream, _data_->cancellable, &error);
		  if (error != NULL) {
			  goto cleanup_and_fail;
		  }

          switch (buf[0])
            {
            case CHILD_CHDIR_FAILED:
              g_set_error (&error,
                           G_SPAWN_ERROR,
                           G_SPAWN_ERROR_CHDIR,
                           ("Failed to change to directory '%s' (%s)"),
                           _data_->working_directory,
                           g_strerror (buf[1]));

              break;
              
            case CHILD_EXEC_FAILED:
              g_set_error (&error,
                           G_SPAWN_ERROR,
                           exec_err_to_g_error (buf[1]),
                           ("Failed to execute child process \"%s\" (%s)"),
                           _data_->argv[0],
                           g_strerror (buf[1]));

              break;
              
            case CHILD_DUP2_FAILED:
              g_set_error (&error,
                           G_SPAWN_ERROR,
                           G_SPAWN_ERROR_FAILED,
                           ("Failed to redirect output or input of child process (%s)"),
                           g_strerror (buf[1]));

              break;

            case CHILD_FORK_FAILED:
              g_set_error (&error,
                           G_SPAWN_ERROR,
                           G_SPAWN_ERROR_FORK,
                           ("Failed to fork child process (%s)"),
                           g_strerror (buf[1]));
              break;
              
            default:
              g_set_error (&error,
                           G_SPAWN_ERROR,
                           G_SPAWN_ERROR_FAILED,
                           ("Unknown error executing child process \"%s\""),
                           _data_->argv[0]);
              break;
            }

          goto cleanup_and_fail;
        }

      /* Get child pid from intermediate child pipe. */
      if (_data_->intermediate_child)
        {
			_data_->_state_ = 2;
			g_buffered_input_stream_fill_async (G_BUFFERED_INPUT_STREAM (_data_->read_stream), sizeof(int)*1, _data_->io_priority, _data_->cancellable, vanubi_spawn_async_with_pipes_ready, _data_);
			return FALSE;
		
		_state_2:
			n_ints = g_buffered_input_stream_fill_finish (G_BUFFERED_INPUT_STREAM (_data_->read_stream), _data_->_res_, &error);
			if (error != NULL) {
				goto cleanup_and_fail;
			}
			n_ints = n_ints / sizeof(int);

          if (n_ints < 1)
            {
              int errsv = errno;

              g_set_error (&error,
                           G_SPAWN_ERROR,
                           G_SPAWN_ERROR_FAILED,
                           ("Failed to read enough data from child pid pipe (%s)"),
                           g_strerror (errsv));
              goto cleanup_and_fail;
            }
          else
            {
              /* we have the child pid */
			  buf[0] = g_data_input_stream_read_int32 (_data_->read_stream, _data_->cancellable, &error);
			  if (error != NULL) {
				  goto cleanup_and_fail;
			  }
              _data_->pid = buf[0];
            }
        }
      
      /* Success against all odds! return the information */
      close_and_invalidate (&_data_->child_err_report_pipe[0]);
      close_and_invalidate (&_data_->child_pid_report_pipe[0]);
 
	  _data_->child_pid = _data_->pid;

	  _data_->standard_input = _data_->stdin_pipe[1];
	  _data_->standard_output = _data_->stdout_pipe[0];
	  _data_->standard_error = _data_->stderr_pipe[0];
      
	  set_error (_data_, error);
	  complete (_data_);
      return FALSE;
    }

 cleanup_and_fail:

  /* There was an error from the Child, reap the child to avoid it being
     a zombie.
   */

  if (_data_->pid > 0)
  {
    wait_failed:
     if (waitpid (_data_->pid, NULL, 0) < 0)
       {
          if (errno == EINTR)
            goto wait_failed;
          else if (errno == ECHILD)
            ; /* do nothing, child already reaped */
          else
            g_warning ("waitpid() should not fail in "
                       "'fork_exec_with_pipes'");
       }
   }

  close_and_invalidate (&_data_->child_err_report_pipe[0]);
  close_and_invalidate (&_data_->child_err_report_pipe[1]);
  close_and_invalidate (&_data_->child_pid_report_pipe[0]);
  close_and_invalidate (&_data_->child_pid_report_pipe[1]);
  close_and_invalidate (&_data_->stdin_pipe[0]);
  close_and_invalidate (&_data_->stdin_pipe[1]);
  close_and_invalidate (&_data_->stdout_pipe[0]);
  close_and_invalidate (&_data_->stdout_pipe[1]);
  close_and_invalidate (&_data_->stderr_pipe[0]);
  close_and_invalidate (&_data_->stderr_pipe[1]);

  set_error (_data_, error);
  complete (_data_);
  	
  return FALSE;
}

/* Based on execvp from GNU C Library */

static void
script_execute (const gchar *file,
                gchar      **argv,
                gchar      **envp)
{
  /* Count the arguments.  */
  int argc = 0;
  while (argv[argc])
    ++argc;
  
  /* Construct an argument list for the shell.  */
  {
    gchar **new_argv;

    new_argv = g_new0 (gchar*, argc + 2); /* /bin/sh and NULL */
    
    new_argv[0] = (char *) "/bin/sh";
    new_argv[1] = (char *) file;
    while (argc > 0)
      {
	new_argv[argc + 1] = argv[argc];
	--argc;
      }

    /* Execute the shell. */
    if (envp)
      execve (new_argv[0], new_argv, envp);
    else
      execv (new_argv[0], new_argv);
    
    g_free (new_argv);
  }
}

static gchar*
my_strchrnul (const gchar *str, gchar c)
{
  gchar *p = (gchar*) str;
  while (*p && (*p != c))
    ++p;

  return p;
}

static gint
g_execute (const gchar *file,
           gchar      **argv,
           gchar      **envp,
           gboolean     search_path,
           gboolean     search_path_from_envp)
{
  if (*file == '\0')
    {
      /* We check the simple case first. */
      errno = ENOENT;
      return -1;
    }

  if (!(search_path || search_path_from_envp) || strchr (file, '/') != NULL)
    {
      /* Don't search when it contains a slash. */
      if (envp)
        execve (file, argv, envp);
      else
        execv (file, argv);
      
      if (errno == ENOEXEC)
	script_execute (file, argv, envp);
    }
  else
    {
      gboolean got_eacces = 0;
      const gchar *path, *p;
      gchar *name, *freeme;
      gsize len;
      gsize pathlen;

      path = NULL;
      if (search_path_from_envp)
        path = g_environ_getenv (envp, "PATH");
      if (search_path && path == NULL)
        path = g_getenv ("PATH");

      if (path == NULL)
	{
	  /* There is no 'PATH' in the environment.  The default
	   * search path in libc is the current directory followed by
	   * the path 'confstr' returns for '_CS_PATH'.
           */

          /* In GLib we put . last, for security, and don't use the
           * unportable confstr(); UNIX98 does not actually specify
           * what to search if PATH is unset. POSIX may, dunno.
           */
          
          path = "/bin:/usr/bin:.";
	}

      len = strlen (file) + 1;
      pathlen = strlen (path);
      freeme = name = g_malloc (pathlen + len + 1);
      
      /* Copy the file name at the top, including '\0'  */
      memcpy (name + pathlen + 1, file, len);
      name = name + pathlen;
      /* And add the slash before the filename  */
      *name = '/';

      p = path;
      do
	{
	  char *startp;

	  path = p;
	  p = my_strchrnul (path, ':');

	  if (p == path)
	    /* Two adjacent colons, or a colon at the beginning or the end
             * of 'PATH' means to search the current directory.
             */
	    startp = name + 1;
	  else
	    startp = memcpy (name - (p - path), path, p - path);

	  /* Try to execute this name.  If it works, execv will not return.  */
          if (envp)
            execve (startp, argv, envp);
          else
            execv (startp, argv);
          
	  if (errno == ENOEXEC)
	    script_execute (startp, argv, envp);

	  switch (errno)
	    {
	    case EACCES:
	      /* Record the we got a 'Permission denied' error.  If we end
               * up finding no executable we can use, we want to diagnose
               * that we did find one but were denied access.
               */
	      got_eacces = TRUE;

              /* FALL THRU */
              
	    case ENOENT:
#ifdef ESTALE
	    case ESTALE:
#endif
#ifdef ENOTDIR
	    case ENOTDIR:
#endif
	      /* Those errors indicate the file is missing or not executable
               * by us, in which case we want to just try the next path
               * directory.
               */
	      break;

	    case ENODEV:
	    case ETIMEDOUT:
	      /* Some strange filesystems like AFS return even
	       * stranger error numbers.  They cannot reasonably mean anything
	       * else so ignore those, too.
	       */
	      break;

	    default:
	      /* Some other error means we found an executable file, but
               * something went wrong executing it; return the error to our
               * caller.
               */
              g_free (freeme);
	      return -1;
	    }
	}
      while (*p++ != '\0');

      /* We tried every element and none of them worked.  */
      if (got_eacces)
	/* At least one failure was due to permissions, so report that
         * error.
         */
        errno = EACCES;

      g_free (freeme);
    }

  /* Return the error from the last attempt (probably ENOENT).  */
  return -1;
}
