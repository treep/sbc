
;;;; This is a wrapper file used in `sbc' script when compiler build image for
;;;; file (just for one file that can require another files/systems).

(defpackage #:sbc-user
  (:use     #:common-lisp
            #:sb-sys
            #:sb-ext
            #:sb-c)
  (:export  #:continue-if-only
            #:with-quit
            #:extreme-optimizing
            #:main
            #:@main
            #:program-name))

(in-package #:sbc-user)

;;;; stuff that can be used in compiled file

(defmacro continue-if-only (thing error-string &rest error-arguments)
  `(unless ,thing
     (format *stderr* ,error-string ,@error-arguments)
     (quit)))

(defmacro with-quit (&body body)
  `(unwind-protect
       (progn ,@body)
     (quit)))

(defmacro extreme-optimizing (&optional (speed 3))
  `(declaim (optimize (speed ,speed)
                      (safety 0)
                      (debug 0)
                      (compilation-speed 0)
                      (space 0))))

;;;; default enrty point

(defmacro main (arguments early-forms &body body)
  `(defun @main ()
     ,@early-forms
     ,@(if arguments
           `((destructuring-bind (,@arguments)
                 (mapcar #'read-from-string (rest *posix-argv*))
               (declare (ignorable ,@arguments))
               ,@body))
           `(,@body))))

;;;; compiling

(defun save-to-image (output-file)
  (continue-if-only (fboundp '@main)
    "SUBJECT file must contain the MAIN function.~%")
  (save-lisp-and-die output-file
                     :purify t
                     :executable t
                     :save-runtime-options t
                     :toplevel '@main))

(defparameter *usage-string*
  "Usage: sbc [input-file] {[:output output-file=input-file.bin] [:room] [:gc]}.~%")

(let* ((input-file  (second *posix-argv*))
       (options     (when (rest (rest *posix-argv*))
                      (read-from-string
                       (concatenate
                        'string
                        "("
                        (reduce #'(lambda (a b) (concatenate 'string a " " b))
                                (rest (rest *posix-argv*)))
                        ")"))))
       (output-file (if (find :output options)
                        (getf options :output)
                        (format nil "~A.bin" input-file))))
  (format t "~A ~A ~A ~%" input-file output-file options)

  ;; check input file
  (continue-if-only input-file *usage-string*)
  (continue-if-only (probe-file input-file) "No such file: ~A~%" input-file)

  ;; check options
  (let ((option-rest (set-difference options '(:compile :load :room :gc :image :output))))
    (continue-if-only (> 2 (length option-rest)) "Bad options: ~A~%" (reverse option-rest)))

  ;; compile and load input file
  (load (compile-file input-file))

  ;; default saving
  (unless options (save-to-image output-file))

  ;; do GC
  (when (find :gc options)     (gc :full t))

  ;; show room
  (when (find :room options)   (room))

  ;; make executable image
  (save-to-image output-file)

  (quit))
