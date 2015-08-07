;;; coq-server.el --- Use a remote server for Proof General

;; Copyright (C) 2015 Pavel Panchekha <me@pavpanchekha.com>

;; Author: Pavel Panchekha <me@pavpanchekha.com>
;; Version: 0.1
;; Keywords: proof-general, coq

;; This program is free software: you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Allows you to use a remote server for running Coq in Proof General.
;; This is useful when you want to work on a laptop but use a beefier remote machine.

;;; Code:

(require 'subr-x)

(defgroup coq-server nil
  "Remote Coq servers"
  :prefix "coq-server-"
  :group 'coq)

(defcustom coq-server-host "dante.cs.washington.edu"
  "The server to use for Coq server processes."
  :group 'coq-server :type 'string)

(defcustom coq-server-user (user-login-name)
  "The remote user to use for Coq server processes."
  :group 'coq-server :type 'string)

(defcustom coq-server-local-sftp-server "/usr/libexec/openssh/sftp-server"
  "The location of the sftp-server binary. It's usually under /usr, in some variant of /usr/lib, in a folder called openssh or ssh or similar."
  :group 'coq-server :type 'string)

(defcustom coq-server-local-dpipe "/usr/bin/dpipe"
  "The location of the dpipe binary. It should come with this project, and can be built with `make'"
  :group 'coq-server :type 'string)

(defcustom coq-server-program "coqtop"
  "The name for coqtop on the remote Coq server."
  :group 'coq-server :type 'string)

(defvar coq-server-dpipe-buffer nil
  "The dpipe buffer associated with this Coq server buffer.")

(defvar coq-server-original-buffer nil
  "The original buffer associated with this Coq server buffer.")

(defvar coq-server-tempdir nil
  "The remote temporary directory associated with this Coq server buffer.")

(defun coq-server-remote-dir ()
  "Return the remote directory name on the Coq server."
  (concat "/ssh:" coq-server-user "@" coq-server-host ":"))

(defun coq-server-remote-cmd ()
  "Return an SSH command for the remote server."
  (combine-and-quote-strings (list "ssh" "-S" (coq-server-socket) "-l" coq-server-user coq-server-host)))

(defun coq-server-mktempd ()
  "Create a temporary directory on the remote server."
  (string-trim-right
   (shell-command-to-string (concat (coq-server-remote-cmd) " mktemp -d"))))

(defvar coq-server-socket-file nil
  "The location of the Coq server SSH control master socket, or nil if not connected yet.")

(defun coq-server-local-mktempd ()
  (string-trim-right (shell-command-to-string "mktemp -d /tmp/coq-server.XXXXXXXXXX")))

(defun coq-server-socket ()
  "Return the location of the SSH control master socket, or start a new control master."
  (if coq-server-socket-file
      coq-server-socket-file
    (setq coq-server-socket-file (concat (coq-server-local-mktempd) "/coq-server.socket"))
    (async-shell-command
     (combine-and-quote-strings
      (list "ssh" "-M" "-N" "-S" coq-server-socket-file "-l" coq-server-user coq-server-host)))
    (sleep-for 0 100)
    coq-server-socket-file))

(defun coq-server-mount-self (path)
  "Mount the local host's whole file system on the remote server at PATH."
  (let* ((dpipe-buffer (get-buffer-create "*coq-server-dpipe*"))
         (dpipe-process
          (start-process
           "coq-server-dpipe" dpipe-buffer coq-server-local-dpipe
           (shell-quote-argument coq-server-local-sftp-server) "="
           "ssh" "-l" (shell-quote-argument coq-server-user)
           "-S" (shell-quote-argument (coq-server-socket))
           (shell-quote-argument coq-server-host) "sshfs" ":/"
           (shell-quote-argument path) "-o" "slave" "-o" "transform_symlinks")))
    dpipe-buffer))

(defun coq-server-unmount-self (path buffer)
  "Unmount the local host's file system on the remote server at PATH, and close the dpipe at BUFFER."
  (when (get-buffer-process buffer)
    (delete-process buffer))
  (with-temp-buffer
    (async-shell-command (concat (coq-server-remote-cmd) " rm " (shell-quote-argument path)) nil nil)))

(defun coq-server ()
  "Use a Coq server on the current file."
  (interactive)
  (if (and coq-server-tempdir coq-server-dpipe-buffer)
      (message "Already on remote Coq server. Kill buffer (C-x k) to return to local Coq.")
    ;; Exit the current proof instance
    (let ((old-buffer (current-buffer))
          (fname (buffer-file-name))
          (old-process-end (proof-unprocessed-begin))
          (old-point (point))
          (old-modified-p (buffer-modified-p))
          (old-contents (buffer-string)))
      (if (not fname)
          (error "Buffer is not visiting a file!")
        (let* ((tempd (coq-server-mktempd))
               (dpipe-buffer (coq-server-mount-self tempd)))
          (when proof-shell-buffer
            (proof-shell-exit t))
          (message "Connecting to Coq server...")
          (sleep-for 1)
          (find-file (concat (coq-server-remote-dir) tempd fname))
          (when old-modified-p
            (erase-buffer)
            (insert old-contents))
          (let ((new-coq-load-path
                 (mapcar (lambda (path)
                           (cond
                            ((stringp path) (concat tempd "/" path))
                            ((and (listp path) (= (length path) 3))
                             (list (car path) (cadr path) (concat tempd "/" (cadr (cdr path)))))
                            ((and (listp path) (= (length path) 2))
                             (list (car path) (concat tempd "/" (cadr path))))
                            (t (error "Invalid entry in coq-load-path: %s" path))))
                         coq-load-path))
                (new-coq-prog-name coq-server-program))
            (setq-local coq-server-dpipe-buffer dpipe-buffer)
            (setq-local coq-server-original-buffer old-buffer)
            (setq-local coq-server-tempdir tempd)
            (setq-local coq-load-path new-coq-load-path)
            (setq-local coq-prog-name new-coq-prog-name)
            (add-hook 'kill-buffer-hook 'coq-server-teardown)
            (proof-shell-start)
            (goto-char old-process-end)
            (proof-assert-until-point)
            (goto-char old-point)))))))

(defun coq-server-teardown ()
  "Close the Coq server connection and unmount the local files."
  (when (and coq-server-tempdir coq-server-dpipe-buffer)
    (setq-local coq-server-tempdir nil)
    (setq-local coq-server-dpipe-buffer nil)
    (when proof-shell-buffer
      (proof-shell-exit t))
    (coq-server-unmount-self coq-server-tempdir coq-server-dpipe-buffer)
    (let ((old-process-end (proof-unprocessed-begin))
          (old-point (point))
          (old-modified-p (buffer-modified-p))
          (old-contents (buffer-string)))
      (switch-to-buffer coq-server-original-buffer)
      (if (not old-modified-p)
          (revert-buffer t t nil)
        (erase-buffer)
        (insert old-contents))
      (proof-shell-start)
      (goto-char old-process-end)
      (proof-assert-until-point)
      (goto-char old-point))))

(with-eval-after-load "coq"
  (define-key coq-mode-map (kbd "C-c r") 'coq-server))

(provide 'coq-server)
;;; coq-server.el ends here
