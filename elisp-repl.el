;;; elisp-repl.el --- Emacs Lisp REPL with Readline support  -*- lexical-binding: t; -*-

;; Copyright (C) 2020  Xu Chunyang

;; Author: Xu Chunyang
;; Homepage: https://github.com/xuchunyang/elisp-repl
;; Package-Requires: ((emacs "25.1") (e2ansi "0.1.2"))
;; Keywords: lisp
;; Version: 0

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; An Emacs Lisp REPL with Readline support

;;; Code:

;; IDEA: Support completion for `completing-read'
;; IDEA: Load init file (Emacs Lisp code, not readline's inputrc)
;; IDEA: Customize prompt (color, last command status, count commands)

(require 'pp)
(require 'e2ansi nil 'noerror)

(declare-function e2ansi-print-buffer "e2ansi" (&optional buffer dest))

(declare-function elisp-repl-readline "elisp-repl-readline" (prompt))
(declare-function elisp-repl-readline-add-history "elisp-repl-readline" (line))
(declare-function elisp-repl-readline-read-history "elisp-repl-readline" (filename))
(declare-function elisp-repl-readline-write-history "elisp-repl-readline" (filename))

(defgroup elisp-repl nil
  "Emacs Lisp REPL with Readline support."
  :group 'lisp)

(defcustom elisp-repl-prompt "> "
  "Prompt used in `elisp-repl'."
  :type 'string)

(defcustom elisp-repl-lexical-binding t
  "Whether to use lexical binding when evaluating code in `elisp-repl'."
  :type 'boolean)

(defcustom elisp-repl-history-file (pcase "~/.elisp_repl_history"
                                     ((and (pred file-exists-p) f) f))
  "History file used by Readline.
It must be either a full file path (including directory) or nil.
If it is a path and not exists, it will be created automatically.
If it is nil, don't save history to file."
  :type '(choice (const :tag "Disable" nil)
                 (file :tag "Full file path")))

(defcustom elisp-init-file (pcase "~/.elisp_init.el"
                             ((and (pred file-exists-p) f) f))
  "User init file used by `elisp-repl'.
It must be either an existing full file path (including directory) or nil.
If nil, don't load init file."
  :type '(choice (const :tag "Disable" nil)
                 (file :tag "Full file path")))

(defvar elisp-repl-real-term-p
  (not (member (getenv "TERM") '("dumb" "cons25" "emacs")))
  "Non-nil if the terminal supports Readline.")

(defvar elisp-repl-blank-or-comment-re
  (rx bos (* space) (? (: ";" (* any))) eos)
  "RegExp to match empty input.")

(defvar elisp-repl-readline-function
  (cond
   (elisp-repl-real-term-p
    ;; IDEA: Provide Emacs function to help user compile the module
    (require 'elisp-repl-readline)
    #'elisp-repl-readline)
   (t
    #'elisp-repl-readline-naive))
  "The Readline function to used.")

(defun elisp-repl-readline-naive (prompt)
  "Read a line with Emacs native method, prompting with string PROMPT.
All readline feature is NOT available."
  (ignore-errors (read-from-minibuffer prompt)))

(defun elisp-repl-readline-according-to-term ()
  "Read a line according to the terminal."
  (funcall elisp-repl-readline-function elisp-repl-prompt))

;; IDEA: Print integer like C-x C-e, 42 (#o52, #x2a, ?*)
(defun elisp-repl-pp (object)
  "Pretty-print OBJECT, add syntax highlighting if possible."
  ;; `pp-to-string' gives more readable output than `prin1-to-string', for
  ;; example, try print the value of `auto-mode-alist'
  (let ((s (pp-to-string object)))
    (cond
     ((and elisp-repl-real-term-p
           (fboundp 'e2ansi-print-buffer))
      (with-current-buffer (get-buffer-create "*elisp repl eval output*")
        (setq buffer-undo-list t)
        (erase-buffer)
        (emacs-lisp-mode)
        (insert s)
        (let ((noninteractive nil))
          (font-lock-mode 1))
        ;; NOTE: change theme, user can change theme within the repl.
        ;; (custom-available-themes) (load-theme 'tango-dark)
        (e2ansi-print-buffer (current-buffer))))
     (t
      ;; IDEA: Warn user `e2ansi-print-buffer' is not available
      (princ s)))
    (unless (string-suffix-p "\n" s)
      (terpri))))

(defun elisp-repl-read-history ()
  "Ask Readline to initialize history from `elisp-repl-history-file'."
  (when (and elisp-repl-real-term-p
             elisp-repl-history-file)
    (let ((path (expand-file-name elisp-repl-history-file)))
      (when (file-readable-p path)
        (elisp-repl-readline-read-history path)))))

(defun elisp-repl-write-history ()
  "Ask Readline to write history to `elisp-repl-history-file'."
  (when (and elisp-repl-real-term-p
             elisp-repl-history-file)
    (let* ((path (expand-file-name elisp-repl-history-file))
           (dir (file-name-directory path)))
      (when (file-directory-p path)
        (user-error "`elisp-repl-history-file' is a directory"))
      (unless (file-exists-p dir)
        (make-directory dir t))
      (elisp-repl-readline-write-history path))))

(defun elisp-repl ()
  "Start the Emacs Lisp REPL.
Must be called from batch mode."
  (unless noninteractive
    (user-error "`elisp-repl' is to be used in batch mode"))
  (when elisp-init-file
    (load-file elisp-init-file))
  (when (and elisp-repl-real-term-p
             (not (fboundp 'e2ansi-print-buffer)))
    (message "[WARNNING] `e2ansi' is not loaded, will not use syntax highlighting"))
  (elisp-repl-read-history)
  (let (eof)
    (while (not eof)
      (let ((line (elisp-repl-readline-according-to-term)))
        (cond
         ((not line) (setq eof t))
         ((string-match-p elisp-repl-blank-or-comment-re line))
         (t
          (when elisp-repl-real-term-p
            (elisp-repl-readline-add-history line))
          ;; IDEA: backtrace (likely impossible)
          (condition-case-unless-debug err
              (let ((val (eval (read line) elisp-repl-lexical-binding)))
                ;; IDEA: Bind the values of the variable `*', `**', and `***' like M-x ielm
                (push val values)
                (elisp-repl-pp val))
            (error
             (princ (format "%s\n" (error-message-string err))))))))))
  (elisp-repl-write-history))

;;;###autoload
(defun elisp-repl-emacs-batch-command ()
  "Copy a shell command that run Emacs Lisp REPL."
  (interactive)
  (let ((cmd (mapconcat
              #'shell-quote-argument
              (list (concat invocation-directory invocation-name)
                    "--batch"
                    "-L" (file-name-directory (locate-library "elisp-repl"))
                    "-L" (file-name-directory (locate-library "e2ansi"))
                    "-L" (file-name-directory (locate-library "face-explorer"))
                    "-l" "elisp-repl"
                    "-f" "elisp-repl")
              " ")))
    (message "Emacs Lisp REPL command saved to kill-ring, please run it in a terminal")
    (kill-new cmd)))

(provide 'elisp-repl)
;;; elisp-repl.el ends here
