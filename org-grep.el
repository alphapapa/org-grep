;;; org-grep.el --- Kind of M-x rgrep adapted for Org mode.

;; Copyright © 2013 Progiciels Bourbeau-Pinard inc.

;; Author: François Pinard <pinard@iro.umontreal.ca>
;; Maintainer: François Pinard <pinard@iro.umontreal.ca>
;; URL: https://github.com/pinard/org-grep

;; This is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software Foundation,
;; Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

;;; Commentary:

;; This tool allows for grepping files in a set of Org directories,
;; formatting the results as a separate Org buffer.  This buffer is
;; assorted with a few specific navigation commands so it works a bit
;; like M-x rgrep.  See https://github.com/pinard/org-grep.

;;; Code:

(defvar org-grep-directories nil
  "Directories to search, or ORG-DIRECTORY if nil.")

(defvar org-grep-extensions '(".org")
  "List of extensions for searchable files.")

(defvar org-grep-buffer-name "*Org grep*")
(defvar org-grep-hit-regexp "^- ")
(defvar org-grep-user-regexp nil)

(defun org-grep (regexp)
  (interactive
   (list (if (use-region-p)
             (buffer-substring (region-beginning) (region-end))
           (read-string "Org grep? "))))
  (when (string-equal regexp "")
    (error "Nothing to find!"))
  ;; Launch grep according to REGEXP.
  (pop-to-buffer org-grep-buffer-name)
  (toggle-read-only 0)
  (erase-buffer)
  (save-some-buffers t)
  (shell-command
   (concat "find "
           (if org-grep-directories
               (org-grep-join org-grep-directories " ")
             org-directory)
           (and org-grep-extensions
                (concat " -regex '.*\\.\\("
                        (org-grep-join org-grep-extensions "\\|")
                        "\\)'"))
           " -print0 | xargs -0 grep -i -n "
           (shell-quote-argument regexp))
   t)
  ;; Reformat output into Org format.
  (let ((counter 0))
    (goto-char (point-min))
    (while (re-search-forward "^\\([^:]+\\):\\([0-9]+\\):" nil t)
      (setq counter (1+ counter))
      (replace-match (concat "- [[file:\\1::\\2]["
                             (file-name-sans-extension
                              (file-name-nondirectory (match-string 1)))
                             ":]]\\2 :: ")))
    (goto-char (point-min))
    (insert (format "* Grep found %d occurrences of %s\n\n" counter regexp)))
  (org-mode)
  (goto-char (point-min))
  (org-show-subtree)
  ;; Highlight the search string.
  (when org-grep-user-regexp
    (hi-lock-unface-buffer (org-grep-hi-lock-helper org-grep-user-regexp)))
  (hi-lock-face-buffer (org-grep-hi-lock-helper regexp) 'hi-yellow)
  (setq org-grep-user-regexp regexp)
  ;; Add special commands to the keymap.
  (use-local-map (copy-keymap (current-local-map)))
  (toggle-read-only 1)
  (local-set-key "\C-c\C-c" 'org-grep-current-jump)
  (local-set-key "\C-x`" 'org-grep-next-jump)
  (local-set-key "." 'org-grep-current)
  (local-set-key "g" 'org-grep-recompute)
  (local-set-key "n" 'org-grep-next)
  (local-set-key "p" 'org-grep-previous)
  (when (boundp 'org-mode-map)
    (define-key org-mode-map "\C-x`" 'org-grep-maybe-next-jump)))

(defun org-grep-join (fragments separator)
  (if fragments
      (concat (car fragments)
              (apply 'concat
                     (mapcar (lambda (fragment) (concat separator fragment))
                             (cdr fragments))))
    ""))

(defun org-grep-hi-lock-helper (regexp)
  ;; Stolen from hi-lock-process-phrase.
  ;; FIXME: ASCII only.  Sad that hi-lock ignores case-fold-search!
  ;; Also, hi-lock-face-phrase-buffer does not have an unface counterpart.
  (replace-regexp-in-string
   "\\<[a-z]"
   (lambda (text) (format "[%s%s]" (upcase text) text))
   regexp))

(defun org-grep-current ()
  (interactive)
  ;; FIXME: save-current-buffer fails: the current buffer is not restored.
  (save-current-buffer (org-grep-current-jump)))

(defun org-grep-current-jump ()
  (interactive)
  ;; FIXME: org-reveal fails: the goal line stays collapsed and hidden.
  (beginning-of-line)
  (forward-char 2)
  (org-open-at-point)
  (org-reveal))

(defun org-grep-maybe-next-jump ()
  (interactive)
  (let ((buffer (current-buffer))
        (hits (get-buffer org-grep-buffer-name))
        jumped)
    (when hits
      (pop-to-buffer hits)
      (when (re-search-forward org-grep-hit-regexp nil t)
        (org-grep-current-jump)
        (setq jumped t)))
    (unless jumped
      (set-buffer buffer)
      (next-error))))

(defun org-grep-next ()
  (interactive)
  (when (re-search-forward org-grep-hit-regexp nil t)
    (org-grep-current)))

(defun org-grep-next-jump ()
  (interactive)
  (when (re-search-forward org-grep-hit-regexp nil t)
    (org-grep-current-jump)))

(defun org-grep-previous ()
  (interactive)
  (when (re-search-backward org-grep-hit-regexp nil t)
    (forward-char 2)
    (org-grep-current)))

(defun org-grep-recompute ()
  (interactive)
  (when org-grep-user-regexp
    (org-grep org-grep-user-regexp)))

;;; org-grep.el ends here
