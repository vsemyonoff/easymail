;;; easymail-init.el --- Notmuch mail user agent configuration. -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:
(require 'gnus-alias)
(require 'message)
(require 'notmuch)

(defun vs|easymail/refresh-complete (&rest _)
  "Refresh all biffers when 'easymail index' completed."
  (notmuch-refresh-all-buffers)
  )

(defun vs|easymail/refresh ()
  "Call 'easymail index' to give a chance for `pre-new' hook."
  (let ((process-connection-type nil))
    (set-process-sentinel
     (start-process "easymail" nil "easymail" "index")
     #'vs|easymail/refresh-complete
     )
    )
  )
(advice-add 'notmuch-bury-or-kill-this-buffer :after #'vs|easymail/refresh)

(defun vs|easymail/before-tag ()
  "Before message tags changed."
  (cond
   ((member "-unread" tag-changes)
    (notmuch-tag query '("+readed"))
    )
   ((member "+unread" tag-changes)
    (notmuch-tag query '("+unreaded"))
    )
   )
  )
(add-hook 'notmuch-before-tag-hook #'vs|easymail/before-tag)

;; Tree mode
(defun vs|easymail|tree-toggle-trashed ()
  "Toggle 'trashed' tag for message."
  (interactive)
  (notmuch-tree-tag
   (if (member "trashed" (notmuch-tree-get-tags))
       (list "-trashed")
     (list "+trashed")
     )
   )
  )
(define-key notmuch-tree-mode-map   "d" #'vs|easymail|tree-toggle-trashed)

(defun vs|easymail|tree-toggle-unread ()
  "Toggle 'unread' tag for message."
  (interactive)
  (notmuch-tree-tag
   (if (member "unread" (notmuch-tree-get-tags))
       (list "-unread")
     (list "+unread")
     )
   )
  )
(define-key notmuch-search-mode-map (kbd "<tab>") #'vs|easymail|tree-toggle-unread)

;; Search mode
(defun vs|easymail|search-toggle-trashed ()
  "Toggle 'trashed' tag for message."
  (interactive)
  (notmuch-search-tag
   (if (member "trashed" (notmuch-search-get-tags))
       (list "-trashed")
     (list "+trashed")
     )
   )
  )
(define-key notmuch-search-mode-map "d" #'vs|easymail|search-toggle-trashed)

(defun vs|easymail|search-toggle-unread ()
  "Toggle 'unread' tag for message."
  (interactive)
  (notmuch-search-tag
   (if (member "unread" (notmuch-search-get-tags))
       (list "-unread")
     (list "+unread")
     )
   )
  )
(define-key notmuch-search-mode-map (kbd "<tab>") #'vs|easymail|search-toggle-unread)

(setq notmuch-draft-tags              '("+newdraft")
      notmuch-hello-hide-tags         '("Archive" "attachment" "Drafts" "draft" "Inbox"
                                        "replied" "Sent" "Spam" "Trash" "unread")
      notmuch-hello-sections          '(notmuch-hello-insert-header
                                        notmuch-hello-insert-saved-searches
                                        notmuch-hello-insert-search
                                        notmuch-hello-insert-alltags
                                        notmuch-hello-insert-footer)
      notmuch-message-headers-visible nil
      notmuch-search-oldest-first     nil
      notmuch-show-all-tags-list      t
      notmuch-show-logo               nil
      )

(setq notmuch-saved-searches
      '(
        (:name "Unread"  :query "tag:unread"                   :key "u")
        (:name "Archive" :query "folder:\"/[^\/]+\/Archive/\"" :key "a")
        (:name "Drafts"  :query "folder:\"/[^\/]*\/Drafts/\""  :key "d")
        (:name "Inbox"   :query "folder:\"/[^\/]+\/Inbox/\""   :key "i")
        (:name "Sent"    :query "folder:\"/[^\/]+\/Sent/\""    :key "s")
        (:name "Spam"    :query "folder:\"/[^\/]+\/Spam/\""    :key "S")
        (:name "Trash"   :query "folder:\"/[^\/]+\/Trash/\""   :key "t")
        )
      )

;; Multiple identities
(defun vs|easymail|setup-aliases ()
  "Traverse through all accounts and fill `gnus-alias-identity-alist'."
  (interactive)
  (let* ((accounts        (split-string (shell-command-to-string "easymail list")))
         (default-account (car accounts))
         (identity-rules  (list))
         (alias-alist     (list))
         (fcc-dirs        (list))
         )
    (dolist (account accounts)
      (let ((name      (substring (shell-command-to-string (format "easymail get %s name" account)) 0 -1))
            (email     (substring (shell-command-to-string (format "easymail get %s email" account)) 0 -1))
            (template  (vs|xdg/config (format "easymail/%s/template.txt" account)))
            (signature (vs|xdg/config (format "easymail/%s/signature.txt" account)))
            (fcc-dir   (format "%s/Sent +newsent" account))
            )
        (when (equal email user-mail-address) (setq default-account account))
        (push (list account (list "any" email 'both) account) identity-rules)
        (push (list account ; account name
                    nil     ; refer to other identity
                    (format "%s <%s>" name email)
                    nil     ; organization
                    nil     ; extra headers (fcc will init later)
                    (if (file-exists-p template) template nil)
                    (if (file-exists-p signature) signature nil)
                    )
              alias-alist
              )
        (push `(,email . ,fcc-dir) fcc-dirs)
        )
      )
    (setq gnus-alias-default-identity default-account
          gnus-alias-identity-alist   alias-alist
          gnus-alias-identity-rules   identity-rules
          notmuch-draft-folder        (format "%s/Drafts" default-account)
          notmuch-fcc-dirs            fcc-dirs
          )
    )
  )
(add-hook 'message-mode-hook #'vs|easymail|setup-aliases)

;; Mail sending
(setq message-cite-style               'message-cite-style-gmail
      message-send-mail-function       #'message-send-mail-with-sendmail
      message-sendmail-extra-arguments '("--read-envelope-from" "--read-recipients")
      message-sendmail-f-is-evil       t
      )

(provide 'easymail-init)
;;; easymail-init.el ends here
