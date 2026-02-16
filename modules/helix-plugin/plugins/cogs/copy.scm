(require "helix/editor.scm")
(require (prefix-in helix.static. "helix/static.scm"))
(require "helix/misc.scm")

(provide copy-line-reference copy-line-url)

(define (current-path)
  (let* ([focus (editor-focus)]
         [focus-doc-id (editor->doc-id focus)])
    (editor-document->path focus-doc-id)))

(define (path-relative-to-workspace path)
  (define workspace (helix-find-workspace))
  (define prefix (if (string? workspace) (string-append workspace "/") ""))
  (if (or (not (string? path)) (equal? prefix ""))
      path
      (let ([trimmed (trim-start-matches path prefix)])
        (if (equal? trimmed path) path trimmed))))

(define (current-line-number-string)
  (number->string (+ 1 (helix.static.get-current-line-number))))

(define (starts-with? value prefix)
  (not (equal? (trim-start-matches value prefix) value)))

(define (ends-with? value suffix)
  (if (< (string-length value) (string-length suffix))
      #f
      (equal? (substring value
                         (- (string-length value) (string-length suffix))
                         (string-length value))
              suffix)))

(define (path-clean path)
  (if (and (string? path)
           (> (string-length path) 1)
           (equal? (substring path (- (string-length path) 1) (string-length path)) "/"))
      (substring path 0 (- (string-length path) 1))
      path))

(define (trim-left-whitespace value)
  (if (or (starts-with? value " ") (starts-with? value "\t"))
      (trim-left-whitespace (substring value 1 (string-length value)))
      value))

(define (trim-right-whitespace value)
  (if (or (ends-with? value " ")
          (ends-with? value "\t")
          (ends-with? value "\n")
          (ends-with? value "\r"))
      (trim-right-whitespace (substring value 0 (- (string-length value) 1)))
      value))

(define (trim-whitespace value)
  (trim-right-whitespace (trim-left-whitespace value)))

(define (read-file-or-false path)
  (with-handler (lambda (_) #f)
                (call-with-input-file path (lambda (f) (read-port-to-string f)))))

(define (extract-gitdir-from-dotgit workspace)
  (define content (read-file-or-false (string-append workspace "/.git")))
  (if (string? content)
      (let* ([first-line (car (split-many content "\n"))]
             [prefix "gitdir: "])
        (if (starts-with? first-line prefix)
            (let ([raw (trim-left-whitespace (trim-start-matches first-line prefix))])
              (if (starts-with? raw "/") raw (string-append workspace "/" raw)))
            #f))
      #f))

(define (resolve-git-dir workspace)
  (define dotgit (string-append workspace "/.git"))
  (cond
    [(is-dir? dotgit) dotgit]
    [(path-exists? dotgit)
     (extract-gitdir-from-dotgit workspace)]
    [else #f]))

(define (strip-git-suffix url)
  (trim-end-matches url ".git"))

(define (remote->https remote)
  (if (starts-with? remote "git@")
      (let ([parts (split-many (trim-start-matches remote "git@") ":")])
        (if (= (length parts) 2)
            (string-append "https://"
                           (car parts)
                           "/"
                           (trim-end-matches (list-ref parts 1) ".git"))
            (strip-git-suffix remote)))
      (strip-git-suffix remote)))

(define (extract-origin-url config-content)
  (define lines (split-many config-content "\n"))
  (define (loop rest in-origin)
    (if (null? rest)
        #f
        (let* ([line (car rest)]
               [trimmed (trim-left-whitespace line)])
          (cond
            [(starts-with? trimmed "[")
             (loop (cdr rest) (equal? trimmed "[remote \"origin\"]"))]
            [in-origin
             (if (starts-with? trimmed "url")
                 (let* ([after-key (trim-left-whitespace (trim-start-matches trimmed "url"))]
                        [after-equals (trim-left-whitespace (trim-start-matches after-key "="))])
                   (if (equal? after-equals after-key)
                       (loop (cdr rest) in-origin)
                       (trim-whitespace after-equals)))
                 (loop (cdr rest) in-origin))]
            [else (loop (cdr rest) in-origin)]))))
  (loop lines #f))

(define (extract-branch-name head-content)
  (define trimmed-head (trim-whitespace head-content))
  (if (starts-with? trimmed-head "ref: ")
      (file-name (trim-start-matches trimmed-head "ref: refs/heads/"))
      "HEAD"))

(define (copy-to-clipboard value)
  (set-register! #\+ (list value))
  (set-register! #\" (list value)))

;;@doc
;; Copy `path:line` reference for current cursor line.
(define (copy-line-reference)
  (define path (path-relative-to-workspace (current-path)))
  (if (string? path)
      (let ([line (current-line-number-string)])
        (copy-to-clipboard (string-append path ":" line))
        (set-status! "Copied line reference"))
      (set-status! "copy-line-reference requires a file-backed buffer")))

;;@doc
;; Copy Git web URL for current cursor line.
(define (copy-line-url)
  (define absolute-path (current-path))
  (define relative-path (path-relative-to-workspace absolute-path))
  (define workspace (helix-find-workspace))
  (if (and (string? relative-path) (string? workspace))
      (let* ([git-dir (resolve-git-dir workspace)]
             [config-content (and (string? git-dir) (read-file-or-false (string-append (path-clean git-dir) "/config")))]
             [head-content (and (string? git-dir) (read-file-or-false (string-append (path-clean git-dir) "/HEAD")))]
             [origin-url (and (string? config-content) (extract-origin-url config-content))]
             [branch (if (string? head-content) (extract-branch-name head-content) "HEAD")]
             [line (current-line-number-string)])
        (if (string? origin-url)
            (let ([url (string-append (remote->https origin-url)
                                      "/blob/"
                                      branch
                                      "/"
                                      relative-path
                                      "#L"
                                      line)])
              (copy-to-clipboard url)
              (set-status! "Copied line URL"))
            (set-warning! "Could not resolve git remote.origin.url")))
      (set-status! "copy-line-url requires a file-backed buffer")))
