(require "helix/editor.scm")
(require (prefix-in helix.static. "helix/static.scm"))
(require "helix/misc.scm")
(require-builtin helix/core/text as text.)

(provide copy-location
         copy-location-snippet
         copy-location-url)

(define (current-doc-id)
  (let* ([focus (editor-focus)])
    (editor->doc-id focus)))

(define (current-path)
  (editor-document->path (current-doc-id)))

(define (path-relative-to-workspace path)
  (define workspace (helix-find-workspace))
  (define prefix (if (string? workspace) (string-append workspace "/") ""))
  (if (or (not (string? path)) (equal? prefix ""))
      path
      (let ([trimmed (trim-start-matches path prefix)])
        (if (equal? trimmed path) path trimmed))))

(define (current-line-range)
  (define selection (helix.static.current-selection-object))
  (define primary (helix.static.selection->primary-range selection))
  (define from (helix.static.range->from primary))
  (define to (helix.static.range->to primary))
  (define rope (editor->text (current-doc-id)))

  (define start-line (+ 1 (text.rope-char->line rope from)))
  (define inclusive-end-char
    (if (> to from)
        (- to 1)
        to))
  (define end-line (+ 1 (text.rope-char->line rope inclusive-end-char)))

  (list start-line end-line))

(define (line-range-ref)
  (define range (current-line-range))
  (define start (list-ref range 0))
  (define end (list-ref range 1))
  (if (= start end)
      (number->string start)
      (string-append (number->string start) "-" (number->string end))))

(define (line-range-url)
  (define range (current-line-range))
  (define start (list-ref range 0))
  (define end (list-ref range 1))
  (if (= start end)
      (string-append "#L" (number->string start))
      (string-append "#L" (number->string start) "-L" (number->string end))))

(define (trim-trailing-newlines value)
  (if (and (string? value)
           (> (string-length value) 0)
           (or (ends-with? value "\n")
               (ends-with? value "\r")))
      (trim-trailing-newlines (substring value 0 (- (string-length value) 1)))
      value))

(define (current-selection-or-line-text)
  (define selected (helix.static.current-highlighted-text!))
  (if (and (string? selected) (> (string-length selected) 0))
      (remove-min-leading-whitespace selected)
      (let* ([rope (editor->text (current-doc-id))]
             [range (current-line-range)]
             [start (list-ref range 0)]
             [line-rope (text.rope->line rope (- start 1))])
        (trim-trailing-newlines (text.rope->string line-rope)))))

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
  (if (or (starts-with? value " ")
          (starts-with? value "\t"))
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

(define (leading-indent-width line)
  (let loop ([chars (string->list line)] [count 0])
    (if (null? chars)
        count
        (if (char=? (car chars) #\space)
            (loop (cdr chars) (+ count 1))
            count))))

(define (drop-leading-indent line strip-count)
  (let loop ([chars (string->list line)] [remaining strip-count])
    (if (or (= remaining 0) (null? chars))
        (list->string chars)
        (if (char=? (car chars) #\space)
            (loop (cdr chars) (- remaining 1))
            (list->string chars)))))

(define (remove-min-leading-whitespace text)
  (define lines (split-many text "\n"))
  (define non-empty-lines
    (filter (lambda (line) (not (equal? (trim-whitespace line) ""))) lines))
  (define strip-count
    (if (null? non-empty-lines)
        0
        (apply min (map leading-indent-width non-empty-lines))))
  (string-join (map (lambda (line) (drop-leading-indent line strip-count)) lines) "\n"))

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
;; Copy `path:line` reference for current cursor line or selection.
(define (copy-location)
  (define path (path-relative-to-workspace (current-path)))
  (if (string? path)
      (let ([line-spec (line-range-ref)])
        (copy-to-clipboard (string-append path ":" line-spec))
        (set-status! "Copied location"))
      (set-status! "copy-location requires a file-backed buffer")))

;;@doc
;; Copy `path:line` reference plus selected code.
(define (copy-location-snippet)
  (define path (path-relative-to-workspace (current-path)))
  (if (string? path)
      (let* ([line-spec (line-range-ref)]
             [reference (string-append path ":" line-spec)]
             [selected-text (current-selection-or-line-text)]
             [payload (string-append reference "\n\n" selected-text)])
        (copy-to-clipboard payload)
        (set-status! "Copied location and snippet"))
      (set-status! "copy-location-snippet requires a file-backed buffer")))

;;@doc
;; Copy Git web URL for current cursor line or selection.
(define (copy-location-url)
  (define relative-path (path-relative-to-workspace (current-path)))
  (define workspace (helix-find-workspace))
  (if (and (string? relative-path) (string? workspace))
      (let* ([git-dir (resolve-git-dir workspace)]
             [config-content (and (string? git-dir) (read-file-or-false (string-append (path-clean git-dir) "/config")))]
             [head-content (and (string? git-dir) (read-file-or-false (string-append (path-clean git-dir) "/HEAD")))]
             [origin-url (and (string? config-content) (extract-origin-url config-content))]
             [branch (if (string? head-content) (extract-branch-name head-content) "HEAD")]
             [line-anchor (line-range-url)])
        (if (string? origin-url)
            (let ([url (string-append (remote->https origin-url)
                                      "/blob/"
                                      branch
                                      "/"
                                      relative-path
                                      line-anchor)])
              (copy-to-clipboard url)
              (set-status! "Copied location URL"))
            (set-warning! "Could not resolve git remote.origin.url")))
      (set-status! "copy-location-url requires a file-backed buffer")))
