;;; auto-tangle-init.el --- Auto-tangle init.org on save
;;; Commentary:
;;; This module provides automatic tangling of init.org whenever it's saved.
;;; Load this early in your init.el for it to work properly.

;;; Code:

(defun ebrimasaye/org-babel-tangle-init ()
  "If the current buffer is init.org, tangle it to init.el.
This function is added to the after-save-hook to automatically
regenerate init.el whenever init.org is modified and saved."
  (when (equal (buffer-file-name)
               (expand-file-name "~/.emacs.d/init.org"))
    (org-babel-tangle)
    (message "✅ init.org tangled to init.el")))

;; Hook init.org tangle to the after-save-hook
(add-hook 'after-save-hook #'ebrimasaye/org-babel-tangle-init)

(provide 'auto-tangle-init)
;;; auto-tangle-init.el ends here
