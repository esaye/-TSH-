;;; init.el --- AI Development Environment for Emacs
;;; Commentary:
;;; Comprehensive Emacs configuration for AI/ML development
;;; Optimized for Python, Jupyter, and AI frameworks

;;; Code:

;; ============================================================================
;; PACKAGE MANAGEMENT (must come first)
;; ============================================================================

(require 'package)
(setq package-enable-at-startup nil)

;; Add package repositories
(setq package-archives
      '(("gnu" . "https://elpa.gnu.org/packages/")
        ("melpa" . "https://melpa.org/packages/")
        ("melpa-stable" . "https://stable.melpa.org/packages/")))

;; Pre-load all-the-icons before package-initialize so that
;; major-mode-icons autoloads (which eagerly call all-the-icons functions)
;; don't trigger a void-function error during init.
(let ((ati-dir (car (file-expand-wildcards
                     (expand-file-name "elpa/all-the-icons-*" user-emacs-directory)))))
  (when ati-dir
    (add-to-list 'load-path ati-dir)
    (require 'all-the-icons nil t)))

(package-initialize)

;;; Load Org and literate configuration files (after package-initialize)
;;; This ensures MELPA Org version is available before requiring it
(setq dotfiles-dir (file-name-directory (or (buffer-file-name) load-file-name)))

(let* ((org-dir (expand-file-name
                    "lisp" (expand-file-name
                            "org" (expand-file-name
                                   "src" dotfiles-dir))))
          (org-contrib-dir (expand-file-name
                            "lisp" (expand-file-name
                                    "contrib" (expand-file-name
                                               ".." org-dir))))
          (load-path (append (list org-dir org-contrib-dir)
                             (or load-path nil))))
  ;; load up Org and Org-babel
  (require 'org)
  (require 'ob-tangle))

;; load up all literate org-mode files in this directory
;; Skip init.org because tangling it regenerates init.el and causes a recursive load.
(mapc #'org-babel-load-file
      (remove (expand-file-name "init.org" dotfiles-dir)
              (directory-files dotfiles-dir t "\\.org$")))

(setq inferior-lisp-program "ros -Q run")

;; Ensure package contents are refreshed if not already
(unless package-archive-contents
  (package-refresh-contents))

;; Bootstrap use-package
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

;; Enable :quelpa keyword in use-package (for GitHub-hosted packages)
(require 'quelpa-use-package)
(quelpa-use-package-activate-advice)

;; ============================================================================
;; LOAD PATH SETUP (after package bootstrap)
;; ============================================================================

;; Add lisp subdirectory to load-path for local configuration files
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(add-to-list 'load-path "~/.emacs.d/lisp/emacs-claude-code")
(require 'emacs-claude-code)

;; Load auto-tangle module for init.org
;; This ensures that saving init.org automatically regenerates init.el
(require 'auto-tangle-init)

;; TMR (manual package — :ensure nil since it's not from MELPA)
(add-to-list 'load-path "~/.emacs.d/manual-packages/tmr")
(use-package tmr
  :ensure nil
  :config
  (define-key global-map (kbd "C-c T") #'tmr-prefix-map)
  (setq tmr-sound-file "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
        tmr-notification-urgency 'normal
        tmr-description-list 'tmr-description-history))

;; Sync shell PATH (including nvm, cargo, etc.) into Emacs exec-path.
;; Must run before any :ensure-system-package or executable-find calls.
;; Without this, graphical Emacs launches miss nvm paths and :ensure-system-package
;; incorrectly treats already-installed binaries as missing.
(use-package exec-path-from-shell
  :config
  (when (memq window-system '(mac ns x pgtk))
    (exec-path-from-shell-initialize))
  (when (daemonp)
    (exec-path-from-shell-initialize)))

;; ============================================================================
;; EAF (Emacs Application Framework)
;; ============================================================================

(condition-case err
    (progn
      (add-to-list 'load-path "~/.emacs.d/site-lisp/emacs-application-framework/")
      ;; Ensure MELPA Org is loaded (not just built-in) to avoid version mismatch
      (require 'org)
      (setq eaf-python-command "/usr/bin/python3")  ; Use system Python, not venv

      ;; Persistent storage path — pins the Qt WebEngine cookie database so
      ;; ForcePersistentCookies works reliably across restarts.
      (setq eaf-config-location (expand-file-name "~/.emacs.d/browser/"))

      (require 'eaf)

      ;; Disable geolocation — GeoClue2 D-Bus service denies access for this UID.
      ;; Appends \",Geolocation\" to the existing --disable-features= value so we
      ;; don't produce a duplicate flag (last one wins in Chromium, which would
      ;; silently drop IsolateOrigins and site-per-process).
      (defun my/eaf-disable-geolocation (orig-fun)
        \"Append ,Geolocation to the existing --disable-features flag in QTWEBENGINE_CHROMIUM_FLAGS.\"
        (mapcar (lambda (var)
                  (if (string-match \"\\\\(QTWEBENGINE_CHROMIUM_FLAGS=.*--disable-features=[^ ]*\\\\)\" var)
                      (concat var \",Geolocation\")
                    var))
                (funcall orig-fun)))
      (advice-add 'eaf--build-process-environment :around #'my/eaf-disable-geolocation)

      ;; Core apps
      (require 'eaf-browser)
      (require 'eaf-terminal)
      (require 'eaf-pdf-viewer)
      (require 'eaf-file-manager)
      (require 'eaf-file-browser)
      (require 'eaf-file-sender)
      (require 'eaf-image-viewer)
      (require 'eaf-map)
      (require 'eaf-mindmap)
      (require 'eaf-mind-elixir)
      (require 'eaf-markmap)
      (require 'eaf-org-previewer)
      (require 'eaf-markdown-previewer)
      (require 'eaf-jupyter)
      (require 'eaf-rss-reader)
      (require 'eaf-music-player)
      (require 'eaf-system-monitor)
      (require 'eaf-video-player)
      (require 'eaf-video-editor)
      (require 'eaf-js-video-player)
      (require 'eaf-camera)
      (require 'eaf-git)
      (require 'eaf-pyqterminal)
      (require 'eaf-airshare)

      ;; Extras
      (require 'eaf-2048)
      (require 'eaf-vue-demo)
      (require 'eaf-vue-tailwindcss)
      (require 'eaf-demo)

      (require 'eaf-config)

      (message \"✅ EAF loaded successfully\"))
  (error (message \"❌ EAF failed to load: %s\" err)))

;; ============================================================================
;; XWIDGETS (WebKitGTK embedded browser)
;; Requires Emacs compiled with --with-xwidgets (snap build has this)
;; ============================================================================

(when (featurep 'xwidget-internal)
  ;; Use xwidget-webkit as the default browser inside Emacs
  (setq browse-url-browser-function #'xwidget-webkit-browse-url)

  ;; Kill the xwidget buffer when its window is closed
  (setq xwidget-webkit-buffer-name-format \"*xwidget: %T*\")

  (with-eval-after-load 'xwidget
    ;; j/k scroll like a browser
    (define-key xwidget-webkit-mode-map (kbd \"j\") #'xwidget-webkit-scroll-up-line)
    (define-key xwidget-webkit-mode-map (kbd \"k\") #'xwidget-webkit-scroll-down-line)
    (define-key xwidget-webkit-mode-map (kbd \"d\") #'xwidget-webkit-scroll-up)
    (define-key xwidget-webkit-mode-map (kbd \"u\") #'xwidget-webkit-scroll-down)
    (define-key xwidget-webkit-mode-map (kbd \"H\") #'xwidget-webkit-back)
    (define-key xwidget-webkit-mode-map (kbd \"L\") #'xwidget-webkit-forward)
    (define-key xwidget-webkit-mode-map (kbd \"r\") #'xwidget-webkit-reload)
    (define-key xwidget-webkit-mode-map (kbd \"o\") #'xwidget-webkit-browse-url)
    (define-key xwidget-webkit-mode-map (kbd \"y\") #'xwidget-webkit-copy-selection-as-kill))

  (global-set-key (kbd \"C-c x\") #'xwidget-webkit-browse-url)
  (message \"✅ xwidgets loaded\"))

;; ============================================================================
;; BASIC CONFIGURATION
;; ============================================================================

;; UI Configuration
(setq inhibit-startup-message t)
(tool-bar-mode -1)
(menu-bar-mode -1)
(scroll-bar-mode -1)
(global-display-line-numbers-mode 1)
(column-number-mode 1)
(show-paren-mode 1)
(electric-pair-mode 1)

;; Editor settings
(setq-default indent-tabs-mode nil
              tab-width 4
              python-indent-offset 4
              fill-column 88)

;; Better defaults
(setq make-backup-files nil
      auto-save-default nil
      ring-bell-function 'ignore
      gc-cons-threshold 100000000
      read-process-output-max (* 1024 1024))

;; ============================================================================
;; THEMES AND UI
;; ============================================================================

(use-package doom-themes
  :config
  (setq doom-themes-enable-bold t
        doom-themes-enable-italic t)
  (load-theme 'doom-one t)
  (doom-themes-visual-bell-config)
  (doom-themes-org-config))

(use-package doom-modeline
  :hook (after-init . doom-modeline-mode)
  :config
  (setq doom-modeline-height 25
        doom-modeline-icon t
        doom-modeline-major-mode-icon t
        doom-modeline-minor-modes nil))

(use-package all-the-icons)

;; Dashboard
(use-package dashboard
  :after all-the-icons
  :config
  (dashboard-setup-startup-hook)
  (setq dashboard-startup-banner 'official
        dashboard-center-content t
        dashboard-banner-logo-title "🚀 Welcome to Emacs - AI Development Environment! 🚀"
        dashboard-show-shortcuts nil
        dashboard-items '((recents  . 10)
                         (bookmarks . 5)
                         (projects . 10)
                         (agenda . 5)
                         (registers . 5))
        dashboard-item-names '(("Recent Files:" . "📁 Recent Files:")
                              ("Projects:" . "🗂️  Projects:")
                              ("Bookmarks:" . "🔖 Bookmarks:")
                              ("Agenda for today:" . "📅 Today's Agenda:")
                              ("Registers:" . "📋 Registers:"))
        dashboard-set-heading-icons t
        dashboard-set-file-icons t
        dashboard-set-navigator t)
  ;; Set up navigator buttons only if all-the-icons is available
  (when (and (display-graphic-p) (require 'all-the-icons nil t))
    (setq dashboard-navigator-buttons
          `(((,(all-the-icons-octicon "mark-github" :height 1.1 :v-adjust 0.0)
             "GitHub"
             "Browse GitHub"
             (lambda (&rest _) (browse-url "https://github.com")))
            (,(all-the-icons-octicon "book" :height 1.1 :v-adjust 0.0)
             "Documentation" 
             "Read the manual"
             (lambda (&rest _) (info-emacs-manual)))
            (,(all-the-icons-material "settings" :height 1.1 :v-adjust 0.0)
             "Settings"
             "Open configuration"
             (lambda (&rest _) (find-file user-init-file)))))))
  :custom
  (initial-buffer-choice (lambda () (get-buffer-create "*dashboard*"))))

(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

;; ============================================================================
;; COMPLETION AND NAVIGATION
;; ============================================================================

(use-package ivy
  :diminish
  :bind ((\"C-s\" . swiper)
         :map ivy-minibuffer-map
         (\"TAB\" . ivy-alt-done)
         (\"C-l\" . ivy-alt-done)
         (\"C-j\" . ivy-next-line)
         (\"C-k\" . ivy-previous-line)
         :map ivy-switch-buffer-map
         (\"C-k\" . ivy-previous-line)
         (\"C-l\" . ivy-done)
         (\"C-d\" . ivy-switch-buffer-kill)
         (\"C-S-d\" . ivy-switch-buffer-other-window)
         :map ivy-reverse-i-search-map
         (\"C-k\" . ivy-previous-line)
         (\"C-d\" . ivy-reverse-i-search-kill))
  :config
  (setq ivy-use-virtual-buffers t
        ivy-count-format \"%d/%d \")
  (ivy-mode 1))

(use-package counsel
  :bind ((\"M-x\" . counsel-M-x)
         (\"C-x b\" . ivy-switch-buffer)
         (\"C-x C-b\" . counsel-ibuffer)
         (\"C-x C-f\" . counsel-find-file)
         :map minibuffer-local-map
         (\"C-r\" . 'counsel-minibuffer-history))
  :config
  (setq ivy-initial-inputs-alist nil))

(use-package which-key
  :init (which-key-mode)
  :diminish which-key-mode
  :config
  (setq which-key-idle-delay 1))

;; Smex: M-x sorting by frequency/recency (used by counsel-M-x when present)
(use-package smex
  :after counsel
  :config
  (setq smex-save-file (expand-file-name \"~/.emacs.d/.smex-items\"))
  (smex-initialize))

(use-package company
  :init (global-company-mode)
  :bind (:map company-active-map
         (\"<tab>\" . company-complete-selection)
         (\"C-n\" . company-select-next)
         (\"C-p\" . company-select-previous))
        (:map company-mode-map
         (\"<tab>\" . company-indent-or-complete-common))
  :custom
  (company-minimum-prefix-length 1)
  (company-idle-delay 0.1)
  (company-tooltip-align-annotations t)
  (company-selection-wrap-around t)
  :config
  ;; Enable company in scratch buffer and other lisp modes
  (add-hook 'lisp-interaction-mode-hook 'company-mode)
  (add-hook 'emacs-lisp-mode-hook 'company-mode)
  
  ;; Use company-capf for Emacs Lisp completion (replaces deprecated company-elisp)
  ;; company-capf uses completion-at-point-functions which works better with elisp-mode
  
  ;; Configure company for scratch buffer specifically
  (defun setup-scratch-completion ()
    \"Set up enhanced completion for scratch buffer.\"
    (when (string= (buffer-name) \"*scratch*\")
      (company-mode 1)
      (setq-local company-backends 
                  '((company-capf company-dabbrev-code company-keywords)
                    company-dabbrev))))
  
  (add-hook 'lisp-interaction-mode-hook 'setup-scratch-completion))

;; ============================================================================
;; VERSION CONTROL
;; ============================================================================

(use-package magit
  :bind (\"C-x g\" . magit-status)
  :config
  (setq magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1))

(use-package git-gutter
  :hook (prog-mode . git-gutter-mode)
  :config
  (setq git-gutter:update-interval 0.02))

;; ============================================================================
;; PROJECT MANAGEMENT
;; ============================================================================

(use-package projectile
  :diminish projectile-mode
  :config (projectile-mode)
  :custom ((projectile-completion-system 'ivy))
  :bind-keymap
  (\"C-c p\" . projectile-command-map)
  :init
  (when (file-directory-p \"~/Development\")
    (setq projectile-project-search-path '(\"~/Development\")))
  (setq projectile-switch-project-action #'projectile-dired))

(use-package counsel-projectile
  :config (counsel-projectile-mode))

;; ============================================================================
;; PROGRAMMING LANGUAGES
;; ============================================================================

;; LSP Configuration
(use-package lsp-mode
  :init
  (setq lsp-keymap-prefix \"C-c l\")
  :hook (;; replace XXX-mode with concrete major-mode(e. g. python-mode)
         (python-mode . lsp)
         (lsp-mode . lsp-enable-which-key-integration))
  :commands lsp
  :config
  (setq lsp-prefer-flymake nil
        lsp-enable-snippet t
        lsp-enable-symbol-highlighting t
        lsp-enable-links t
        lsp-signature-auto-activate t
        lsp-signature-render-documentation t))

(use-package lsp-ui
  :hook (lsp-mode . lsp-ui-mode)
  :custom
  (lsp-ui-doc-position 'bottom))

(use-package lsp-ivy :commands lsp-ivy-workspace-symbol)

;; Python Configuration
(use-package python-mode
  :ensure nil
  :hook (python-mode . lsp-deferred)
  :custom
  (python-shell-interpreter \"python3\")
  (python-shell-interpreter-args \"-i\"))

(use-package pyvenv
  :config
  (pyvenv-mode 1)
  ;; Activate AI environment by default
  (pyvenv-activate \"/home/ebrimasaye/Development/AI/ai-venv\"))

(use-package blacken
  :hook (python-mode . blacken-mode)
  :config
  (setq blacken-line-length 88))

(use-package py-isort
  :hook (python-mode . py-isort-before-save))

(use-package julia-mode
  :ensure t)

(use-package lsp-pyright
  :ensure t
  :custom (lsp-pyright-langserver-command \"pyright\") ;; or basedpyright
  :hook (python-mode . (lambda ()
                          (require 'lsp-pyright)
                          (lsp))))  ; or lsp-deferred

;; ============================================================================
;; AI/ML SPECIFIC PACKAGES
;; ============================================================================

;; Jupyter integration
(condition-case err
    (use-package jupyter
      :config
      (setq jupyter-eval-use-overlays t))
  (error (message \"⚠️ Jupyter package failed to load: %s\" err)))

(use-package ein
  :config
  (setq ein:output-area-inlined-images t))

;; Basic org configuration (babel languages configured in org-config.el)
(use-package org
  :ensure nil)

;; ============================================================================
;; AI CODING ASSISTANTS
;; ============================================================================

;; GitHub Copilot Configuration
;; Note: Requires Node.js 20.x or later for the language server
(when (file-directory-p \"~/.emacs.d/copilot\")
  (condition-case err
      (progn
        (add-to-list 'load-path \"~/.emacs.d/copilot\")
        (require 'copilot)
        
        ;; Check Node.js version and provide helpful message
        (let ((node-version (shell-command-to-string \"node --version 2>/dev/null\")))
          (if (string-match \"v\\\\([0-9]+\\\\)\" node-version)
              (let ((version-number (string-to-number (match-string 1 node-version))))
                (if (>= version-number 20)
                    (progn
                      ;; Enhanced language server configuration
                      (setq copilot-node-executable \"node\")
                      
                      ;; Set the path to the language server executable
                      (setq copilot-language-server-executable 
                            (expand-file-name \"~/.local/node_modules/@github/copilot-language-server/native/linux-x64/copilot-language-server\"))
                      
                      ;; Advanced language server settings
                      (setq copilot-lsp-settings
                            '(:github-enterprise (:uri \"\")
                              :completion (:maxCompletions 5
                                         :debounceMs 75
                                         :enableAutoTrigger t
                                         :enablePartialAccept t
                                         :contextLines 50)
                              :ai (:temperature 0.3
                                 :maxTokens 2048
                                 :enableMultilineCompletions t
                                 :streamingEnabled t
                                 :cacheEnabled t)
                              :performance (:maxMemoryMB 512
                                          :enableIncrementalParsing t
                                          :enableBackgroundIndexing t)
                              :security (:enableTelemetry nil
                                       :enableCrashReporting nil)))
                      
                      ;; Enhanced Copilot settings for better performance
                      (setq copilot-idle-delay 0.1)  ; Faster response time
                      (setq copilot-max-char 1000000)  ; Larger context window
                      (setq copilot-completion-auto-accept nil)  ; Manual acceptance
                      
                      ;; Enable debug logging if needed
                      (setq copilot-log-max 1000)  ; Keep more logs for debugging
                      
                      ;; FIXED: Only use supported arguments (--stdio only)
                      (setq copilot-server-args '(\"--stdio\"))
                      
                      ;; Enable copilot in programming modes (start disabled, enable manually)
                      ;; (add-hook 'prog-mode-hook 'copilot-mode)
                      
                      ;; Set up keybindings
                      (define-key copilot-completion-map (kbd \"<tab>\") 'copilot-accept-completion)
                      (define-key copilot-completion-map (kbd \"TAB\") 'copilot-accept-completion)
                      (define-key copilot-completion-map (kbd \"C-TAB\") 'copilot-accept-completion-by-word)
                      (define-key copilot-completion-map (kbd \"C-<tab>\") 'copilot-accept-completion-by-word)
                      
                      ;; Manual activation keybinding
                      (global-set-key (kbd \"C-c C-p\") 'copilot-mode)
                      
                      ;; Optional: Set up additional keybindings
                      (define-key copilot-mode-map (kbd \"M-C-<return>\") 'copilot-accept-completion)
                      (define-key copilot-mode-map (kbd \"M-C-<right>\") 'copilot-accept-completion-by-word)
                      (define-key copilot-mode-map (kbd \"M-C-<down>\") 'copilot-next-completion)
                      (define-key copilot-mode-map (kbd \"M-C-<up>\") 'copilot-previous-completion)
                      
                      (message \"✅ GitHub Copilot available - Use C-c C-p to enable in buffer\"))
                  (message \"⚠️ Copilot requires Node.js 20+. Current: %s. Use 'C-c C-p' to try anyway.\" node-version)))
            (message \"⚠️ Node.js not found. Install Node.js 20+ for Copilot support.\")))
        
        ;; Always set up the manual toggle function
        (defun copilot-toggle ()
          \"Toggle Copilot mode in the current buffer.\"
          (interactive)
          (if copilot-mode
              (progn
                (copilot-mode -1)
                (message \"Copilot disabled\"))
            (progn
              (copilot-mode 1)
              (message \"Copilot enabled\"))))
        
        (global-set-key (kbd \"C-c C-p\") 'copilot-toggle))
    (error (message \"❌ Copilot not available: %s\" err))))

;; ChatGPT integration
(use-package chatgpt-shell
  :config
  (setq chatgpt-shell-openai-key
        (lambda ()
          (auth-source-pass-get 'secret \"openai-key\"))))

;; Gptel
(use-package gptel)
(gptel-make-anthropic \"Claude\" :stream t :key gptel-api-key)
(gptel-make-deepseek \"DeepSeek\"       ;Any name you want
  :stream t                           ;for streaming responses
  :key \"your-api-key\")               ;can be a function that returns the key

;; OPTIONAL configuration
(setq
 gptel-model 'llama4:latest
 gptel-backend (gptel-make-ollama \"Ollama\"
                 :host \"localhost:11434\"
                 :stream t
                 :models '(llama4:latest)))

(gptel-make-gh-copilot \"Copilot\")

(use-package agent-shell
    :ensure t
    :ensure-system-package
    ((claude . \"npm install -g @anthropic-ai/claude-code\")
     (claude-agent-acp . \"npm install -g @zed-industries/claude-agent-acp\")))

;; ============================================================================
;; TERMINAL AND SHELL
;; ============================================================================

(use-package vterm
  :config
  (setq vterm-shell \"/bin/zsh\"))

(use-package multi-vterm
  :config
  (add-hook 'vterm-mode-hook
            (lambda ()
              (setq-local evil-insert-state-cursor 'box)
              (evil-insert-state)))
  :bind
  ((\"C-c v\" . multi-vterm-dedicated-toggle)))

;; ============================================================================
;; FLYCHECK AND ERROR CHECKING
;; ============================================================================

(use-package flycheck
  :init (global-flycheck-mode)
  :config
  (setq flycheck-python-flake8-executable \"flake8\"
        flycheck-python-pylint-executable \"pylint\"
        flycheck-python-mypy-executable \"mypy\"))

;; ============================================================================
;; LISPY - ENHANCED LISP EDITING
;; ============================================================================

(use-package lispy
  :ensure t
  :defer t
  :hook ((emacs-lisp-mode . lispy-mode)
         (lisp-interaction-mode . lispy-mode)
         (lisp-mode . lispy-mode)
         (scheme-mode . lispy-mode))
  :config
  ;; Basic settings
  (setq lispy-compat '(edebug cider)
        lispy-close-quotes-at-end-p t
        lispy-eval-display-style 'overlay
        lispy-no-space nil)
  
  (message \"✅ Lispy mode loaded\"))

;; ============================================================================
;; HELPFUL PACKAGES
;; ============================================================================

(use-package helpful
  :bind
  ([remap describe-function] . helpful-function)
  ([remap describe-symbol] . helpful-symbol)
  ([remap describe-variable] . helpful-variable)
  ([remap describe-command] . helpful-command)
  ([remap describe-key] . helpful-key))

(use-package expand-region
  :bind (\"C-=\" . er/expand-region))

(use-package multiple-cursors
  :bind ((\"C->\" . mc/mark-next-like-this)
         (\"C-<\" . mc/mark-previous-like-this)
         (\"C-c C-<\" . mc/mark-all-like-this)))

;; ============================================================================
;; BROWSER INTEGRATION
;; ============================================================================

;; Load browser configuration (optional)
(condition-case nil
    (require 'browser-config)
  (error (message \"Browser config not loaded - some features may be unavailable\")))

;; Load comprehensive Org mode configuration
(condition-case nil
    (progn
      (require 'org-config)
      (message \"✅ Org mode configuration loaded successfully\"))
  (error (message \"❌ Failed to load org-config - some Org features may be unavailable\")))

;; Load yt-dlp integration
(condition-case nil
    (progn
      (require 'yt-dlp-config)
      (yt-dlp-setup)
      (message \"✅ yt-dlp integration loaded successfully\"))
  (error (message \"❌ Failed to load yt-dlp-config - media download features may be unavailable\")))

;; Load lambda symbol configuration for Lisp programming
(condition-case err
    (progn
      (require 'lambda-symbol-config-simple)
      (message \"✅ Lambda symbol configuration loaded - Use C-c L h for help\"))
  (error (message \"❌ Failed to load lambda-symbol-config: %s\" err)))

;; Load enhanced Lispy configuration (only if lispy is installed)
(with-eval-after-load 'lispy
  (condition-case err
      (progn
        (require 'lispy-enhanced-config)
        (message \"✅ Lispy enhanced configuration loaded - Use C-c l h for help\"))
    (error (message \"❌ Failed to load lispy-enhanced-config: %s\" err))))

;; ============================================================================
;; SCRATCH BUFFER ENHANCEMENTS
;; ============================================================================

;; Enhance scratch buffer with better default content and completion
(defun enhanced-scratch-buffer ()
  \"Create or switch to an enhanced scratch buffer with helpful content.\"
  (interactive)
  (let ((scratch-buffer (get-buffer-create \"*scratch*\")))
    (with-current-buffer scratch-buffer
      (lisp-interaction-mode)
      (when (zerop (buffer-size))
        (insert \";; Welcome to the Enhanced Emacs Scratch Buffer!
;; This buffer is for Emacs Lisp evaluation and experimentation.
;; 
;; Useful keybindings:
;; C-x C-e  : Evaluate expression before point
;; C-j      : Evaluate expression and insert result
;; M-TAB    : Complete symbol at point
;; TAB      : Company completion (if available)
;;
;; Try some examples:
;; (+ 2 3)
;; (current-time-string)
;; (buffer-list)
;; (apropos \\\"company\\\")

\"))
      (company-mode 1)
      (goto-char (point-max)))
    (switch-to-buffer scratch-buffer)))

;; Add keybinding for enhanced scratch buffer
(global-set-key (kbd \"C-c s\") 'enhanced-scratch-buffer)

;; Make scratch buffer persistent
(defun save-scratch-buffer ()
  \"Save the scratch buffer content to a file.\"
  (interactive)
  (with-current-buffer \"*scratch*\"
    (write-file (expand-file-name \"scratch-backup.el\" user-emacs-directory))
    (rename-buffer \"*scratch*\" t)
    (lisp-interaction-mode)
    (message \"Scratch buffer saved to ~/.emacs.d/scratch-backup.el\")))

(global-set-key (kbd \"C-c S\") 'save-scratch-buffer)

;; Auto-load scratch backup on startup if it exists
(defun load-scratch-backup ()
  \"Load scratch buffer backup if it exists.\"
  (let ((scratch-file (expand-file-name \"scratch-backup.el\" user-emacs-directory)))
    (when (file-exists-p scratch-file)
      (with-current-buffer (get-buffer-create \"*scratch*\")
        (insert-file-contents scratch-file)
        (lisp-interaction-mode)
        (company-mode 1)))))

(add-hook 'emacs-startup-hook 'load-scratch-backup)

;; ============================================================================
;; CUSTOM FUNCTIONS FOR AI DEVELOPMENT
;; ============================================================================

(defun ai-run-chatbot ()
  \"Run the AI chatbot example.\"
  (interactive)
  (let ((default-directory \"/home/ebrimasaye/Development/AI/\"))
    (async-shell-command \"source ai-venv/bin/activate && python examples/llm/first_chatbot.py\")))

(defun ai-run-object-detection ()
  \"Run the object detection demo.\"
  (interactive)
  (let ((default-directory \"/home/ebrimasaye/Development/AI/\"))
    (async-shell-command \"source ai-venv/bin/activate && python examples/vision/object_detection.py --demo\")))

(defun ai-run-speech-recognition ()
  \"Run the speech recognition demo.\"
  (interactive)
  (let ((default-directory \"/home/ebrimasaye/Development/AI/\"))
    (async-shell-command \"source ai-venv/bin/activate && python examples/audio/speech_to_text.py --demo\")))

(defun ai-start-jupyter ()
  \"Start Jupyter Lab server.\"
  (interactive)
  (let ((default-directory \"/home/ebrimasaye/Development/AI/\"))
    (async-shell-command \"source ai-venv/bin/activate && jupyter lab --no-browser\")))

(defun ai-start-ollama ()
  \"Start Ollama service.\"
  (interactive)
  (async-shell-command \"ollama serve\"))

(defun ai-activate-env ()
  \"Activate the AI virtual environment.\"
  (interactive)
  (pyvenv-activate \"/home/ebrimasaye/Development/AI/ai-venv\")
  (message \"AI environment activated\"))

;; ============================================================================
;; KEY BINDINGS
;; ============================================================================

;; AI Development Keybindings (using C-c A prefix to avoid org-agenda conflict)
(global-set-key (kbd \"C-c A c\") 'ai-run-chatbot)
(global-set-key (kbd \"C-c A v\") 'ai-run-object-detection)
(global-set-key (kbd \"C-c A s\") 'ai-run-speech-recognition)
(global-set-key (kbd \"C-c A j\") 'ai-start-jupyter)
(global-set-key (kbd \"C-c A o\") 'ai-start-ollama)
(global-set-key (kbd \"C-c A e\") 'ai-activate-env)

;; Enhanced Buffer Navigation Keybindings
(global-set-key (kbd \"M-o\") 'ivy-switch-buffer)         ; Quick buffer switch
(global-set-key (kbd \"C-x C-r\") 'counsel-recentf)       ; Recent files
(global-set-key (kbd \"C-c B k\") 'kill-current-buffer)   ; Kill current buffer
(global-set-key (kbd \"C-c B n\") 'next-buffer)          ; Next buffer
(global-set-key (kbd \"C-c B p\") 'previous-buffer)      ; Previous buffer
(global-set-key (kbd \"C-c B s\") 'save-buffer)          ; Save buffer

;; ============================================================================
;; CUSTOM VARIABLES
;; ============================================================================

(custom-set-variables
 '(bongo-enabled-backends '(mpg123 vlc mpv ogg123 timidity afplay))
 '(custom-safe-themes
   '(\"4594d6b9753691142f02e67b8eb0fda7d12f6cc9f1299a49b819312d6addad1d\" \"3613617b9953c22fe46ef2b593a2e5bc79ef3cc88770602e7e569bbd71de113b\" \"8d3ef5ff6273f2a552152c7febc40eabca26bae05bd12bc85062e2dc224cde9a\" \"6963de2ec3f8313bb95505f96bf0cf2025e7b07cefdb93e3d2e348720d401425\" \"9b9d7a851a8e26f294e778e02c8df25c8a3b15170e6f9fd6965ac5f2544ef2a9\" \"720838034f1dd3b3da66f6bd4d053ee67c93a747b219d1c546c41c4e425daf93\" \"fffef514346b2a43900e1c7ea2bc7d84cbdd4aa66c1b51946aade4b8d343b55a\" \"aec7b55f2a13307a55517fdf08438863d694550565dee23181d2ebd973ebd6b8\" \"7de64ff2bb2f94d7679a7e9019e23c3bf1a6a04ba54341c36e7cf2d2e56e2bcc\" default))
 '(life-calendar-birthday \"1967-09-09\")
 '(send-mail-function 'mailclient-send-it)
 '(smtpmail-smtp-server \"smtp.gmail.com\")
 '(smtpmail-smtp-service 25)
 '(warning-suppress-log-types '((native-compiler) (gptel) (emacs) ((tar link)) (comp)))
 '(warning-suppress-types
   '((native-compiler)
     (native-compiler)
     (native-compiler)
     (tramp)
     (emacs))))

(custom-set-faces
 ;; Custom faces managed by Emacs
 )

;; ============================================================================
;; STARTUP ACTIONS
;; ============================================================================

(add-hook 'emacs-startup-hook
          (lambda ()
            (message \"🤖 AI Development Environment ready!\")
            (message \"📚 Scratch buffer autocompletion enabled - Press C-c s for enhanced scratch buffer\")
            (message \"📖 Documentation: ~/.emacs.d/SCRATCH_BUFFER_AUTOCOMPLETION.md\")
            (when (file-exists-p \"/home/ebrimasaye/Development/AI/\")
              (find-file \"/home/ebrimasaye/Development/AI/README.md\"))))

;;; init.el ends here
