;;; wl-summary.el --- Summary mode for Wanderlust.

;; Copyright (C) 1998,1999,2000 Yuuichi Teranishi <teranisi@gohome.org>
;; Copyright (C) 1998,1999,2000 Masahiro MURATA <muse@ba2.so-net.ne.jp>
;; Copyright (C) 1999,2000      TSUMURA Tomoaki <tsumura@kuis.kyoto-u.ac.jp>
;; Copyright (C) 1999,2000      Kenichi OKADA <okada@opaopa.org>

;; Author: Yuuichi Teranishi <teranisi@gohome.org>
;;	Masahiro MURATA <muse@ba2.so-net.ne.jp>
;;	TSUMURA Tomoaki <tsumura@kuis.kyoto-u.ac.jp>
;;	Kenichi OKADA <okada@opaopa.org>
;; Keywords: mail, net news

;; This file is part of Wanderlust (Yet Another Message Interface on Emacsen).

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.
;;

;;; Commentary:
;;

;;; Code:
;;

(require 'elmo)
(require 'elmo-multi)
(require 'wl-message)
(require 'wl-vars)
(require 'wl-highlight)
(require 'wl-refile)
(require 'wl-util)
(condition-case nil (require 'timezone) (error nil))
(condition-case nil (require 'easymenu) (error nil))
(require 'elmo-date)
(condition-case nil (require 'ps-print) (error nil))

(eval-when-compile
  (require 'cl)
  (condition-case () (require 'timer) (error nil))
  (defalias-maybe 'ps-print-buffer-with-faces 'ignore)
  (defalias-maybe 'elmo-database-msgid-put 'ignore)
  (defalias-maybe 'elmo-database-close 'ignore)
  (defalias-maybe 'elmo-database-msgid-get 'ignore)
  (defalias-maybe 'run-with-idle-timer 'ignore)
  (defalias-maybe 'ps-print-preprint 'ignore))

(defvar dragdrop-drop-functions)
(defvar scrollbar-height)
(defvar mail-reply-buffer)

(defvar wl-summary-buffer-name "Summary")
(defvar wl-summary-mode-map nil)
(defvar wl-current-summary-buffer nil)

(defvar wl-summary-buffer-elmo-folder nil)

(defmacro wl-summary-buffer-folder-name ()
  (` (and wl-summary-buffer-elmo-folder
	  (elmo-folder-name-internal wl-summary-buffer-elmo-folder))))

(defmacro wl-summary-buffer-msgdb ()
  (` (and wl-summary-buffer-elmo-folder
	  (elmo-folder-msgdb wl-summary-buffer-elmo-folder))))

(defvar wl-summary-buffer-folder-indicator nil)
(defvar wl-summary-buffer-disp-msg    nil)
(defvar wl-summary-buffer-disp-folder nil)
(defvar wl-summary-buffer-refile-list nil)
(defvar wl-summary-buffer-delete-list nil)
(defvar wl-summary-buffer-last-displayed-msg nil)
(defvar wl-summary-buffer-current-msg nil)
(defvar wl-summary-buffer-unread-status " (0 new/0 unread)")
(defvar wl-summary-buffer-unread-count 0)
(defvar wl-summary-buffer-new-count    0)
(defvar wl-summary-buffer-mime-charset  nil)
(defvar wl-summary-buffer-weekday-name-lang  nil)
(defvar wl-summary-buffer-thread-indent-set-alist  nil)
(defvar wl-summary-buffer-view 'thread)
(defvar wl-summary-buffer-message-modified nil)
(defvar wl-summary-buffer-mark-modified nil)
(defvar wl-summary-buffer-thread-modified nil)
(defvar wl-summary-buffer-number-column nil)
(defvar wl-summary-buffer-number-regexp nil)
(defvar wl-summary-buffer-persistent nil)
(defvar wl-summary-buffer-thread-nodes nil)
(defvar wl-summary-buffer-target-mark-list nil)
(defvar wl-summary-buffer-copy-list nil)
(defvar wl-summary-buffer-prev-refile-destination nil)
(defvar wl-summary-buffer-prev-copy-destination nil)
(defvar wl-summary-buffer-saved-message nil)
(defvar wl-summary-buffer-prev-folder-function nil)
(defvar wl-summary-buffer-next-folder-function nil)
(defvar wl-summary-buffer-exit-function nil)
(defvar wl-summary-buffer-next-message-function nil)
(defvar wl-summary-buffer-number-list nil)
(defvar wl-summary-buffer-msgdb nil)
(defvar wl-summary-buffer-folder-name nil)

(defvar wl-thread-indent-level-internal nil)
(defvar wl-thread-have-younger-brother-str-internal nil)
(defvar wl-thread-youngest-child-str-internal nil)
(defvar wl-thread-vertical-str-internal nil)
(defvar wl-thread-horizontal-str-internal nil)
(defvar wl-thread-space-str-internal nil)
(defvar wl-summary-last-visited-folder nil)
(defvar wl-read-folder-hist nil)
(defvar wl-summary-scored nil)
(defvar wl-crosspost-alist-modified nil)
(defvar wl-summary-alike-hashtb nil)
(defvar wl-summary-search-buf-name " *wl-search-subject*")
(defvar wl-summary-delayed-update nil)
(defvar wl-summary-search-buf-folder-name nil)

(defvar wl-summary-get-petname-function 'wl-address-get-petname-1)

(defvar wl-summary-message-regexp "^ *\\(-?[0-9]+\\)")

(defvar wl-summary-shell-command-last "")

(defvar wl-ps-preprint-hook nil)
(defvar wl-ps-print-hook nil)

(make-variable-buffer-local 'wl-summary-buffer-elmo-folder)
(make-variable-buffer-local 'wl-summary-search-buf-folder-name)
(make-variable-buffer-local 'wl-summary-buffer-disp-msg)
(make-variable-buffer-local 'wl-summary-buffer-disp-folder)
(make-variable-buffer-local 'wl-summary-buffer-refile-list)
(make-variable-buffer-local 'wl-summary-buffer-copy-list)
(make-variable-buffer-local 'wl-summary-buffer-target-mark-list)
(make-variable-buffer-local 'wl-summary-buffer-delete-list)
(make-variable-buffer-local 'wl-summary-buffer-folder-indicator)
(make-variable-buffer-local 'wl-summary-buffer-last-displayed-msg)
(make-variable-buffer-local 'wl-summary-buffer-unread-status)
(make-variable-buffer-local 'wl-summary-buffer-unread-count)
(make-variable-buffer-local 'wl-summary-buffer-new-count)
(make-variable-buffer-local 'wl-summary-buffer-mime-charset)
(make-variable-buffer-local 'wl-summary-buffer-weekday-name-lang)
(make-variable-buffer-local 'wl-summary-buffer-thread-indent-set)
(make-variable-buffer-local 'wl-summary-buffer-view)
(make-variable-buffer-local 'wl-summary-buffer-message-modified)
(make-variable-buffer-local 'wl-summary-buffer-mark-modified)
(make-variable-buffer-local 'wl-summary-buffer-thread-modified)
(make-variable-buffer-local 'wl-summary-buffer-number-column)
(make-variable-buffer-local 'wl-summary-buffer-number-regexp)
(make-variable-buffer-local 'wl-summary-buffer-persistent)
(make-variable-buffer-local 'wl-summary-buffer-thread-nodes)
(make-variable-buffer-local 'wl-summary-buffer-prev-refile-destination)
(make-variable-buffer-local 'wl-summary-buffer-saved-message)
(make-variable-buffer-local 'wl-summary-scored)
(make-variable-buffer-local 'wl-summary-default-score)
(make-variable-buffer-local 'wl-summary-move-direction-downward)
(make-variable-buffer-local 'wl-summary-important-above)
(make-variable-buffer-local 'wl-summary-target-above)
(make-variable-buffer-local 'wl-summary-mark-below)
(make-variable-buffer-local 'wl-summary-expunge-below)
(make-variable-buffer-local 'wl-thread-indent-level-internal)
(make-variable-buffer-local 'wl-thread-have-younger-brother-str-internal)
(make-variable-buffer-local 'wl-thread-youngest-child-str-internal)
(make-variable-buffer-local 'wl-thread-vertical-str-internal)
(make-variable-buffer-local 'wl-thread-horizontal-str-internal)
(make-variable-buffer-local 'wl-thread-space-str-internal)
(make-variable-buffer-local 'wl-summary-buffer-prev-folder-function)
(make-variable-buffer-local 'wl-summary-buffer-next-folder-function)
(make-variable-buffer-local 'wl-summary-buffer-exit-function)
(make-variable-buffer-local 'wl-summary-buffer-next-message-function)
(make-variable-buffer-local 'wl-summary-buffer-number-list)
(make-variable-buffer-local 'wl-summary-buffer-msgdb)
(make-variable-buffer-local 'wl-summary-buffer-folder-name)

;; internal functions (dummy)
(unless (fboundp 'wl-summary-append-message-func-internal)
  (defun wl-summary-append-message-func-internal (entity overview
							 mark-alist update
							 &optional force-insert)))
(unless (fboundp 'wl-summary-from-func-internal)
  (defun wl-summary-from-func-internal (from)
    from))
(unless (fboundp 'wl-summary-subject-func-internal)
  (defun wl-summary-subject-func-internal (subject)
    subject))
(unless (fboundp 'wl-summary-subject-filter-func-internal)
  (defun wl-summary-subject-filter-func-internal (subject)
    subject))

(defmacro wl-summary-sticky-buffer-name (name)
  (` (concat wl-summary-buffer-name ":" (, name))))

(defun wl-summary-default-subject (subject-string)
  (if (string-match "^[ \t]*\\[[^:]+[,: ][0-9]+\\][ \t]*" subject-string)
      (substring subject-string (match-end 0))
    subject-string))

(eval-when-compile (defvar-maybe entity nil)) ; silence byte compiler.
(defun wl-summary-default-from (from)
  (let (retval tos ng)
    (unless
	(and (eq major-mode 'wl-summary-mode)
	     (stringp wl-summary-showto-folder-regexp)
	     (string-match wl-summary-showto-folder-regexp
			   (wl-summary-buffer-folder-name))
	     (wl-address-user-mail-address-p from)
	     (cond
	      ((and (setq tos (elmo-msgdb-overview-entity-get-to entity))
		    (not (string= "" tos)))
	       (setq retval
		     (concat "To:"
			     (mapconcat
			      (function
			       (lambda (to)
				 (eword-decode-string
				  (if wl-use-petname
				      (or
				       (funcall wl-summary-get-petname-function to)
				       (car
					(std11-extract-address-components to))
				       to)
				    to))))
			      (wl-parse-addresses tos)
			      ","))))
	      ((setq ng (elmo-msgdb-overview-entity-get-extra-field
			 entity "newsgroups"))
	       (setq retval (concat "Ng:" ng)))))
      (if wl-use-petname
	  (setq retval (or (funcall wl-summary-get-petname-function from)
			   (car (std11-extract-address-components from))
			   from))
	(setq retval from)))
    retval))

(defun wl-summary-simple-from (string)
  (if wl-use-petname
      (or (funcall wl-summary-get-petname-function string)
	  (car (std11-extract-address-components string))
	  string)
    string))

(defvar wl-summary-mode-menu-spec
  '("Summary"
    ["Read" wl-summary-read t]
    ["Prev page" wl-summary-prev-page t]
    ["Next page" wl-summary-next-page t]
    ["Top"       wl-summary-display-top t]
    ["Bottom"    wl-summary-display-bottom t]
    ["Prev"      wl-summary-prev t]
    ["Next"      wl-summary-next t]
    ["Up"        wl-summary-up t]
    ["Down"      wl-summary-down t]
    ["Parent message" wl-summary-jump-to-parent-message t]
    "----"
    ["Sync"            wl-summary-sync t]
    ["Execute"         wl-summary-exec t]
    ["Go to other folder" wl-summary-goto-folder t]
    ["Pick" wl-summary-pick t]
    ["Mark as read all" wl-summary-mark-as-read-all t]
    ["Unmark all"      wl-summary-unmark-all t]
    ["Toggle display message" wl-summary-toggle-disp-msg t]
    ["Display folder" wl-summary-toggle-disp-folder t]
    ["Toggle threading" wl-summary-toggle-thread t]
    ["Stick" wl-summary-stick t]
    ("Sort"
     ["By Number" wl-summary-sort-by-number t]
     ["By Date" wl-summary-sort-by-date t]
     ["By From" wl-summary-sort-by-from t]
     ["By Subject" wl-summary-sort-by-subject t])
    "----"
    ("Message Operation"
     ["Mark as read"    wl-summary-mark-as-read t]
     ["Mark as important" wl-summary-mark-as-important t]
     ["Mark as unread"   wl-summary-mark-as-unread t]
     ["Set delete mark" wl-summary-delete t]
     ["Set refile mark" wl-summary-refile t]
     ["Set copy mark"   wl-summary-copy t]
     ["Prefetch"        wl-summary-prefetch t]
     ["Set target mark" wl-summary-target-mark t]
     ["Unmark"          wl-summary-unmark t]
     ["Save"		wl-summary-save t]
     ["Cancel posted news" wl-summary-cancel-message t]
     ["Supersedes message" wl-summary-supersedes-message t]
     ["Resend bounced mail" wl-summary-resend-bounced-mail t]
     ["Resend message" wl-summary-resend-message t]
     ["Enter the message" wl-summary-jump-to-current-message t]
     ["Pipe message" wl-summary-pipe-message t]
     ["Print message" wl-summary-print-message t])
    ("Thread Operation"
     ["Open or Close" wl-thread-open-close (eq wl-summary-buffer-view 'thread)]
     ["Open all"     wl-thread-open-all (eq wl-summary-buffer-view 'thread)]
     ["Close all"    wl-thread-close-all (eq wl-summary-buffer-view 'thread)]
     ["Mark as read" wl-thread-mark-as-read (eq wl-summary-buffer-view 'thread)]
     ["Mark as important"	wl-thread-mark-as-important (eq wl-summary-buffer-view 'thread)]
     ["Mark as unread"		wl-thread-mark-as-unread (eq wl-summary-buffer-view 'thread)]
     ["Set delete mark"  wl-thread-delete (eq wl-summary-buffer-view 'thread)]
     ["Set refile mark"  wl-thread-refile (eq wl-summary-buffer-view 'thread)]
     ["Set copy mark"    wl-thread-copy (eq wl-summary-buffer-view 'thread)]
     ["Prefetch"     wl-thread-prefetch (eq wl-summary-buffer-view 'thread)]
     ["Set target mark"        wl-thread-target-mark (eq wl-summary-buffer-view 'thread)]
     ["Unmark"      wl-thread-unmark (eq wl-summary-buffer-view 'thread)]
     ["Save"		wl-thread-save (eq wl-summary-buffer-view 'thread)]
     ["Execute"      wl-thread-exec (eq wl-summary-buffer-view 'thread)])
    ("Region Operation"
     ["Mark as read" wl-summary-mark-as-read-region t]
     ["Mark as important" wl-summary-mark-as-important-region t]
     ["Mark as unread" wl-summary-mark-as-unread-region t]
     ["Set delete mark" wl-summary-delete-region t]
     ["Set refile mark" wl-summary-refile-region t]
     ["Set copy mark" wl-summary-copy-region t]
     ["Prefetch" wl-summary-prefetch-region t]
     ["Set target mark" wl-summary-target-mark-region t]
     ["Unmark" wl-summary-unmark-region t]
     ["Save" wl-summary-save-region t]
     ["Execute" wl-summary-exec-region t])
    ("Mark Operation"
     ["Mark as read" wl-summary-target-mark-mark-as-read t]
     ["Mark as important" wl-summary-target-mark-mark-as-important t]
     ["Mark as unread" wl-summary-target-mark-mark-as-unread t]
     ["Set delete mark" wl-summary-target-mark-delete t]
     ["Set refile mark" wl-summary-target-mark-refile t]
     ["Set copy mark" wl-summary-target-mark-copy t]
     ["Prefetch" wl-summary-target-mark-prefetch t]
     ["Save" wl-summary-target-mark-save t]
     ["Reply with citation" wl-summary-target-mark-reply-with-citation t]
     ["Forward" wl-summary-target-mark-forward t]
     ["uudecode" wl-summary-target-mark-uudecode t])
    ("Score Operation"
     ["Switch current score file" wl-score-change-score-file t]
     ["Edit current score file" wl-score-edit-current-scores t]
     ["Edit score file" wl-score-edit-file t]
     ["Set mark below" wl-score-set-mark-below t]
     ["Set expunge below" wl-score-set-expunge-below t]
     ["Rescore buffer" wl-summary-rescore t]
     ["Increase score" wl-summary-increase-score t]
     ["Lower score" wl-summary-lower-score t])
    "----"
    ("Writing Messages"
     ["Write a message" wl-summary-write t]
     ["Reply" wl-summary-reply t]
     ["Reply with citation" wl-summary-reply-with-citation t]
     ["Forward" wl-summary-forward t])
    "----"
    ["Toggle Plug Status" wl-toggle-plugged t]
    ["Change Plug Status" wl-plugged-change t]
    "----"
    ["Exit Current Folder" wl-summary-exit t]))

(if wl-on-xemacs
    (defun wl-summary-setup-mouse ()
      (define-key wl-summary-mode-map 'button4 'wl-summary-prev)
      (define-key wl-summary-mode-map 'button5 'wl-summary-next)
      (define-key wl-summary-mode-map [(shift button4)]
	'wl-summary-up)
      (define-key wl-summary-mode-map [(shift button5)]
	'wl-summary-down)
      (define-key wl-summary-mode-map 'button2 'wl-summary-click))
  (defun wl-summary-setup-mouse ()
    (define-key wl-summary-mode-map [mouse-4] 'wl-summary-prev)
    (define-key wl-summary-mode-map [mouse-5] 'wl-summary-next)
    (define-key wl-summary-mode-map [S-mouse-4] 'wl-summary-up)
    (define-key wl-summary-mode-map [S-mouse-5] 'wl-summary-down)
    (define-key wl-summary-mode-map [mouse-2] 'wl-summary-click)))

(if wl-summary-mode-map
    ()
  (setq wl-summary-mode-map (make-sparse-keymap))
  (define-key wl-summary-mode-map " "    'wl-summary-read)
  (define-key wl-summary-mode-map "."    'wl-summary-redisplay)
  (define-key wl-summary-mode-map "<"    'wl-summary-display-top)
  (define-key wl-summary-mode-map ">"    'wl-summary-display-bottom)
  (define-key wl-summary-mode-map "\177" 'wl-summary-prev-page)
  (define-key wl-summary-mode-map [backspace] 'wl-summary-prev-page)
  (define-key wl-summary-mode-map "\r"   'wl-summary-next-line-content)
  (define-key wl-summary-mode-map "\C-m" 'wl-summary-next-line-content)
  (define-key wl-summary-mode-map "/"    'wl-thread-open-close)
  (define-key wl-summary-mode-map "["    'wl-thread-open-all)
  (define-key wl-summary-mode-map "]"    'wl-thread-close-all)
  (define-key wl-summary-mode-map "-"    'wl-summary-prev-line-content)
  (define-key wl-summary-mode-map "\e\r" 'wl-summary-prev-line-content)
  (define-key wl-summary-mode-map "g"    'wl-summary-goto-folder)
  (define-key wl-summary-mode-map "c"    'wl-summary-mark-as-read-all)
;  (define-key wl-summary-mode-map "D"    'wl-summary-drop-unsync)

  (define-key wl-summary-mode-map "a"    'wl-summary-reply)
  (define-key wl-summary-mode-map "A"    'wl-summary-reply-with-citation)
  (define-key wl-summary-mode-map "C"    'wl-summary-cancel-message)
  (define-key wl-summary-mode-map "E"    'wl-summary-reedit)
  (define-key wl-summary-mode-map "\eE"  'wl-summary-resend-bounced-mail)
  (define-key wl-summary-mode-map "f"    'wl-summary-forward)
  (define-key wl-summary-mode-map "$"    'wl-summary-mark-as-important)
  (define-key wl-summary-mode-map "@"    'wl-summary-edit-addresses)

  (define-key wl-summary-mode-map "y"    'wl-summary-save)
  (define-key wl-summary-mode-map "n"    'wl-summary-next)
  (define-key wl-summary-mode-map "p"    'wl-summary-prev)
  (define-key wl-summary-mode-map "N"    'wl-summary-down)
  (define-key wl-summary-mode-map "P"    'wl-summary-up)
;;;(define-key wl-summary-mode-map "w"    'wl-draft)
  (define-key wl-summary-mode-map "w"    'wl-summary-write)
  (define-key wl-summary-mode-map "W"    'wl-summary-write-current-folder)
;;;(define-key wl-summary-mode-map "e"     'wl-draft-open-file)
  (define-key wl-summary-mode-map "e"     'wl-summary-save)
  (define-key wl-summary-mode-map "\C-c\C-o" 'wl-jump-to-draft-buffer)
  (define-key wl-summary-mode-map "\C-c\C-a" 'wl-addrmgr)
  (define-key wl-summary-mode-map "H"    'wl-summary-redisplay-all-header)
  (define-key wl-summary-mode-map "M"    'wl-summary-redisplay-no-mime)
  (define-key wl-summary-mode-map "B"    'wl-summary-burst)
  (define-key wl-summary-mode-map "Z"    'wl-status-update)
  (define-key wl-summary-mode-map "#"    'wl-summary-print-message)
  (define-key wl-summary-mode-map "|"    'wl-summary-pipe-message)
  (define-key wl-summary-mode-map "q"    'wl-summary-exit)
  (define-key wl-summary-mode-map "Q"    'wl-summary-force-exit)

  (define-key wl-summary-mode-map "j"    'wl-summary-jump-to-current-message)
  (define-key wl-summary-mode-map "J"    'wl-thread-jump-to-msg)
  (define-key wl-summary-mode-map "I"    'wl-summary-incorporate)
  (define-key wl-summary-mode-map "\M-j" 'wl-summary-jump-to-msg-by-message-id)
  (define-key wl-summary-mode-map "^"    'wl-summary-jump-to-parent-message)
  (define-key wl-summary-mode-map "!"    'wl-summary-mark-as-unread)

  (define-key wl-summary-mode-map "s"    'wl-summary-sync)
  (define-key wl-summary-mode-map "S"    'wl-summary-sort)
  (define-key wl-summary-mode-map "\M-s"    'wl-summary-stick)
  (define-key wl-summary-mode-map "T"    'wl-summary-toggle-thread)

  (define-key wl-summary-mode-map "l"    'wl-summary-toggle-disp-folder)
  (define-key wl-summary-mode-map "v"    'wl-summary-toggle-disp-msg)
  (define-key wl-summary-mode-map "V"    'wl-summary-virtual)

  (define-key wl-summary-mode-map "\C-i"  'wl-summary-goto-last-displayed-msg)
  (define-key wl-summary-mode-map "?"    'wl-summary-pick)
  (define-key wl-summary-mode-map "\ee"  'wl-summary-expire)

  ;; copy & paste.
  (define-key wl-summary-mode-map "\ew"  'wl-summary-save-current-message)
  (define-key wl-summary-mode-map "\C-y"  'wl-summary-yank-saved-message)

  ;; line commands
  (define-key wl-summary-mode-map "R"    'wl-summary-mark-as-read)
  (define-key wl-summary-mode-map "i"    'wl-summary-prefetch)
  (define-key wl-summary-mode-map "x"    'wl-summary-exec)
  (define-key wl-summary-mode-map "*"    'wl-summary-target-mark)
  (define-key wl-summary-mode-map "o"    'wl-summary-refile)
  (define-key wl-summary-mode-map "O"    'wl-summary-copy)
  (define-key wl-summary-mode-map "\M-o" 'wl-summary-refile-prev-destination)
;  (define-key wl-summary-mode-map "\M-O" 'wl-summary-copy-prev-destination)
  (define-key wl-summary-mode-map "\C-o" 'wl-summary-auto-refile)
  (define-key wl-summary-mode-map "d"    'wl-summary-delete)
  (define-key wl-summary-mode-map "u"    'wl-summary-unmark)
  (define-key wl-summary-mode-map "U"    'wl-summary-unmark-all)

  ;; thread commands
  (define-key wl-summary-mode-map "t"	(make-sparse-keymap))
  (define-key wl-summary-mode-map "tR" 'wl-thread-mark-as-read)
  (define-key wl-summary-mode-map "ti" 'wl-thread-prefetch)
  (define-key wl-summary-mode-map "tx" 'wl-thread-exec)
  (define-key wl-summary-mode-map "t*" 'wl-thread-target-mark)
  (define-key wl-summary-mode-map "to" 'wl-thread-refile)
  (define-key wl-summary-mode-map "tO" 'wl-thread-copy)
  (define-key wl-summary-mode-map "td" 'wl-thread-delete)
  (define-key wl-summary-mode-map "tu" 'wl-thread-unmark)
  (define-key wl-summary-mode-map "t!" 'wl-thread-mark-as-unread)
  (define-key wl-summary-mode-map "t$" 'wl-thread-mark-as-important)
  (define-key wl-summary-mode-map "ty" 'wl-thread-save)
  (define-key wl-summary-mode-map "ts" 'wl-thread-set-parent)

  ;; target-mark commands
  (define-key wl-summary-mode-map "m"	  (make-sparse-keymap))
  (define-key wl-summary-mode-map "mi"   'wl-summary-target-mark-prefetch)
  (define-key wl-summary-mode-map "mR"   'wl-summary-target-mark-mark-as-read)
  (define-key wl-summary-mode-map "mo"   'wl-summary-target-mark-refile)
  (define-key wl-summary-mode-map "mO"   'wl-summary-target-mark-copy)
  (define-key wl-summary-mode-map "md"   'wl-summary-target-mark-delete)
  (define-key wl-summary-mode-map "my"   'wl-summary-target-mark-save)
  (define-key wl-summary-mode-map "m!"   'wl-summary-target-mark-mark-as-unread)
  (define-key wl-summary-mode-map "m$"   'wl-summary-target-mark-mark-as-important)
  (define-key wl-summary-mode-map "mu"   'wl-summary-delete-all-temp-marks)
  (define-key wl-summary-mode-map "mU"   'wl-summary-target-mark-uudecode)
  (define-key wl-summary-mode-map "ma"   'wl-summary-target-mark-all)
  (define-key wl-summary-mode-map "mt"   'wl-summary-target-mark-thread)
  (define-key wl-summary-mode-map "mA"   'wl-summary-target-mark-reply-with-citation)
  (define-key wl-summary-mode-map "mf"   'wl-summary-target-mark-forward)
  (define-key wl-summary-mode-map "m?"   'wl-summary-target-mark-pick)

  ;; region commands
  (define-key wl-summary-mode-map "r"    (make-sparse-keymap))
  (define-key wl-summary-mode-map "rR"   'wl-summary-mark-as-read-region)
  (define-key wl-summary-mode-map "ri"   'wl-summary-prefetch-region)
  (define-key wl-summary-mode-map "rx"   'wl-summary-exec-region)
  (define-key wl-summary-mode-map "mr"   'wl-summary-target-mark-region)
  (define-key wl-summary-mode-map "r*"   'wl-summary-target-mark-region)
  (define-key wl-summary-mode-map "ro"   'wl-summary-refile-region)
  (define-key wl-summary-mode-map "rO"   'wl-summary-copy-region)
  (define-key wl-summary-mode-map "rd"   'wl-summary-delete-region)
  (define-key wl-summary-mode-map "ru"   'wl-summary-unmark-region)
  (define-key wl-summary-mode-map "r!"   'wl-summary-mark-as-unread-region)
  (define-key wl-summary-mode-map "r$"   'wl-summary-mark-as-important-region)
  (define-key wl-summary-mode-map "ry"   'wl-summary-save-region)

  ;; score commands
  (define-key wl-summary-mode-map "K"    'wl-summary-increase-score)
  (define-key wl-summary-mode-map "L"    'wl-summary-lower-score)
  (define-key wl-summary-mode-map "h"    (make-sparse-keymap))
  (define-key wl-summary-mode-map "hR"   'wl-summary-rescore)
  (define-key wl-summary-mode-map "hc"   'wl-score-change-score-file)
  (define-key wl-summary-mode-map "he"   'wl-score-edit-current-scores)
  (define-key wl-summary-mode-map "hf"   'wl-score-edit-file)
  (define-key wl-summary-mode-map "hF"   'wl-score-flush-cache)
  (define-key wl-summary-mode-map "hm"	 'wl-score-set-mark-below)
  (define-key wl-summary-mode-map "hx"   'wl-score-set-expunge-below)

  (define-key wl-summary-mode-map "\M-t" 'wl-toggle-plugged)
  (define-key wl-summary-mode-map "\C-t" 'wl-plugged-change)
  ;;
  (wl-summary-setup-mouse)
  (easy-menu-define
   wl-summary-mode-menu
   wl-summary-mode-map
   "Menu used in Summary mode."
   wl-summary-mode-menu-spec))

(defun wl-status-update ()
  (interactive)
  (wl-address-init))

(defun wl-summary-display-top ()
  (interactive)
  (goto-char (point-min))
  (if wl-summary-buffer-disp-msg
      (wl-summary-redisplay)))

(defun wl-summary-display-bottom ()
  (interactive)
  (goto-char (point-max))
  (forward-line -1)
  (if wl-summary-buffer-disp-msg
      (wl-summary-redisplay)))

(defun wl-summary-count-unread (mark-alist)
  (let ((new 0)
	(unread 0)
	mark)
    (while mark-alist
      (setq mark (cadr (car mark-alist)))
      (and mark
	   (cond
	    ((string= mark wl-summary-new-mark)
	     (setq new (+ 1 new)))
	    ((or (string= mark wl-summary-unread-uncached-mark)
		 (string= mark wl-summary-unread-cached-mark))
	     (setq unread (+ 1 unread)))))
      (setq mark-alist (cdr mark-alist)))
    (if (eq major-mode 'wl-summary-mode)
	(setq wl-summary-buffer-new-count new
	      wl-summary-buffer-unread-count unread))
    (cons new unread)))

(defun wl-summary-message-string (&optional use-cache)
  "Return full body string of current message.
If optional USE-CACHE is non-nil, use cache if exists."
  (let ((number (wl-summary-message-number))
	(folder wl-summary-buffer-elmo-folder))
    (if (null number)
	(message "No message.")
      (elmo-set-work-buf
       (elmo-message-fetch folder
			   number
			   (elmo-make-fetch-strategy
			    'entire
			    use-cache ; use cache
			    nil ; save cache (should `t'?)
			    (and
			     use-cache
			     (elmo-file-cache-get-path
			      (elmo-message-field folder number 'message-id))))
			   nil
			   (current-buffer)
			   'unread)
       (buffer-string)))))

(defun wl-summary-reedit (&optional arg)
  "Re-edit current message.
If ARG is non-nil, Supersedes message"
  (interactive "P")
  (if arg
      (wl-summary-supersedes-message)
    (if (string= (wl-summary-buffer-folder-name) wl-draft-folder)
	(if (wl-summary-message-number)
	    (progn
	      (wl-draft-reedit (wl-summary-message-number))
	      (if (wl-message-news-p)
		  (mail-position-on-field "Newsgroups")
		(mail-position-on-field "To"))
	      (delete-other-windows)))
      (wl-draft-edit-string (wl-summary-message-string)))))

(defun wl-summary-resend-bounced-mail ()
  "Re-mail the current message.
This only makes sense if the current message is a bounce message which
contains some mail you have written but has been bounced back to
you."
  (interactive)
  (save-excursion
    (wl-summary-set-message-buffer-or-redisplay)
    (set-buffer (wl-message-get-original-buffer))
    (goto-char (point-min))
    (let ((case-fold-search nil))
      (cond
       ((and
	 (re-search-forward
	  (concat "^\\($\\|[Cc]ontent-[Tt]ype:[ \t]+multipart/\\(report\\|mixed\\)\\)") nil t)
	 (not (bolp))
	 (re-search-forward "boundary=\"\\([^\"]+\\)\"" nil t))
	(let ((boundary (buffer-substring (match-beginning 1) (match-end 1)))
	      start)
	  (cond
	   ((and (setq start (re-search-forward
			      (concat "^--" boundary "\n"
				      "\\([Cc]ontent-[Dd]escription:.*\n\\)?"
				      "[Cc]ontent-[Tt]ype:[ \t]+"
				      "\\(message/rfc822\\|text/rfc822-headers\\)\n"
				      "\\(.+\n\\)*\n") nil t))
		 (re-search-forward
		  (concat "\n\\(--" boundary "\\)--\n") nil t))
	    (wl-draft-edit-string (buffer-substring start (match-beginning 1))))
	   (t
	    (message "Seems no message/rfc822 part.")))))
       ((let ((case-fold-search t))
	  (re-search-forward wl-rejected-letter-start nil t))
	(skip-chars-forward " \t\n")
	(wl-draft-edit-string (buffer-substring (point) (point-max))))
       (t
	(message "Does not appear to be a rejected letter."))))))

(defun wl-summary-resend-message (address)
  "Resend the current message to ADDRESS."
  (interactive "sResend message to: ")
  (if (or (null address) (string-match "^[ \t]*$" address))
      (message "No address specified.")
    (message "Resending message to %s..." address)
    (save-excursion
      (let ((original (wl-summary-get-original-buffer)))
	;; We first set up a normal mail buffer.
	(set-buffer (get-buffer-create " *wl-draft-resend*"))
	(buffer-disable-undo (current-buffer))
	(erase-buffer)
	(setq wl-sent-message-via nil)
	;; Insert our usual headers.
	(wl-draft-insert-from-field)
	(wl-draft-insert-date-field)
	(insert "to: " address "\n")
	(goto-char (point-min))
	;; Rename them all to "Resent-*".
	(while (re-search-forward "^[A-Za-z]" nil t)
	  (forward-char -1)
	  (insert "Resent-"))
	(widen)
	(forward-line)
	(delete-region (point) (point-max))
	(let ((beg  (point)))
	  ;; Insert the message to be resent.
	  (insert-buffer-substring original)
	  (goto-char (point-min))
	  (search-forward "\n\n")
	  (forward-char -1)
	  (save-restriction
	    (narrow-to-region beg (point))
	    (wl-draft-delete-fields wl-ignored-resent-headers)
	    (goto-char (point-max)))
	  (insert mail-header-separator)
	  ;; Rename all old ("Previous-")Resent headers.
	  (while (re-search-backward "^\\(Previous-\\)*Resent-" beg t)
	    (beginning-of-line)
	    (insert "Previous-"))
	  ;; Quote any "From " lines at the beginning.
	  (goto-char beg)
	  (when (looking-at "From ")
	    (replace-match "X-From-Line: ")))
	;; Send it.
	(wl-draft-dispatch-message)
	(kill-buffer (current-buffer)))
      (message "Resending message to %s...done" address))))

(defun wl-summary-buffer-set-folder (folder)
  (if (stringp folder)
      (setq folder (wl-folder-get-elmo-folder folder)))
  (setq wl-summary-buffer-elmo-folder folder)
  (setq wl-summary-buffer-folder-indicator
	(if (memq 'modeline wl-use-folder-petname)
	    (wl-folder-get-petname (elmo-folder-name-internal folder))
	  (elmo-folder-name-internal folder)))
  (make-local-variable 'wl-message-buffer)
  (setq wl-summary-buffer-mime-charset (or (wl-get-assoc-list-value
					    wl-folder-mime-charset-alist
					    (elmo-folder-name-internal folder))
					   wl-mime-charset))
  (setq wl-summary-buffer-weekday-name-lang
	(or (wl-get-assoc-list-value
	     wl-folder-weekday-name-lang-alist
	     (elmo-folder-name-internal folder))
	    wl-summary-weekday-name-lang))
  (setq wl-summary-buffer-thread-indent-set
	(wl-get-assoc-list-value
	 wl-folder-thread-indent-set-alist
	 (elmo-folder-name-internal folder)))
  (setq wl-summary-buffer-persistent
	(wl-folder-persistent-p (elmo-folder-name-internal folder)))
  (elmo-folder-set-persistent-internal folder wl-summary-buffer-persistent)
  ;; process duplicates.
  (elmo-folder-set-process-duplicates-internal
   folder (cdr (elmo-string-matched-assoc
		(elmo-folder-name-internal folder)
		wl-folder-process-duplicates-alist)))
  (setq
   wl-thread-indent-level-internal
   (or (nth 0 wl-summary-buffer-thread-indent-set)
       wl-thread-indent-level)
   wl-thread-have-younger-brother-str-internal
   (or (nth 1 wl-summary-buffer-thread-indent-set)
       wl-thread-have-younger-brother-str)
   wl-thread-youngest-child-str-internal
   (or (nth 2 wl-summary-buffer-thread-indent-set)
       wl-thread-youngest-child-str)
   wl-thread-vertical-str-internal
   (or (nth 3 wl-summary-buffer-thread-indent-set)
       wl-thread-vertical-str)
   wl-thread-horizontal-str-internal
   (or (nth 4 wl-summary-buffer-thread-indent-set)
       wl-thread-horizontal-str)
   wl-thread-space-str-internal
   (or (nth 5 wl-summary-buffer-thread-indent-set)
       wl-thread-space-str))
  (setq wl-thread-indent-regexp
	(concat
	 (regexp-quote wl-thread-have-younger-brother-str-internal) "\\|"
	 (regexp-quote wl-thread-youngest-child-str-internal) "\\|"
	 (regexp-quote wl-thread-vertical-str-internal) "\\|"
	 (regexp-quote wl-thread-horizontal-str-internal) "\\|"
	 (regexp-quote wl-thread-space-str-internal)))
  (run-hooks 'wl-summary-buffer-set-folder-hook))

(defun wl-summary-mode ()
  "Major mode for reading threaded messages.
See Info under Wanderlust for full documentation.

Special commands:
\\{wl-summary-mode-map}

Entering Folder mode calls the value of `wl-summary-mode-hook'."
  (interactive)
  (unless (interactive-p) (kill-all-local-variables))
  (setq major-mode 'wl-summary-mode)
  (setq mode-name "Summary")
  (use-local-map wl-summary-mode-map)
;;;(setq default-directory (or wl-tmp-dir (expand-file-name "~/")))
  (setq buffer-read-only t)
  (setq truncate-lines t)
;;;(make-local-variable 'tab-width)
;;;(setq tab-width 1)
  (buffer-disable-undo (current-buffer))
  (wl-mode-line-buffer-identification '("Wanderlust: "
					wl-summary-buffer-folder-indicator
					wl-summary-buffer-unread-status))
  (easy-menu-add wl-summary-mode-menu)
  (when wl-summary-lazy-highlight
    (make-local-variable 'window-scroll-functions)
    (add-hook 'window-scroll-functions 'wl-highlight-summary-window))
  ;; This hook may contain the function `wl-setup-summary' for reasons
  ;; of system internal to accord facilities for the Emacs variants.
  (run-hooks 'wl-summary-mode-hook))

(defun wl-summary-overview-entity-compare-by-date (x y)
  "Compare entity X and Y by date."
  (condition-case nil
      (string<
       (timezone-make-date-sortable
	(elmo-msgdb-overview-entity-get-date x))
       (timezone-make-date-sortable
	(elmo-msgdb-overview-entity-get-date y)))
    (error))) ;; ignore error.

(defun wl-summary-overview-entity-compare-by-number (x y)
   "Compare entity X and Y by number."
  (<
   (elmo-msgdb-overview-entity-get-number x)
   (elmo-msgdb-overview-entity-get-number y)))

(defun wl-summary-overview-entity-compare-by-from (x y)
  "Compare entity X and Y by from."
  (string<
   (wl-address-header-extract-address
    (or (elmo-msgdb-overview-entity-get-from-no-decode x)
	wl-summary-no-from-message))
   (wl-address-header-extract-address
    (or (elmo-msgdb-overview-entity-get-from-no-decode y)
	wl-summary-no-from-message))))

(defun wl-summary-overview-entity-compare-by-subject (x y)
  "Compare entity X and Y by subject."
  (string< (elmo-msgdb-overview-entity-get-subject-no-decode x)
	   (elmo-msgdb-overview-entity-get-subject-no-decode y)))

(defun wl-summary-sort-by-date ()
  (interactive)
  (wl-summary-rescan "date"))
(defun wl-summary-sort-by-number ()
  (interactive)
  (wl-summary-rescan "number"))
(defun wl-summary-sort-by-subject ()
  (interactive)
  (wl-summary-rescan "subject"))
(defun wl-summary-sort-by-from ()
  (interactive)
  (wl-summary-rescan "from"))

(defun wl-summary-rescan (&optional sort-by)
  "Rescan current folder without updating."
  (interactive)
  (let* ((cur-buf (current-buffer))
	 (msgdb (wl-summary-buffer-msgdb))
	 (overview (elmo-msgdb-get-overview msgdb))
	 (number-alist (elmo-msgdb-get-number-alist msgdb))
	 (mark-alist (elmo-msgdb-get-mark-alist msgdb))
	 (elmo-mime-charset wl-summary-buffer-mime-charset)
	 i percent num
	 gc-message entity
	 curp
	 (inhibit-read-only t)
	 (buffer-read-only nil)
	 expunged)
    (fset 'wl-summary-append-message-func-internal
	  (wl-summary-get-append-message-func))
    (wl-summary-buffer-number-column-detect nil)
    (erase-buffer)
    (message "Re-scanning...")
    (setq i 0)
    (setq num (length overview))
    (when sort-by
      (message "Sorting by %s..." sort-by)
      (setq overview
	    (sort overview
		  (intern (format "wl-summary-overview-entity-compare-by-%s"
				  sort-by))))
      (message "Sorting by %s...done" sort-by)
      (elmo-msgdb-set-overview (wl-summary-buffer-msgdb)
			       overview))
    (setq curp overview)
    (set-buffer cur-buf)
    (setq wl-thread-entity-hashtb (elmo-make-hash (* (length overview) 2)))
    (setq wl-thread-entity-list nil)
    (setq wl-thread-entities nil)
    (setq wl-summary-buffer-number-list nil)
    (setq wl-summary-buffer-target-mark-list nil)
    (setq wl-summary-buffer-refile-list nil)
    (setq wl-summary-buffer-delete-list nil)
    (setq wl-summary-delayed-update nil)
    (elmo-kill-buffer wl-summary-search-buf-name)
    (message "Constructing summary structure...")
    (while curp
      (setq entity (car curp))
      (wl-summary-append-message-func-internal entity overview mark-alist
					       nil)
      (setq curp (cdr curp))
      (when (> num elmo-display-progress-threshold)
	(setq i (+ i 1))
	(if (or (zerop (% i 5)) (= i num))
	    (elmo-display-progress
	     'wl-summary-rescan "Constructing summary structure..."
	     (/ (* i 100) num)))))
    (when wl-summary-delayed-update
      (while wl-summary-delayed-update
	(message "Parent (%d) of message %d is no entity"
		 (caar wl-summary-delayed-update)
		 (elmo-msgdb-overview-entity-get-number
		  (cdar wl-summary-delayed-update)))
	(wl-summary-append-message-func-internal
	 (cdar wl-summary-delayed-update)
	 overview mark-alist nil t)
	(setq wl-summary-delayed-update (cdr wl-summary-delayed-update))))
    (message "Constructing summary structure...done")
    (set-buffer cur-buf)
    (if (eq wl-summary-buffer-view 'thread)
	(progn
	  (message "Inserting thread...")
	  (wl-thread-insert-top)
	  (message "Inserting thread...done"))
      (wl-summary-make-number-list))
    (when wl-use-scoring
      (setq wl-summary-scored nil)
      (wl-summary-score-headers nil msgdb
				(wl-summary-rescore-msgs number-alist)
				t)
      (when (and wl-summary-scored
		 (setq expunged (wl-summary-score-update-all-lines)))
	(message "%d message(s) are expunged by scoring." (length expunged))))
    (wl-summary-set-message-modified)
    (wl-summary-count-unread
     (elmo-msgdb-get-mark-alist
      (elmo-folder-msgdb wl-summary-buffer-elmo-folder)))
    (wl-summary-update-modeline)
    (goto-char (point-max))
    (forward-line -1)
    (set-buffer-modified-p nil)))

(defun wl-summary-next-folder-or-exit (&optional next-entity upward)
  (if (and next-entity
	   wl-auto-select-next)
      (let (retval)
	(wl-summary-toggle-disp-msg 'off)
	(unwind-protect
	    (setq retval
		  (wl-summary-goto-folder-subr next-entity
					       'force-update
					       nil
					       nil ; not sticky
					       t   ; interactive!
					       ))
	  (wl-folder-set-current-entity-id (wl-folder-get-entity-id next-entity))
	  (if (and (eq retval 'more-next)
		   (memq wl-auto-select-next '(unread skip-no-unread))
		   (memq this-command wl-summary-next-no-unread-command))
	      (if upward
		  (wl-summary-up
		   t (eq wl-auto-select-next 'skip-no-unread))
		(goto-char (point-max))
		(forward-line -1)
		(wl-summary-down
		 t (eq wl-auto-select-next 'skip-no-unread))))))
    (wl-summary-exit)))

(defun wl-summary-entity-info-msg (entity finfo)
  (or (and entity
	   (concat
	    (elmo-replace-in-string
	     (if (memq 'ask-folder wl-use-folder-petname)
		 (wl-folder-get-petname entity)
	       entity)
	     "%" "%%")
	    (if (null (car finfo))
		" (? new/? unread)"
	      (format
	       " (%d new/%d unread)"
	       (nth 0 finfo)
	       (+ (nth 0 finfo)
		  (nth 1 finfo))))))
      "folder mode"))

(defun wl-summary-set-message-modified ()
  (elmo-folder-set-message-modified-internal
   wl-summary-buffer-elmo-folder t)
  (setq wl-summary-buffer-message-modified t))
(defun wl-summary-message-modified-p ()
  wl-summary-buffer-message-modified)
(defun wl-summary-set-mark-modified ()
  (elmo-folder-set-mark-modified-internal
   wl-summary-buffer-elmo-folder t)
  (setq wl-summary-buffer-mark-modified t))
(defun wl-summary-mark-modified-p ()
  wl-summary-buffer-mark-modified)
(defun wl-summary-set-thread-modified ()
  (setq wl-summary-buffer-thread-modified t))
(defun wl-summary-thread-modified-p ()
  wl-summary-buffer-thread-modified)

(defsubst wl-summary-cleanup-temp-marks (&optional sticky)
  (if (or wl-summary-buffer-refile-list
	  wl-summary-buffer-copy-list
	  wl-summary-buffer-delete-list)
      (if (y-or-n-p "Marks remain to be executed.  Execute them? ")
	  (progn
	    (wl-summary-exec)
	    (if (or wl-summary-buffer-refile-list
		    wl-summary-buffer-copy-list
		    wl-summary-buffer-delete-list)
		(error "Some execution was failed")))
	;; delete temp-marks
	(message "")
	(wl-summary-delete-all-refile-marks)
	(wl-summary-delete-all-copy-marks)
	(wl-summary-delete-all-delete-marks)))
  (if wl-summary-buffer-target-mark-list
      (progn
	(wl-summary-delete-all-target-marks)
	(setq wl-summary-buffer-target-mark-list nil)))
  (wl-summary-delete-all-temp-marks-on-buffer sticky)
  (setq wl-summary-scored nil))

;; a subroutine for wl-summary-exit/wl-save-status
;; Note that folder is not commited here.
(defun wl-summary-save-view ()
  ;; already in summary buffer.
  (when wl-summary-buffer-persistent
    ;; save the current summary buffer view.
    (if (and wl-summary-cache-use
	     (or (wl-summary-message-modified-p)
		 (wl-summary-mark-modified-p)
		 (wl-summary-thread-modified-p)))
	(wl-summary-save-view-cache))))

(defun wl-summary-force-exit ()
  "Exit current summary.  Buffer is deleted even the buffer is sticky."
  (interactive)
  (wl-summary-exit 'force-exit))

(defun wl-summary-exit (&optional force-exit)
  "Exit current summary.  if FORCE-EXIT, exits even the summary is sticky."
  (interactive "P")
  (let ((summary-buf (current-buffer))
	(sticky (wl-summary-sticky-p))
	summary-win
	message-buf message-win
	folder-buf folder-win)
    (run-hooks 'wl-summary-exit-pre-hook)
    (if wl-summary-buffer-exit-function
	(funcall wl-summary-buffer-exit-function)
      (wl-summary-cleanup-temp-marks sticky)
      (unwind-protect
	  ;; save summary status
	  (progn
	    (wl-summary-save-view)
	    (if (or force-exit (not sticky))
		(elmo-folder-close wl-summary-buffer-elmo-folder)
	      (elmo-folder-commit wl-summary-buffer-elmo-folder)
	      (elmo-folder-check wl-summary-buffer-elmo-folder))
	    (if wl-use-scoring (wl-score-save)))
	;; for sticky summary
	(wl-delete-all-overlays)
	(setq wl-summary-buffer-disp-msg nil)
	(elmo-kill-buffer wl-summary-search-buf-name)
	;; delete message window if displayed.
	(if (and wl-message-buffer (get-buffer-window wl-message-buffer))
	    (delete-window (get-buffer-window wl-message-buffer)))
	(if (and wl-summary-use-frame
		 (> (length (visible-frame-list)) 1))
	    (delete-frame))
	(if (setq folder-buf (get-buffer wl-folder-buffer-name))
	    (if wl-summary-use-frame
		(let (select-frame)
		  (save-selected-window
		    (dolist (frame (visible-frame-list))
		      (select-frame frame)
		      (if (get-buffer-window folder-buf)
			  (setq select-frame frame))))
		  (if select-frame
		      (select-frame select-frame)
		    (switch-to-buffer folder-buf)))
	      (if (setq folder-win (get-buffer-window folder-buf))
		  ;; folder win is already displayed.
		  (select-window folder-win)
		;; folder win is not displayed.
		(switch-to-buffer folder-buf)))
	  ;; currently no folder buffer
	  (wl-folder))
	(and wl-folder-move-cur-folder
	     wl-folder-buffer-cur-point
	     (goto-char wl-folder-buffer-cur-point))
	(setq wl-folder-buffer-cur-path nil)
	(setq wl-folder-buffer-cur-entity-id nil)
	(wl-delete-all-overlays)
	(if wl-summary-exit-next-move
	    (wl-folder-next-unsync t)
	  (beginning-of-line))
	(if (setq summary-win (get-buffer-window summary-buf))
	    (delete-window summary-win))
	(if (or force-exit
		(not sticky))
	    (progn
	      (set-buffer summary-buf)
	      (kill-buffer summary-buf)))
	(run-hooks 'wl-summary-exit-hook)))))

(defun wl-summary-sync-force-update (&optional unset-cursor no-check)
  (interactive)
  (wl-summary-sync-update unset-cursor nil no-check))

(defsubst wl-summary-sync-all-init ()
  (wl-summary-cleanup-temp-marks)
  (erase-buffer)
  (wl-summary-set-message-modified)
  (wl-summary-set-mark-modified)
  (setq wl-thread-entity-hashtb (elmo-make-hash
				 (* (length (elmo-msgdb-get-number-alist
					     (wl-summary-buffer-msgdb))) 2)))
  (setq wl-thread-entity-list nil)
  (setq wl-thread-entities nil)
  (setq wl-summary-buffer-number-list nil)
  (setq wl-summary-buffer-target-mark-list nil)
  (setq wl-summary-buffer-refile-list nil)
  (setq wl-summary-buffer-copy-list nil)
  (setq wl-summary-buffer-delete-list nil)
  (wl-summary-buffer-number-column-detect nil))

(defun wl-summary-sync (&optional unset-cursor force-range)
  (interactive)
  (let* ((folder wl-summary-buffer-elmo-folder)
	 (inhibit-read-only t)
	 (buffer-read-only nil)
	 (msgdb-dir (elmo-folder-msgdb-path folder))
	 (range (or force-range (wl-summary-input-range
				 (elmo-folder-name-internal folder)))))
    (cond ((string= range "rescan")
	   (let ((msg (wl-summary-message-number)))
	     (wl-summary-rescan)
	     (and msg (wl-summary-jump-to-msg msg))))
	  ((string= range "rescan-noscore")
	   (let ((msg (wl-summary-message-number))
		 wl-use-scoring)
	     (wl-summary-rescan)
	     (and msg (wl-summary-jump-to-msg msg))))
	  ((string= range "cache-status")
	   (let ((msg (wl-summary-message-number)))
	     (wl-summary-resume-cache-status)
	     (and msg (wl-summary-jump-to-msg msg))))
	  ((or (string-match "last:" range)
	       (string-match "first:" range))
	   (wl-summary-goto-folder-subr (concat "/" range "/"
						(elmo-folder-name-internal
						 folder))
	    'force-update nil nil t))
	  (t
	   (wl-summary-sync-update unset-cursor
				   (cond ((string= range "all") 'all)
					 ((string= range "all-visible")
					  'visible-only)))))))

(defvar wl-summary-edit-addresses-candidate-fields
  ;; First element becomes default.
  '("from" "to" "cc"))

(defun wl-summary-edit-addresses-collect-candidate-fields (mime-charset)
  (let ((fields wl-summary-edit-addresses-candidate-fields)
	body candidates components)
    (while fields
      (setq body
	    (mapconcat 'identity (elmo-multiple-field-body (car fields))
		       ","))
      (setq body (wl-parse-addresses body))
      (if body (setq candidates (append candidates body)))
      (setq fields (cdr fields)))
    (setq candidates (elmo-uniq-list candidates))
    (elmo-set-work-buf
     (elmo-set-buffer-multibyte default-enable-multibyte-characters)
     (mapcar (function
	      (lambda (x)
		(setq components (std11-extract-address-components x))
		(cons (nth 1 components)
		      (and (car components)
			   (eword-decode-string
			    (decode-mime-charset-string
			     (car components)
			     mime-charset))))))
	     candidates))))

(defun wl-summary-edit-addresses-subr (the-email name-in-addr)
  ;; returns nil if there's no change.
  (if (elmo-get-hash-val (downcase the-email) wl-address-petname-hash)
      (let (char)
	(message "'%s' already exists. (e)dit/(d)elete/(c)ancel?"
		 the-email)
	(while (not (or (eq (setq char (read-char)) ?\r)
			(eq char ?\n)
			(eq char ? )
			(eq char ?e)
			(eq char ?c)
			(eq char ?d)))
	  (message
	   "Please answer `e' or `d' or `c'. (e)dit/(d)elete/(c)ancel?"))
	(cond
	 ((or (eq char ?e)
	      (eq char ?\n)
	      (eq char ?\r)
	      (eq char ? ))
	  ;; Change Addresses
	  (wl-address-add-or-change
	   the-email
	   (wl-address-header-extract-realname
	    (cdr (assoc
		  (let ((completion-ignore-case t) comp)
		    (setq comp
			  (try-completion the-email wl-address-completion-list))
		    (if (equal comp t) the-email comp))
		  wl-address-completion-list))))
	  "edited")
	 ((eq char ?d)
	  ;; Delete Addresses
	  (if (y-or-n-p (format "Delete '%s'? "
				the-email))
	      (progn
		(wl-address-delete the-email)
		"deleted")
	    (message "")
	    nil))
	 (t (message "")
	    nil)))
    ;; Add Petname
    (wl-address-add-or-change the-email name-in-addr)
    "added"))

(defun wl-summary-edit-addresses (&optional addr-str)
  "Edit address book interactively.
Optional argument ADDR-STR is used as a target address if specified."
  (interactive (if current-prefix-arg
		   (list (read-from-minibuffer "Target address: "))))
  (if (null (wl-summary-message-number))
      (message "No message.")
    (save-excursion
      (let* ((charset wl-summary-buffer-mime-charset)
	     (candidates
	      (with-current-buffer (wl-summary-get-original-buffer)
		(wl-summary-edit-addresses-collect-candidate-fields
		 charset)))
	     address pair result)
	(if addr-str
	    (setq address addr-str)
	  (when candidates
	    (setq address (car (car candidates)))
	    (setq address
		  (completing-read
		   (format "Target address (%s): " address)
		   (mapcar
		    (function (lambda (x) (cons (car x) (car x))))
		    candidates)
		   nil nil nil nil address))))
	(when address
	  (setq pair (assoc address candidates))
	  (unless pair
	    (setq pair (cons address nil)))
	  (when (setq result (wl-summary-edit-addresses-subr (car pair) (cdr pair)))
	    ;; update alias
	    (wl-status-update)
	    (setq address (assoc (car pair) wl-address-list))
	    (if address
		(message "%s, %s, <%s> is %s."
			 (nth 2 address)
			 (nth 1 address)
			 (nth 0 address)
			 result)))
;;; i'd like to update summary-buffer, but...
;;;	(wl-summary-rescan)
	  (run-hooks 'wl-summary-edit-addresses-hook))))))

(defun wl-summary-incorporate (&optional arg)
  "Check and prefetch all uncached messages.
If ARG is non-nil, checking is omitted."
  (interactive "P")
  (unless arg
    (save-excursion
      (wl-summary-sync-force-update)))
  (wl-summary-prefetch-region (point-min) (point-max)
			      wl-summary-incorporate-marks))

(defun wl-summary-prefetch-msg (number &optional arg)
  "Returns status-mark. if skipped, returns nil."
  ;; prefetching procedure.
  (save-excursion
    (let* ((msgdb (wl-summary-buffer-msgdb))
	   (mark-alist (elmo-msgdb-get-mark-alist msgdb))
	   (number-alist (elmo-msgdb-get-number-alist msgdb))
	   (message-id (cdr (assq number number-alist)))
	   (ov (elmo-msgdb-overview-get-entity message-id msgdb))
	   (entity ov)
	   (size (elmo-msgdb-overview-entity-get-size ov))
	   (inhibit-read-only t)
	   (buffer-read-only nil)
	   (file-cached (elmo-file-cache-exists-p message-id))
	   (force-read (and size
			    (or (null wl-prefetch-threshold)
				(< size wl-prefetch-threshold))))
	   mark new-mark)
      (unwind-protect
	  (progn
	    (when (and (or arg (not file-cached))
		       size (not force-read) wl-prefetch-confirm)
	      (setq force-read
		    (save-restriction
		      (widen)
		      (y-or-n-p
		       (format
			"Message from %s has %d bytes.  Prefetch it? "
			(concat
			 "[ "
			 (save-match-data
			   (wl-set-string-width
			    wl-summary-from-width
			    (wl-summary-from-func-internal
			     (eword-decode-string
			      (elmo-delete-char
			       ?\"
			       (or
				(elmo-msgdb-overview-entity-get-from ov)
				"??")))))) " ]")
			size))))
	      (message ""))		; flush.
	    (setq mark (cadr (assq number mark-alist)))
	    (if force-read
		(save-excursion
		  (save-match-data
		    ;; online
		    (if (or arg (not file-cached))
			(elmo-message-encache
			 wl-summary-buffer-elmo-folder
			 number))
		    (setq new-mark
			  (cond
			   ((string= mark
				     wl-summary-unread-uncached-mark)
			    wl-summary-unread-cached-mark)
			   ((string= mark wl-summary-new-mark)
			    (setq wl-summary-buffer-new-count
				  (- wl-summary-buffer-new-count 1))
			    (setq wl-summary-buffer-unread-count
				  (+ wl-summary-buffer-unread-count 1))
			    wl-summary-unread-cached-mark)
			   ((string= mark wl-summary-read-uncached-mark)
			    nil)
			   (t mark)))
		    (setq mark-alist (elmo-msgdb-mark-set
				      mark-alist number new-mark))
		    (or new-mark (setq new-mark " "))
		    (elmo-msgdb-set-mark-alist msgdb mark-alist)
		    (wl-summary-set-mark-modified)
		    (wl-summary-update-modeline)
		    (wl-folder-update-unread
		     (wl-summary-buffer-folder-name)
		     (+ wl-summary-buffer-unread-count
			wl-summary-buffer-new-count)))
		  new-mark)))))))

;;(defvar wl-summary-message-uncached-marks
;;  (list wl-summary-new-mark
;;	wl-summary-unread-uncached-mark
;;	wl-summary-read-uncached-mark))

(defun wl-summary-prefetch-region (beg end &optional prefetch-marks)
  (interactive "r")
  (let ((count 0)
	targets
	mark length
	entity msg
	start-pos pos)
    (save-excursion
      (setq start-pos (point))
      (save-restriction
	(narrow-to-region beg end)
	;; collect prefetch targets.
	(message "Collecting marks...")
	(goto-char (point-min))
	(while (not (eobp))
	  (beginning-of-line)
	  (when (looking-at "^ *\\(-?[0-9]+\\)[^0-9]\\([^0-9]\\)")
	    (setq mark (wl-match-buffer 2))
	    (setq msg (string-to-int (wl-match-buffer 1)))
	    (if (or (and (null prefetch-marks)
			 msg
			 (null (elmo-file-cache-exists-p
				(cdr (assq msg
					   (elmo-msgdb-get-number-alist
					    (wl-summary-buffer-msgdb)))))))
		    (member mark prefetch-marks))
		(setq targets (nconc targets (list msg))))
	    (setq entity (wl-thread-get-entity msg))
	    (if (or (not (eq wl-summary-buffer-view 'thread))
		    (wl-thread-entity-get-opened entity))
		(); opened. no hidden children.
	      ;; hidden children!!
	      (setq targets (nconc
			     targets
			     (wl-thread-get-children-msgs-uncached
			      msg prefetch-marks)))))
	  (forward-line 1))
	(setq length (length targets))
	(message "Prefetching...")
	(while targets
	  (setq mark (if (not (wl-thread-entity-parent-invisible-p
			       (wl-thread-get-entity (car targets))))
			 (progn
			   (wl-summary-jump-to-msg (car targets))
			   (wl-summary-prefetch))
		       (wl-summary-prefetch-msg (car targets))))
	  (if (if prefetch-marks
		  (string= mark wl-summary-unread-cached-mark)
		(or (string= mark wl-summary-unread-cached-mark)
		    (string= mark " ")))
	      (message "Prefetching... %d/%d message(s)"
		       (setq count (+ 1 count)) length))
	  ;; redisplay!
	  (save-excursion
	    (setq pos (point))
	    (goto-char start-pos)
	    (if (pos-visible-in-window-p pos)
		(save-restriction
		  (widen)
		  (sit-for 0))))
	  (setq targets (cdr targets)))
	(message "Prefetched %d/%d message(s)" count length)
	(cons count length)))))

(defun wl-summary-prefetch (&optional arg)
  "Prefetch current message."
  (interactive "P")
  (save-excursion
    (save-match-data
      (beginning-of-line)
      (when (looking-at "^ *\\(-?[0-9]+\\)[^0-9]\\([^0-9]\\)")
	(goto-char (match-beginning 2))
	(let ((inhibit-read-only t)
	      (buffer-read-only nil)
	      (beg (match-beginning 2))
	      (end (match-end 2))
	      mark)
	  (setq mark (wl-summary-prefetch-msg
		      (string-to-int (wl-match-buffer 1)) arg))
	  (when mark
	    (delete-region beg end)
	    (insert mark)
	    (if wl-summary-highlight
		(wl-highlight-summary-current-line)))
	  (set-buffer-modified-p nil)
	  mark)))))

(defun wl-summary-delete-all-status-marks-on-buffer ()
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (let ((inhibit-read-only t)
	  (buffer-read-only nil)
	  (case-fold-search nil))
      (while (re-search-forward
	      (concat "^" wl-summary-buffer-number-regexp ".\\(.\\)") nil t)
	(delete-region (match-beginning 1) (match-end 1))
	(insert " ")))))

(defun wl-summary-delete-marks-on-buffer (marks)
  (while marks
    (wl-summary-unmark (pop marks))))

(defun wl-summary-delete-copy-marks-on-buffer (copies)
  (wl-summary-delete-marks-on-buffer copies))

(defun wl-summary-delete-all-refile-marks ()
  (let ((marks wl-summary-buffer-refile-list))
    (while marks
      (wl-summary-unmark (car (pop marks))))))

(defun wl-summary-delete-all-copy-marks ()
  (let ((marks wl-summary-buffer-copy-list))
    (while marks
      (wl-summary-unmark (car (pop marks))))))

(defun wl-summary-delete-all-delete-marks ()
  (wl-summary-delete-marks-on-buffer wl-summary-buffer-delete-list))

(defun wl-summary-delete-all-target-marks ()
  (wl-summary-delete-marks-on-buffer wl-summary-buffer-target-mark-list))

(defun wl-summary-delete-all-temp-marks-on-buffer (&optional sticky)
  ;; for summary view cache saving.
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (let ((inhibit-read-only t)
	  (buffer-read-only nil)
	  (case-fold-search nil)
	  (regexp (concat "^" wl-summary-buffer-number-regexp "\\([^ ]\\)" )))
      (while (re-search-forward regexp nil t)
	(delete-region (match-beginning 1) (match-end 1))
	(insert " ")
	(if (and sticky wl-summary-highlight)
	    (wl-highlight-summary-current-line))))))

(defun wl-summary-delete-all-marks (mark-alist mark)
  "Delete all MARKs in MARK-ALIST."
  (let ((malist mark-alist)
	(ret-val mark-alist)
	entity)
    (while malist
      (setq entity (car malist))
      (if (string= (cadr entity) mark)
	  ;; delete this entity
	  (setq ret-val (delete entity ret-val)))
      (setq malist (cdr malist)))
    ret-val))

;; Does not work correctly...
(defun wl-summary-mark-as-read-region (beg end)
  (interactive "r")
  (save-excursion
    (save-restriction
      (narrow-to-region beg end)
;;; use narrowing.
;;;   (save-excursion (goto-char end)
;;;		      (end-of-line) (point)))
      (goto-char (point-min))
      (if (eq wl-summary-buffer-view 'thread)
	  (progn
	    (while (not (eobp))
	      (let* ((number (wl-summary-message-number))
		     (entity (wl-thread-get-entity number))
		     children)
		(if (wl-thread-entity-get-opened entity)
		    ;; opened...mark line.
		    ;; Crossposts are not processed
		    (wl-summary-mark-as-read t)
		  ;; closed
		  (wl-summary-mark-as-read t) ; mark itself.
		  (setq children (wl-thread-get-children-msgs number))
		  (while children
		    (wl-summary-mark-as-read t nil nil (car children))
		    (setq children (cdr children))))
		(forward-line 1))))
	(while (not (eobp))
	  (wl-summary-mark-as-read t)
	  (forward-line 1)))))
  (wl-summary-count-unread (elmo-msgdb-get-mark-alist (wl-summary-buffer-msgdb)))
  (wl-summary-update-modeline))

(defun wl-summary-mark-as-unread-region (beg end)
  (interactive "r")
  (save-excursion
    (save-restriction
      (narrow-to-region beg end)
;;; use narrowing.
;;;      (save-excursion (goto-char end)
;;;		      (end-of-line) (point)))
      (goto-char (point-min))
      (if (eq wl-summary-buffer-view 'thread)
	  (progn
	    (while (not (eobp))
	      (let* ((number (wl-summary-message-number))
		     (entity (wl-thread-get-entity number))
		     children)
		(if (wl-thread-entity-get-opened entity)
		    ;; opened...mark line.
		    ;; Crossposts are not processed
		    (wl-summary-mark-as-unread)
		  ;; closed
		  (wl-summary-mark-as-unread) ; mark itself.
		  (setq children
			(delq number (wl-thread-get-children-msgs number)))
		  (while children
		    (wl-summary-mark-as-unread (car children))
		    (setq children (cdr children))))
		(forward-line 1))))
	(while (not (eobp))
	  (wl-summary-mark-as-unread)
	  (forward-line 1)))))
  (wl-summary-count-unread (elmo-msgdb-get-mark-alist (wl-summary-buffer-msgdb)))
  (wl-summary-update-modeline))

(defun wl-summary-mark-as-important-region (beg end)
  (interactive "r")
  (save-excursion
    (save-restriction
      (narrow-to-region beg end);(save-excursion (goto-char end)
					;    (end-of-line) (point)))
      (goto-char (point-min))
      (if (eq wl-summary-buffer-view 'thread)
	  (progn
	    (while (not (eobp))
	      (let* ((number (wl-summary-message-number))
		     (entity (wl-thread-get-entity number))
		     children)
		(if (wl-thread-entity-get-opened entity)
		    ;; opened...mark line.
		    ;; Crossposts are not processed
		    (wl-summary-mark-as-important)
		  ;; closed
		  (wl-summary-mark-as-important) ; mark itself.
		  (setq children
			(delq number (wl-thread-get-children-msgs number)))
		  (while children
		    (wl-thread-msg-mark-as-important (car children))
		    (setq children (cdr children))))
		(forward-line 1))))
	(while (not (eobp))
	  (wl-summary-mark-as-important)
	  (forward-line 1)))))
  (wl-summary-count-unread (elmo-msgdb-get-mark-alist (wl-summary-buffer-msgdb)))
  (wl-summary-update-modeline))

(defun wl-summary-mark-as-read-all ()
  (interactive)
  (if (or (not (interactive-p))
	  (y-or-n-p "Mark all messages as read? "))
      (let* ((folder wl-summary-buffer-elmo-folder)
	     (cur-buf (current-buffer))
	     (msgdb (wl-summary-buffer-msgdb))
;;;	     (number-alist (elmo-msgdb-get-number-alist msgdb))
	     (mark-alist (elmo-msgdb-get-mark-alist msgdb))
	     (malist mark-alist)
	     (inhibit-read-only t)
	     (buffer-read-only nil)
	     (case-fold-search nil)
	     msg mark)
	(message "Setting all msgs as read...")
	(elmo-folder-mark-as-read folder
				  (elmo-folder-list-unreads
				   folder
				   (list wl-summary-unread-cached-mark
					 wl-summary-unread-uncached-mark
					 wl-summary-new-mark)))
	(save-excursion
	  (goto-char (point-min))
	  (while (re-search-forward "^ *\\(-?[0-9]+\\)[^0-9]\\([^0-9 ]\\)" nil t)
	    (setq msg (string-to-int (wl-match-buffer 1)))
	    (setq mark (wl-match-buffer 2))
	    (when (and (not (string= mark wl-summary-important-mark))
		       (not (string= mark wl-summary-read-uncached-mark)))
	      (delete-region (match-beginning 2) (match-end 2))
	      (if (or (not (elmo-message-use-cache-p folder msg))
		      (string= mark wl-summary-unread-cached-mark))
		  (progn
		    (insert " ")
		    (setq mark-alist
			  (elmo-msgdb-mark-set
			   mark-alist
			   msg
;;; Use msg instead of (cdr (assq msg number-alist)).
;;;			   (cdr (assq msg number-alist))
			   nil)))
		;; New mark and unread-uncached mark
		(insert wl-summary-read-uncached-mark)
		(setq mark-alist
		      (elmo-msgdb-mark-set mark-alist
					   msg
;;;					   (cdr (assq msg number-alist))
					   wl-summary-read-uncached-mark)))
	      (if wl-summary-highlight
		  (wl-highlight-summary-current-line nil nil t)))))
	(setq mark-alist (wl-summary-set-as-read-mark-alist mark-alist))
	(wl-summary-set-mark-modified)
	(set-buffer cur-buf); why is this needed???
	(elmo-msgdb-set-mark-alist msgdb mark-alist)
	(wl-folder-update-unread (wl-summary-buffer-folder-name) 0)
	(setq wl-summary-buffer-unread-count 0)
	(setq wl-summary-buffer-new-count    0)
	(wl-summary-update-modeline)
	(message "Setting all msgs as read...done")
	(set-buffer-modified-p nil))))

(defun wl-summary-delete-cache ()
  "Delete cache of current message."
  (interactive)
  (save-excursion
    (let* ((inhibit-read-only t)
	   (buffer-read-only nil)
	   (folder wl-summary-buffer-elmo-folder)
	   (msgdb (wl-summary-buffer-msgdb))
	   (mark-alist (elmo-msgdb-get-mark-alist msgdb))
	   (number-alist (elmo-msgdb-get-number-alist msgdb))
	   (case-fold-search nil)
	   mark number unread new-mark)
;;;   (re-search-backward "^ *[0-9]+..[0-9]+/[0-9]+" nil t) ; set cursor line
      (beginning-of-line)
      (when (looking-at "^ *\\(-?[0-9]+\\)[^0-9]\\([^0-9]\\)")
	(progn
	  (setq mark (wl-match-buffer 2))
	  (cond
	   ((or (string= mark wl-summary-new-mark)
		(string= mark wl-summary-unread-uncached-mark)
		(string= mark wl-summary-important-mark))
	    ;; noop
	    )
	   ((string= mark wl-summary-unread-cached-mark)
	    (setq new-mark wl-summary-unread-uncached-mark))
	   (t
	    (setq new-mark wl-summary-read-uncached-mark)))
	  (when new-mark
	    (setq number (string-to-int (wl-match-buffer 1)))
	    (delete-region (match-beginning 2) (match-end 2))
	    (goto-char (match-beginning 2))
	    (insert new-mark)
	    (elmo-file-cache-delete
	     (elmo-file-cache-get-path
	      (elmo-message-field wl-summary-buffer-elmo-folder
				  number
				  'message-id)))
	    (setq mark-alist
		  (elmo-msgdb-mark-set mark-alist number new-mark))
	    (elmo-msgdb-set-mark-alist msgdb mark-alist)
	    (wl-summary-set-mark-modified)
	    (if wl-summary-highlight
		(wl-highlight-summary-current-line nil nil t))
	    (set-buffer-modified-p nil)))))))

(defun wl-summary-resume-cache-status ()
  "Resume the cache status of all messages in the current folder."
  (interactive)
  (let* ((folder wl-summary-buffer-elmo-folder)
	 (cur-buf (current-buffer))
	 (msgdb (wl-summary-buffer-msgdb))
	 (number-alist (elmo-msgdb-get-number-alist msgdb))
	 (mark-alist (elmo-msgdb-get-mark-alist msgdb))
	 (inhibit-read-only t)
	 (buffer-read-only nil)
	 (case-fold-search nil)
	 msg mark msgid set-mark)
    (message "Resuming cache status...")
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "^ *\\(-?[0-9]+\\)[^0-9]\\([^0-9]\\)" nil t)
	(setq msg (string-to-int
		   (wl-match-buffer 1)))
	(setq mark (wl-match-buffer 2))
	(setq msgid (cdr (assq msg number-alist)))
	(setq set-mark nil)
	(if (elmo-file-cache-exists-p msgid)
	    (if (or
		 (string= mark wl-summary-unread-uncached-mark) ; U -> !
		 (string= mark wl-summary-new-mark)		; N -> !
		 )
		(setq set-mark wl-summary-unread-cached-mark)
	      (if (string= mark wl-summary-read-uncached-mark)  ; u -> ' '
		  (setq set-mark " ")))
	  (if (string= mark " ")
	      (setq set-mark wl-summary-read-uncached-mark)     ;' ' -> u
	    (if (string= mark wl-summary-unread-cached-mark)
		(setq set-mark wl-summary-unread-uncached-mark) ; !  -> U
	      )))
	(when set-mark
	  (delete-region (match-beginning 2) (match-end 2))
	  (insert set-mark)
	  (setq mark-alist
		(elmo-msgdb-mark-set
		 mark-alist msg ; msgid
		 (if (string= set-mark " ") nil set-mark)))
	  (if wl-summary-highlight
	      (wl-highlight-summary-current-line))))
      (wl-summary-set-mark-modified)
      (set-buffer cur-buf); why is this needed???
      (elmo-msgdb-set-mark-alist msgdb mark-alist)
      (wl-summary-count-unread mark-alist)
      (wl-summary-update-modeline)
      (message "Resuming cache status...done")
      (set-buffer-modified-p nil))))

(defun wl-summary-resume-marks-and-highlight ()
  (let* ((msgdb (wl-summary-buffer-msgdb))
	 (mark-alist (elmo-msgdb-get-mark-alist msgdb))
;;;	 (number-alist (elmo-msgdb-get-number-alist msgdb))
	 (count (count-lines (point-min)(point-max)))
	 (i 0)
	 msg-num percent smark)
    (save-excursion
      (goto-char (point-min))
      (message "Resuming all marks...")
      (while (not (eobp))
	(setq msg-num (wl-summary-message-number))
	(setq smark (car (cdr (assq msg-num mark-alist))))
	(if (looking-at (format "^ *%s \\( \\)" msg-num))
	    (progn
	      (goto-char (match-end 1))
	      (delete-region (match-beginning 1) (match-end 1))
	      (insert (or smark " "))))
	(wl-highlight-summary-current-line smark)
	(when (> count elmo-display-progress-threshold)
	  (setq i (+ i 1))
	  (setq percent (/ (* i 100) count))
	  (elmo-display-progress
	   'wl-summary-resume-marks-and-highlight "Resuming all marks..."
	   percent))
	(forward-line 1)))
    (message "Resuming all marks...done")))

(defun wl-summary-resume-marks ()
  (let* ((msgdb (wl-summary-buffer-msgdb))
	 (mark-alist (elmo-msgdb-get-mark-alist msgdb))
	 (number-alist (elmo-msgdb-get-number-alist msgdb))
	 (count (length mark-alist))
	 (i 0)
	 entity msg-num percent)
    (save-excursion
      (message "Resuming all marks...")
      (while mark-alist
	(setq entity (car mark-alist))
	(if (setq msg-num (car (rassoc (car entity) number-alist)))
	    (progn
;;;	      (goto-char (point-min))
	      (if (re-search-forward (format "^ *%s \\( \\)" msg-num) nil t)
		  (progn
		    (delete-region (match-beginning 1) (match-end 1))
		    (insert (or (cadr entity)
				" ")))
		(if (re-search-backward (format "^ *%s \\( \\)" msg-num) nil t)
		    (progn
		      (goto-char (match-end 1))
		      (delete-region (match-beginning 1) (match-end 1))
		      (insert (or (cadr entity)
				  " ")))))))
	(when (> count elmo-display-progress-threshold)
	  (setq i (+ i 1))
	  (setq percent (/ (* i 100) count))
	  (elmo-display-progress
	   'wl-summary-resume-marks "Resuming all marks..."
	   percent))
	(setq mark-alist (cdr mark-alist)))
      (message "Resuming all marks...done"))))

(defun wl-summary-delete-messages-on-buffer (msgs &optional deleting-info)
  (interactive)
  (save-excursion
    (let ((inhibit-read-only t)
	  (buffer-read-only nil)
	  (msgs2 msgs)
	  (len (length msgs))
	  (i 0)
	  update-list)
      (elmo-kill-buffer wl-summary-search-buf-name)
      (while msgs
	(if (eq wl-summary-buffer-view 'thread)
	    (progn
	      ;; don't use wl-append(nconc), because list is broken. ...why?
	      (setq update-list
		    (append update-list
			    (wl-thread-delete-message (car msgs))))
	      (setq update-list (delq (car msgs) update-list)))
	  (goto-char (point-min))
	  (if (re-search-forward (format "^ *%d[^0-9]\\([^0-9]\\).*$"
					 (car msgs)) nil t)
	      (progn
		(delete-region (match-beginning 0) (match-end 0))
		(delete-char 1) ; delete '\n'
		(setq wl-summary-buffer-number-list
		      (delq (car msgs) wl-summary-buffer-number-list)))))
	(when (and deleting-info
		   (> len elmo-display-progress-threshold))
	  (setq i (1+ i))
	  (if (or (zerop (% i 5)) (= i len))
	      (elmo-display-progress
	       'wl-summary-delete-messages-on-buffer deleting-info
	       (/ (* i 100) len))))
	(setq msgs (cdr msgs)))
      (when (eq wl-summary-buffer-view 'thread)
	(wl-thread-update-line-msgs (elmo-uniq-list update-list)
				    (unless deleting-info 'no-msg))
	(wl-thread-cleanup-symbols msgs2))
      (wl-summary-count-unread
       (elmo-msgdb-get-mark-alist (wl-summary-buffer-msgdb)))
      (wl-summary-update-modeline)
      (wl-folder-update-unread
       (wl-summary-buffer-folder-name)
       (+ wl-summary-buffer-unread-count wl-summary-buffer-new-count)))))

(defun wl-summary-set-as-read-mark-alist (mark-alist)
  (let ((marks (list (cons wl-summary-unread-cached-mark
			   nil)
		     (cons wl-summary-unread-uncached-mark
			   wl-summary-read-uncached-mark)
		     (cons wl-summary-new-mark
			   wl-summary-read-uncached-mark)))
	(ret-val mark-alist)
	entity pair)
    (while mark-alist
      (setq entity (car mark-alist))
      (when (setq pair (assoc (cadr entity) marks))
	(if (elmo-message-use-cache-p wl-summary-buffer-elmo-folder
				      (caar mark-alist))
	    (if (cdr pair)
		(setcar (cdr entity) (cdr pair))
	      (setq ret-val (delete entity ret-val)))
	  (setq ret-val (delete entity ret-val))))
      (setq mark-alist (cdr mark-alist)))
    ret-val))

(defun wl-summary-set-status-marks (mark-alist before after)
  "Set the BEFORE marks to AFTER."
  (let ((ret-val mark-alist)
	entity)
    (while mark-alist
      (setq entity (car mark-alist))
      (when (string= (cadr entity) before)
	(if after
	    (setcar (cdr entity) after)
	  (setq ret-val (delete entity ret-val))))
      (setq mark-alist (cdr mark-alist)))
    ret-val))

(defun wl-summary-set-status-marks-on-buffer (before after)
  "Set the MARKS marks on buffer."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (let ((inhibit-read-only t)
	  (buffer-read-only nil)
	  (regexp (concat "^" wl-summary-buffer-number-regexp ".\\(\\%s\\)")))
      (while (re-search-forward
	      (format regexp (regexp-quote before)) nil t)
	(delete-region (match-beginning 1) (match-end 1))
	(insert after)
	(if wl-summary-highlight
	    (wl-highlight-summary-current-line))))))

(defun wl-summary-get-delete-folder (folder)
  (if (string= folder wl-trash-folder)
      'null
    (let* ((type (or (wl-get-assoc-list-value wl-delete-folder-alist folder)
		     'trash)))
      (cond ((stringp type)
	     type)
	    ((or (equal type 'remove) (equal type 'null))
	     'null)
	    (t;; (equal type 'trash)
	     wl-trash-folder)))))

(defun wl-summary-delete-important-msgs-from-list (delete-list
						   mark-alist)
  (let ((dlist delete-list))
    (while dlist
      (if (string= wl-summary-important-mark
		   (car (cdr (assq (car dlist) mark-alist))))
	  (setq delete-list (delete (car dlist) delete-list)))
      (setq dlist (cdr dlist)))
    delete-list))

(defun wl-summary-delete-canceled-msgs-from-list (delete-list msgdb)
  (let ((dlist delete-list))
    (while dlist
      (if (null (cdr (assq (car dlist) (cadr msgdb))))
	  (setq delete-list (delete (car dlist) delete-list)))
      (setq dlist (cdr dlist)))
    delete-list))

(defun wl-summary-get-append-message-func ()
  (if (eq wl-summary-buffer-view 'thread)
      'wl-summary-insert-thread-entity
;;;   'wl-summary-insert-thread
    'wl-summary-insert-summary))

(defun wl-summary-sort ()
  (interactive)
  (let ((sort-by (let ((input-range-list '("number" "date" "subject" "from"))
		       (default "date")
		       in)
		   (setq in
			 (completing-read
			  (format "Sort by (%s): " default)
			  (mapcar
			   (function (lambda (x) (cons x x)))
			   input-range-list)))
		   (if (string= in "")
		       default
		     in))))
    (if (not (member sort-by '("number" "date" "subject" "from")))
	(error "Sort by %s is not implemented"  sort-by))
    (wl-summary-rescan sort-by)))

(defun wl-summary-sync-marks ()
  "Update marks in summary."
  (interactive)
  (let ((last-progress 0)
	(i 0)
	mark-alist unread-marks importants unreads
	importants-in-db unreads-in-db diff diffs
	mes num-ma progress)
    ;; synchronize marks.
    (when (not (eq (elmo-folder-type-internal
		    wl-summary-buffer-elmo-folder)
		   'internal))
      (message "Updating marks...")
      (setq unread-marks (list wl-summary-unread-cached-mark
			       wl-summary-unread-uncached-mark
			       wl-summary-new-mark)
	    mark-alist (elmo-msgdb-get-mark-alist (wl-summary-buffer-msgdb))
	    num-ma (length mark-alist)
	    importants (elmo-folder-list-importants
			wl-summary-buffer-elmo-folder
			wl-summary-important-mark)
	    unreads (elmo-folder-list-unreads
		     wl-summary-buffer-elmo-folder
		     unread-marks))
      (while mark-alist
	(if (string= (cadr (car mark-alist))
		     wl-summary-important-mark)
	    (setq importants-in-db (cons (car (car mark-alist))
					 importants-in-db))
	  (if (member (cadr (car mark-alist)) unread-marks)
	      (setq unreads-in-db (cons (car (car mark-alist))
					unreads-in-db))))
	(setq mark-alist (cdr mark-alist))
	(when (> num-ma elmo-display-progress-threshold)
	  (setq i (1+ i)
		progress (/ (* i 100) num-ma))
	  (if (not (eq progress last-progress))
	      (elmo-display-progress 'wl-summary-sync-marks
				     "Updating marks..."
				     progress))
	  (setq last-progress progress)))
      (setq diff (elmo-list-diff importants importants-in-db))
      (setq diffs (cadr diff)) ; important-deletes
      (setq mes (format "Updated (-%d" (length diffs)))
      (while diffs
	(wl-summary-mark-as-important (car diffs)
				      wl-summary-important-mark
				      'no-server)
	(setq diffs (cdr diffs)))
      (setq diffs (car diff)) ; important-appends
      (setq mes (concat mes (format "/+%d) important," (length diffs))))
      (while diffs
	(wl-summary-mark-as-important (car diffs) " " 'no-server)
	(setq diffs (cdr diffs)))
      (setq diff (elmo-list-diff unreads unreads-in-db))
      (setq diffs (cadr diff))
      (setq mes (concat mes (format "(-%d" (length diffs))))
      (while diffs
	(wl-summary-mark-as-read t 'no-server nil (car diffs))
	(setq diffs (cdr diffs)))
      (setq diffs (car diff)) ; unread-appends
      (setq mes (concat mes (format "/+%d) unread mark(s)." (length diffs))))
      (while diffs
	(wl-summary-mark-as-unread (car diffs) 'no-server 'no-modeline)
	(setq diffs (cdr diffs)))
      (if (interactive-p) (message mes)))))

(defun wl-summary-sync-update (&optional unset-cursor sync-all no-check)
  "Update the summary view to the newest folder status."
  (interactive)
  (let* ((folder wl-summary-buffer-elmo-folder)
	 (case-fold-search nil)
	 (elmo-mime-charset wl-summary-buffer-mime-charset)
	 (inhibit-read-only t)
	 (buffer-read-only nil)
	 gc-message
	 overview number-alist mark-alist
	 curp num i new-msgdb
	 append-list delete-list crossed
	 update-thread update-top-list
	 expunged mes sync-result)
    (unwind-protect
	(progn
	  (unless wl-summary-buffer-elmo-folder
	    (error "(Internal error) Folder is not set:%s" (buffer-name
							    (current-buffer))))
	  (fset 'wl-summary-append-message-func-internal
		(wl-summary-get-append-message-func))
	  ;; Flush pending append operations (disconnected operation).
	  ;;(setq seen-list
	  ;;(wl-summary-flush-pending-append-operations seen-list))
	  (goto-char (point-max))
	  (wl-folder-confirm-existence folder 'force)
	  (setq sync-result (elmo-folder-synchronize
			     folder
			     wl-summary-new-mark
			     wl-summary-unread-uncached-mark
			     wl-summary-unread-cached-mark
			     wl-summary-read-uncached-mark
			     wl-summary-important-mark
			     sync-all no-check))
	  (setq new-msgdb (nth 0 sync-result))
	  (setq delete-list (nth 1 sync-result))
	  (setq crossed (nth 2 sync-result))
	  (if sync-result
	      (progn
		;; Setup sync-all
		(if sync-all (wl-summary-sync-all-init))
;    (if (and has-nntp
;	     (elmo-nntp-max-number-precedes-list-active-p))
	;; XXX this does not work correctly in rare case.
;	(setq delete-list
;	      (wl-summary-delete-canceled-msgs-from-list
;	       delete-list
;	       (wl-summary-buffer-msgdb))))
		(when delete-list
		  (wl-summary-delete-messages-on-buffer delete-list "Deleting...")
		  (message "Deleting...done"))
		(when new-msgdb
		  (wl-summary-set-status-marks-on-buffer
		   wl-summary-new-mark
		   wl-summary-unread-uncached-mark))
		(setq append-list (elmo-msgdb-get-overview new-msgdb))
		(setq curp append-list)
		(setq num (length curp))
		(when append-list
		  (setq i 0)
		  ;; set these value for append-message-func
		  (setq overview (elmo-msgdb-get-overview
				  (elmo-folder-msgdb folder)))
		  (setq number-alist (elmo-msgdb-get-number-alist
				      (elmo-folder-msgdb folder)))
		  (setq mark-alist (elmo-msgdb-get-mark-alist
				    (elmo-folder-msgdb folder)))
		  (setq wl-summary-delayed-update nil)
		  (elmo-kill-buffer wl-summary-search-buf-name)
		  (while curp
		    (setq entity (car curp))
		    (when (setq update-thread
				(wl-summary-append-message-func-internal
				 entity overview mark-alist
				 (not sync-all)))
		      (wl-append update-top-list update-thread))
		    (if elmo-use-database
			(elmo-database-msgid-put
			 (car entity) (elmo-folder-name-internal folder)
			 (elmo-msgdb-overview-entity-get-number entity)))
		    (setq curp (cdr curp))
		    (when (> num elmo-display-progress-threshold)
		      (setq i (+ i 1))
		      (if (or (zerop (% i 5)) (= i num))
			  (elmo-display-progress
			   'wl-summary-sync-update "Updating thread..."
			   (/ (* i 100) num)))))
		  (when wl-summary-delayed-update
		    (while wl-summary-delayed-update
		      (message "Parent (%d) of message %d is no entity"
			       (caar wl-summary-delayed-update)
			       (elmo-msgdb-overview-entity-get-number
				(cdar wl-summary-delayed-update)))
		      (when (setq update-thread
				  (wl-summary-append-message-func-internal
				   (cdar wl-summary-delayed-update)
				   overview mark-alist (not sync-all) t))
			(wl-append update-top-list update-thread))
		      (setq wl-summary-delayed-update
			    (cdr wl-summary-delayed-update))))
		  (when (and (eq wl-summary-buffer-view 'thread)
			     update-top-list)
		    (wl-thread-update-indent-string-thread
		     (elmo-uniq-list update-top-list)))
		  (message "Updating thread...done"))
		(unless (eq wl-summary-buffer-view 'thread)
		  (wl-summary-make-number-list))
		(wl-summary-set-message-modified)
		(wl-summary-set-mark-modified)
		(when (and sync-all (eq wl-summary-buffer-view 'thread))
		  (elmo-kill-buffer wl-summary-search-buf-name)
		  (message "Inserting thread...")
		  (setq wl-thread-entity-cur 0)
		  (wl-thread-insert-top)
		  (message "Inserting thread...done"))
		(if elmo-use-database
		    (elmo-database-close))
		(run-hooks 'wl-summary-sync-updated-hook)
		(setq mes
		      (if (and (eq (length delete-list) 0)
			       (eq num 0))
			  (format
			   "No updates for \"%s\"" (elmo-folder-name-internal
						    folder))
			(format "Updated (-%d/+%d) message(s)"
				(length delete-list) num))))
	    (setq mes "Quit updating.")))
      ;; synchronize marks.
      (if (and wl-summary-auto-sync-marks sync-result)
	  (wl-summary-sync-marks))
      ;; scoring
      (when wl-use-scoring
	(setq wl-summary-scored nil)
	(wl-summary-score-headers nil (wl-summary-buffer-msgdb)
				  (and sync-all
				       (wl-summary-rescore-msgs number-alist))
				  sync-all)
	(when (and wl-summary-scored
		   (setq expunged (wl-summary-score-update-all-lines)))
	  (setq mes (concat mes
			    (format " (%d expunged)"
				    (length expunged))))))
      (if (and crossed (> crossed 0))
	  (setq mes
		(if mes
		    (concat mes
			    (format " (%d crosspost)" crossed))
		  (format "%d crosspost message(s)" crossed)))
	(and mes (setq mes (concat mes "."))))
      ;; Update Folder mode
      (wl-folder-set-folder-updated
       (elmo-folder-name-internal folder)
       (list 0
	     (let ((pair (wl-summary-count-unread
			  (elmo-msgdb-get-mark-alist
			   (elmo-folder-msgdb folder)))))
	       (+ (car pair) (cdr pair)))
	     (elmo-folder-messages folder)))
      (wl-summary-update-modeline)
      (wl-summary-buffer-number-column-detect t)
      ;;
      (unless unset-cursor
	(goto-char (point-min))
	(if (not (wl-summary-cursor-down t))
	    (progn
	      (goto-char (point-max))
	      (forward-line -1))
	  (if (and wl-summary-highlight
		   (not (get-text-property (point) 'face)))
	      (save-excursion
		(forward-line (- 0
				 (or
				  wl-summary-partial-highlight-above-lines
				  wl-summary-highlight-partial-threshold)))
		(wl-highlight-summary (point) (point-max))))))
      (setq wl-summary-buffer-msgdb (elmo-folder-msgdb folder))
      (wl-delete-all-overlays)
      (set-buffer-modified-p nil)
      (if mes (message "%s" mes)))))

(defun wl-summary-set-score-mark (mark)
  (save-excursion
    (beginning-of-line)
    (let ((inhibit-read-only t)
	  (buffer-read-only nil)
	  msg-num
	  cur-mark)
      (when (looking-at "^ *\\(-?[0-9]+\\)\\([^0-9]\\)")
	(setq msg-num  (string-to-int (wl-match-buffer 1)))
	(setq cur-mark (wl-match-buffer 2))
	(when (member cur-mark (list " "
				     wl-summary-score-below-mark
				     wl-summary-score-over-mark))
	  (goto-char (match-end 1))
	  (delete-region (match-beginning 2) (match-end 2))
	  (insert mark)
	  (if wl-summary-highlight
	      (wl-highlight-summary-current-line nil nil t))
	  (set-buffer-modified-p nil))))))

(defun wl-summary-get-score-mark (msg-num)
  (let ((score (cdr (assq msg-num wl-summary-scored))))
    (if score
	(cond ((< score wl-summary-default-score)
	       "-")
	      ((> score wl-summary-default-score)
	       "+")))))

(defun wl-summary-update-modeline ()
  (setq wl-summary-buffer-unread-status
	(format " {%s}(%d new/%d unread)"
		(if (eq wl-summary-buffer-view 'thread)
		    "T" "S")
		wl-summary-buffer-new-count
		(+ wl-summary-buffer-new-count
		   wl-summary-buffer-unread-count))))

(defsubst wl-summary-jump-to-msg (&optional number)
  (interactive)
  (let ((num (or number
		 (string-to-int
		  (read-from-minibuffer "Jump to Message(No.): ")))))
    (setq num (int-to-string num))
    (beginning-of-line)
    (if (or (re-search-forward (concat "^[ \t]*" num "[^0-9]") nil t)
	    (re-search-backward (concat "^[ \t]*" num "[^0-9]") nil t))
	(progn (beginning-of-line) t)
      nil)))

(defun wl-summary-highlight-msgs (msgs)
  (save-excursion
    (let ((len (length msgs))
	  i)
      (message "Hilighting...")
      (setq i 0)
      (while msgs
	(if (wl-summary-jump-to-msg (car msgs))
	    (wl-highlight-summary-current-line))
	(setq msgs (cdr msgs))
	(when (> len elmo-display-progress-threshold)
	  (setq i (+ i 1))
	  (if (or (zerop (% i 5)) (= i len))
	      (elmo-display-progress
	       'wl-summary-highlight-msgs "Highlighting..."
	       (/ (* i 100) len)))))
      (message "Highlighting...done"))))

(defun wl-summary-message-number ()
  (save-excursion
    (beginning-of-line)
    (if (looking-at "^ *\\(-?[0-9]+\\)")
	(string-to-int (wl-match-buffer 1))
      nil)))

(defun wl-summary-move (src dsts-msgs)
  (let* ((dsts (car dsts-msgs))		; (+foo +bar)
;;;	 (msgs (cdr dsts-msgs))		; (1 2 3)
;;;	 (msgdb (wl-summary-buffer-msgdb))
;;;	 result)
	 )
    (while dsts
      (setq dsts (cdr dsts)))))

(defun wl-summary-delete-all-msgs ()
  (interactive)
  (let ((cur-buf (current-buffer))
	(dels (elmo-folder-list-messages wl-summary-buffer-elmo-folder)))
    (set-buffer cur-buf)
    (if (null dels)
	(message "No message to delete.")
      (if (y-or-n-p (format "%s has %d message(s).  Delete all? "
			    (wl-summary-buffer-folder-name)
			    (length dels)))
	  (progn
	    (message "Deleting...")
	    (elmo-folder-delete-messages
	     wl-summary-buffer-elmo-folder dels)
	    (elmo-msgdb-delete-msgs (wl-summary-buffer-msgdb)
				    dels)
;;;	    (elmo-msgdb-save (wl-summary-buffer-folder-name) nil)
	    (wl-summary-set-message-modified)
	    (wl-summary-set-mark-modified)
	    (wl-folder-set-folder-updated (wl-summary-buffer-folder-name)
					  (list 0 0 0))
;;; for thread.
;;;	    (setq wl-thread-top-entity '(nil t nil nil))
	    (setq wl-summary-buffer-unread-count 0)
	    (setq wl-summary-buffer-new-count    0)
	    (wl-summary-update-modeline)
	    (set-buffer cur-buf)
	    (let ((inhibit-read-only t)
		  (buffer-read-only nil))
	      (erase-buffer))
;;;	    (if wl-summary-cache-use (wl-summary-save-view-cache))
	    (message "Deleting...done")
	    t)
	nil))))

(defun wl-summary-toggle-thread (&optional arg)
  "Toggle thread status (T)hread and (S)equential.
If ARG, without confirm."
  (interactive "P")
  (when (or arg
	    (y-or-n-p (format "Toggle threading? (y=%s): "
			      (if (eq wl-summary-buffer-view 'thread)
				  "\"off\"" "\"on\""))))
    (if (eq wl-summary-buffer-view 'thread)
	(setq wl-summary-buffer-view 'sequence)
      (setq wl-summary-buffer-view 'thread))
    (wl-summary-update-modeline)
    (force-mode-line-update)
    (wl-summary-rescan)))

(defun wl-summary-load-file-object (filename)
  "Load lisp object from dir."
  (save-excursion
    (let ((tmp-buffer (get-buffer-create " *wl-summary-load-file-object*"))
	  insert-file-contents-pre-hook   ; To avoid autoconv-xmas...
	  insert-file-contents-post-hook
	  ret-val)
      (if (not (file-readable-p filename))
	  ()
	(set-buffer tmp-buffer)
	(as-binary-input-file (insert-file-contents filename))
	(setq ret-val
	      (condition-case nil
		  (read (current-buffer))
		(error (error "Reading failed")))))
      (kill-buffer tmp-buffer)
      ret-val)))

(defun wl-summary-goto-folder (&optional arg)
  (interactive "P")
  (wl-summary-goto-folder-subr nil nil nil arg t))

(defun wl-summary-goto-last-visited-folder ()
  (interactive)
  (let ((entity
	 (wl-folder-search-entity-by-name wl-summary-last-visited-folder
					  wl-folder-entity
					  'folder)))
    (if entity (wl-folder-set-current-entity-id
		(wl-folder-get-entity-id entity))))
  (wl-summary-goto-folder-subr wl-summary-last-visited-folder nil nil nil t))

(defun wl-summary-sticky-p (&optional folder)
  (if folder
      (get-buffer (wl-summary-sticky-buffer-name
		   (elmo-folder-name-internal folder)))
    (not (string= wl-summary-buffer-name (buffer-name)))))

(defun wl-summary-always-sticky-folder-p (folder)
  (or (eq t wl-summary-always-sticky-folder-list)
      (wl-string-match-member
       (elmo-folder-name-internal folder)
       wl-summary-always-sticky-folder-list)))

(defun wl-summary-stick (&optional force)
  "Make current summary buffer sticky."
  (interactive "P")
  (if (wl-summary-sticky-p)
      (message "Current summary buffer is already sticky.")
    (when (or force (y-or-n-p "Stick current summary buffer? "))
      (wl-summary-toggle-disp-msg 'off)
      (wl-summary-switch-to-clone-buffer
       (wl-summary-sticky-buffer-name
	(wl-summary-buffer-folder-name)))
;;; ???hang up
;;;   (rename-buffer (wl-summary-sticky-buffer-name
;;;		      (wl-summary-buffer-folder-name))))
      (message "Folder `%s' is now sticky." (wl-summary-buffer-folder-name)))))

(defun wl-summary-switch-to-clone-buffer (buffer-name)
  (let ((cur-buf (current-buffer))
	(msg (wl-summary-message-number))
	(buf (get-buffer-create buffer-name))
	(folder wl-summary-buffer-elmo-folder)
	(copy-variables
	 (append '(wl-summary-buffer-view
		   wl-summary-buffer-refile-list
		   wl-summary-buffer-delete-list
		   wl-summary-buffer-copy-list
		   wl-summary-buffer-target-mark-list
		   wl-summary-buffer-elmo-folder
		   wl-summary-buffer-number-column
		   wl-summary-buffer-number-regexp
		   wl-summary-buffer-message-modified
		   wl-summary-buffer-mark-modified
		   wl-summary-buffer-thread-modified
		   wl-summary-buffer-number-list
		   wl-summary-buffer-msgdb
		   wl-summary-buffer-folder-name)
		 (and (eq wl-summary-buffer-view 'thread)
		      '(wl-thread-entity-hashtb
			wl-thread-entities
			wl-thread-entity-list))
		 (and wl-use-scoring
		      '(wl-summary-scored
			wl-summary-default-score
			wl-summary-important-above
			wl-summary-target-above
			wl-summary-mark-below
			wl-summary-expunge-below))
		 (and (featurep 'wl-score)
		      '(wl-current-score-file
			wl-score-alist)))))
    (set-buffer buf)
    (wl-summary-mode)
    (wl-summary-buffer-set-folder folder)
    (let ((buffer-read-only nil))
      (insert-buffer cur-buf))
    (set-buffer-modified-p nil)
    (while copy-variables
      (set (car copy-variables)
	   (save-excursion
	     (set-buffer cur-buf)
	     (symbol-value (car copy-variables))))
      (setq copy-variables (cdr copy-variables)))
    (switch-to-buffer buf)
    (kill-buffer cur-buf)
    (wl-summary-count-unread
     (elmo-msgdb-get-mark-alist (wl-summary-buffer-msgdb)))
    (wl-summary-update-modeline)
    (if msg
	(if (eq wl-summary-buffer-view 'thread)
	    (wl-thread-jump-to-msg msg)
	  (wl-summary-jump-to-msg msg))
      (goto-char (point-max))
      (beginning-of-line))))

(defun wl-summary-get-buffer (folder)
  (or (and folder
	   (get-buffer (wl-summary-sticky-buffer-name folder)))
      (get-buffer wl-summary-buffer-name)))

(defun wl-summary-get-buffer-create (name &optional force-sticky)
  (if force-sticky
      (get-buffer-create
       (wl-summary-sticky-buffer-name name))
    (or (get-buffer (wl-summary-sticky-buffer-name name))
	(get-buffer-create wl-summary-buffer-name))))

(defun wl-summary-make-number-list ()
  (setq wl-summary-buffer-number-list
	(mapcar
	 (lambda (x) (elmo-msgdb-overview-entity-get-number x))
	 (elmo-msgdb-get-overview (wl-summary-buffer-msgdb)))))

(defun wl-summary-auto-select-msg-p (unread-msg)
  (and unread-msg
       (not (string=
	     (cadr (assoc unread-msg
			  (elmo-msgdb-get-mark-alist
			   (wl-summary-buffer-msgdb))))
	     wl-summary-important-mark))))

(defsubst wl-summary-open-folder (folder)
  ;; Select folder
  (let ((elmo-mime-charset wl-summary-buffer-mime-charset))
    (unwind-protect
	(elmo-folder-open folder 'load-msgdb)
      ;; For compatibility
      (setq wl-summary-buffer-msgdb (elmo-folder-msgdb folder))
      (setq wl-summary-buffer-folder-name (elmo-folder-name-internal
					   folder)))))

(defun wl-summary-goto-folder-subr (&optional name scan-type other-window
					      sticky interactive scoring)
  "Display target folder on summary."
  (interactive)
  (let* ((keep-cursor (memq this-command
			    wl-summary-keep-cursor-command))
	 (name (or name (wl-summary-read-folder wl-default-folder)))
	 (cur-fld wl-summary-buffer-elmo-folder)
	 folder buf mes hilit reuse-buf
	 retval entity)
    (if (string= name "")
	(setq name wl-default-folder))
    (setq folder (wl-folder-get-elmo-folder name))
    (when (and (not (string=
		     (and cur-fld (elmo-folder-name-internal cur-fld))
		     (elmo-folder-name-internal folder))) ; folder is moved.
	       (eq major-mode 'wl-summary-mode)) ; called in summary.
      (setq wl-summary-last-visited-folder (wl-summary-buffer-folder-name))
      (run-hooks 'wl-summary-exit-pre-hook)
      (wl-summary-cleanup-temp-marks (wl-summary-sticky-p))
      (wl-summary-save-view)
      (elmo-folder-commit wl-summary-buffer-elmo-folder))
    (setq buf (wl-summary-get-buffer-create (elmo-folder-name-internal folder)
					    sticky))
    (setq reuse-buf
	  (save-excursion
	    (set-buffer buf)
	    (string= (elmo-folder-name-internal folder)
		     (wl-summary-buffer-folder-name))))
    (unwind-protect
	(if reuse-buf
	    (if interactive
		(switch-to-buffer buf)
	      (set-buffer buf))
	  (if other-window
	      (delete-other-windows))
	  (set-buffer buf)
	  (unless (eq major-mode 'wl-summary-mode)
	    (wl-summary-mode))
	  (wl-summary-buffer-set-folder folder)
	  (setq wl-summary-buffer-disp-msg nil)
	  (setq wl-summary-buffer-last-displayed-msg nil)
	  (setq wl-summary-buffer-current-msg nil)
	  (let ((case-fold-search nil)
		(inhibit-read-only t)
		(buffer-read-only nil))
	    (erase-buffer)
	    ;; Resume summary view
	    (if wl-summary-cache-use
		(let* ((dir (elmo-folder-msgdb-path folder))
		       (cache (expand-file-name wl-summary-cache-file dir))
		       (view (expand-file-name wl-summary-view-file dir)))
		  (when (file-exists-p cache)
		    (insert-file-contents-as-binary cache)
		    (elmo-set-buffer-multibyte
		     default-enable-multibyte-characters)
		    (decode-mime-charset-region
		     (point-min)(point-max)
		     wl-summary-buffer-mime-charset))
		  (when (file-exists-p view)
		    (setq wl-summary-buffer-view
			  (wl-summary-load-file-object view)))
		  (wl-thread-resume-entity folder)
		  (wl-summary-open-folder folder))
	      (setq wl-summary-buffer-view
		    (wl-summary-load-file-object
		     (expand-file-name wl-summary-view-file
				       (elmo-folder-msgdb-path folder))))
	      (wl-summary-open-folder folder)
	      (wl-summary-rescan))
	    (wl-summary-count-unread
	     (elmo-msgdb-get-mark-alist (wl-summary-buffer-msgdb)))
	    (wl-summary-update-modeline)))
      (unless (eq wl-summary-buffer-view 'thread)
	(wl-summary-make-number-list))
      (wl-summary-buffer-number-column-detect t)
      (wl-summary-toggle-disp-msg (if wl-summary-buffer-disp-msg 'on 'off))
      (unless (and reuse-buf keep-cursor)
	;(setq hilit wl-summary-highlight)
	(unwind-protect
	    (let ((wl-summary-highlight (if reuse-buf wl-summary-highlight))
		  (wl-use-scoring
		   (if (or scoring interactive) wl-use-scoring)))
	      (if (and (not scan-type)
		       interactive
		       (not wl-ask-range))
		  (setq scan-type (wl-summary-get-sync-range folder)))
	      (cond
	       ((eq scan-type nil)
		(wl-summary-sync 'unset-cursor))
	       ((eq scan-type 'all)
		(wl-summary-sync 'unset-cursor "all"))
	       ((eq scan-type 'no-sync))
	       ((or (eq scan-type 'force-update)
		    (eq scan-type 'update))
		(setq mes (wl-summary-sync-force-update
			   'unset-cursor 'no-check)))))
	  (if interactive
	      (switch-to-buffer buf)
	    (set-buffer buf))
	  ;; stick always-sticky-folder
	  (when (wl-summary-always-sticky-folder-p folder)
	    (or (wl-summary-sticky-p) (wl-summary-stick t)))
	  (run-hooks 'wl-summary-prepared-pre-hook)
	  (set-buffer-modified-p nil)
	  (goto-char (point-min))
	  (if (wl-summary-cursor-down t)
	      (let ((unreadp (wl-summary-next-message
			      (wl-summary-message-number)
			      'down t)))
		(cond ((and wl-auto-select-first
			    (wl-summary-auto-select-msg-p unreadp))
		       ;; wl-auto-select-first is non-nil and
		       ;; unreadp is non-nil but not important
		       (setq retval 'disp-msg))
		      ((and wl-auto-prefetch-first
			    (wl-summary-auto-select-msg-p unreadp))
		       ;; wl-auto-select-first is non-nil and
		       ;; unreadp is non-nil but not important
		       (setq retval 'prefetch-msg))
		      ((not (wl-summary-auto-select-msg-p unreadp))
		       ;; unreadp is nil or important
		       (setq retval 'more-next))))
	    (goto-char (point-max))
	    (if (elmo-folder-plugged-p folder)
		(forward-line -1)
	      (wl-summary-prev))
	    (setq retval 'more-next))
	  ;(setq wl-summary-highlight hilit)
	  (if (and wl-summary-highlight
		   (not wl-summary-lazy-highlight)
		   (not reuse-buf))
	      (if (and wl-summary-highlight-partial-threshold
		       (> (count-lines (point-min) (point-max))
			  wl-summary-highlight-partial-threshold))
		  (save-excursion
		    (forward-line (-
				   0
				   (or
				    wl-summary-partial-highlight-above-lines
				    wl-summary-highlight-partial-threshold)))
		    (wl-highlight-summary (point) (point-max)))
		(wl-highlight-summary (point-min) (point-max))))
	  (if (eq retval 'disp-msg)
	      (wl-summary-redisplay))
	  (if (eq retval 'prefetch-msg)
	      (wl-message-buffer-prefetch
	       folder
	       (wl-summary-message-number)
	       wl-message-buffer-prefetch-depth
	       (current-buffer)
	       wl-summary-buffer-mime-charset))
	  (if mes (message "%s" mes))
	  (if (and interactive wl-summary-recenter)
	      (recenter (/ (- (window-height) 2) 2))))))
    ;; set current entity-id
    (if (and (not folder)
	     (setq entity
		   (wl-folder-search-entity-by-name (elmo-folder-name-internal
						     folder)
						    wl-folder-entity
						    'folder)))
	;; entity-id is unknown.
	(wl-folder-set-current-entity-id
	 (wl-folder-get-entity-id entity)))
    (unwind-protect
	(run-hooks 'wl-summary-prepared-hook)
      (set-buffer-modified-p nil))
    retval))

(defun wl-summary-summary-line-already-exists-p (parent-number buffer)
  "Return the depth."
  (set-buffer buffer)
  (goto-char (point-max))
  (let ((depth 0))
    (when (re-search-backward (format "^ *%s..../..\(.*\)..:.. "
				      parent-number) nil t)
      (goto-char (match-end 0))
      (while (string-match wl-thread-indent-regexp
			   (char-to-string
			    (char-after (point))))
	(setq depth (+ 1 depth))
	(forward-char))
      (/ depth wl-thread-indent-level-internal))))

(defun wl-summary-goto-bottom-of-current-thread ()
  (if (re-search-forward (concat "^" wl-summary-buffer-number-regexp
				 "..../..\(.*\)..:.. [[<]") nil t)
      ()
    (goto-char (point-max))))

(defun wl-summary-goto-top-of-current-thread ()
  (wl-summary-jump-to-msg
   (wl-thread-entity-get-number
    (wl-thread-entity-get-top-entity (wl-thread-get-entity
				      (wl-summary-message-number))))))

(defun wl-summary-goto-bottom-of-sub-thread (&optional depth)
  (interactive)
  (let ((depth (or depth
		   (wl-thread-get-depth-of-current-line))))
    (forward-line 1)
    (while (and (not (eobp))
		(>= (wl-thread-get-depth-of-current-line)
		    depth))
      (forward-line 1))
    (beginning-of-line)))

(defun wl-summary-insert-line (line)
  "Insert LINE in the Summary."
  (if wl-use-highlight-mouse-line
      ;; remove 'mouse-face of current line.
      (put-text-property
       (save-excursion (beginning-of-line)(point))
       (save-excursion (end-of-line)(point))
       'mouse-face nil))
  (insert line "\n")
  (if wl-use-highlight-mouse-line
      ;; remove 'mouse-face of current line.
      (put-text-property
       (save-excursion (beginning-of-line)(point))
       (save-excursion (end-of-line)(point))
       'mouse-face nil))
  (condition-case nil ; it's dangerous, so ignore error.
      (run-hooks 'wl-summary-line-inserted-hook)
    (error (ding)
	   (message "Error in wl-summary-line-inserted-hook"))))

(defun wl-summary-insert-summary (entity database mark-alist dummy &optional dumm)
  (let ((overview-entity entity)
	summary-line msg)
    (setq msg (elmo-msgdb-overview-entity-get-number entity))
    (when (setq summary-line
		(wl-summary-overview-create-summary-line
		 msg entity nil 0 mark-alist))
      (let ((inhibit-read-only t)
	    buffer-read-only)
	(goto-char (point-max))
	(wl-summary-insert-line summary-line)))))

(defun wl-summary-default-subject-filter (subject)
  (let ((case-fold-search t))
    (setq subject (elmo-replace-in-string subject "[ \t]*\\(re\\|was\\)[:>]" ""))
    (setq subject (elmo-replace-in-string subject "[ \t]" ""))
    (elmo-replace-in-string subject "^\\[.*\\]" "")))

(defun wl-summary-subject-equal (subject1 subject2)
  (string= (wl-summary-subject-filter-func-internal subject1)
	   (wl-summary-subject-filter-func-internal subject2)))

(defmacro wl-summary-put-alike (alike)
  (` (elmo-set-hash-val (format "#%d" (wl-count-lines))
			(, alike)
			wl-summary-alike-hashtb)))

(defmacro wl-summary-get-alike ()
  (` (elmo-get-hash-val (format "#%d" (wl-count-lines))
			wl-summary-alike-hashtb)))

(defun wl-summary-insert-headers (overview func mime-decode)
  (let (ov this last alike)
    (buffer-disable-undo (current-buffer))
    (make-local-variable 'wl-summary-alike-hashtb)
    (setq wl-summary-alike-hashtb (elmo-make-hash (* (length overview) 2)))
    (when mime-decode
      (elmo-set-buffer-multibyte default-enable-multibyte-characters))
    (while (setq ov (pop overview))
      (setq this (funcall func ov))
      (and this (setq this (std11-unfold-string this)))
      (if (equal last this)
	  (wl-append alike (list ov))
	(when last
	  (wl-summary-put-alike alike)
	  (insert last ?\n))
	(setq alike (list ov)
	      last this)))
    (when last
      (wl-summary-put-alike alike)
      (insert last ?\n))
    (when mime-decode
      (decode-mime-charset-region (point-min) (point-max)
				  elmo-mime-charset)
      (when (eq mime-decode 'mime)
	(eword-decode-region (point-min) (point-max))))
    (run-hooks 'wl-summary-insert-headers-hook)))

(defun wl-summary-search-by-subject (entity overview)
  (let ((summary-buf (current-buffer))
	(buf (get-buffer-create wl-summary-search-buf-name))
	(folder-name (wl-summary-buffer-folder-name))
	match founds found-entity)
    (with-current-buffer buf
      (let ((case-fold-search t))
	(when (or (not (string= wl-summary-search-buf-folder-name folder-name))
		  (zerop (buffer-size)))
	  (setq wl-summary-search-buf-folder-name folder-name)
	  (wl-summary-insert-headers
	   overview
	   (function
	    (lambda (x)
	      (wl-summary-subject-filter-func-internal
	       (elmo-msgdb-overview-entity-get-subject-no-decode x))))
	   t))
	(setq match (wl-summary-subject-filter-func-internal
		     (elmo-msgdb-overview-entity-get-subject entity)))
	(if (string= match "")
	    (setq match "\n"))
	(goto-char (point-min))
	(while (and (not founds)
		    (not (= (point) (point-max)))
		    (search-forward match nil t))
	  ;; check exactly match
	  (when (and (eolp)
		     (= (point-at-bol)
			(match-beginning 0)))
	    (setq found-entity (wl-summary-get-alike))
	    (if (and found-entity
		     ;; Is founded entity myself or children?
		     (not (string=
			   (elmo-msgdb-overview-entity-get-id entity)
			   (elmo-msgdb-overview-entity-get-id
			    (car found-entity))))
		     (with-current-buffer summary-buf
		       (not (wl-thread-descendant-p
			     (elmo-msgdb-overview-entity-get-number entity)
			     (elmo-msgdb-overview-entity-get-number
			      (car found-entity))))))
		;; return matching entity
		(setq founds found-entity))))
	(if founds
	    (car founds))))))

(defun wl-summary-insert-thread-entity (entity overview mark-alist update
					       &optional force-insert)
  (let (update-list entity-stack)
    (while entity
      (let* ((this-id (elmo-msgdb-overview-entity-get-id entity))
	     (parent-entity
	      (elmo-msgdb-overview-get-parent-entity entity overview));; temp
;;;	     (parent-id (elmo-msgdb-overview-entity-get-id parent-entity))
	     (parent-number (elmo-msgdb-overview-entity-get-number parent-entity))
	     (case-fold-search t)
	     msg overview2 cur-entity linked retval delayed-entity)
	(setq msg (elmo-msgdb-overview-entity-get-number entity))
	(if (and parent-number
		 (not (wl-thread-get-entity parent-number))
		 (not force-insert))
	    ;; parent is exists in overview, but not exists in wl-thread-entities
	    (progn
	      (wl-append wl-summary-delayed-update
			 (list (cons parent-number entity)))
	      (setq entity nil)) ;; exit loop
	  ;; Search parent by subject.
	  (when (and (null parent-number)
		     wl-summary-search-parent-by-subject-regexp
		     (string-match
		      wl-summary-search-parent-by-subject-regexp
		      (elmo-msgdb-overview-entity-get-subject entity)))
	    (let ((found (wl-summary-search-by-subject entity overview)))
	      (when (and found
			 (not (member found wl-summary-delayed-update)))
		(setq parent-entity found)
		(setq parent-number
		      (elmo-msgdb-overview-entity-get-number parent-entity))
		(setq linked t))))
	  ;; If subject is change, divide thread.
	  (if (and parent-number
		   wl-summary-divide-thread-when-subject-changed
		   (not (wl-summary-subject-equal
			 (or (elmo-msgdb-overview-entity-get-subject
			      entity) "")
			 (or (elmo-msgdb-overview-entity-get-subject
			      parent-entity) ""))))
	      (setq parent-number nil))
	  ;;
	  (setq retval
		(wl-thread-insert-message entity overview mark-alist
					  msg parent-number update linked))
	  (and retval
	       (wl-append update-list (list retval)))
	  (setq entity nil) ; exit loop
	  (while (setq delayed-entity (assq msg wl-summary-delayed-update))
	    (setq wl-summary-delayed-update
		  (delete delayed-entity wl-summary-delayed-update))
	    ;; update delayed message
	    (wl-append entity-stack (list (cdr delayed-entity)))))
	(if (and (not entity)
		 entity-stack)
	    (setq entity (pop entity-stack)))))
    update-list))

(defun wl-summary-update-thread (entity
				 overview
				 mark-alist
				 thr-entity
				 parent-entity)
  (let* ((depth 0)
	 (this-id (elmo-msgdb-overview-entity-get-id entity))
	 (overview-entity entity)
	 (parent-id (elmo-msgdb-overview-entity-get-id parent-entity))
	 (parent-number (elmo-msgdb-overview-entity-get-number parent-entity))
	 summary-line msg subject-differ)
    (cond
     ((or (not parent-id)
	  (string= this-id parent-id))
      (goto-char (point-max))
      (beginning-of-line))
     ;; parent already exists in buffer.
     ((setq depth (or (wl-summary-summary-line-already-exists-p
		       parent-number (current-buffer)) -1))
      (setq depth (+ 1 depth))
      (wl-thread-goto-bottom-of-sub-thread)))
    (if (and (setq msg (elmo-msgdb-overview-entity-get-number entity)))
	(if (setq summary-line
		  (wl-summary-overview-create-summary-line
		   msg entity parent-entity depth mark-alist
		   (wl-thread-maybe-get-children-num msg)
		   nil thr-entity))
	    (let ((inhibit-read-only t)
		  (buffer-read-only nil))
	      (wl-summary-insert-line summary-line))))))

(defun wl-summary-mark-as-unread (&optional number
					    no-server-update
					    no-modeline-update)
  (interactive)
  (save-excursion
    (let* (eol
	  (inhibit-read-only t)
	  (buffer-read-only nil)
	  (folder wl-summary-buffer-elmo-folder)
	  (msgdb (wl-summary-buffer-msgdb))
	  (mark-alist (elmo-msgdb-get-mark-alist msgdb))
;;;	  (number-alist (elmo-msgdb-get-number-alist msgdb))
	  new-mark visible mark)
      (if number
	  (progn
	    (setq visible (wl-summary-jump-to-msg number))
	    (unless (setq mark (cadr (assq number mark-alist)))
	      (setq mark " ")))
	;; interactive
	(setq visible t))
      (when visible
	(if (null (wl-summary-message-number))
	    (message "No message.")
	  (end-of-line)
	  (setq eol (point))
	  (re-search-backward (concat "^" wl-summary-buffer-number-regexp
				      "..../..")) ; set cursor line
	  (beginning-of-line)))
      (if (or (and (not visible)
		   ;; already exists in msgdb.
		   (assq number (elmo-msgdb-get-number-alist msgdb)))
	      (re-search-forward
	       (format (concat "^ *\\("
			       (if number (int-to-string number)
				 "-?[0-9]+")
			       "\\)[^0-9]\\(%s\\|%s\\)")
		       wl-summary-read-uncached-mark
		       " ") eol t))
	  (progn
	    (setq number (or number (string-to-int (wl-match-buffer 1))))
	    (setq mark (or mark (elmo-match-buffer 2)))
	    (save-match-data
	      (setq new-mark (if (string= mark
					  wl-summary-read-uncached-mark)
				 wl-summary-unread-uncached-mark
			       (if (elmo-message-use-cache-p folder number)
				   wl-summary-unread-mark
				 wl-summary-unread-uncached-mark))))
	    ;; server side mark
	    (unless no-server-update
	      (save-match-data
		(unless (elmo-folder-unmark-read folder (list number))
		  (error "Setting mark failed"))))
	    (when visible
	      (delete-region (match-beginning 2) (match-end 2))
	      (insert new-mark))
	    (setq mark-alist
		  (elmo-msgdb-mark-set mark-alist
				       number
				       new-mark))
	    (elmo-msgdb-set-mark-alist msgdb mark-alist)
	    (unless no-modeline-update
	      (setq wl-summary-buffer-unread-count
		    (+ 1 wl-summary-buffer-unread-count))
	      (wl-summary-update-modeline)
	      (wl-folder-update-unread
	       (wl-summary-buffer-folder-name)
	       (+ wl-summary-buffer-unread-count
		  wl-summary-buffer-new-count)))
	    (wl-summary-set-mark-modified)
	    (if (and visible wl-summary-highlight)
		(wl-highlight-summary-current-line))))))
  (set-buffer-modified-p nil))

(defun wl-summary-delete (&optional number)
  "Mark Delete mark 'D'.
If optional argument NUMBER is specified, mark message specified by NUMBER."
  (interactive)
  (let* ((buffer-num (wl-summary-message-number))
	 (msg-num (or number buffer-num))
	 mark)
    (catch 'done
      (when (null msg-num)
	(if (interactive-p)
	    (message "No message."))
	(throw 'done nil))
      (when (setq mark (wl-summary-get-mark msg-num))
	(when (wl-summary-reserve-temp-mark-p mark)
	  (if (interactive-p)
	      (error "Already marked as `%s'" mark))
	  (throw 'done nil))
	(wl-summary-unmark msg-num))
      (if (or (interactive-p)
	      (eq number buffer-num))
	  (wl-summary-mark-line "D"))
      (setq wl-summary-buffer-delete-list
	    (cons msg-num wl-summary-buffer-delete-list))
      (if (interactive-p)
	  (if (eq wl-summary-move-direction-downward nil)
	      (wl-summary-prev)
	    (wl-summary-next)))
      msg-num)))

(defun wl-summary-remove-destination ()
  (save-excursion
    (let ((inhibit-read-only t)
	  (buffer-read-only nil)
	  (buf (current-buffer))
	  sol eol rs re)
      (beginning-of-line)
      (setq sol (point))
      (end-of-line)
      (setq eol (point))
      (setq rs (next-single-property-change sol 'wl-summary-destination
					    buf eol))
      (setq re (next-single-property-change rs 'wl-summary-destination
					    buf eol))
      (put-text-property rs re 'wl-summary-destination nil)
      (put-text-property rs re 'invisible nil)
      (goto-char re)
      (delete-char (- eol re)))))

(defun wl-summary-check-mark (msg mark)
  (let ((check-func (cond ((string= mark "o")
			   'wl-summary-msg-marked-as-refiled)
			  ((string= mark "O")
			   'wl-summary-msg-marked-as-copied)
			  ((string= mark "D")
			   'wl-summary-msg-marked-as-deleted)
			  ((string= mark "*")
			   'wl-summary-msg-marked-as-target))))
    (if check-func
	(funcall check-func msg))))

(defun wl-summary-mark-collect (mark &optional begin end)
  (save-excursion
    (save-restriction
      (let (msglist)
	(narrow-to-region (or begin (point-min))
			  (or end (point-max)))
	(goto-char (point-min))
	;; for thread...
	(if (eq wl-summary-buffer-view 'thread)
	    (progn
	      (while (not (eobp))
		(let* ((number (wl-summary-message-number))
		       (entity (wl-thread-get-entity number))
		       result)
		  ;; opened...only myself is checked.
		  (if (wl-summary-check-mark number mark)
		      (wl-append msglist (list number)))
		  (unless (wl-thread-entity-get-opened entity)
		    ;; closed...children is also checked.
		    (if (setq result (wl-thread-get-children-msgs-with-mark
				      number
				      mark))
			(wl-append msglist result)))
		  (forward-line 1)))
	      (elmo-uniq-list msglist))
	  (let* ((case-fold-search nil)
		 (re (format (concat wl-summary-message-regexp "%s")
			     (regexp-quote mark))))
	    (while (re-search-forward re nil t)
	      (setq msglist (cons (wl-summary-message-number) msglist)))
	    (nreverse msglist)))))))

(defun wl-summary-exec ()
  (interactive)
  (wl-summary-exec-subr (mapcar 'car wl-summary-buffer-refile-list)
			(reverse wl-summary-buffer-delete-list)
			(mapcar 'car wl-summary-buffer-copy-list)))

(defun wl-summary-exec-region (beg end)
  (interactive "r")
  (message "Collecting marks ...")
  (save-excursion
    (goto-char beg)
    (beginning-of-line)
    (setq beg (point))
    (goto-char (1- end))
    (forward-line)
    (setq end (point))
    (wl-summary-exec-subr (wl-summary-mark-collect "o" beg end)
			  (wl-summary-mark-collect "D" beg end)
			  (wl-summary-mark-collect "O" beg end))))

(defun wl-summary-exec-subr (moves dels copies)
  (if (not (or moves dels copies))
      (message "No marks")
    (save-excursion
      (let ((del-fld (wl-summary-get-delete-folder
		      (wl-summary-buffer-folder-name)))
	    (start (point))
	    (unread-marks (list wl-summary-unread-cached-mark
				wl-summary-unread-uncached-mark
				wl-summary-new-mark))
	    (refiles (append moves dels))
	    (refile-failures 0)
	    (copy-failures 0)
	    (copy-len (length copies))
	    refile-len
	    dst-msgs			; loop counter
	    result)
	(message "Executing ...")
	(while dels
	  (when (not (assq (car dels) wl-summary-buffer-refile-list))
	    (wl-append wl-summary-buffer-refile-list
		       (list (cons (car dels) del-fld)))
	    (setq wl-summary-buffer-delete-list
		  (delete (car dels) wl-summary-buffer-delete-list)))
	  (setq dels (cdr dels)))
	;; begin refile...
	(setq refile-len (length refiles))
	(setq dst-msgs
	      (wl-inverse-alist refiles wl-summary-buffer-refile-list))
	(goto-char start)		; avoid moving cursor to
					; the bottom line.
	(when (> refile-len elmo-display-progress-threshold)
	  (elmo-progress-set 'elmo-folder-move-messages
			     refile-len "Moving messages..."))
	(while dst-msgs
	  (setq result nil)
	  (condition-case nil
	      (setq result (elmo-folder-move-messages
			    wl-summary-buffer-elmo-folder
			    (cdr (car dst-msgs))
			    (if (eq 'null (car (car dst-msgs)))
				'null
			      (wl-folder-get-elmo-folder
			       (car (car dst-msgs))))
			    (wl-summary-buffer-msgdb)
			    (not (null (cdr dst-msgs)))
			    nil ; no-delete
			    nil ; same-number
			    unread-marks
			    t))
	    (error nil))
	  (if result			; succeeded.
	      (progn
		;; update buffer.
		(wl-summary-delete-messages-on-buffer (cdr (car dst-msgs)))
		;; update refile-alist.
		(setq wl-summary-buffer-refile-list
		      (wl-delete-associations (cdr (car dst-msgs))
					      wl-summary-buffer-refile-list)))
	    (setq refile-failures
		  (+ refile-failures (length (cdr (car dst-msgs))))))
	  (setq dst-msgs (cdr dst-msgs)))
	(elmo-progress-clear 'elmo-folder-move-messages)
	;; end refile
	;; begin cOpy...
	(setq dst-msgs (wl-inverse-alist copies wl-summary-buffer-copy-list))
	(when (> copy-len elmo-display-progress-threshold)
	  (elmo-progress-set 'elmo-folder-move-messages
			     copy-len "Copying messages..."))
	(while dst-msgs
	  (setq result nil)
	  (condition-case nil
	      (setq result (elmo-folder-move-messages
			    wl-summary-buffer-elmo-folder
			    (cdr (car dst-msgs))
			    (wl-folder-get-elmo-folder
			     (car (car dst-msgs)))
			    (wl-summary-buffer-msgdb)
			    (not (null (cdr dst-msgs)))
			    t ; t is no-delete (copy)
			    nil ; same number
			    unread-marks
			    t))
	    (error nil))
	  (if result			; succeeded.
	      (progn
		;; update buffer.
		(wl-summary-delete-copy-marks-on-buffer (cdr (car dst-msgs)))
		;; update copy-alist
		(setq wl-summary-buffer-copy-list
		      (wl-delete-associations (cdr (car dst-msgs))
					      wl-summary-buffer-copy-list)))
	    (setq copy-failures
		  (+ copy-failures (length (cdr (car dst-msgs))))))
	  (setq dst-msgs (cdr dst-msgs)))
	;; Hide progress bar.
	(elmo-progress-clear 'elmo-folder-move-messages)
	;; end cOpy
	(wl-summary-folder-info-update)
	(wl-summary-set-message-modified)
	(wl-summary-set-mark-modified)
	(run-hooks 'wl-summary-exec-hook)
	(unless (and wl-message-buffer
		     (eq (wl-summary-message-number)
			 (with-current-buffer wl-message-buffer
			   wl-message-buffer-cur-number)))
	  (wl-summary-toggle-disp-msg 'off))
	(set-buffer-modified-p nil)
	(message (concat "Executing ... done"
			 (if (> refile-failures 0)
			     (format " (%d refiling failed)" refile-failures)
			   "")
			 (if (> copy-failures 0)
			     (format " (%d copying failed)" copy-failures)
			   "")
			 "."))))))

(defun wl-summary-read-folder (default &optional purpose ignore-error
				no-create init)
  (let ((fld (completing-read
	      (format "Folder name %s(%s): " (or purpose "")
		      default)
	      (or wl-folder-completion-function
		  (if (memq 'read-folder wl-use-folder-petname)
		      (wl-folder-get-entity-with-petname)
		    wl-folder-entity-hashtb))
	      nil nil (or init wl-default-spec)
	      'wl-read-folder-hist)))
    (if (or (string= fld wl-default-spec)
	    (string= fld ""))
	(setq fld default))
    (setq fld (elmo-string (wl-folder-get-realname fld)))
    (if (string-match "\n" fld)
	(error "Not supported folder name: %s" fld))
    (unless no-create
      (if ignore-error
	  (condition-case nil
	      (wl-folder-confirm-existence
	       (wl-folder-get-elmo-folder
		fld))
	    (error))
	(wl-folder-confirm-existence (wl-folder-get-elmo-folder
				      fld))))
    fld))

(defun wl-summary-print-destination (msg-num folder)
  "Print refile destination on line."
  (wl-summary-remove-destination)
  (let ((inhibit-read-only t)
	(folder (copy-sequence folder))
	(buffer-read-only nil)
	len rs re c)
    (setq len (string-width folder))
    (if (< len 1) ()
      (end-of-line)
      (setq re (point))
      (setq c 0)
      (while (< c len)
	(forward-char -1)
	(setq c (+ c (char-width (following-char)))))
      (and (> c len) (setq folder (concat " " folder)))
      (setq rs (point))
      (put-text-property rs re 'invisible t)
      (put-text-property rs re 'wl-summary-destination t)
      (goto-char re)
      (wl-highlight-refile-destination-string folder)
      (insert folder)
      (set-buffer-modified-p nil))))

(defsubst wl-summary-get-mark (number)
  "Return a temporal mark of message specified by NUMBER."
  (or (and (memq number wl-summary-buffer-delete-list) "D")
      (and (assq number wl-summary-buffer-copy-list) "O")
      (and (assq number wl-summary-buffer-refile-list) "o")
      (and (memq number wl-summary-buffer-target-mark-list) "*")))

(defsubst wl-summary-reserve-temp-mark-p (mark)
  "Return t if temporal MARK should be reserved."
  (member mark wl-summary-reserve-mark-list))

(defun wl-summary-refile (&optional dst number)
  "Put refile mark on current line message.
If optional argument DST is specified, put mark without asking
destination folder.
If optional argument NUMBER is specified, mark message specified by NUMBER.

If folder is read-only, message should be copied.
See `wl-refile-policy-alist' for more details."
  (interactive)
  (let ((policy (wl-get-assoc-list-value wl-refile-policy-alist
					 (wl-summary-buffer-folder-name))))
    (cond ((eq policy 'copy)
	   (if (interactive-p)
	       (call-interactively 'wl-summary-copy)
	     (wl-summary-copy dst number)))
	  (t
	   (wl-summary-refile-subr 'refile (interactive-p) dst number)))))

(defun wl-summary-copy (&optional dst number)
  "Put copy mark on current line message.
If optional argument DST is specified, put mark without asking
destination folder.
If optional argument NUMBER is specified, mark message specified by NUMBER."
  (interactive)
  (wl-summary-refile-subr 'copy (interactive-p) dst number))

(defun wl-summary-refile-subr (copy-or-refile interactive &optional dst number)
  (let* ((buffer-num (wl-summary-message-number))
	 (msg-num (or number buffer-num))
	 (msgid (and msg-num
		     (elmo-message-field wl-summary-buffer-elmo-folder
					 msg-num 'message-id)))
	 (entity (and msg-num
		      (elmo-msgdb-overview-get-entity
		       msg-num (wl-summary-buffer-msgdb))))
	 (variable
	  (intern (format "wl-summary-buffer-%s-list" copy-or-refile)))
	 folder mark already tmp-folder)
    (catch 'done
      (when (null entity)
	;; msgdb is empty?
	(if interactive
	    (message "Cannot refile."))
	(throw 'done nil))
      (when (null msg-num)
	(if interactive
	    (message "No message."))
	(throw 'done nil))
      (when (setq mark (wl-summary-get-mark msg-num))
	(when (wl-summary-reserve-temp-mark-p mark)
	  (if interactive
	      (error "Already marked as `%s'" mark))
	  (throw 'done nil)))
      (setq folder (and msg-num
			(or dst (wl-summary-read-folder
				 (or (wl-refile-guess entity) wl-trash-folder)
				 (format "for %s" copy-or-refile)))))
      ;; Cache folder hack by okada@opaopa.org
      (if (and (eq (elmo-folder-type-internal
		    (wl-folder-get-elmo-folder
		     (wl-folder-get-realname folder))) 'cache)
	       (not (string= folder
			     (setq tmp-folder
				   (concat "'cache/"
					   (elmo-cache-get-path-subr
					    (elmo-msgid-to-cache msgid)))))))
	  (progn
	    (setq folder tmp-folder)
	    (message "Force refile to %s." folder)))
      (if (string= folder (wl-summary-buffer-folder-name))
	  (error "Same folder"))
      (if (or (string= folder wl-queue-folder)
	      (string= folder wl-draft-folder))
	  (error "Don't %s messages to %s" copy-or-refile folder))
      ;; learn for refile.
      (if (eq copy-or-refile 'refile)
	  (wl-refile-learn entity folder))
      (wl-summary-unmark msg-num)
      (set variable (append
		     (symbol-value variable)
		     (list (cons msg-num folder))))
      (when (or interactive
		(eq number buffer-num))
	(wl-summary-mark-line (if (eq copy-or-refile 'refile)
				  "o" "O"))
	;; print refile destination
	(wl-summary-print-destination msg-num folder))
      (if interactive
	  (if (eq wl-summary-move-direction-downward nil)
	      (wl-summary-prev)
	    (wl-summary-next)))
      (run-hooks (intern (format "wl-summary-%s-hook" copy-or-refile)))
      (setq wl-summary-buffer-prev-refile-destination folder)
      msg-num)))

(defun wl-summary-refile-prev-destination ()
  "Refile message to previously refiled destination."
  (interactive)
  (wl-summary-refile wl-summary-buffer-prev-refile-destination
		     (wl-summary-message-number))
  (if (eq wl-summary-move-direction-downward nil)
      (wl-summary-prev)
    (wl-summary-next)))

(defun wl-summary-copy-prev-destination ()
  "Refile message to previously refiled destination."
  (interactive)
  (wl-summary-copy wl-summary-buffer-prev-copy-destination
		   (wl-summary-message-number))
  (if (eq wl-summary-move-direction-downward nil)
      (wl-summary-prev)
    (wl-summary-next)))

(defsubst wl-summary-no-auto-refile-message-p (msg mark-alist)
  (member (cadr (assq msg mark-alist)) wl-summary-auto-refile-skip-marks))

(defun wl-summary-auto-refile (&optional open-all)
  "Set refile mark automatically according to 'wl-refile-guess-by-rule'."
  (interactive "P")
  (message "Marking...")
  (save-excursion
    (if (and (eq wl-summary-buffer-view 'thread)
	     open-all)
	(wl-thread-open-all))
    (let* ((spec (wl-summary-buffer-folder-name))
	   (overview (elmo-msgdb-get-overview
		      (wl-summary-buffer-msgdb)))
	   (mark-alist (elmo-msgdb-get-mark-alist
			(wl-summary-buffer-msgdb)))
	   checked-dsts
	   (count 0)
	   number dst thr-entity)
      (goto-line 1)
      (while (not (eobp))
	(setq number (wl-summary-message-number))
	(when (and (not (wl-summary-no-auto-refile-message-p number
							     mark-alist))
		   (setq dst
			 (wl-folder-get-realname
			  (wl-refile-guess-by-rule
			   (elmo-msgdb-overview-get-entity
			    number (wl-summary-buffer-msgdb)))))
		   (not (equal dst spec)))
	  (when (not (member dst checked-dsts))
	    (wl-folder-confirm-existence (wl-folder-get-elmo-folder dst))
	    (setq checked-dsts (cons dst checked-dsts)))
	  (if (wl-summary-refile dst number)
	      (incf count))
	  (message "Marking...%d message(s)." count))
	(if (eq wl-summary-buffer-view 'thread)
	    ;; process invisible children.
	    (unless (wl-thread-entity-get-opened
		     (setq thr-entity (wl-thread-get-entity number)))
	      (let ((messages
		     (elmo-delete-if
		      (function
		       (lambda (x)
			 (wl-summary-no-auto-refile-message-p
			  x mark-alist)))
		      (wl-thread-entity-get-descendant thr-entity))))
		(while messages
		  (when (and (setq dst
				   (wl-refile-guess-by-rule
				    (elmo-msgdb-overview-get-entity
				     (car messages) (wl-summary-buffer-msgdb))))
			     (not (equal dst spec)))
		    (if (wl-summary-refile dst (car messages))
			(incf count))
		    (message "Marking...%d message(s)." count))
		  (setq messages (cdr messages))))))
	(forward-line))
      (if (eq count 0)
	  (message "No message was marked.")
	(message "Marked %d message(s)." count)))))

(defun wl-summary-unmark (&optional number)
  "Unmark marks (temporary, refile, copy, delete)of current line.
If optional argument NUMBER is specified, unmark message specified by NUMBER."
  (interactive)
  (save-excursion
    (beginning-of-line)
    (let ((inhibit-read-only t)
	  (buffer-read-only nil)
	  visible
	  msg-num
	  cur-mark
	  score-mark)
      (if number
	  (setq visible (wl-summary-jump-to-msg number))
	(setq visible t))
      ;; Delete mark on buffer.
      (when (and visible
		 (looking-at "^ *\\(-?[0-9]+\\)\\([^0-9]\\)"))
	(goto-char (match-end 2))
	(or number
	    (setq number (string-to-int (wl-match-buffer 1))))
	(setq cur-mark (wl-match-buffer 2))
	(if (string= cur-mark " ")
	    ()
	  (delete-region (match-beginning 2) (match-end 2))
	  (if (setq score-mark (wl-summary-get-score-mark number))
	      (insert score-mark)
	    (insert " ")))
	(if (or (string= cur-mark "o")
		(string= cur-mark "O"))
	    (wl-summary-remove-destination))
	(if wl-summary-highlight
	    (wl-highlight-summary-current-line nil nil score-mark))
	(set-buffer-modified-p nil))
      ;; Remove from temporary mark structure.
      (and number
	   (wl-summary-delete-mark number)))))

(defun wl-summary-msg-marked-as-target (msg)
  (if (memq msg wl-summary-buffer-target-mark-list)
      t))

(defun wl-summary-msg-marked-as-copied (msg)
  (assq msg wl-summary-buffer-copy-list))

(defun wl-summary-msg-marked-as-deleted (msg)
  (if (memq msg wl-summary-buffer-delete-list)
      t))

(defun wl-summary-msg-marked-as-refiled (msg)
  (assq msg wl-summary-buffer-refile-list))

(defun wl-summary-target-mark (&optional number)
  "Put target mark '*' on current message.
If optional argument NUMBER is specified, mark message specified by NUMBER."
  (interactive)
  (let* ((buffer-num (wl-summary-message-number))
	 (msg-num (or number buffer-num))
	 mark)
    (catch 'done
      (when (null msg-num)
	(if (interactive-p)
	    (message "No message."))
	(throw 'done nil))
      (when (setq mark (wl-summary-get-mark msg-num))
	(when (wl-summary-reserve-temp-mark-p mark)
	  (if (interactive-p)
	      (error "Already marked as `%s'" mark))
	  (throw 'done nil))
	(wl-summary-unmark msg-num))
      (if (or (interactive-p)
	      (eq number buffer-num))
	  (wl-summary-mark-line "*"))
      (setq wl-summary-buffer-target-mark-list
	    (cons msg-num wl-summary-buffer-target-mark-list))
      (if (interactive-p)
	  (if (eq wl-summary-move-direction-downward nil)
	      (wl-summary-prev)
	    (wl-summary-next)))
      msg-num)))


(defun wl-summary-refile-region (beg end)
  "Put copy mark on messages in the region specified by BEG and END."
  (interactive "r")
  (wl-summary-refile-region-subr "refile" beg end))

(defun wl-summary-copy-region (beg end)
  "Put copy mark on messages in the region specified by BEG and END."
  (interactive "r")
  (wl-summary-refile-region-subr "copy" beg end))

(defun wl-summary-refile-region-subr (copy-or-refile beg end)
  (save-excursion
    (save-restriction
      (goto-char beg)
      ;; guess by first msg
      (let* ((msgid (cdr (assq (wl-summary-message-number)
			       (elmo-msgdb-get-number-alist
				(wl-summary-buffer-msgdb)))))
	     (function (intern (format "wl-summary-%s" copy-or-refile)))
	     (entity (assoc msgid (elmo-msgdb-get-overview
				   (wl-summary-buffer-msgdb))))
	     folder)
	(if entity
	    (setq folder (wl-summary-read-folder (wl-refile-guess entity)
						 (format "for %s"
							 copy-or-refile))))
	(narrow-to-region beg end)
	(if (eq wl-summary-buffer-view 'thread)
	    (progn
	      (while (not (eobp))
		(let* ((number (wl-summary-message-number))
		       (entity (wl-thread-get-entity number))
		       children)
		  (if (wl-thread-entity-get-opened entity)
		      ;; opened...refile line.
		      (funcall function folder number)
		    ;; closed
		    (setq children (wl-thread-get-children-msgs number))
		    (while children
		      (funcall function folder (pop children))))
		  (forward-line 1))))
	  (while (not (eobp))
	    (funcall function folder (wl-summary-message-number))
	    (forward-line 1)))))))

(defun wl-summary-unmark-region (beg end)
  (interactive "r")
  (save-excursion
    (save-restriction
      (narrow-to-region beg end)
      (goto-char (point-min))
      (if (eq wl-summary-buffer-view 'thread)
	  (progn
	    (while (not (eobp))
	      (let* ((number (wl-summary-message-number))
		     (entity (wl-thread-get-entity number)))
		(if (wl-thread-entity-get-opened entity)
		    ;; opened...unmark line.
		    (wl-summary-unmark)
		  ;; closed
		  (wl-summary-delete-marks-on-buffer
		   (wl-thread-get-children-msgs number))))
	      (forward-line 1)))
	(while (not (eobp))
	  (wl-summary-unmark)
	  (forward-line 1))))))

(defun wl-summary-mark-region-subr (function beg end)
  (save-excursion
    (save-restriction
      (narrow-to-region beg end)
      (goto-char (point-min))
      (if (eq wl-summary-buffer-view 'thread)
	  (progn
	    (while (not (eobp))
	      (let* ((number (wl-summary-message-number))
		     (entity (wl-thread-get-entity number))
		     (wl-summary-move-direction-downward t)
		     children)
		(if (wl-thread-entity-get-opened entity)
		    ;; opened...delete line.
		    (funcall function number)
		  ;; closed
		  (setq children (wl-thread-get-children-msgs number))
		  (while children
		    (funcall function (pop children))))
		(forward-line 1))))
	(while (not (eobp))
	  (funcall function (wl-summary-message-number))
	  (forward-line 1))))))

(defun wl-summary-delete-region (beg end)
  (interactive "r")
  (wl-summary-mark-region-subr 'wl-summary-delete beg end))

(defun wl-summary-target-mark-region (beg end)
  (interactive "r")
  (wl-summary-mark-region-subr 'wl-summary-target-mark beg end))

(defun wl-summary-target-mark-all ()
  (interactive)
  (wl-summary-target-mark-region (point-min) (point-max))
  (setq wl-summary-buffer-target-mark-list
	(mapcar 'car
		(elmo-msgdb-get-number-alist (wl-summary-buffer-msgdb)))))

(defun wl-summary-delete-all-mark (mark)
  (goto-char (point-min))
  (let ((case-fold-search nil))
    (while (re-search-forward (format "^ *-?[0-9]+%s"
				      (regexp-quote mark)) nil t)
      (wl-summary-unmark))
    (cond ((string= mark "*")
	   (setq wl-summary-buffer-target-mark-list nil))
	  ((string= mark "D")
	   (setq wl-summary-buffer-delete-list nil))
	  ((string= mark "O")
	   (setq wl-summary-buffer-copy-list nil))
	  ((string= mark "o")
	   (setq wl-summary-buffer-refile-list nil)))))

(defun wl-summary-unmark-all ()
  "Unmark all according to what you input."
  (interactive)
  (let ((unmarks (string-to-char-list (read-from-minibuffer "Unmark: ")))
	cur-mark)
    (save-excursion
      (while unmarks
	(setq cur-mark (char-to-string (car unmarks)))
	(wl-summary-delete-all-mark cur-mark)
	(setq unmarks (cdr unmarks))))))

(defun wl-summary-target-mark-thread ()
  (interactive)
  (let (beg end)
    (end-of-line)
    (wl-summary-goto-top-of-current-thread)
    (wl-thread-force-open)
    (setq beg (point))
    (end-of-line)
    (wl-summary-goto-bottom-of-current-thread)
;;; (forward-line -1)
    (beginning-of-line)
    (setq end (point))
    (wl-summary-target-mark-region beg end)))

(defun wl-summary-target-mark-msgs (msgs)
  "Return the number of marked messages."
  (let ((i 0) num)
    (while msgs
      (if (eq wl-summary-buffer-view 'thread)
	  (wl-thread-jump-to-msg (car msgs))
	(wl-summary-jump-to-msg (car msgs)))
      (setq num (wl-summary-message-number))
      (when (eq num (car msgs))
	(wl-summary-target-mark num)
	(setq i (1+ i)))
      (setq msgs (cdr msgs)))
    i))

(defun wl-summary-pick (&optional from-list delete-marks)
  (interactive)
  (save-excursion
    (let* ((condition (car (elmo-parse-search-condition
			    (elmo-read-search-condition
			     wl-summary-pick-field-default))))
	   (result (elmo-folder-search wl-summary-buffer-elmo-folder
				       condition
				       from-list))
	   num)
      (if delete-marks
	  (let ((mlist wl-summary-buffer-target-mark-list))
	    (while mlist
	      (when (wl-summary-jump-to-msg (car mlist))
		(wl-summary-unmark))
	      (setq mlist (cdr mlist)))
	    (setq wl-summary-buffer-target-mark-list nil)))
      (if (and result
	       (setq num (wl-summary-target-mark-msgs result))
	       (> num 0))
	  (if (= num (length result))
	      (message "%d message(s) are picked." num)
	    (message "%d(%d) message(s) are picked." num
		     (- (length result) num)))
	(message "No message was picked.")))))

(defun wl-summary-unvirtual ()
  "Exit from current virtual folder."
  (interactive)
  (if (eq 'filter
	  (elmo-folder-type-internal wl-summary-buffer-elmo-folder))
      (wl-summary-goto-folder-subr
       (elmo-folder-name-internal
	(elmo-filter-folder-target-internal
	 wl-summary-buffer-elmo-folder))
       'update nil nil t)
    (error "This folder is not filtered")))

(defun wl-summary-virtual (&optional arg)
  "Goto virtual folder.
If ARG, exit virtual folder."
  (interactive "P")
  (if arg
      (wl-summary-unvirtual)
    (wl-summary-goto-folder-subr (concat "/"
					 (elmo-read-search-condition
					  wl-summary-pick-field-default)
					 "/"
					 (wl-summary-buffer-folder-name))
				 'update nil nil t)))

(defun wl-summary-delete-all-temp-marks ()
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (message "Unmarking...")
    (while (not (eobp))
      (wl-summary-unmark)
      (forward-line))
    (message "Unmarking...done")
    (setq wl-summary-buffer-target-mark-list nil)
    (setq wl-summary-buffer-delete-list nil)
    (setq wl-summary-buffer-refile-list nil)
    (setq wl-summary-buffer-copy-list nil)))

(defun wl-summary-delete-mark (number)
  "Delete temporary mark of the message specified by NUMBER."
  (cond
   ((memq number wl-summary-buffer-target-mark-list)
    (setq wl-summary-buffer-target-mark-list
	  (delq number wl-summary-buffer-target-mark-list)))
   ((memq number wl-summary-buffer-delete-list)
    (setq wl-summary-buffer-delete-list
	  (delq number wl-summary-buffer-delete-list)))
   (t
    (let (pair)
      (cond
       ((setq pair (assq number wl-summary-buffer-copy-list))
	(setq wl-summary-buffer-copy-list
	      (delq pair wl-summary-buffer-copy-list)))
       ((setq pair (assq number wl-summary-buffer-refile-list))
	(setq wl-summary-buffer-refile-list
	      (delq pair wl-summary-buffer-refile-list))))))))

(defun wl-summary-mark-line (mark)
  "Put MARK on current line.  Return message number."
  (save-excursion
    (beginning-of-line)
    (let ((inhibit-read-only t)
	  (buffer-read-only nil)
	  msg-num
	  cur-mark)
      (when (looking-at "^ *\\(-?[0-9]+\\)\\([^0-9]\\)")
	(setq msg-num  (string-to-int (wl-match-buffer 1)))
	(setq cur-mark (wl-match-buffer 2))
	(goto-char (match-end 1))
	(delete-region (match-beginning 2) (match-end 2))
;;;	(wl-summary-delete-mark msg-num)
	(insert mark)
	(if wl-summary-highlight
	    (wl-highlight-summary-current-line nil nil t))
	(set-buffer-modified-p nil)
	msg-num))))

(defun wl-summary-target-mark-delete ()
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (let ((regexp (concat "^" wl-summary-buffer-number-regexp "\\(\\*\\)"))
	  number mlist)
      (while (re-search-forward regexp nil t)
	(let (wl-summary-buffer-disp-msg)
	  (when (setq number (wl-summary-message-number))
	    (wl-summary-delete number)
	    (setq wl-summary-buffer-target-mark-list
		  (delq number wl-summary-buffer-target-mark-list)))))
      (setq mlist wl-summary-buffer-target-mark-list)
      (while mlist
	(wl-append wl-summary-buffer-delete-list (list (car mlist)))
	(setq wl-summary-buffer-target-mark-list
	      (delq (car mlist) wl-summary-buffer-target-mark-list))
	(setq mlist (cdr mlist))))))

(defun wl-summary-target-mark-prefetch (&optional ignore-cache)
  (interactive "P")
  (save-excursion
    (let* ((mlist (nreverse wl-summary-buffer-target-mark-list))
	   (inhibit-read-only t)
	   (buffer-read-only nil)
	   (count 0)
	   (length (length mlist))
	   (pos (point))
	   skipped
	   new-mark)
      (while mlist
	(setq new-mark (wl-summary-prefetch-msg (car mlist) ignore-cache))
	(if new-mark
	    (progn
	      (message "Prefetching... %d/%d message(s)"
		       (setq count (+ 1 count)) length)
	      (when (wl-summary-jump-to-msg (car mlist))
		(wl-summary-unmark)
		(when new-mark
		  (when (looking-at "^ *-?[0-9]+[^0-9]\\([^0-9]\\)")
		    (delete-region (match-beginning 1) (match-end 1)))
		  (goto-char (match-beginning 1))
		  (insert new-mark)
		  (if wl-summary-highlight
		      (wl-highlight-summary-current-line))
		  (save-excursion
		    (goto-char pos)
		    (sit-for 0)))))
	  (setq skipped (cons (car mlist) skipped)))
	(setq mlist (cdr mlist)))
      (setq wl-summary-buffer-target-mark-list skipped)
      (message "Prefetching... %d/%d message(s)." count length)
      (set-buffer-modified-p nil))))

(defun wl-summary-target-mark-refile-subr (copy-or-refile)
  (let ((variable
	 (intern (format "wl-summary-buffer-%s-list" copy-or-refile)))
	(function
	 (intern (format "wl-summary-%s" copy-or-refile)))
	regexp number msgid entity folder mlist)
    (save-excursion
      (goto-char (point-min))
      (setq regexp (concat "^" wl-summary-buffer-number-regexp "\\(\\*\\)"))
      ;; guess by first mark
      (when (re-search-forward regexp nil t)
	(setq msgid (cdr (assq (setq number (wl-summary-message-number))
			       (elmo-msgdb-get-number-alist
				(wl-summary-buffer-msgdb))))
	      entity (assoc msgid
			    (elmo-msgdb-get-overview
			     (wl-summary-buffer-msgdb))))
	(if (null entity)
	    (error "Cannot %s" copy-or-refile))
	(funcall function
		 (setq folder (wl-summary-read-folder
			       (wl-refile-guess entity)
			       (format "for %s" copy-or-refile)))
		 number)
	(if number
	    (setq wl-summary-buffer-target-mark-list
		  (delq number wl-summary-buffer-target-mark-list)))
	(while (re-search-forward regexp nil t)
	  (let (wl-summary-buffer-disp-msg)
	    (when (setq number (wl-summary-message-number))
	      (funcall function folder number)
	      (setq wl-summary-buffer-target-mark-list
		    (delq number wl-summary-buffer-target-mark-list)))))
	;; process invisible messages.
	(setq mlist wl-summary-buffer-target-mark-list)
	(while mlist
	  (set variable
	       (append (symbol-value variable)
		       (list (cons (car mlist) folder))))
	  (setq wl-summary-buffer-target-mark-list
		(delq (car mlist) wl-summary-buffer-target-mark-list))
	  (setq mlist (cdr mlist)))))))

(defun wl-summary-target-mark-copy ()
  (interactive)
  (wl-summary-target-mark-refile-subr "copy"))

(defun wl-summary-target-mark-refile ()
  (interactive)
  (wl-summary-target-mark-refile-subr "refile"))

(defun wl-summary-target-mark-mark-as-read ()
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (let ((regexp (concat "^" wl-summary-buffer-number-regexp "\\(\\*\\)"))
	  (inhibit-read-only t)
	  (buffer-read-only nil)
	  number mlist)
      (while (re-search-forward regexp nil t)
	(let (wl-summary-buffer-disp-msg)
	  ;; delete target-mark from buffer.
	  (delete-region (match-beginning 1) (match-end 1))
	  (insert " ")
	  (setq number (wl-summary-mark-as-read t))
	  (if wl-summary-highlight
	      (wl-highlight-summary-current-line))
	  (if number
	      (setq wl-summary-buffer-target-mark-list
		    (delq number wl-summary-buffer-target-mark-list)))))
      (setq mlist wl-summary-buffer-target-mark-list)
      (while mlist
	(wl-summary-mark-as-read t nil nil (car mlist))
	(setq wl-summary-buffer-target-mark-list
	      (delq (car mlist) wl-summary-buffer-target-mark-list))
	(setq mlist (cdr mlist)))
      (wl-summary-count-unread
       (elmo-msgdb-get-mark-alist (wl-summary-buffer-msgdb)))
      (wl-summary-update-modeline))))

(defun wl-summary-target-mark-mark-as-unread ()
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (let ((regexp (concat "^" wl-summary-buffer-number-regexp "\\(\\*\\)"))
	  (inhibit-read-only t)
	  (buffer-read-only nil)
	  number mlist)
      (while (re-search-forward regexp nil t)
	(let (wl-summary-buffer-disp-msg)
	  ;; delete target-mark from buffer.
	  (delete-region (match-beginning 1) (match-end 1))
	  (insert " ")
	  (setq number (wl-summary-mark-as-unread))
	  (if wl-summary-highlight
	      (wl-highlight-summary-current-line))
	  (if number
	      (setq wl-summary-buffer-target-mark-list
		    (delq number wl-summary-buffer-target-mark-list)))))
      (setq mlist wl-summary-buffer-target-mark-list)
      (while mlist
	(wl-summary-mark-as-unread (car mlist))
;;;	(wl-thread-msg-mark-as-unread (car mlist))
	(setq wl-summary-buffer-target-mark-list
	      (delq (car mlist) wl-summary-buffer-target-mark-list))
	(setq mlist (cdr mlist)))
      (wl-summary-count-unread
       (elmo-msgdb-get-mark-alist (wl-summary-buffer-msgdb)))
      (wl-summary-update-modeline))))

(defun wl-summary-target-mark-mark-as-important ()
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (let ((regexp (concat "^" wl-summary-buffer-number-regexp "\\(\\*\\)"))
	  (inhibit-read-only t)
	  (buffer-read-only nil)
	  number mlist)
      (while (re-search-forward regexp nil t)
	(let (wl-summary-buffer-disp-msg)
	  ;; delete target-mark from buffer.
	  (delete-region (match-beginning 1) (match-end 1))
	  (insert " ")
	  (setq number (wl-summary-mark-as-important))
	  (if wl-summary-highlight
	      (wl-highlight-summary-current-line))
	  (if number
	      (setq wl-summary-buffer-target-mark-list
		    (delq number wl-summary-buffer-target-mark-list)))))
      (setq mlist wl-summary-buffer-target-mark-list)
      (while mlist
	(wl-summary-mark-as-important (car mlist))
	(wl-thread-msg-mark-as-important (car mlist))
	(setq wl-summary-buffer-target-mark-list
	      (delq (car mlist) wl-summary-buffer-target-mark-list))
	(setq mlist (cdr mlist)))
      (wl-summary-count-unread
       (elmo-msgdb-get-mark-alist (wl-summary-buffer-msgdb)))
      (wl-summary-update-modeline))))

(defun wl-summary-target-mark-save ()
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (let ((wl-save-dir
	   (wl-read-directory-name "Save to directory: "
				   wl-temporary-file-directory))
	  (regexp (concat "^" wl-summary-buffer-number-regexp "\\(\\*\\)"))
	  number mlist)
      (if (null (file-exists-p wl-save-dir))
	  (make-directory wl-save-dir))
      (while (re-search-forward regexp nil t)
	(let (wl-summary-buffer-disp-msg)
	  (setq number (wl-summary-save t wl-save-dir))
	  (wl-summary-unmark)
	  (if number
	      (setq wl-summary-buffer-target-mark-list
		    (delq number wl-summary-buffer-target-mark-list))))))))

(defun wl-summary-target-mark-pick ()
  (interactive)
  (wl-summary-pick wl-summary-buffer-target-mark-list 'delete))

(defun wl-summary-mark-as-read (&optional notcrosses
					  leave-server-side-mark-untouched
					  displayed
					  number
					  cached)
  (interactive)
  (save-excursion
    (let* (eol
	   (inhibit-read-only t)
	   (buffer-read-only nil)
	   (folder wl-summary-buffer-elmo-folder)
	   (msgdb (wl-summary-buffer-msgdb))
	   (mark-alist (elmo-msgdb-get-mark-alist msgdb))
;;;	   (number-alist (elmo-msgdb-get-number-alist msgdb))
	   (case-fold-search nil)
	   mark stat visible uncached new-mark marked)
      (if number
	  (progn
	    (setq visible (wl-summary-jump-to-msg number))
	    (setq mark (cadr (assq number mark-alist))))
	;; interactive
	(setq visible t))
      (beginning-of-line)
      (if (or (not visible)
	      (looking-at
	       (format "^ *\\(-?[0-9]+\\)[^0-9]\\(%s\\|%s\\|%s\\|%s\\).*$"
		       (regexp-quote wl-summary-read-uncached-mark)
		       (regexp-quote wl-summary-unread-uncached-mark)
		       (regexp-quote wl-summary-unread-cached-mark)
		       (regexp-quote wl-summary-new-mark))))
	  (progn
	    (setq mark (or mark (wl-match-buffer 2)))
	    (when mark
	      (cond
	       ((string= mark wl-summary-new-mark) ; N
		(setq stat 'new)
		(setq uncached t))
	       ((string= mark wl-summary-unread-uncached-mark) ; U
		(setq stat 'unread)
		(setq uncached t))
	       ((string= mark wl-summary-unread-cached-mark)  ; !
		(setq stat 'unread))
	       (t
		;; no need to mark server.
		(setq leave-server-side-mark-untouched t))))
	    (setq number (or number (string-to-int (wl-match-buffer 1))))
	    ;; set server side mark...
	    (setq new-mark (if (and uncached
				    (if (elmo-message-use-cache-p folder number)
					(not (elmo-folder-local-p folder)))
				    (not cached))
			       wl-summary-read-uncached-mark
			     nil))
	    (if (not leave-server-side-mark-untouched)
		(save-match-data
		  (setq marked (elmo-folder-mark-as-read
				folder
				(list number)))))
	    (if (or leave-server-side-mark-untouched
		    marked)
		(progn
		  (cond ((eq stat 'unread)
			 (setq wl-summary-buffer-unread-count
			       (1- wl-summary-buffer-unread-count)))
			((eq stat 'new)
			 (setq wl-summary-buffer-new-count
			       (1- wl-summary-buffer-new-count))))
		  (wl-summary-update-modeline)
		  (wl-folder-update-unread
		   (wl-summary-buffer-folder-name)
		   (+ wl-summary-buffer-unread-count
		      wl-summary-buffer-new-count))
		  (when (or stat cached)
		    (when visible
		      (goto-char (match-end 2))
		      (delete-region (match-beginning 2) (match-end 2))
		      (insert (or new-mark " ")))
		    (setq mark-alist
			  (elmo-msgdb-mark-set mark-alist number new-mark))
		    (elmo-msgdb-set-mark-alist msgdb mark-alist)
		    (wl-summary-set-mark-modified))
		  (if (and visible wl-summary-highlight)
		      (wl-highlight-summary-current-line nil nil t)))
	      (if mark (message "Warning: Changing mark failed.")))))
      (set-buffer-modified-p nil)
      (if stat
	  (run-hooks 'wl-summary-unread-message-hook))
      number ;return value
      )))

(defun wl-summary-mark-as-important (&optional number
					       mark
					       no-server-update)
  (interactive)
  (if (eq (elmo-folder-type-internal wl-summary-buffer-elmo-folder)
	  'internal)
      (error "Cannot process mark in this folder"))
  (save-excursion
    (let* (eol
	  (inhibit-read-only t)
	  (buffer-read-only nil)
	  (folder wl-summary-buffer-elmo-folder)
	  (msgdb (wl-summary-buffer-msgdb))
	  (mark-alist (elmo-msgdb-get-mark-alist msgdb))
	  (number-alist (elmo-msgdb-get-number-alist msgdb))
	  message-id visible)
      (if number
	  (progn
	    (setq visible (wl-summary-jump-to-msg number))
	    (setq mark (or mark (cadr (assq number mark-alist)))))
	(setq visible t))
      (when visible
	(if (null (setq number (wl-summary-message-number)))
	    (progn
	      (message "No message.")
	      (setq visible nil))
	  (end-of-line)
	  (setq eol (point))
	  (re-search-backward (concat "^" wl-summary-buffer-number-regexp
				      "..../..") nil t)) ; set cursor line
	(beginning-of-line))
      (if (or (and (not visible)
		   (assq number (elmo-msgdb-get-number-alist msgdb)))
	      (re-search-forward "^ *\\(-?[0-9]+\\)[^0-9]\\([^0-9]\\)" eol t))
	  (progn
	    (setq number (or number (string-to-int (wl-match-buffer 1))))
	    (setq mark (or mark (wl-match-buffer 2)))
	    (setq message-id (elmo-message-field
			      wl-summary-buffer-elmo-folder
			      number
			      'message-id))
	    (if (string= mark wl-summary-important-mark)
		(progn
		  ;; server side mark
		  (save-match-data
		    (unless no-server-update
		      (elmo-folder-unmark-important folder (list number))
		      (elmo-msgdb-global-mark-delete message-id))
		    ;; Remove cache if local folder.
		    (if (and (elmo-folder-local-p folder)
			     (not (eq 'mark
				      (elmo-folder-type-internal folder))))
			(elmo-file-cache-delete
			 (elmo-file-cache-get-path message-id))))
		  (when visible
		    (delete-region (match-beginning 2) (match-end 2))
		    (insert " "))
		  (setq mark-alist
			(elmo-msgdb-mark-set mark-alist
					     number
					     nil)))
	      ;; server side mark
	      (save-match-data
		(unless no-server-update
		  (elmo-folder-mark-as-important folder (list number))))
	      (when visible
		(delete-region (match-beginning 2) (match-end 2))
		(insert wl-summary-important-mark))
	      (setq mark-alist
		    (elmo-msgdb-mark-set mark-alist
					 number
					 wl-summary-important-mark))
	      (if (elmo-file-cache-exists-p message-id)
		  (elmo-folder-mark-as-read folder (list number))
		;; Force cache message.
		(elmo-message-encache folder number 'read))
	      (unless no-server-update
		(elmo-msgdb-global-mark-set message-id
					    wl-summary-important-mark)))
	    (elmo-msgdb-set-mark-alist msgdb mark-alist)
	    (wl-summary-set-mark-modified)))
      (if (and visible wl-summary-highlight)
	  (wl-highlight-summary-current-line nil nil t))))
  (set-buffer-modified-p nil)
  number)

(defsubst wl-summary-format-date (date-string)
  (condition-case nil
      (let ((datevec (timezone-fix-time date-string nil
					wl-summary-fix-timezone)))
	(format "%02d/%02d(%s)%02d:%02d"
		(aref datevec 1)
		(aref datevec 2)
		(elmo-date-get-week (aref datevec 0)
				    (aref datevec 1)
				    (aref datevec 2))
		(aref datevec 3)
		(aref datevec 4)))
    (error "??/??(??)??:??")))

(defun wl-summary-overview-create-summary-line (msg
						entity
						parent-entity
						depth
						mark-alist
						&optional
						children-num
						temp-mark thr-entity
						subject-differ)
  (let ((wl-mime-charset wl-summary-buffer-mime-charset)
	(elmo-mime-charset wl-summary-buffer-mime-charset)
	no-parent before-indent
	from subject parent-raw-subject parent-subject
	mark line
	(elmo-lang wl-summary-buffer-weekday-name-lang)
	(children-num (if children-num (int-to-string children-num)))
	(thr-str "")
	linked)
    (when thr-entity
      (setq thr-str (wl-thread-make-indent-string thr-entity))
      (setq linked (wl-thread-entity-get-linked thr-entity)))
    (if (string= thr-str "")
	(setq no-parent t)) ; no parent
    (if (and wl-summary-indent-length-limit
	     (< wl-summary-indent-length-limit
		(string-width thr-str)))
	(setq thr-str (wl-set-string-width
		       wl-summary-indent-length-limit
		       thr-str)))
    (setq from
	  (wl-set-string-width
	   (if children-num
	       (- wl-summary-from-width (length children-num) 2)
	     wl-summary-from-width)
	   (elmo-delete-char ?\n
			     (wl-summary-from-func-internal
			      (elmo-msgdb-overview-entity-get-from entity)))))
    (setq subject
	  (elmo-delete-char ?\n
			    (or (elmo-msgdb-overview-entity-get-subject
				 entity)
				wl-summary-no-subject-message)))
    (setq parent-raw-subject
	  (elmo-msgdb-overview-entity-get-subject parent-entity))
    (setq parent-subject
	  (if parent-raw-subject
	      (elmo-delete-char ?\n parent-raw-subject)))
    (setq mark (or (cadr (assq msg mark-alist)) " "))
    (setq line
	  (concat
	   (setq before-indent
		 (format (concat "%"
				 (int-to-string
				  wl-summary-buffer-number-column)
				 "s%s%s%s %s")
			 msg
			 (or temp-mark " ")
			 mark
			 (wl-summary-format-date
			  (elmo-msgdb-overview-entity-get-date entity))
			 (if thr-str thr-str "")))
	   (format (if linked
		       "<%s > %s"
		     "[%s ] %s")
		   (if children-num
		       (concat "+" children-num ": " from)
		     (concat " " from))
		   (progn
		     (setq subject
			   (if (or no-parent
				   (null parent-subject)
				   (not (wl-summary-subject-equal
					 subject parent-subject)))
			       (wl-summary-subject-func-internal subject) ""))
		     (if (and (not wl-summary-width)
			      wl-summary-subject-length-limit)
			 (truncate-string subject wl-summary-subject-length-limit)
		       subject)))))
    (if wl-summary-width (setq line
			       (wl-set-string-width
				(- wl-summary-width 1) line)))
    (if wl-summary-highlight
	(wl-highlight-summary-line-string line
					  mark
					  temp-mark
					  thr-str))
    line))

(defsubst wl-summary-buffer-number-column-detect (update)
  (let (end)
    (save-excursion
      (goto-char (point-min))
      (setq wl-summary-buffer-number-column
	    (or
	     (if (and update
		      (setq end (if (re-search-forward
				     "^ *-?[0-9]+[^0-9]" nil t)
				    (point))))
		 (- end (progn (beginning-of-line) (point)) 1))
	     (wl-get-assoc-list-value wl-summary-number-column-alist
				      (wl-summary-buffer-folder-name))
	     wl-summary-default-number-column))
      (setq wl-summary-buffer-number-regexp
	    (wl-repeat-string "." wl-summary-buffer-number-column)))))

(defsubst wl-summary-proc-wday (wday-str year month mday)
  (save-match-data
    (if (string-match "\\([A-Z][a-z][a-z]\\).*" wday-str)
	(wl-match-string 1 wday-str)
      (elmo-date-get-week year month mday))))

(defvar wl-summary-move-spec-plugged-alist
  (` ((new . ((t . nil)
	      (p . (, wl-summary-new-mark))
	      (p . (, (wl-regexp-opt
		       (list wl-summary-unread-uncached-mark
			     wl-summary-unread-cached-mark))))
	      (p . (, (regexp-quote wl-summary-important-mark)))))
      (unread . ((t . nil)
		 (p . (, (wl-regexp-opt
			  (list wl-summary-new-mark
				wl-summary-unread-uncached-mark
				wl-summary-unread-cached-mark))))
		 (p . (, (regexp-quote wl-summary-important-mark))))))))

(defvar wl-summary-move-spec-unplugged-alist
  (` ((new . ((t . nil)
	      (p . (, wl-summary-unread-cached-mark))
	      (p . (, (regexp-quote wl-summary-important-mark)))))
      (unread . ((t . nil)
		 (p . (, wl-summary-unread-cached-mark))
		 (p . (, (regexp-quote wl-summary-important-mark))))))))

(defsubst wl-summary-next-message (num direction hereto)
  (if wl-summary-buffer-next-message-function
      (funcall wl-summary-buffer-next-message-function num direction hereto)
    (let ((cur-spec (cdr (assq wl-summary-move-order
			       (if (elmo-folder-plugged-p
				    wl-summary-buffer-elmo-folder)
				   wl-summary-move-spec-plugged-alist
				 wl-summary-move-spec-unplugged-alist))))
	  (nums (memq num (if (eq direction 'up)
			      (reverse wl-summary-buffer-number-list)
			    wl-summary-buffer-number-list)))
	  marked-list nums2)
      (unless hereto (setq nums (cdr nums)))
      (setq nums2 nums)
      (if cur-spec
	  (catch 'done
	    (while cur-spec
	      (setq nums nums2)
	      (cond ((eq (car (car cur-spec)) 'p)
		     (if (setq marked-list
			       (elmo-folder-list-messages-mark-match
				wl-summary-buffer-elmo-folder
				(cdr (car cur-spec))))
			 (while nums
			   (if (memq (car nums) marked-list)
			       (throw 'done (car nums)))
			   (setq nums (cdr nums)))))
		    ((eq (car (car cur-spec)) 't)
		     (if wl-summary-buffer-target-mark-list
			 (while nums
			   (if (memq (car nums)
				     wl-summary-buffer-target-mark-list)
			       (throw 'done (car nums)))
			   (setq nums (cdr nums))))))
	      (setq cur-spec (cdr cur-spec))))
	(car nums)))))

(defsubst wl-summary-cursor-move (direction hereto)
  (when (and (eq direction 'up)
	     (eobp))
    (forward-line -1)
    (setq hereto t))
  (let (num)
    (when (setq num (wl-summary-next-message (wl-summary-message-number)
					     direction hereto))
      (if (numberp num)
	  (wl-thread-jump-to-msg num))
      t)))
;;
;; Goto unread or important
;; returns t if next message exists in this folder.
(defun wl-summary-cursor-down (&optional hereto)
  (interactive "P")
  (wl-summary-cursor-move 'down hereto))

(defun wl-summary-cursor-up (&optional hereto)
  (interactive "P")
  (wl-summary-cursor-move 'up hereto))

(defun wl-summary-save-view-cache ()
  (save-excursion
    (let* ((dir (elmo-folder-msgdb-path wl-summary-buffer-elmo-folder))
	   (cache (expand-file-name wl-summary-cache-file dir))
	   (view (expand-file-name wl-summary-view-file dir))
	   (save-view wl-summary-buffer-view)
	   (tmp-buffer (get-buffer-create " *wl-summary-save-view-cache*"))
	   (charset wl-summary-buffer-mime-charset))
      (if (file-directory-p dir)
	  (); ok.
	(if (file-exists-p dir)
	    (error "File %s already exists" dir)
	  (elmo-make-directory dir)))
      (if (eq save-view 'thread)
	  (wl-thread-save-entity dir))
      (unwind-protect
	  (progn
	    (when (file-writable-p cache)
	      (copy-to-buffer tmp-buffer (point-min) (point-max))
	      (with-current-buffer tmp-buffer
		(widen)
		(encode-mime-charset-region
		 (point-min) (point-max) charset)
		(write-region-as-binary (point-min)(point-max)
					cache nil 'no-msg)))
	    (when (file-writable-p view) ; 'thread or 'sequence
	      (save-excursion
		(set-buffer tmp-buffer)
		(erase-buffer)
		(prin1 save-view tmp-buffer)
		(princ "\n" tmp-buffer)
		(write-region (point-min) (point-max) view nil 'no-msg))))
	;; kill tmp buffer.
	(kill-buffer tmp-buffer)))))

(defsubst wl-summary-get-sync-range (folder)
  (intern (or (and
	       (elmo-folder-plugged-p folder)
	       (wl-get-assoc-list-value
		wl-folder-sync-range-alist
		(elmo-folder-name-internal folder)))
	      wl-default-sync-range)))

;; redefined for wl-summary-sync-update
(defun wl-summary-input-range (folder)
  "returns update or all or rescan."
  ;; for the case when parts are expanded in the bottom of the folder
  (let ((input-range-list '("update" "all" "rescan" "first:" "last:"
			    "cache-status"
			    "no-sync" "rescan-noscore" "all-visible"))
	(default (or (wl-get-assoc-list-value
		      wl-folder-sync-range-alist
		      folder)
		     wl-default-sync-range))
	range)
    (setq range
	  (completing-read (format "Range (%s): " default)
			   (mapcar
			    (function (lambda (x) (cons x x)))
			    input-range-list)))
    (if (string= range "")
	default
      range)))

(defun wl-summary-toggle-disp-folder (&optional arg)
  (interactive)
  (let ((cur-buf (current-buffer))
	(summary-win (get-buffer-window (current-buffer)))
	fld-buf fld-win)
    (cond
     ((eq arg 'on)
      (setq wl-summary-buffer-disp-folder t)
      ;; hide your folder window
      (if (setq fld-buf (get-buffer wl-folder-buffer-name))
	  (if (setq fld-win (get-buffer-window fld-buf))
	      (delete-window fld-win))))
     ((eq arg 'off)
      (setq wl-summary-buffer-disp-folder nil)
      ;; hide your wl-message window!
      (when (buffer-live-p wl-message-buffer)
	(wl-message-select-buffer wl-message-buffer)
	(delete-window))
      (select-window (get-buffer-window cur-buf))
      ;; display wl-folder window!!
      (if (setq fld-buf (get-buffer wl-folder-buffer-name))
	  (if (setq fld-win (get-buffer-window fld-buf))
	      ;; folder win is already displayed.
	      (select-window fld-win)
	    ;; folder win is not displayed.
	    (switch-to-buffer fld-buf))
	;; no folder buf
	(wl-folder))
      ;; temporarily delete summary-win.
      (if summary-win
	  (delete-window summary-win))
      (split-window-horizontally wl-folder-window-width)
      (other-window 1)
      (switch-to-buffer cur-buf))
     (t
      (if (setq fld-buf (get-buffer wl-folder-buffer-name))
	  (if (setq fld-win (get-buffer-window fld-buf))
	      (setq wl-summary-buffer-disp-folder nil)
	    (setq wl-summary-buffer-disp-folder t)))
      (if (not wl-summary-buffer-disp-folder)
	  ;; hide message window
	  (let ((mes-win (and wl-message-buffer
			      (get-buffer-window wl-message-buffer)))
		(wl-stay-folder-window t))
	    (if mes-win (delete-window mes-win))
	    ;; hide your folder window
	    (if (setq fld-buf (get-buffer wl-folder-buffer-name))
		(if (setq fld-win (get-buffer-window fld-buf))
		    (progn
		      (delete-window (get-buffer-window cur-buf))
		      (select-window fld-win)
		      (switch-to-buffer cur-buf))))
	    (run-hooks 'wl-summary-toggle-disp-folder-off-hook)
	    ;; resume message window.
	    (when mes-win
	      (wl-message-select-buffer wl-message-buffer)
	      (run-hooks 'wl-summary-toggle-disp-folder-message-resumed-hook)
	      (select-window (get-buffer-window cur-buf))))
	;; hide message window
	(let ((wl-stay-folder-window t)
	      (mes-win (and wl-message-buffer
			    (get-buffer-window wl-message-buffer))))
	  (if mes-win (delete-window mes-win))
	  (select-window (get-buffer-window cur-buf))
	  ;; display wl-folder window!!
	  (if (setq fld-buf (get-buffer wl-folder-buffer-name))
	      (if (setq fld-win (get-buffer-window fld-buf))
		  ;; folder win is already displayed.
		  (select-window fld-win)
		;; folder win is not displayed...occupy all.
		(switch-to-buffer fld-buf))
	    ;; no folder buf
	    (wl-folder))
	  (split-window-horizontally wl-folder-window-width)
	  (other-window 1)
	  (switch-to-buffer cur-buf)
	  ;; resume message window.
	  (run-hooks 'wl-summary-toggle-disp-folder-on-hook)
	  (when mes-win
	    (wl-message-select-buffer wl-message-buffer)
	    (run-hooks 'wl-summary-toggle-disp-folder-message-resumed-hook)
	    (select-window (get-buffer-window cur-buf))))))))
  (run-hooks 'wl-summary-toggle-disp-folder-hook))

(defun wl-summary-toggle-disp-msg (&optional arg)
  (interactive)
  (let ((cur-buf (current-buffer))
	fld-buf fld-win
	summary-win)
    (cond
     ((eq arg 'on)
      (setq wl-summary-buffer-disp-msg t)
      (save-excursion
	;; hide your folder window
	(if (and (not wl-stay-folder-window)
		 (setq fld-buf (get-buffer wl-folder-buffer-name)))
	    (if (setq fld-win (get-buffer-window fld-buf))
		(unless (one-window-p fld-win)
		  (delete-window fld-win))))))
     ((eq arg 'off)
      (wl-delete-all-overlays)
      (setq wl-summary-buffer-disp-msg nil)
      (save-excursion
	(when (buffer-live-p wl-message-buffer)
	  (wl-message-select-buffer wl-message-buffer)
	  (delete-window)
	  (and (get-buffer-window cur-buf)
	       (select-window (get-buffer-window cur-buf))))
	(run-hooks 'wl-summary-toggle-disp-off-hook)))
     (t
      (if (and wl-message-buffer
	       (get-buffer-window wl-message-buffer)) ; already displayed
	  (setq wl-summary-buffer-disp-msg nil)
	(setq wl-summary-buffer-disp-msg t))
      (if wl-summary-buffer-disp-msg
	  (progn
	    (wl-summary-redisplay)
;;; hide your folder window
;;;	    (setq fld-buf (get-buffer wl-folder-buffer-name))
;;;	    (if (setq fld-win (get-buffer-window fld-buf))
;;;		(delete-window fld-win)))
	    (run-hooks 'wl-summary-toggle-disp-on-hook))
	(wl-delete-all-overlays)
	(save-excursion
	  (wl-message-select-buffer wl-message-buffer)
	  (delete-window)
	  (select-window (get-buffer-window cur-buf))
	  (run-hooks 'wl-summary-toggle-disp-off-hook))
;;;	(switch-to-buffer cur-buf)
	)))))

(defun wl-summary-next-line-content ()
  "Show next line of the message."
  (interactive)
  (let ((cur-buf (current-buffer)))
    (wl-summary-toggle-disp-msg 'on)
    (when (wl-summary-set-message-buffer-or-redisplay 'ignore-original)
      (set-buffer cur-buf)
      (wl-message-next-page 1))))

(defun wl-summary-prev-line-content ()
  (interactive)
  (let ((cur-buf (current-buffer)))
    (wl-summary-toggle-disp-msg 'on)
    (when (wl-summary-set-message-buffer-or-redisplay 'ignore-original)
      (set-buffer cur-buf)
      (wl-message-prev-page 1))))

(defun wl-summary-next-page ()
  (interactive)
  (wl-message-next-page))

(defun wl-summary-prev-page ()
  (interactive)
  (wl-message-prev-page))

(defsubst wl-summary-no-mime-p (folder)
  (wl-string-match-member (elmo-folder-name-internal folder)
			  wl-summary-no-mime-folder-list))

(defun wl-summary-set-message-buffer-or-redisplay (&rest args)
  "Set message buffer.
If message is not displayed yet, display it.
Return t if message exists."
  (let ((folder wl-summary-buffer-elmo-folder)
	(number (wl-summary-message-number))
	cur-folder cur-number message-last-pos)
    (when (buffer-live-p wl-message-buffer)
      (save-window-excursion
	(wl-message-select-buffer wl-message-buffer)
	(setq cur-folder wl-message-buffer-cur-folder)
	(setq cur-number wl-message-buffer-cur-number)))
    (if (and (string= (elmo-folder-name-internal folder) (or cur-folder ""))
	     (eq number (or cur-number 0)))
	(progn
	  (set-buffer wl-message-buffer)
	  t)
      (if (wl-summary-no-mime-p folder)
	  (wl-summary-redisplay-no-mime folder number)
	(wl-summary-redisplay-internal folder number))
      (when (buffer-live-p wl-message-buffer)
	(set-buffer wl-message-buffer))
      nil)))

(defun wl-summary-target-mark-forward (&optional arg)
  (interactive "P")
  (let ((mlist (nreverse wl-summary-buffer-target-mark-list))
	(summary-buf (current-buffer))
	(wl-draft-forward t)
	start-point
	draft-buf)
    (wl-summary-jump-to-msg (car mlist))
    (wl-summary-forward t)
    (setq start-point (point))
    (setq draft-buf (current-buffer))
    (setq mlist (cdr mlist))
    (save-window-excursion
      (when mlist
	(while mlist
	  (set-buffer summary-buf)
	  (wl-summary-jump-to-msg (car mlist))
	  (wl-summary-redisplay)
	  (set-buffer draft-buf)
	  (goto-char (point-max))
	  (wl-draft-insert-message)
	  (setq mlist (cdr mlist)))
	(wl-draft-body-goto-top)
	(wl-draft-enclose-digest-region (point) (point-max)))
      (goto-char start-point)
      (save-excursion
	(set-buffer summary-buf)
	(wl-summary-delete-all-temp-marks)))
    (run-hooks 'wl-mail-setup-hook)))

(defun wl-summary-target-mark-reply-with-citation (&optional arg)
  (interactive "P")
  (let ((mlist (nreverse wl-summary-buffer-target-mark-list))
	(summary-buf (current-buffer))
	change-major-mode-hook
	start-point
	draft-buf)
    (wl-summary-jump-to-msg (car mlist))
    (wl-summary-reply arg t)
    (goto-char (point-max))
    (setq start-point (point-marker))
    (setq draft-buf (current-buffer))
    (save-window-excursion
      (while mlist
	(set-buffer summary-buf)
	(delete-other-windows)
	(wl-summary-jump-to-msg (car mlist))
	(wl-summary-redisplay)
	(set-buffer draft-buf)
	(goto-char (point-max))
	(wl-draft-yank-original)
	(setq mlist (cdr mlist)))
      (goto-char start-point)
      (save-excursion
	(set-buffer summary-buf)
	(wl-summary-delete-all-temp-marks)))
    (run-hooks 'wl-mail-setup-hook)))

(defun wl-summary-reply-with-citation (&optional arg)
  (interactive "P")
  (when (wl-summary-reply arg t)
    (goto-char (point-max))
    (wl-draft-yank-original)
    (run-hooks 'wl-mail-setup-hook)))

(defun wl-summary-jump-to-msg-by-message-id (&optional id)
  (interactive)
  (let* ((original (wl-summary-message-number))
	 (msgid (elmo-string (or id (read-from-minibuffer "Message-ID: "))))
	 (number-alist (elmo-msgdb-get-number-alist (wl-summary-buffer-msgdb)))
	 msg otherfld schar
	 (errmsg
	  (format "No message with id \"%s\" in the folder." msgid)))
    (if (setq msg (car (rassoc msgid number-alist)))
;;;	(wl-summary-jump-to-msg-internal
;;;	 (wl-summary-buffer-folder-name) msg 'no-sync)
	(progn
	  (wl-thread-jump-to-msg msg)
	  t)
      ;; for XEmacs!
      (if (and elmo-use-database
	       (setq errmsg
		     (format
		      "No message with id \"%s\" in the database." msgid))
	       (setq otherfld (elmo-database-msgid-get msgid)))
	  (if (cdr (wl-summary-jump-to-msg-internal
		    (car otherfld) (nth 1 otherfld) 'no-sync))
	      t ; succeed.
	    ;; Back to original.
	    (wl-summary-jump-to-msg-internal
	     (wl-summary-buffer-folder-name) original 'no-sync))
	(cond ((eq wl-summary-search-via-nntp 'confirm)
	       (require 'elmo-nntp)
	       (message "Search message in nntp server \"%s\" <y/n/s(elect)>?"
			elmo-nntp-default-server)
	       (setq schar (read-char))
	       (cond ((eq schar ?y)
		      (wl-summary-jump-to-msg-by-message-id-via-nntp msgid))
		     ((eq schar ?s)
		      (wl-summary-jump-to-msg-by-message-id-via-nntp
		       msgid
		       (read-from-minibuffer "NNTP Server: ")))
		     (t
		      (message errmsg)
		      nil)))
	      (wl-summary-search-via-nntp
	       (wl-summary-jump-to-msg-by-message-id-via-nntp msgid))
	      (t
	       (message errmsg)
	       nil))))))

(defun wl-summary-jump-to-msg-by-message-id-via-nntp (&optional id server-spec)
  (interactive)
  (let* ((msgid (elmo-string (or id (read-from-minibuffer "Message-ID: "))))
	 newsgroups folder ret
	 user server port type spec)
    (if server-spec
	(if (string-match "^-" server-spec)
	    (setq spec (wl-folder-get-elmo-folder server-spec)
		  user (elmo-net-folder-user-internal spec)
		  server (elmo-net-folder-server-internal spec)
		  port (elmo-net-folder-port-internal spec)
		  type (elmo-net-folder-stream-type-internal spec))
	  (setq server server-spec)))
    (when (setq ret (elmo-nntp-get-newsgroup-by-msgid
		     msgid
		     (or server elmo-nntp-default-server)
		     (or user elmo-nntp-default-user)
		     (or port elmo-nntp-default-port)
		     (or type elmo-nntp-default-stream-type)))
      (setq newsgroups (elmo-nntp-parse-newsgroups ret))
      (setq folder (concat "-" (car newsgroups)
			   (elmo-nntp-folder-postfix user server port type)))
      (catch 'found
	(while newsgroups
	  (if (wl-folder-entity-exists-p (car newsgroups)
					 wl-folder-newsgroups-hashtb)
	      (throw 'found
		     (setq folder (concat "-" (car newsgroups)
					  (elmo-nntp-folder-postfix
					   user server port type)))))
	  (setq newsgroups (cdr newsgroups)))))
    (if ret
	(wl-summary-jump-to-msg-internal folder nil 'update msgid)
      (message "No message id \"%s\" in nntp server \"%s\"."
	       msgid (or server elmo-nntp-default-server))
      nil)))

(defun wl-summary-jump-to-msg-internal (folder msg scan-type &optional msgid)
  (let (wl-auto-select-first entity)
    (if (or (string= folder (wl-summary-buffer-folder-name))
	    (y-or-n-p
	     (format
	      "Message was found in the folder \"%s\". Jump to it? "
	      folder)))
	(progn
	  (unwind-protect
	      (wl-summary-goto-folder-subr
	       folder scan-type nil nil t)
	    (if msgid
		(setq msg
		      (car (rassoc msgid
				   (elmo-msgdb-get-number-alist
				    (wl-summary-buffer-msgdb))))))
	    (setq entity (wl-folder-search-entity-by-name folder
							  wl-folder-entity
							  'folder))
	    (if entity
		(wl-folder-set-current-entity-id
		 (wl-folder-get-entity-id entity))))
	  (if (null msg)
	      (message "Message was not found currently in this folder.")
	    (setq msg (and (wl-thread-jump-to-msg msg) msg)))
	  (cons folder msg)))))

(defun wl-summary-jump-to-parent-message (arg)
  (interactive "P")
  (let ((cur-buf (current-buffer))
	(number (wl-summary-message-number))
	(regexp "\\(<[^<>]*>\\)[ \t]*$")
	(i -1) ;; xxx
	msg-id msg-num ref-list ref irt)
    (if (null number)
	(message "No message.")
      (when (eq wl-summary-buffer-view 'thread)
	(cond ((and arg (not (numberp arg)))
	       (setq msg-num
		     (wl-thread-entity-get-number
		      (wl-thread-entity-get-top-entity
		       (wl-thread-get-entity number)))))
	      ((and arg (numberp arg))
	       (setq i 0)
	       (setq msg-num number)
	       (while (< i arg)
		 (setq msg-num
		       (wl-thread-entity-get-number
			(wl-thread-entity-get-parent-entity
			 (wl-thread-get-entity msg-num))))
		 (setq i (1+ i))))
	      (t (setq msg-num
		       (wl-thread-entity-get-number
			(wl-thread-entity-get-parent-entity
			 (wl-thread-get-entity number)))))))
      (when (null msg-num)
	(wl-summary-set-message-buffer-or-redisplay)
	(set-buffer (wl-message-get-original-buffer))
	(message "Searching parent message...")
	(setq ref (std11-field-body "References")
	      irt (std11-field-body "In-Reply-To"))
	(cond
	 ((and arg (not (numberp arg)) ref (not (string= ref ""))
	       (string-match regexp ref))
	  ;; The first message of the thread.
	  (setq msg-id (wl-match-string 1 ref)))
	 ;; "In-Reply-To:" has only one msg-id.
	 ((and (null arg) irt (not (string= irt ""))
	       (string-match regexp irt))
	  (setq msg-id (wl-match-string 1 irt)))
	 ((and (or (null arg) (numberp arg)) ref (not (string= ref ""))
	       (string-match regexp ref))
	  ;; "^" searching parent, "C-u 2 ^" looking for grandparent.
	  (while (string-match regexp ref)
	    (setq ref-list
		  (append (list
			   (wl-match-string 1 ref))
			  ref-list))
	    (setq ref (substring ref (match-end 0)))
	    (setq i (1+ i)))
	  (setq msg-id
		(if (null arg) (nth 0 ref-list) ;; previous
		  (if (<= arg i) (nth (1- arg) ref-list)
		    (nth i ref-list)))))))
      (set-buffer cur-buf)
      (cond ((and (null msg-id) (null msg-num))
	     (message "No parent message!")
	     nil)
	    ((and msg-id (wl-summary-jump-to-msg-by-message-id msg-id))
	     (wl-summary-redisplay)
	     (message "Searching parent message...done")
	     t)
	    ((and msg-num (wl-summary-jump-to-msg msg-num))
	     (wl-summary-redisplay)
	     (message "Searching parent message...done")
	     t)
	    (t ; failed.
	     (message "Parent message was not found.")
	     nil)))))

(defun wl-summary-reply (&optional arg without-setup-hook)
  "Reply to current message. Default is \"wide\" reply.
Reply to author if invoked with ARG."
  (interactive "P")
  (let ((folder wl-summary-buffer-elmo-folder)
	(number (wl-summary-message-number))
	(summary-buf (current-buffer))
	mes-buf)
    (when number
      (save-excursion
	(wl-summary-redisplay-internal folder number))
      (setq mes-buf wl-message-buffer)
      (wl-message-select-buffer wl-message-buffer)
      (set-buffer mes-buf)
      (goto-char (point-min))
      (unless wl-draft-use-frame
	(split-window-vertically)
	(other-window 1))
      (when (setq mes-buf (wl-message-get-original-buffer))
	(wl-draft-reply mes-buf arg summary-buf)
	(unless without-setup-hook
	  (run-hooks 'wl-mail-setup-hook)))
      t)))

(defun wl-summary-write ()
  "Write a new draft from Summary."
  (interactive)
  (wl-draft nil nil nil nil nil
	    nil nil nil nil nil nil (current-buffer)
	    nil (wl-summary-buffer-folder-name))
  (run-hooks 'wl-mail-setup-hook)
  (mail-position-on-field "To"))

(defvar wl-summary-write-current-folder-functions
  '(wl-folder-get-newsgroups
    wl-folder-guess-mailing-list-by-refile-rule
    wl-folder-guess-mailing-list-by-folder-name)
  "Newsgroups or Mailing List address guess functions list.
Call from `wl-summary-write-current-folder'.
When guess function return nil, challenge next guess-function.")

(defun wl-summary-write-current-folder (&optional folder)
  "Write message to current FOLDER's newsgroup or mailing-list.
Use function list is `wl-summary-write-current-folder-functions'."
  (interactive)
  ;; default FOLDER is current buffer folder
  (setq folder (or folder (wl-summary-buffer-folder-name)))
  (let ((func-list wl-summary-write-current-folder-functions)
	guess-list guess-func)
    (while func-list
      (setq guess-list (funcall (car func-list) folder))
      (if (null guess-list)
	  (setq func-list (cdr func-list))
	(setq guess-func (car func-list))
	(setq func-list nil)))
    (when (null guess-func)
      (error "Can't guess by folder %s" folder))
    (unless (or (stringp (nth 0 guess-list))
		(stringp (nth 1 guess-list))
		(stringp (nth 2 guess-list)))
      (error "Invalid value return guess function `%s'"
	     (symbol-name guess-func)))
    (wl-draft (nth 0 guess-list) nil nil ; To:
	      (nth 1 guess-list) nil	; Cc:
	      (nth 2 guess-list)	; Newsgroups:
	      nil nil nil nil nil nil nil
	      folder)
    (run-hooks 'wl-mail-setup-hook)
    (mail-position-on-field "Subject")))

(defun wl-summary-forward (&optional without-setup-hook)
  ""
  (interactive)
  (let ((folder wl-summary-buffer-elmo-folder)
	(number (wl-summary-message-number))
	(summary-buf (current-buffer))
	(wl-draft-forward t)
	mes-buf
	entity subject num)
    (if (null number)
	(message "No message.")
      (if (and (elmo-message-use-cache-p folder number)
	       (eq (elmo-file-cache-status
		    (elmo-file-cache-get
		     (elmo-message-field folder number 'message-id)))
		   'section))
	  ;; Reload.
	  (wl-summary-redisplay-internal nil nil 'force-reload)
	(wl-summary-redisplay-internal folder number))
      (setq mes-buf wl-message-buffer)
      (wl-message-select-buffer mes-buf)
      (unless wl-draft-use-frame
	(split-window-vertically)
	(other-window 1))
      ;; get original subject.
      (if summary-buf
	  (save-excursion
	    (set-buffer summary-buf)
	    (setq subject
		  (or (elmo-message-field folder number 'subject) ""))))
      (set-buffer mes-buf)
      (wl-draft-forward subject summary-buf)
      (unless without-setup-hook
	(run-hooks 'wl-mail-setup-hook)))))

(defun wl-summary-click (e)
  (interactive "e")
  (mouse-set-point e)
  (wl-summary-read))

(defun wl-summary-read ()
  "Proceed reading message in the summary buffer."
  (interactive)
  (let ((cur-buf (current-buffer)))
    (wl-summary-toggle-disp-msg 'on)
    (when (wl-summary-set-message-buffer-or-redisplay 'ignore-original)
      (set-buffer cur-buf)
      (if (wl-message-next-page)
	  (wl-summary-down t)))))

(defun wl-summary-prev (&optional interactive)
  ""
  (interactive)
  (if wl-summary-move-direction-toggle
      (setq wl-summary-move-direction-downward nil))
  (let ((skip-mark-regexp (mapconcat
			   'regexp-quote
			   wl-summary-skip-mark-list ""))
	goto-next regex-list regex next-entity finfo)
    (beginning-of-line)
    (if (elmo-folder-plugged-p wl-summary-buffer-elmo-folder)
	(setq regex (format "^%s[^%s]"
			    wl-summary-buffer-number-regexp
			    skip-mark-regexp))
      (setq regex (format "^%s[^%s]\\(%s\\|%s\\| \\)"
			  wl-summary-buffer-number-regexp
			  skip-mark-regexp
			  (regexp-quote wl-summary-unread-cached-mark)
			  (regexp-quote wl-summary-important-mark))))
    (unless (re-search-backward regex nil t)
      (setq goto-next t))
    (beginning-of-line)
    (if (not goto-next)
	(progn
	  (if wl-summary-buffer-disp-msg
	      (wl-summary-redisplay)))
      (if (or interactive (interactive-p))
	  (if wl-summary-buffer-prev-folder-function
	      (funcall wl-summary-buffer-prev-folder-function)
	    (when wl-auto-select-next
	      (setq next-entity (wl-summary-get-prev-folder))
	      (if next-entity
		  (setq finfo (wl-folder-get-entity-info next-entity))))
	    (wl-ask-folder
	     '(lambda () (wl-summary-next-folder-or-exit next-entity))
	     (format
	      "No more messages. Type SPC to go to %s."
	      (wl-summary-entity-info-msg next-entity finfo))))))))

(defun wl-summary-next (&optional interactive)
  ""
  (interactive)
  (if wl-summary-move-direction-toggle
      (setq wl-summary-move-direction-downward t))
  (let ((skip-mark-regexp (mapconcat
			   'regexp-quote
			   wl-summary-skip-mark-list ""))
	goto-next regex regex-list next-entity finfo)
    (end-of-line)
    (if (elmo-folder-plugged-p wl-summary-buffer-elmo-folder)
	(setq regex (format "^%s[^%s]"
			    wl-summary-buffer-number-regexp
			    skip-mark-regexp))
      (setq regex (format "^%s[^%s]\\(%s\\|%s\\| \\)"
			  wl-summary-buffer-number-regexp
			  skip-mark-regexp
			  (regexp-quote wl-summary-unread-cached-mark)
			  (regexp-quote wl-summary-important-mark))))
    (unless (re-search-forward regex nil t)
      (forward-line 1)
      (setq goto-next t))
    (beginning-of-line)
    (if (not goto-next)
	(if wl-summary-buffer-disp-msg
	    (wl-summary-redisplay))
      (if (or interactive (interactive-p))
	  (if wl-summary-buffer-next-folder-function
	      (funcall wl-summary-buffer-next-folder-function)
	    (when wl-auto-select-next
	      (setq next-entity (wl-summary-get-next-folder))
	      (if next-entity
		  (setq finfo (wl-folder-get-entity-info next-entity))))
	    (wl-ask-folder
	     '(lambda () (wl-summary-next-folder-or-exit next-entity))
	     (format
	      "No more messages. Type SPC to go to %s."
	      (wl-summary-entity-info-msg next-entity finfo))))))))

(defun wl-summary-up (&optional interactive skip-no-unread)
  ""
  (interactive)
  (if wl-summary-move-direction-toggle
      (setq wl-summary-move-direction-downward nil))
  (if (wl-summary-cursor-up)
      (if wl-summary-buffer-disp-msg
	  (wl-summary-redisplay))
    (if (or interactive
	    (interactive-p))
	(if wl-summary-buffer-prev-folder-function
	    (funcall wl-summary-buffer-prev-folder-function)
	  (let (next-entity finfo)
	    (when wl-auto-select-next
	      (progn
		(setq next-entity (wl-summary-get-prev-unread-folder))
		(if next-entity
		    (setq finfo (wl-folder-get-entity-info next-entity)))))
	    (if (and skip-no-unread
		     (eq wl-auto-select-next 'skip-no-unread))
		(wl-summary-next-folder-or-exit next-entity t)
	      (wl-ask-folder
	       '(lambda () (wl-summary-next-folder-or-exit next-entity t))
	       (format
		"No more unread messages. Type SPC to go to %s."
		(wl-summary-entity-info-msg next-entity finfo)))))))))

(defun wl-summary-get-prev-folder ()
  (let ((folder-buf (get-buffer wl-folder-buffer-name))
	last-entity cur-id)
    (when folder-buf
      (setq cur-id (save-excursion (set-buffer folder-buf)
				   wl-folder-buffer-cur-entity-id))
      (wl-folder-get-prev-folder cur-id))))

(defun wl-summary-get-next-folder ()
  (let ((folder-buf (get-buffer wl-folder-buffer-name))
	cur-id)
    (when folder-buf
      (setq cur-id (save-excursion (set-buffer folder-buf)
				   wl-folder-buffer-cur-entity-id))
      (wl-folder-get-next-folder cur-id))))

(defun wl-summary-get-next-unread-folder ()
  (let ((folder-buf (get-buffer wl-folder-buffer-name))
	cur-id)
    (when folder-buf
      (setq cur-id (save-excursion (set-buffer folder-buf)
				   wl-folder-buffer-cur-entity-id))
      (wl-folder-get-next-folder cur-id 'unread))))

(defun wl-summary-get-prev-unread-folder ()
  (let ((folder-buf (get-buffer wl-folder-buffer-name))
	cur-id)
    (when folder-buf
      (setq cur-id (save-excursion (set-buffer folder-buf)
				   wl-folder-buffer-cur-entity-id))
      (wl-folder-get-prev-folder cur-id 'unread))))

(defun wl-summary-down (&optional interactive skip-no-unread)
  (interactive)
  (if wl-summary-move-direction-toggle
      (setq wl-summary-move-direction-downward t))
  (if (wl-summary-cursor-down)
      (if wl-summary-buffer-disp-msg
	  (wl-summary-redisplay))
    (if (or interactive
	    (interactive-p))
	(if wl-summary-buffer-next-folder-function
	    (funcall wl-summary-buffer-next-folder-function)
	  (let (next-entity finfo)
	    (when wl-auto-select-next
	      (setq next-entity (wl-summary-get-next-unread-folder)))
	    (if next-entity
		(setq finfo (wl-folder-get-entity-info next-entity)))
	    (if (and skip-no-unread
		     (eq wl-auto-select-next 'skip-no-unread))
		(wl-summary-next-folder-or-exit next-entity)
	      (wl-ask-folder
	       '(lambda () (wl-summary-next-folder-or-exit next-entity))
	       (format
		"No more unread messages. Type SPC to go to %s."
		(wl-summary-entity-info-msg next-entity finfo)))))))))

(defun wl-summary-goto-last-displayed-msg ()
  (interactive)
  (unless wl-summary-buffer-last-displayed-msg
    (setq wl-summary-buffer-last-displayed-msg
	  wl-summary-buffer-current-msg))
  (if wl-summary-buffer-last-displayed-msg
      (progn
	(wl-summary-jump-to-msg wl-summary-buffer-last-displayed-msg)
	(if wl-summary-buffer-disp-msg
	    (wl-summary-redisplay)))
    (message "No last message.")))

(defun wl-summary-redisplay (&optional arg)
  (interactive "P")
  (if (and (not arg)
	   (wl-summary-no-mime-p wl-summary-buffer-elmo-folder))
      (wl-summary-redisplay-no-mime)
    (wl-summary-redisplay-internal nil nil arg)))

(defsubst wl-summary-redisplay-internal (&optional folder number force-reload)
  (interactive)
  (let* ((msgdb (wl-summary-buffer-msgdb))
	 (folder (or folder wl-summary-buffer-elmo-folder))
	 (num (or number (wl-summary-message-number)))
	 (wl-mime-charset      wl-summary-buffer-mime-charset)
	 (default-mime-charset wl-summary-buffer-mime-charset)
	 fld-buf fld-win thr-entity)
    (if (and wl-thread-open-reading-thread
	     (eq wl-summary-buffer-view 'thread)
	     (not (wl-thread-entity-get-opened
		   (setq thr-entity (wl-thread-get-entity
				     num))))
	     (wl-thread-entity-get-children thr-entity))
	(wl-thread-force-open))
    (if num
	(progn
	  (setq wl-summary-buffer-disp-msg t)
	  (setq wl-summary-buffer-last-displayed-msg
		wl-summary-buffer-current-msg)
	  ;; hide folder window
	  (if (and (not wl-stay-folder-window)
		   (setq fld-buf (get-buffer wl-folder-buffer-name)))
	      (if (setq fld-win (get-buffer-window fld-buf))
		  (delete-window fld-win)))
	  (setq wl-current-summary-buffer (current-buffer))
	  (wl-summary-mark-as-read
	   nil
	   ;; not fetched, then change server-mark.
	   (if (wl-message-redisplay folder num 'mime
				     (or force-reload
					 (string= (elmo-folder-name-internal
						   folder)
						  wl-draft-folder)))
	       nil
	     ;; plugged, then leave server-mark.
	     (if (and
		  (not
		   (elmo-folder-local-p
		    wl-summary-buffer-elmo-folder))
		  (elmo-folder-plugged-p
		   wl-summary-buffer-elmo-folder))
		 'leave))
	   t ; displayed
	   nil
	   'cached ; cached by reading.
	   )
	  (setq wl-summary-buffer-current-msg num)
	  (when wl-summary-recenter
	    (recenter (/ (- (window-height) 2) 2))
	    (if (not wl-summary-indent-length-limit)
		(wl-horizontal-recenter)))
	  (wl-highlight-summary-displaying)
	  (wl-message-buffer-prefetch-next folder num
					   wl-message-buffer-prefetch-depth
					   (current-buffer)
					   wl-summary-buffer-mime-charset)
	  (run-hooks 'wl-summary-redisplay-hook))
      (message "No message to display."))))

(defun wl-summary-redisplay-no-mime (&optional folder number)
  (interactive)
  (let* ((fld (or folder wl-summary-buffer-elmo-folder))
	 (num (or number (wl-summary-message-number)))
	 wl-break-pages)
    (if num
	(progn
	  (setq wl-summary-buffer-disp-msg t)
	  (setq wl-summary-buffer-last-displayed-msg
		wl-summary-buffer-current-msg)
	  (setq wl-current-summary-buffer (current-buffer))
	  (wl-message-redisplay fld num 'as-is
				(string= (elmo-folder-name-internal fld)
					 wl-draft-folder))
	  (wl-summary-mark-as-read nil nil t)
	  (setq wl-summary-buffer-current-msg num)
	  (when wl-summary-recenter
	    (recenter (/ (- (window-height) 2) 2))
	    (if (not wl-summary-indent-length-limit)
		(wl-horizontal-recenter)))
	  (wl-highlight-summary-displaying)
	  (run-hooks 'wl-summary-redisplay-hook))
      (message "No message to display.")
      (wl-ask-folder 'wl-summary-exit
		     "No more messages. Type SPC to go to folder mode."))))

(defun wl-summary-redisplay-all-header (&optional folder number)
  (interactive)
  (let* ((fld (or folder wl-summary-buffer-elmo-folder))
	 (num (or number (wl-summary-message-number)))
	 (wl-mime-charset      wl-summary-buffer-mime-charset)
	 (default-mime-charset wl-summary-buffer-mime-charset))
    (if num
	(progn
	  (setq wl-summary-buffer-disp-msg t)
	  (setq wl-summary-buffer-last-displayed-msg
		wl-summary-buffer-current-msg)
	  (setq wl-current-summary-buffer (current-buffer))
	  (if (wl-message-redisplay fld num 'all-header
				    (string= (elmo-folder-name-internal fld)
					     wl-draft-folder))
	      (wl-summary-mark-as-read nil nil t))
	  (setq wl-summary-buffer-current-msg num)
	  (when wl-summary-recenter
	    (recenter (/ (- (window-height) 2) 2))
	    (if (not wl-summary-indent-length-limit)
		(wl-horizontal-recenter)))
	  (wl-highlight-summary-displaying)
	  (run-hooks 'wl-summary-redisplay-hook))
      (message "No message to display."))))

(defun wl-summary-jump-to-current-message ()
  (interactive)
  (let (message-buf message-win)
    (if (setq message-buf wl-message-buffer)
	(if (setq message-win (get-buffer-window message-buf))
	    (select-window message-win)
	  (wl-message-select-buffer wl-message-buffer))
      (wl-summary-redisplay)
      (wl-message-select-buffer wl-message-buffer))))

(defun wl-summary-cancel-message ()
  "Cancel an article on news."
  (interactive)
  (if (null (wl-summary-message-number))
      (message "No message.")
    (let ((summary-buf (current-buffer))
	  message-buf)
      (wl-summary-set-message-buffer-or-redisplay)
      (if (setq message-buf (wl-message-get-original-buffer))
	  (set-buffer message-buf))
      (unless (wl-message-news-p)
	(set-buffer summary-buf)
	(if (and (eq (elmo-folder-type-internal wl-summary-buffer-elmo-folder)
		     'nntp)
		 (y-or-n-p "Cannot get Newsgroups. Fetch again? "))
	    (progn
	      (wl-summary-redisplay t)
	      (wl-summary-supersedes-message))
	  (error "This is not a news article; supersedes is impossible")))
      (when (yes-or-no-p "Do you really want to cancel this article? ")
	(let (from newsgroups message-id distribution buf)
	  (save-excursion
	    (setq from (std11-field-body "from")
		  newsgroups (std11-field-body "newsgroups")
		  message-id (std11-field-body "message-id")
		  distribution (std11-field-body "distribution"))
	    ;; Make sure that this article was written by the user.
	    (unless (wl-address-user-mail-address-p
		     (wl-address-header-extract-address
		      (car (wl-parse-addresses from))))
	      (error "This article is not yours"))
	    ;; Make control message.
	    (setq buf (set-buffer (get-buffer-create " *message cancel*")))
	    (setq wl-draft-buffer-cur-summary-buffer summary-buf)
	    (buffer-disable-undo (current-buffer))
	    (erase-buffer)
	    (insert "Newsgroups: " newsgroups "\n"
		    "From: " (wl-address-header-extract-address
			      wl-from) "\n"
			      "Subject: cmsg cancel " message-id "\n"
			      "Control: cancel " message-id "\n"
			      (if distribution
				  (concat "Distribution: " distribution "\n")
				"")
			      mail-header-separator "\n"
			      wl-summary-cancel-message)
	    (message "Canceling your message...")
	    (wl-draft-raw-send t t) ; kill when done, force-pre-hooks.
	    (message "Canceling your message...done")))))))

(defun wl-summary-supersedes-message ()
  "Supersede current message."
  (interactive)
  (let ((summary-buf (current-buffer))
	message-buf from)
    (wl-summary-set-message-buffer-or-redisplay)
    (if (setq message-buf (wl-message-get-original-buffer))
	(set-buffer message-buf))
    (unless (wl-message-news-p)
      (set-buffer summary-buf)
      (if (and (eq (elmo-folder-type-internal wl-summary-buffer-elmo-folder)
		   'nntp)
	       (y-or-n-p "Cannot get Newsgroups. Fetch again? "))
	  (progn
	    (wl-summary-redisplay t)
	    (wl-summary-supersedes-message))
	(error "This is not a news article; supersedes is impossible")))
    (save-excursion
      (setq from (std11-field-body "from"))
      ;; Make sure that this article was written by the user.
      (unless (wl-address-user-mail-address-p
	       (wl-address-header-extract-address
		(car (wl-parse-addresses from))))
	(error "This article is not yours"))
      (let* ((message-id (std11-field-body "message-id"))
	     (followup-to (std11-field-body "followup-to"))
	     (mail-default-headers
	      (concat mail-default-headers
		      "Supersedes: " message-id "\n"
		      (and followup-to
			   (concat "Followup-To: " followup-to "\n")))))
	(if message-buf (set-buffer message-buf))
	(wl-draft-edit-string (buffer-substring (point-min) (point-max)))))))

(defun wl-summary-save (&optional arg wl-save-dir)
  (interactive)
  (let ((filename)
	(num (wl-summary-message-number)))
    (if (null wl-save-dir)
	(setq wl-save-dir wl-temporary-file-directory))
    (if num
	(save-excursion
	  (setq filename (expand-file-name
			  (int-to-string num)
			  wl-save-dir))
	  (if (null (and arg
			 (null (file-exists-p filename))))
	      (setq filename
		    (read-file-name "Save to file: " filename)))

	  (wl-summary-set-message-buffer-or-redisplay)
	  (set-buffer (wl-message-get-original-buffer))
	  (if (and (null arg) (file-exists-p filename))
	      (if (y-or-n-p "File already exists.  override it? ")
		  (write-region (point-min) (point-max) filename))
	    (write-region (point-min) (point-max) filename)))
      (message "No message to save."))
    num))

(defun wl-summary-save-region (beg end)
  (interactive "r")
  (save-excursion
    (save-restriction
      (narrow-to-region beg end)
      (goto-char (point-min))
      (let ((wl-save-dir
	     (wl-read-directory-name "Save to directory: "
				     wl-temporary-file-directory)))
	(if (null (file-exists-p wl-save-dir))
	    (make-directory wl-save-dir))
	(if (eq wl-summary-buffer-view 'thread)
	    (progn
	      (while (not (eobp))
		(let* ((number (wl-summary-message-number))
		       (entity (wl-thread-get-entity number)))
		  (if (wl-thread-entity-get-opened entity)
		      (wl-summary-save t wl-save-dir)
		    ;; closed
		    (wl-summary-save t wl-save-dir))
		  (forward-line 1))))
	  (while (not (eobp))
	    (wl-summary-save t wl-save-dir)
	    (forward-line 1)))))))

;; mew-summary-pipe-message()
(defun wl-summary-pipe-message (prefix command)
  "Send this message via pipe."
  (interactive (list current-prefix-arg nil))
  (if (null (wl-summary-message-number))
      (message "No message.")
    (setq command (read-string "Shell command on message: "
			       wl-summary-shell-command-last))
    (if (y-or-n-p "Send this message to pipe? ")
	(save-excursion
	  (wl-summary-set-message-buffer-or-redisplay)
	  (set-buffer (wl-message-get-original-buffer))
	  (if (string= command "")
	      (setq command wl-summary-shell-command-last))
	  (goto-char (point-min)) ; perhaps this line won't be necessary
	  (if prefix
	      (search-forward "\n\n"))
	  (shell-command-on-region (point) (point-max) command nil)
	  (setq wl-summary-shell-command-last command)))))

(defun wl-summary-print-message (&optional arg)
  (interactive "P")
  (if (null (wl-summary-message-number))
      (message "No message.")
    (save-excursion
      (wl-summary-set-message-buffer-or-redisplay)
      (if (or (not (interactive-p))
	      (y-or-n-p "Print ok? "))
	  (progn
	    (let ((buffer (generate-new-buffer " *print*")))
	      (copy-to-buffer buffer (point-min) (point-max))
	      (set-buffer buffer)
	      (funcall wl-print-buffer-function)
	      (kill-buffer buffer)))
	(message "")))))

(defun wl-summary-print-message-with-ps-print (&optional filename)
  (interactive)
  (if (null (wl-summary-message-number))
      (message "No message.")
    (setq filename (ps-print-preprint current-prefix-arg))
    (if (or (not (interactive-p))
	    (y-or-n-p "Print ok? "))
	(let ((summary-buffer (current-buffer))
	      wl-break-pages)
	  (save-excursion
	    (wl-summary-set-message-buffer-or-redisplay)
	    ;; (wl-summary-redisplay-internal)
	    (let* ((buffer (generate-new-buffer " *print*"))
		   (entity (progn
			     (set-buffer summary-buffer)
			     (assoc (cdr (assq
					  (wl-summary-message-number)
					  (elmo-msgdb-get-number-alist
					   (wl-summary-buffer-msgdb))))
				    (elmo-msgdb-get-overview
				     (wl-summary-buffer-msgdb)))))
		   (wl-ps-subject
		    (and entity
			 (or (elmo-msgdb-overview-entity-get-subject entity)
			     "")))
		   (wl-ps-from
		    (and entity
			 (or (elmo-msgdb-overview-entity-get-from entity) "")))
		   (wl-ps-date
		    (and entity
			 (or (elmo-msgdb-overview-entity-get-date entity) ""))))
	      (run-hooks 'wl-ps-preprint-hook)
	      (set-buffer wl-message-buffer)
	      (copy-to-buffer buffer (point-min) (point-max))
	      (set-buffer buffer)
	      (unwind-protect
		  (let ((ps-left-header
			 (list (concat "(" wl-ps-subject ")")
			       (concat "(" wl-ps-from ")")))
			(ps-right-header
			 (list "/pagenumberstring load"
			       (concat "(" wl-ps-date ")"))))
		    (run-hooks 'wl-ps-print-hook)
		    (funcall wl-ps-print-buffer-function filename))
		(kill-buffer buffer)))))
      (message ""))))

(if (featurep 'ps-print) ; ps-print is available.
    (fset 'wl-summary-print-message 'wl-summary-print-message-with-ps-print))

(defun wl-summary-folder-info-update ()
  (let ((folder (elmo-string (wl-summary-buffer-folder-name)))
	(num-db (elmo-msgdb-get-number-alist
		 (wl-summary-buffer-msgdb))))
    (wl-folder-set-folder-updated folder
				  (list 0
					(+ wl-summary-buffer-unread-count
					   wl-summary-buffer-new-count)
					(length num-db)))))

(defun wl-summary-get-original-buffer ()
  "Get original buffer for the current summary."
  (save-excursion
    (wl-summary-set-message-buffer-or-redisplay)
    (wl-message-get-original-buffer)))

(defun wl-summary-pack-number (&optional arg)
  (interactive "P")
  (elmo-folder-pack-numbers wl-summary-buffer-elmo-folder)
  (let (wl-use-scoring)
    (wl-summary-rescan)))

(defun wl-summary-target-mark-uudecode ()
  (interactive)
  (let ((mlist (reverse wl-summary-buffer-target-mark-list))
	(summary-buf (current-buffer))
	(tmp-buf (get-buffer-create "*WL UUENCODE*"))
	orig-buf i k filename rc errmsg)
    (setq i 1)
    (setq k (length mlist))
    (set-buffer tmp-buf)
    (erase-buffer)
    (save-window-excursion
      (while mlist
	(set-buffer summary-buf)
	(wl-summary-jump-to-msg (car mlist))
	(wl-summary-redisplay)
	(set-buffer (setq orig-buf (wl-summary-get-original-buffer)))
	(goto-char (point-min))
	(cond ((= i 1) ; first
	       (if (setq filename (wl-message-uu-substring
				   orig-buf tmp-buf t
				   (= i k)))
		   nil
		 (error "Can't find begin line")))
	      ((< i k)
	       (wl-message-uu-substring orig-buf tmp-buf))
	      (t ; last
	       (wl-message-uu-substring orig-buf tmp-buf nil t)))
	(setq i (1+ i))
	(setq mlist (cdr mlist)))
      (set-buffer tmp-buf)
      (message "Exec %s..." wl-prog-uudecode)
      (unwind-protect
	  (let ((decode-dir wl-temporary-file-directory))
	    (if (not wl-prog-uudecode-no-stdout-option)
		(setq filename (read-file-name "Save to file: "
					       (expand-file-name
						(elmo-safe-filename filename)
						wl-temporary-file-directory)))
	      (setq decode-dir
		    (wl-read-directory-name "Save to directory: "
					    wl-temporary-file-directory))
	      (setq filename (expand-file-name filename decode-dir)))
	    (if (file-exists-p filename)
		(or (yes-or-no-p (format "File %s exists. Save anyway? "
					 filename))
		    (error "")))
	    (elmo-bind-directory
	     decode-dir
	     (setq rc
		   (as-binary-process
		    (apply 'call-process-region (point-min) (point-max)
			   wl-prog-uudecode t (current-buffer) nil
			   wl-prog-uudecode-arg))))
	    (when (not (= 0 rc))
	      (setq errmsg (buffer-substring (point-min)(point-max)))
	      (error "Uudecode error: %s" errmsg))
	    (if (not wl-prog-uudecode-no-stdout-option)
		(let (file-name-handler-alist) ;; void jka-compr
		  (as-binary-output-file
		   (write-region (point-min) (point-max)
				 filename nil 'no-msg))))
	    (save-excursion
	      (set-buffer summary-buf)
	      (wl-summary-delete-all-temp-marks))
	    (if (file-exists-p filename)
		(message "Saved as %s" filename)))
	(kill-buffer tmp-buf)))))

;; Someday
;; (defun wl-summary-drop-unsync ()
;;   "Drop all unsync messages."
;;   (interactive)
;;   (if (elmo-folder-pipe-p (wl-summary-buffer-folder-name))
;;       (error "You cannot drop unsync messages in this folder"))
;;   (if (or (not (interactive-p))
;; 	  (y-or-n-p "Drop all unsync messages? "))
;;       (let* ((folder-list (elmo-folder-get-primitive-folder-list
;; 			   (wl-summary-buffer-folder-name)))
;; 	     (is-multi (elmo-multi-p (wl-summary-buffer-folder-name)))
;; 	     (sum 0)
;; 	     (multi-num 0)
;; 	     pair)
;; 	(message "Dropping...")
;; 	(while folder-list
;; 	  (setq pair (elmo-folder-message-numbers (car folder-list)))
;; 	  (when is-multi ;; dirty hack...
;; 	    (incf multi-num)
;; 	    (setcar pair (+ (* multi-num elmo-multi-divide-number)
;; 			    (car pair))))
;; 	  (elmo-msgdb-set-number-alist
;; 	   (wl-summary-buffer-msgdb)
;; 	   (nconc
;; 	    (elmo-msgdb-get-number-alist (wl-summary-buffer-msgdb))
;; 	    (list (cons (car pair) nil))))
;; 	  (setq sum (+ sum (cdr pair)))
;; 	  (setq folder-list (cdr folder-list)))
;; 	(wl-summary-set-message-modified)
;; 	(wl-folder-set-folder-updated (wl-summary-buffer-folder-name)
;; 				      (list 0
;; 					    (+ wl-summary-buffer-unread-count
;; 					       wl-summary-buffer-new-count)
;; 					    sum))
;; 	(message "Dropping...done"))))

(defun wl-summary-default-get-next-msg (msg)
  (or (wl-summary-next-message msg
			       (if wl-summary-move-direction-downward 'down
				 'up)
			       nil)
      (cadr (memq msg (if wl-summary-move-direction-downward
			  wl-summary-buffer-number-list
			(reverse wl-summary-buffer-number-list))))))

(defun wl-summary-save-current-message ()
  "Save current message for `wl-summary-yank-saved-message'."
  (interactive)
  (let ((number (wl-summary-message-number)))
    (setq wl-summary-buffer-saved-message number)
    (and number (message "No: %s is saved." number))))

(defun wl-summary-yank-saved-message ()
  "Set current message as a parent of the saved message."
  (interactive)
  (if wl-summary-buffer-saved-message
      (let ((number (wl-summary-message-number)))
	(if (eq wl-summary-buffer-saved-message number)
	    (message "Cannot set itself as a parent.")
	  (save-excursion
	    (wl-thread-jump-to-msg wl-summary-buffer-saved-message)
	    (wl-thread-set-parent number)
	    (wl-summary-set-thread-modified))
	  (setq  wl-summary-buffer-saved-message nil)))
    (message "There's no saved message.")))

(require 'product)
(product-provide (provide 'wl-summary) (require 'wl-version))

;;; wl-summary.el ends here
