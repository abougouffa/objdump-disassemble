;;; objdump-disassemble.el --- Disassemble executable and object files using objdump  -*- lexical-binding: t; -*-

;; Copyright (C) 2022-2024  Abdelhak Bougouffa

;; Author: Abdelhak Bougouffa <abougouffa@fedoraproject.org>
;; Keywords: c, tools, files, languages

;; SPDX-License-Identifier: MIT

;;; Commentary:

;;

;;; Code:

(require 'asm-mode)


(defgroup objdump-disassemble nil
  "Use \"objdump\" to display disassembled execulables and object files."
  :group 'tools)

(defcustom objdump-executable "objdump"
  "The \"objdump\" command."
  :group 'objdump-disassemble
  :type '(choice file string))

(defcustom objdump-binary-predicate-chunk-size 1024
  "The chunk size used in `objdump-binary-file-p' to check for binary files."
  :group 'objdump-disassemble
  :type '(choice file string))

;; A predicate for detecting binary buffers. Inspired by: emacs.stackexchange.com/q/10277/37002
;;;###autoload
(defun objdump-binary-buffer-p (&optional buffer)
  "Return whether BUFFER or the current buffer is binary.

A binary buffer is defined as containing at least one null byte.

Returns either nil, or the position of the first null byte."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (search-forward (string ?\x00) nil t 1))))

;;;###autoload
(defun objdump-binary-file-p (file &optional chunk)
  "Is FILE a binary?

This checks the first CHUNK of bytes, defaults to 1024."
  (with-temp-buffer
    (insert-file-contents-literally file nil 0 (or chunk objdump-binary-predicate-chunk-size))
    (objdump-binary-buffer-p)))

;;;###autoload
(defun objdump-recognizable-file-p (filename)
  "Can FILENAME be recognized by \"objdump\"."
  (when-let* ((file (and filename (file-truename filename))))
    (and objdump-executable
         (executable-find objdump-executable)
         (not (file-remote-p file))
         (file-exists-p file)
         (not (file-directory-p file))
         (not (zerop (file-attribute-size (file-attributes file))))
         (not (string-match-p
               "file format not recognized"
               (shell-command-to-string
                (format "%s --file-headers %s" objdump-executable (shell-quote-argument file))))))))

;;;###autoload
(defun objdump-recognizable-buffer-p (&optional buffer)
  "Can the BUFFER be viewed as a disassembled code with objdump."
  (objdump-recognizable-file-p (buffer-file-name buffer)))

(defvar-local objdump-disassemble--orig-filename nil)
(defvar objdump-disassemble-mode-syntax-table (make-syntax-table asm-mode-syntax-table))
(defvar objdump-disassemble-font-lock-keywords (copy-sequence asm-font-lock-keywords))

(defun objdump-disassemble-buffer ()
  "Disassemble the current buffer.

Return nil if the current buffer is not recognizable by objdump."
  (let* ((file (buffer-file-name))
         (buffer-read-only nil))
    (when (objdump-recognizable-file-p file)
      (message "Disassembling %S using objdump." (file-name-nondirectory file))
      (erase-buffer)
      (set-visited-file-name (file-name-with-extension file ".objdump"))
      (call-process objdump-executable nil (current-buffer) nil "-d" file)
      (goto-char (point-min))
      (setq-local objdump-disassemble--orig-filename file))))

(defun objdump-disassemble-setup ()
  "Setup the current buffer for `objdump-disassemble-mode'."
  (when (objdump-disassemble-buffer)
    (buffer-disable-undo)
    (set-buffer-modified-p nil)
    (view-mode 1)
    (read-only-mode 1)
    ;; Apply syntax highlighting from `asm-mode'
    (set-syntax-table objdump-disassemble-mode-syntax-table)
    (modify-syntax-entry ?# "< b") ; use # for comments
    (setq-local font-lock-defaults '(objdump-disassemble-font-lock-keywords))
    (font-lock-update)))

(defun objdump-disassemble-teardown ()
  "Setup the current buffer for `objdump-disassemble-mode'."
  (when objdump-disassemble--orig-filename
    (set-visited-file-name objdump-disassemble--orig-filename))
  (revert-buffer t t))

;;;###autoload
(define-minor-mode objdump-disassemble-mode
  "Major mode for viewing executable files disassembled using objdump."
  :lighter "Objdump"
  :group 'objdump-disassemble
  (if objdump-disassemble-mode
      (objdump-disassemble-setup)
    (objdump-disassemble-teardown)))


(provide 'objdump-disassemble)
;;; objdump-disassemble.el ends here
