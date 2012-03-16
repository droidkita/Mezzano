(in-package #:sys.int)

(defun proclaim (declaration-specifier)
  (case (first declaration-specifier)
    (special (dolist (var (rest declaration-specifier))
               (setf (system:symbol-mode var) :special)))))

(defun system:symbol-mode (symbol)
  (let* ((flags (%symbol-flags symbol))
         (bits (logand flags 3)))
    (svref #(nil :special :constant :symbol-macro) bits)))

(defun (setf system:symbol-mode) (value symbol)
  (let ((flags (%symbol-flags symbol))
        (bits (ecase value
                ((nil) 0)
                ((:special) 1)
                ((:constant) 2)
                ((:symbol-macro) 3))))
    (setf (%symbol-flags symbol)
          (logior (logand flags -4) bits))
    value))

;;; The compiler can only handle (apply function arg-list).
(defun apply (function arg &rest more-args)
  (declare (dynamic-extent more-args))
  (cond (more-args
         ;; Convert (... (final-list ...)) to (... final-list...)
         (do* ((arg-list (cons arg more-args))
               (i arg-list (cdr i)))
              ((null (cddr i))
               (setf (cdr i) (cadr i))
               (apply function arg-list))))
        (t (apply function arg))))

;;; TODO: This requires a considerably more flexible mechanism.
;;; 12 is where the TLS slots in a stack group start.
(defparameter *next-symbol-tls-slot* 12)
(defconstant +maximum-tls-slot+ 512)
(defun %allocate-tls-slot (symbol)
  (when (>= *next-symbol-tls-slot* +maximum-tls-slot+)
    (error "Critial error! TLS slots exhausted!"))
  (let ((slot *next-symbol-tls-slot*))
    (incf *next-symbol-tls-slot*)
    (setf (%symbol-flags symbol) (logior (logand (%symbol-flags symbol) (lognot #b111111111111111100000000))
                                         (ash slot 8)))
    slot))

(defun %symbol-tls-slot (symbol)
  (ash (logand (%symbol-flags symbol) #b111111111111111100000000) -8))

(defun funcall (function &rest arguments)
  (declare (dynamic-extent arguments))
  (apply function arguments))

(defun values (&rest values)
  (declare (dynamic-extent values))
  (values-list values))

(defun fboundp (name)
  (%fboundp (function-symbol name)))

(defun fmakunbound (name)
  (%fmakunbound (function-symbol name))
  name)

(defun macro-function (symbol &optional env)
  (when env
    (error "TODO: Macro-function in environment."))
  (get symbol '%macro-function))

;;; Calls to these functions are generated by the compiler to
;;; signal errors.
(defun raise-undefined-function (invoked-through)
  (error 'undefined-function :name invoked-through))

(defun raise-unbound-error (symbol)
  (error 'unbound-variable :name symbol))

(defun raise-type-error (datum expected-type)
  (error 'type-error :datum datum :expected-type expected-type))

(defun %invalid-argument-error (&rest args)
  (error "Invalid arguments to function."))

(defun endp (list)
  (cond ((null list) t)
        ((consp list) nil)
        (t (error 'type-error
                  :datum list
                  :expected-type 'list))))

(defun list (&rest args)
  args)

(defun copy-list (list)
  (when list
    (cons (car list) (copy-list (cdr list)))))

(defun function-name (function)
  (check-type function function)
  (let* ((address (logand (lisp-object-address function) -16))
         (info (memref-unsigned-byte-64 address 0)))
    (ecase (logand info #xFF)
      (0 ;; Regular function. First entry in the constant pool.
       (memref-t address (* (logand (ash info -16) #xFFFF) 2)))
      (1 ;; Closure.
       (function-name (memref-t address 4))))))

(defvar *gensym-counter* 0)
(defun gensym (&optional (thing "G"))
  (make-symbol (format nil "~A~D" thing (prog1 *gensym-counter* (incf *gensym-counter*)))))
