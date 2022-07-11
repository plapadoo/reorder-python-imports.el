(require 'cl-lib)
(require 'projectile)

(defgroup reorder-python-imports nil
  "Reformat Python code with \"reorder-python-imports\"."
  :group 'python)

(defcustom reorder-python-imports-executable "reorder-python-imports"
  "Name of the executable to run."
  :type 'string)

(defvar reorder-python-imports-call-args
  '("-")
  "Reorder-python-imports process call arguments."
  )

(defun reorder-python-imports-call-bin (input-buffer output-buffer error-buffer)
  "Call process reorder-python-executable.

Send INPUT-BUFFER content to the process stdin.  Saving the
output to OUTPUT-BUFFER.  Saving process stderr to ERROR-BUFFER.
Return reorder-python-imports process the exit code."
  (with-current-buffer input-buffer
    (let ((default-directory (projectile-project-root)))
      (let ((process (make-process :name "reorder-python-imports"
                                   :command `(,reorder-python-imports-executable ,@reorder-python-imports-call-args)
                                   :buffer output-buffer
                                   :stderr error-buffer
                                   :noquery t
                                   :sentinel (lambda (process event)))))
      (set-process-query-on-exit-flag (get-buffer-process error-buffer) nil)
      (set-process-sentinel (get-buffer-process error-buffer) (lambda (process event)))
      (save-restriction
          (widen)
          (process-send-region process (point-min) (point-max)))
      (process-send-eof process)
      (accept-process-output process nil nil t)
      (while (process-live-p process)
          (accept-process-output process nil nil t))
      (process-exit-status process)))))

;;;###autoload
(defun reorder-python-imports-buffer (&optional display)
  "Try to reorder-python-imports the current buffer.

Show reorder-python-imports output, if reorder-python-imports exit abnormally and DISPLAY is t."
  (interactive (list t))
  (let* ((original-buffer (current-buffer))
         (tmpbuf (get-buffer-create "*reorder-python-imports*"))
         (errbuf (get-buffer-create "*reorder-python-imports-error*")))
    ;; This buffer can be left after previous reorder-python-imports invocation.  It
    ;; can contain error message of the previous run.
    (dolist (buf (list tmpbuf errbuf))
      (with-current-buffer buf
        (erase-buffer)))
    (condition-case err
        (if (and (not (zerop (reorder-python-imports-call-bin original-buffer tmpbuf errbuf))) nil)
            (error "Process reorder-python-imports failed, see %s buffer for details" (buffer-name errbuf))
          (unless (or (eq (buffer-size tmpbuf) 0) (eq (compare-buffer-substrings tmpbuf nil nil original-buffer nil nil) 0))
            (with-current-buffer original-buffer (replace-buffer-contents tmpbuf)))
          (mapc 'kill-buffer (list tmpbuf errbuf)))
      (error (message "%s" (error-message-string err))
             (when display
               (pop-to-buffer errbuf))))))

;;;###autoload
(define-minor-mode reorder-python-imports-mode
  "Automatically run reorder-python-imports before saving."
  :lighter " Reorder"
  (if reorder-python-imports-mode
      (add-hook 'before-save-hook 'reorder-python-imports-buffer nil t)
    (remove-hook 'before-save-hook 'reorder-python-imports-buffer t)))

(provide 'reorder-python-imports)

;;; reorder-python-imports.el ends here
