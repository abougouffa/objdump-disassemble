;;; objdump-disassemble-utils.el --- Extra functions for `objdump'  -*- lexical-binding: t; -*-

;; Copyright (C) 2022-2025  Abdelhak Bougouffa

;; Author: Abdelhak Bougouffa <abougouffa@fedoraproject.org>
;; Keywords: c, tools, files, languages

;; SPDX-License-Identifier: MIT

;;; Commentary:

;;

;;; Code:

(require 'objdump-disassemble)


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


(provide 'objdump-disassemble-utils)
;;; objdump-disassemble-utils.el ends here
