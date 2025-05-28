;;; objdump-disassemble.el --- Disassemble executable and object files using objdump  -*- lexical-binding: t; -*-

;; Copyright (C) 2022-2025  Abdelhak Bougouffa

;; Author: Abdelhak Bougouffa <abougouffa@fedoraproject.org>
;; Keywords: c, tools, files, languages
;; Version: 1.0.1

;; SPDX-License-Identifier: MIT

;;; Commentary:

;;

;;; Code:

(require 'asm-mode)

(eval-when-compile
  (require 'cl-macs))

(defgroup objdump-disassemble nil
  "Use \"objdump\" to display disassembled executable and object files."
  :group 'tools)

(defcustom objdump-disassemble-executable "objdump"
  "The \"objdump\" command."
  :group 'objdump-disassemble
  :type '(choice file string))

(make-obsolete-variable 'objdump-executable 'objdump-disassemble-executable "1.0")

(defcustom objdump-disassemble-disable-on-remote nil
  "Don't try to disassemble remote files.

Normally, this requires objdump to be installed on the remote machine."
  :group 'objdump-disassemble
  :type 'boolean)

;;;###autoload
(defun objdump-recognizable-file-p (filename)
  "Can FILENAME be recognized by \"objdump\"."
  (when-let* ((filename (and filename (file-truename filename))))
    (and (executable-find objdump-disassemble-executable)
         (or (not (file-remote-p filename))
             (and (file-remote-p filename)
                  (not objdump-disassemble-disable-on-remote)))
         (file-regular-p filename)
         (not (zerop (file-attribute-size (file-attributes filename))))
         (not (string-match-p
               "file format not recognized"
               (let ((default-directory (file-name-directory filename)) ; To ensure running the command in the remote host if any
                     (local-filename (file-name-nondirectory filename)))
                 (shell-command-to-string
                  (format "%s --file-headers %s" objdump-disassemble-executable (shell-quote-argument local-filename)))))))))

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
  (let* ((filename (buffer-file-name))
         (buffer-read-only nil))
    (when (objdump-recognizable-file-p filename)
      (message "Disassembling %S using objdump." (file-name-nondirectory filename))
      (erase-buffer)
      (set-visited-file-name (file-name-with-extension filename ".objdump"))
      (let ((default-directory (file-name-directory filename)))
        (call-process objdump-disassemble-executable nil (current-buffer) nil "-d" (file-name-nondirectory filename)))
      (goto-char (point-min))
      (setq-local objdump-disassemble--orig-filename filename))))

(defun objdump-disassemble-setup ()
  "Setup the current buffer for `objdump-disassemble-mode'."
  (when (objdump-disassemble-buffer)
    (buffer-disable-undo)
    (set-buffer-modified-p nil)
    ;; Apply syntax highlighting from `asm-mode'
    (set-syntax-table objdump-disassemble-mode-syntax-table)
    (modify-syntax-entry ?# "< b") ; use # for comments
    (setq-local font-lock-defaults '(objdump-disassemble-font-lock-keywords))
    (font-lock-update)
    (view-mode 1)
    (read-only-mode 1)))

(defun objdump-disassemble-teardown ()
  "Setup the current buffer for `objdump-disassemble-mode'."
  (when (and objdump-disassemble-mode objdump-disassemble--orig-filename)
    (set-visited-file-name objdump-disassemble--orig-filename)
    (setq objdump-disassemble--orig-filename nil)
    (revert-buffer t t)))

;;;###autoload
(define-minor-mode objdump-disassemble-mode
  "Major mode for viewing executable files disassembled using objdump."
  :lighter "Objdump"
  :group 'objdump-disassemble
  (if objdump-disassemble-mode
      (objdump-disassemble-setup)
    (objdump-disassemble-teardown)))

(defun objdump-disassemble-enable ()
  (objdump-disassemble-mode 1))

;;;###autoload
(define-global-minor-mode global-objdump-disassemble-mode objdump-disassemble-mode objdump-disassemble-enable
  :lighter "Objdump"
  :group 'objdump-disassemble
  (if global-objdump-disassemble-mode
      (add-hook 'magic-fallback-mode-alist '(objdump-recognizable-buffer-p . objdump-disassemble-mode) 99)
    (cl-callf2 delete '(objdump-recognizable-buffer-p . objdump-disassemble-mode) magic-fallback-mode-alist)))


(provide 'objdump-disassemble)
;;; objdump-disassemble.el ends here
