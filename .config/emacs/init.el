;;; init.el --- Personal Emacs configuration -*- lexical-binding: t; -*-

;;;; Package management

(require 'package)
(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("gnu"   . "https://elpa.gnu.org/packages/")))
(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))
(unless (package-installed-p 'use-package)
  (package-install 'use-package))
(require 'use-package)
(setq use-package-always-ensure t)

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(load custom-file)

;;;; Performance

(setq gc-cons-threshold 100000000)
(setq read-process-output-max (* 1024 1024))

;;;; Core

(menu-bar-mode 0)
(setq make-backup-files nil)
(setq auto-save-default nil)
(setq create-lockfiles nil)
(setq inhibit-startup-screen t)
(setq ring-bell-function 'ignore)
(setq gdb-many-windows t)

(setq display-line-numbers-type 'relative)
(global-display-line-numbers-mode 1)

(setq-default indent-tabs-mode nil)
(setq-default tab-width 2)
(setq-default sh-basic-offset 2)

(setq compilation-scroll-output 'first-error)
(setq compilation-ask-about-save nil)
(add-hook 'compilation-filter-hook 'ansi-color-compilation-filter)
(keymap-global-set "C-c c"   'compile)

(windmove-default-keybindings)
(savehist-mode 1)
(save-place-mode 1)
(recentf-mode 1)
(global-auto-revert-mode 1)
(repeat-mode 1)
(electric-pair-mode 1)

(load-theme 'modus-vivendi)

(with-eval-after-load 'dired
  (define-key dired-mode-map (kbd "%") 'dired-create-empty-file))

;;;; Treesitter

(setq treesit-language-source-alist
      '((cpp "https://github.com/tree-sitter/tree-sitter-cpp" "v0.22.3")
        (c   "https://github.com/tree-sitter/tree-sitter-c"   "v0.23.6")
        (java "https://github.com/tree-sitter/tree-sitter-java" "v0.23.5")
        (javascript "https://github.com/tree-sitter/tree-sitter-javascript" "v0.23.1")
        (typescript "https://github.com/tree-sitter/tree-sitter-typescript" "v0.23.2" "typescript/src")
        (tsx "https://github.com/tree-sitter/tree-sitter-typescript" "v0.23.2" "tsx/src")))

(setq major-mode-remap-alist
      '((c-mode . c-ts-mode)
        (c++-mode . c++-ts-mode)
        (c-or-c++-mode . c-or-c++-ts-mode)
        (java-mode . java-ts-mode)
        (typescript-mode . typescript-ts-mode)))

(defun cpp-declaration-from-declarator-node (func-declarator-node)
  "Walk up the tree from FUNC-DECLARATOR-NODE to find the enclosing declaration."
  (let ((node func-declarator-node))
    (while (and (not (string-equal "field_declaration"  (treesit-node-type node)))
                (not (string-equal "declaration"        (treesit-node-type node)))
                (not (string-equal "function_definition" (treesit-node-type node))))
      (setq node (treesit-node-parent node)))
    node))

(defun cpp-declaration-extract-return-type (func-declaration-node func-declarator-node)
  "Extract the return type from FUNC-DECLARATION-NODE up to FUNC-DECLARATOR-NODE."
  (let* ((start    (treesit-node-start func-declaration-node))
         (end      (treesit-node-start func-declarator-node))
         (raw-text (buffer-substring-no-properties start end)))
    (replace-regexp-in-string
     "\\b\\(virtual\\|static\\|explicit\\|friend\\)\\b" "" raw-text)))

(defun cpp-identifier-convert-at-point ()
  "Yank a function definition stub from the declarator at point."
  (interactive)
  (let* ((identifier-node     (treesit-node-at (point) 'cpp))
         (func-declarator-node (treesit-parent-until
                                identifier-node
                                (lambda (n) (string-equal "function_declarator"
                                                          (treesit-node-type n)))))
         (func-declarator      (treesit-node-text func-declarator-node))
         (func-identifier      (treesit-node-text (treesit-node-child func-declarator-node 0))))
    (if (string-equal "function_declarator" (treesit-node-type func-declarator-node))
        (let* ((func-declaration-node (cpp-declaration-from-declarator-node func-declarator-node))
               (return-type    (cpp-declaration-extract-return-type func-declaration-node func-declarator-node))
               (context-stack  '())
               (template-stack '())
               (current-node   func-declaration-node))
          (while current-node
            (cond
             ((string-equal "template_declaration" (treesit-node-type current-node))
              (let* ((params-node  (treesit-node-child-by-field-name current-node "parameters"))
                     (params       (treesit-node-text params-node))
                     (constraint-node (treesit-search-subtree
                                       current-node
                                       (lambda (n) (string-equal "requires_clause" (treesit-node-type n)))
                                       t nil 1))
                     (constraint   (if constraint-node
                                       (concat (treesit-node-text constraint-node) "\n") "")))
                (push (concat "template " params "\n" constraint) template-stack)))
             ((string-equal "class_specifier" (treesit-node-type current-node))
              (push (concat (treesit-node-text
                             (treesit-node-child-by-field-name current-node "name")) "::")
                    context-stack))
             ((string-equal "struct_specifier" (treesit-node-type current-node))
              (push (concat (treesit-node-text
                             (treesit-node-child-by-field-name current-node "name")) "::")
                    context-stack))
             ((string-equal "namespace_definition" (treesit-node-type current-node))
              (push (concat (treesit-node-text
                             (treesit-node-child-by-field-name current-node "name")) "::")
                    context-stack)))
            (setq current-node (treesit-node-parent current-node)))
          (kill-new (concat (mapconcat #'identity template-stack "")
                            return-type
                            (mapconcat #'identity context-stack "")
                            func-declarator
                            "\n{\n\t\n}"))
          (message "%s's function definition is yanked." func-identifier))
      (message "[%s] is NOT a function declarator" func-declarator))))

(with-eval-after-load 'c++-ts-mode
  (define-key c++-ts-mode-map (kbd "C-c d") 'cpp-identifier-convert-at-point))

;;;; Vendor

(use-package glsl-mode)
(use-package markdown-mode)
(use-package cmake-mode)

(use-package which-key :config (which-key-mode))
(use-package hl-todo :config (global-hl-todo-mode))
(use-package xclip :config (xclip-mode))
(use-package evil-surround :after evil :config (global-evil-surround-mode 1))
(use-package vertico :ensure t :init (vertico-mode 1))
(use-package marginalia :ensure t :init (marginalia-mode 1))
(use-package workgroups2 :ensure t :init (setq wg-session-file (expand-file-name ".emacs_workgroups" user-emacs-directory)))

(use-package magit :bind ("C-x g" . magit-status))
(use-package move-text :bind (("M-u" . move-text-up) ("M-d" . move-text-down)))

(use-package helpful
  :bind (("C-h f" . helpful-callable)
         ("C-h v" . helpful-variable)
         ("C-h k" . helpful-key)))

(use-package yasnippet
  :config
  (setq yas-snippet-dirs (list (expand-file-name "snippets" user-emacs-directory)))
  (setq yas-triggers-in-field nil)
  (yas-global-mode))

(use-package java-imports
  :defer t
  :hook (java-mode . java-imports-scan-file)
  :bind (:map java-mode-map ("C-c i" . java-imports-add-import-dwim)))

(use-package lorem-ipsum
  :bind (("C-c l p" . lorem-ipsum-insert-paragraphs)
         ("C-c l s" . lorem-ipsum-insert-sentences)
         ("C-c l l" . lorem-ipsum-insert-list)))

(use-package emmet-mode
  :ensure t
  :hook ((prog-mode . emmet-mode))
  :bind (:map emmet-mode-keymap ("C-j" . emmet-expand-line)))

(use-package projectile
  :ensure t
  :config
  (projectile-mode +1)
  (setq projectile-project-search-path '("/home/horki/projects/"))
  (setq projectile-switch-project-action  #'projectile-find-file)
  (setq projectile-enable-caching t)
  (projectile-discover-projects-in-search-path)
  :bind-keymap ("C-c p" . projectile-command-map))

(use-package company
  :ensure t
  :config
  (setq company-idle-delay 0.1)
  (setq company-require-match nil)
  (setq company-dabbrev-downcase nil)
  (setq company-dabbrev-code-downcase nil)
  (setq company-backends
        '((company-capf company-dabbrev-code company-keywords company-files)
          company-dabbrev))
  (setq company-global-modes '(not magit-status-mode
                                   magit-log-mode
                                   magit-diff-mode
                                   magit-revision-mode
                                   magit-process-mode
                                   git-commit-mode))
  (global-company-mode 1)
  (define-key company-active-map (kbd "RET") nil))

(use-package evil
  :ensure t
  :config
  (evil-mode 1)
  (evil-set-initial-state 'magit-status-mode 'emacs)
  (evil-set-undo-system 'undo-tree))

(use-package eglot
  :ensure t
  :hook (prog-mode . eglot-ensure)
  :config
  (add-to-list 'eglot-server-programs
               '((c-mode c++-mode c-ts-mode c++-ts-mode)
                 . ("clangd"
                    "--query-driver=**/**arm-none-eabi-g*"
                    "--background-index"
                    "--header-insertion=iwyu")))
  :bind (:map eglot-mode-map
              ("C-c r" . eglot-rename)
              ("C-c a" . eglot-code-actions)))

(use-package undo-tree
  :ensure t
  :init
  (global-undo-tree-mode)
  :config
  (setq undo-tree-auto-save-history nil))

(use-package consult
  :ensure t
  :bind (("C-s" . consult-line)
         ;; C-c bindings in `mode-specific-map'
         ("C-c h" . consult-history)
         ("C-c k" . consult-kmacro)
         ;; C-x bindings in `ctl-x-map'
         ("C-x b" . consult-buffer)
         ;; M-g bindings in `goto-map'
         ("M-g e" . consult-compile-error)
         ("M-g r" . consult-grep-match)
         ("M-g i" . consult-imenu)
         ("M-g g" . consult-goto-line)
         ;; M-s bindings in `search-map'
         ("M-s d" . consult-find)                
         ("M-s c" . consult-locate)
         ("M-s g" . consult-grep)
         ("M-s G" . consult-git-grep)
         ("M-s r" . consult-ripgrep)
         ("M-s l" . consult-line)
         ("M-s L" . consult-line-multi)
         ("M-s k" . consult-keep-lines)
         ("M-s u" . consult-focus-lines))
  :init
  (advice-add #'register-preview :override #'consult-register-window)
  (setq register-preview-delay 0.5)

  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref))

(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles partial-completion))))
  (completion-pcm-leading-wildcard t))

;;;; tasks.el
;;; My version of VS Code's tasks.json. Tasks are defined per-project in .dir-locals.el
;;;
;;; The task protocol is:
;;;   "shell cmd"             => (implicit) compile shell command (default)
;;;   (:compile "cmd")        => (explicit) compile shell command (default)
;;;   (:service "name" "cmd") => indefinite process in buffer *name - root*
;;;   (:elisp FUNCTION)       => call an emacs lisp function
;;;   (:chain "t1" "t2" ...)  => run named tasks in order, stop on fail

(defgroup tasks nil
  "Project-task runner via dir-locals."
  :group 'tools
  :prefix "tasks/")

(defcustom tasks/service-kill-delay 0.2
  "Seconds to wait after killing a service process before restarting it.
Gives the OS time to release any port/socket the old process had."
  :type 'number
  :group 'tasks)

(defvar-local tasks/root-dir nil
  "Project root directory; commands run here. ${root} expands it.
If nil, falls back to `project.el' detection, then `default-directory'.")
(defvar-local tasks/alist nil
  "Alist of (NAME . SPEC) defining this project's tasks.")
(defvar-local tasks/vars nil
  "Alist of (NAME . VALUE) for ${NAME} substitution in commands.
Values may themselves use ${root}.")

(put 'tasks/root-dir 'safe-local-variable #'stringp)
(put 'tasks/alist    'safe-local-variable #'listp)
(put 'tasks/vars     'safe-local-variable #'listp)

(defvar tasks/last nil
  "Name of the most recently run task (for `tasks/rerun').")

(defvar tasks/-chains (make-hash-table :test #'equal)
  "Active chains, keyed by project root directory (i.e., ${root} value).
Each value is a plist with keys :names :index :total :ctx :start :buf.")

(defvar tasks/-services (make-hash-table :test #'equal)
  "Service buffers we started, keyed by (ROOT . NAME) cons cells.")

(defun tasks/-current-root ()
  "Project root for the current buffer, normalized for use as a hash key.
Prefers an explicit `tasks/root-dir', then `project.el', then
`default-directory'.  Always returns an expanded path with a trailing
slash so that the same project produces `equal' keys from any buffer."
  (file-name-as-directory
   (expand-file-name
    (or tasks/root-dir
        (when-let ((proj (project-current)))
          (project-root proj))
        default-directory))))
 
(defun tasks/-subst (s vars)
  "Replace every ${NAME} in S using VARS; error on unknown names."
  (replace-regexp-in-string
   "\\${\\([^}]+\\)}"
   (lambda (match)
     (let ((key (substring match 2 -1)))
       (or (cdr (assoc key vars))
           (user-error "tasks: unknown variable ${%s}" key))))
   s t t))
 
(defun tasks/-expand (cmd ctx)
  "Expand ${root} and `tasks/vars' entries (from CTX) inside CMD."
  (let* ((root (plist-get ctx :root))
         (rootvar (list (cons "root" (directory-file-name root))))
         (vars (append (mapcar (lambda (kv)
                                 (cons (car kv) (tasks/-subst (cdr kv) rootvar)))
                               (plist-get ctx :vars))
                       rootvar)))
    (tasks/-subst cmd vars)))
 
(defun tasks/-compile (cmd root)
  "Run CMD with `compile', in a compilation buffer unique to ROOT.
Returns the compilation buffer, so chains can track which buffer
belongs to them even when several projects compile at once."
  (let ((compilation-buffer-name-function
         (lambda (_mode)
           (format "*compilation: %s*"
                   (abbreviate-file-name (directory-file-name root))))))
    (compile cmd)))
 
(defun tasks/run (&optional name)
  "Run a project task by NAME, prompting from `tasks/alist' if nil.
With a prefix argument, a :service task is restarted instead of reused."
  (interactive)
  (unless tasks/alist
    (user-error "tasks: none defined - set tasks/alist in .dir-locals.el"))
  (let* ((completion-extra-properties
          (list :annotation-function
                (lambda (n) (concat "  " (tasks/-describe
                                          (cdr (assoc n tasks/alist)))))))
         (name (or name (completing-read "Task: " (mapcar #'car tasks/alist)
                                         nil t)))
         (spec (or (cdr (assoc name tasks/alist))
                   (user-error "tasks: no task named %s" name)))
         (ctx (list :alist tasks/alist
                    :root (tasks/-current-root)
                    :vars tasks/vars)))
    (setq tasks/last name)
    (tasks/-dispatch spec ctx current-prefix-arg)))
 
(defun tasks/rerun ()
  "Re-run the most recent task without prompting."
  (interactive)
  (if tasks/last (tasks/run tasks/last) (call-interactively #'tasks/run)))
 
(defun tasks/abort ()
  "Abort the current project's running chain (and its active compilation)."
  (interactive)
  (let* ((root (tasks/-current-root))
         (st (gethash root tasks/-chains)))
    (if (not st)
        (message "tasks: no chain running in %s" (abbreviate-file-name root))
      (remhash root tasks/-chains)
      (when-let* ((buf (plist-get st :buf))
                  (proc (get-buffer-process buf)))
        (ignore-errors (interrupt-process proc)))
      (force-mode-line-update t)
      (message "tasks: chain aborted"))))
 
(defun tasks/edit ()
  "Open this project's .dir-locals.el, where tasks are defined."
  (interactive)
  (find-file (expand-file-name ".dir-locals.el" (tasks/-current-root))))
 
(defun tasks/list-services ()
  "Pick a running service buffer (across all projects) and pop to it.
Dead services are pruned from the table as a side effect."
  (interactive)
  (let (live stale)
    (maphash (lambda (key buf)
               (if (and (buffer-live-p buf)
                        (process-live-p (get-buffer-process buf)))
                   (push buf live)
                 (push key stale)))
             tasks/-services)
    (dolist (key stale) (remhash key tasks/-services))
    (if (null live)
        (message "tasks: no services running")
      (pop-to-buffer
       (completing-read "Service: " (mapcar #'buffer-name live) nil t)))))
 
(defun tasks/-describe (spec)
  "One-line description of SPEC for completion annotations."
  (pcase spec
    ((pred stringp)          spec)
    (`(:compile ,c)          c)
    (`(:service ,n ,c)       (format "service[%s] %s" n c))
    (`(:elisp ,_)            "elisp")
    (`(:chain . ,ns)         (format "chain: %s" (string-join ns " -> ")))
    (_                       "invalid spec")))
 
(defun tasks/-dispatch (spec ctx &optional restart)
  "Execute one task SPEC within project context CTX.
Internal; use `tasks/run' instead of calling this directly."
  (let ((root (plist-get ctx :root)))
    (let ((default-directory root))
      (pcase spec
        ((pred stringp)            (tasks/-compile (tasks/-expand spec ctx) root))
        (`(:compile ,cmd)          (tasks/-compile (tasks/-expand cmd ctx) root))
        (`(:service ,bufname ,cmd) (tasks/-service bufname
                                                   (tasks/-expand cmd ctx)
                                                   root restart))
        (`(:elisp ,fn)             (funcall fn))
        (`(:chain . ,names)        (tasks/-chain-start names ctx))
        (_ (user-error "tasks: bad spec %S" spec))))))
 
(defun tasks/-service (bufname cmd root restart)
  "Run CMD indefinitely in a buffer namespaced by BUFNAME and ROOT.
If already running: pop to it, unless RESTART (prefix arg) kills it first.
Internal; use `tasks/run' instead of calling this directly."
  (let* ((key (cons root bufname))
         (buf (format "*%s - %s*" bufname
                      (abbreviate-file-name (directory-file-name root))))
         (proc (get-buffer-process buf)))
    (cond
     ((and proc (process-live-p proc) (not restart))
      (pop-to-buffer buf)
      (message "tasks: %s already running - C-u C-c t to restart" bufname))
     (t
      (when (and proc (process-live-p proc))
        (kill-process proc)
        (sit-for tasks/service-kill-delay))
      (when (get-buffer buf) (kill-buffer buf))
      (async-shell-command cmd buf)
      (puthash key (get-buffer buf) tasks/-services)))))
 
(defun tasks/-flatten-chain (names alist seen)
  "Validate and flatten NAMES against ALIST; expand nested chains.
Errors early on undefined tasks, services in chains, and cycles (via SEEN)."
  (apply #'append
         (mapcar
          (lambda (n)
            (when (member n seen)
              (user-error "tasks: chain cycle through %s" n))
            (let ((spec (cdr (assoc n alist))))
              (pcase spec
                ('nil            (user-error "tasks: chain uses undefined task %s" n))
                (`(:chain . ,ns) (tasks/-flatten-chain ns alist (cons n seen)))
                (`(:service . ,_)
                 (user-error "tasks: service %s cannot be chained (it never finishes)" n))
                (_ (list n)))))
          names)))
 
(defun tasks/-chain-start (names ctx)
  "Begin executing NAMES sequentially for the project in CTX."
  (let ((root (plist-get ctx :root)))
    (when (gethash root tasks/-chains)
      (user-error "tasks: a chain is already running in %s - M-x tasks/abort first"
                  (abbreviate-file-name root)))
    (let ((flat (tasks/-flatten-chain names (plist-get ctx :alist) nil)))
      (puthash root
               (list :names flat :index 0 :total (length flat)
                     :ctx ctx :start (current-time) :buf nil)
               tasks/-chains)
      (tasks/-chain-step root))))
 
(defun tasks/-chain-step (root)
  "Run the next step of ROOT's chain, or finish it."
  (let* ((st (gethash root tasks/-chains))
         (names (plist-get st :names))
         (i (plist-get st :index)))
    (if (>= i (plist-get st :total))
        (progn
          (message "tasks: chain done in %.1fs"
                   (float-time (time-subtract (current-time)
                                              (plist-get st :start))))
          (remhash root tasks/-chains)
          (force-mode-line-update t))
      (let* ((name (nth i names))
             (ctx (plist-get st :ctx))
             (spec (cdr (assoc name (plist-get ctx :alist))))
             (default-directory root))
        (message "tasks: [%d/%d] %s" (1+ i) (plist-get st :total) name)
        (puthash root (plist-put st :index (1+ i)) tasks/-chains)
        (force-mode-line-update t)
        (pcase spec
          ((pred stringp)
           (puthash root
                    (plist-put (gethash root tasks/-chains) :buf
                               (tasks/-compile (tasks/-expand spec ctx) root))
                    tasks/-chains))
          (`(:compile ,cmd)
           (puthash root
                    (plist-put (gethash root tasks/-chains) :buf
                               (tasks/-compile (tasks/-expand cmd ctx) root))
                    tasks/-chains))
          (`(:elisp ,fn)
           (condition-case err
               (funcall fn)
             (error (remhash root tasks/-chains)
                    (force-mode-line-update t)
                    (signal (car err) (cdr err))))
           (tasks/-chain-step root)))))))
 
(defun tasks/-chain-advance (buffer status)
  "`compilation-finish-functions' hook: advance the chain owning BUFFER.
Looks up which project's chain started BUFFER; other compilations are
ignored.  On failure the owning chain is dropped."
  (let (owner)
    (maphash (lambda (root st)
               (when (eq (plist-get st :buf) buffer)
                 (setq owner root)))
             tasks/-chains)
    (when owner
      (if (string-prefix-p "finished" status)
          (tasks/-chain-step owner)
        (let ((st (gethash owner tasks/-chains)))
          (message "tasks: chain aborted - step %d/%d failed (%s)"
                   (plist-get st :index)
                   (plist-get st :total)
                   (string-trim status)))
        (remhash owner tasks/-chains)
        (force-mode-line-update t)))))
 
(defun tasks/-mode-line-string ()
  "Return \" [Task i/N]\" when this buffer's project has a running chain."
  (if-let* ((st (and tasks-mode
                     (gethash (tasks/-current-root) tasks/-chains))))
      (format " [Task %d/%d]"
              (plist-get st :index) (plist-get st :total))
    ""))
 
(defvar tasks/-mode-line '(:eval (tasks/-mode-line-string))
  "Mode-line construct showing chain progress for the current project.")
(put 'tasks/-mode-line 'risky-local-variable t)
 
(defvar tasks-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c t") #'tasks/run)
    (define-key map (kbd "C-c T") #'tasks/rerun)
    map)
  "Keymap for `tasks-mode'.")
 
;;;###autoload
(define-minor-mode tasks-mode
  "Global minor mode for running project tasks defined via dir-locals.
Enables the `C-c t' / `C-c T' bindings, hooks chain advancement into
`compilation-finish-functions', and shows chain progress in the mode line."
  :global t
  :keymap tasks-mode-map
  :group 'tasks
  (if tasks-mode
      (progn
        (add-hook 'compilation-finish-functions #'tasks/-chain-advance)
        (unless (member tasks/-mode-line global-mode-string)
          (setq global-mode-string
                (append (or global-mode-string '("")) (list tasks/-mode-line)))))
    (remove-hook 'compilation-finish-functions #'tasks/-chain-advance)
    (setq global-mode-string (remove tasks/-mode-line global-mode-string))))
 
(tasks-mode 1)

