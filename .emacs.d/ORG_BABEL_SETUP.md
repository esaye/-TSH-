# Org-Babel Emacs Configuration Guide

Your Emacs configuration has been converted to a literate programming format using org-babel.

## Files

- **`~/.emacs.d/init.org`** - Source configuration file (read-friendly)
- **`~/.emacs.d/init.el`** - Generated initialization file (auto-generated)
- **`~/.emacs.d/lisp/auto-tangle-init.el`** - Auto-tangle module (saves init.org → init.el)

## Workflow

### Editing Your Configuration

1. Open `~/.emacs.d/init.org` in Emacs
2. Edit the desired section (each major feature has its own section)
3. Save the file with `C-c C-s` (or `C-x C-s`)
4. **Automatic tangling** will regenerate `init.el` automatically

### Manual Tangling (if needed)

If auto-tangle isn't working or you want to manually regenerate:

```lisp
M-x org-babel-tangle
```

Or from the shell:

```bash
emacs -Q --batch ~/.emacs.d/init.org -f org-babel-tangle
```

## How Auto-Tangle Works

When you save `init.org`:
1. The `after-save-hook` triggers
2. `ebrimasaye/org-babel-tangle-init()` checks if the current file is `init.org`
3. If yes, it runs `org-babel-tangle` to regenerate `init.el`
4. A confirmation message appears: `✅ init.org tangled to init.el`

## Configuration Sections in init.org

The configuration is organized into logical sections:

1. **Package Management** - Package archives and bootstrap
2. **Literate Configuration Loading** - Org-babel setup
3. **Package Bootstrap** - use-package initialization
4. **Load Path Setup** - Local module paths
5. **EAF** - Emacs Application Framework
6. **XWidgets** - WebKitGTK browser
7. **Basic Configuration** - UI and editor settings
8. **Themes and UI** - Appearance (doom-themes, dashboard)
9. **Completion and Navigation** - Ivy, Counsel, Company
10. **Version Control** - Magit, git-gutter
11. **Project Management** - Projectile
12. **Programming Languages** - LSP, Python, Julia, etc.
13. **AI/ML Packages** - Jupyter, EIN
14. **AI Coding Assistants** - Copilot, GPTel, ChatGPT
15. **Terminal and Shell** - Vterm, multi-vterm
16. **Error Checking** - Flycheck
17. **Enhanced Lisp Editing** - Lispy
18. **Helpful Packages** - helpful, expand-region, multiple-cursors
19. **Browser Integration** - EAF browser, xwidgets
20. **Scratch Buffer** - Enhanced scratch buffer
21. **Custom AI Functions** - AI development helpers
22. **Key Bindings** - Global shortcuts
23. **Final Setup** - Custom variables and startup

## Navigation Tips

### In Emacs

- **Show outline**: `C-c C-t` (or `Ctrl+Tab` in some configs)
- **Jump to heading**: `C-c C-j` (with ivy)
- **Navigate outline**: Use `n`/`p` to move between headings (in outline-mode)
- **Expand/collapse**: `TAB` on headings

### Adding New Configuration

1. Find the appropriate section or create a new section
2. Add a new subsection with `*` or `**` 
3. Write documentation in Org format
4. Add code blocks with `#+BEGIN_SRC emacs-lisp :tangle yes`
5. Save and auto-tangle will regenerate init.el

### Code Block Examples

**Block that tangles to init.el:**
```org
#+BEGIN_SRC emacs-lisp :tangle yes
(message "This goes to init.el")
#+END_SRC
```

**Block that doesn't tangle (documentation only):**
```org
#+BEGIN_SRC emacs-lisp :tangle no
(message "This is just documentation")
#+END_SRC
```

## Troubleshooting

### init.el isn't updating automatically

1. Check that `auto-tangle-init` is loaded:
   ```lisp
   M-x load-file ~/.emacs.d/lisp/auto-tangle-init.el
   ```

2. Verify the hook is registered:
   ```lisp
   M-x describe-variable after-save-hook
   ```

3. Manually tangle:
   ```bash
   emacs -Q --batch ~/.emacs.d/init.org -f org-babel-tangle
   ```

### Editing init.org while Emacs is running

When you edit `init.org` and regenerate `init.el`, you may need to:
- Restart Emacs to load the new configuration
- Or selectively reload modules: `M-x load-file ~/.emacs.d/init.el`

### Backup files

- Original `init.el`: `~/.emacs.d/init.el.backup`
- Keep this safe in case you need to revert

## Benefits of This Setup

✅ **Documentation** - Each section explains what it does  
✅ **Organization** - Configuration is logically grouped  
✅ **Discoverability** - Easy to find related settings  
✅ **Maintainability** - Comments are right next to code  
✅ **Export-friendly** - Can export to HTML/PDF for sharing  
✅ **Automatic Updates** - Save init.org → init.el updates automatically  

## Further Reading

- [Org-Babel Documentation](https://orgmode.org/worg/org-contrib/babel/)
- [Literate Programming](https://en.wikipedia.org/wiki/Literate_programming)
- [Donald Knuth on Literate Programming](https://www-cs-faculty.stanford.edu/~knuth/lp.html)
