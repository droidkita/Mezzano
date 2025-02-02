;;;; ARM64 runtime support functions.

(in-package :mezzano.runtime)

(defun values-list (values)
  (sys.int::values-simple-vector
   (make-array (length values)
               :initial-contents values)))

(sys.int::define-lap-function sys.int::values-simple-vector ((simple-vector))
  "Returns the elements of SIMPLE-VECTOR as multiple values."
  ENTRY-POINT
  (:gc :no-frame :incoming-arguments :rcx :layout #*)
  ;; Check arg count.
  (mezzano.lap.arm64:subs :xzr :x5 #.(ash 1 sys.int::+n-fixnum-bits+)) ; fixnum 1
  (mezzano.lap.arm64:b.ne BAD-ARGUMENTS)
  (mezzano.lap.arm64:stp :x29 :x30 (:pre :sp -16))
  (:gc :no-frame :layout #*00)
  (mezzano.lap.arm64:add :x29 :sp :xzr)
  (:gc :frame)
  ;; Check type.
  (mezzano.lap.arm64:and :x9 :x0 #b1111)
  (mezzano.lap.arm64:subs :xzr :x9 #.sys.int::+tag-object+)
  (mezzano.lap.arm64:b.ne TYPE-ERROR)
  (mezzano.lap.arm64:ldr :x9 (:object :x0 -1))
  ;; Simple vector object tag is zero.
  (mezzano.lap.arm64:ands :xzr :x9 #.(ash (1- (ash 1 sys.int::+object-type-size+))
                                          sys.int::+object-type-shift+))
  (mezzano.lap.arm64:b.ne TYPE-ERROR)
  ;; Get number of values.
  (mezzano.lap.arm64:adds :x9 :xzr :x9 :lsr #.sys.int::+object-data-shift+)
  (mezzano.lap.arm64:b.eq ZERO-VALUES)
  (mezzano.lap.arm64:subs :xzr :x9 #.(+ mezzano.supervisor::+thread-mv-slots-size+
                                        5))
  (mezzano.lap.arm64:b.cs TOO-MANY-VALUES)
  ;; Set up. X6(RBX) = vector, X5(RCX) = number of values loaded so far, X9(RAX) = total number of values.
  (mezzano.lap.arm64:orr :x6 :xzr :x0)
  (mezzano.lap.arm64:orr :x5 :xzr :xzr)
  ;; Load register values.
  (mezzano.lap.arm64:add :x5 :x5 #.(ash 1 sys.int::+n-fixnum-bits+)) ; fixnum 1
  (mezzano.lap.arm64:ldr :x0 (:object :x6 0))
  (mezzano.lap.arm64:subs :xzr :x9 1)
  (mezzano.lap.arm64:b.eq DONE)
  (mezzano.lap.arm64:add :x5 :x5 #.(ash 1 sys.int::+n-fixnum-bits+)) ; fixnum 1
  (mezzano.lap.arm64:ldr :x1 (:object :x6 1))
  (mezzano.lap.arm64:subs :xzr :x9 2)
  (mezzano.lap.arm64:b.eq DONE)
  (mezzano.lap.arm64:add :x5 :x5 #.(ash 1 sys.int::+n-fixnum-bits+)) ; fixnum 1
  (mezzano.lap.arm64:ldr :x2 (:object :x6 2))
  (mezzano.lap.arm64:subs :xzr :x9 3)
  (mezzano.lap.arm64:b.eq DONE)
  (mezzano.lap.arm64:add :x5 :x5 #.(ash 1 sys.int::+n-fixnum-bits+)) ; fixnum 1
  (mezzano.lap.arm64:ldr :x3 (:object :x6 3))
  (mezzano.lap.arm64:subs :xzr :x9 4)
  (mezzano.lap.arm64:b.eq DONE)
  (mezzano.lap.arm64:add :x5 :x5 #.(ash 1 sys.int::+n-fixnum-bits+)) ; fixnum 1
  (mezzano.lap.arm64:ldr :x4 (:object :x6 4))
  (mezzano.lap.arm64:subs :xzr :x9 5)
  (mezzano.lap.arm64:b.eq DONE)
  ;; Registers are populated, now unpack into the MV-area
  (mezzano.lap.arm64:add :x12 :x28 #.(+ (- 8 sys.int::+tag-object+)
                                        (* mezzano.supervisor::+thread-mv-slots+ 8)))
  (mezzano.lap.arm64:movz :x10 #.(+ (- 8 sys.int::+tag-object+)
                                    (* 5 8))) ; Current index.
  (mezzano.lap.arm64:movz :x11 5)
  (:gc :frame :multiple-values 0)
  UNPACK-LOOP
  (mezzano.lap.arm64:ldr :x7 (:x6 :x10))
  (mezzano.lap.arm64:str :x7 (:x12))
  (:gc :frame :multiple-values 1)
  (mezzano.lap.arm64:add :x5 :x5 #.(ash 1 sys.int::+n-fixnum-bits+)) ; fixnum 1
  (:gc :frame :multiple-values 0)
  (mezzano.lap.arm64:add :x12 :x12 8)
  (mezzano.lap.arm64:add :x10 :x10 8)
  (mezzano.lap.arm64:add :x11 :x11 1)
  (mezzano.lap.arm64:subs :xzr :x11 :x9)
  (mezzano.lap.arm64:b.ne UNPACK-LOOP)
  DONE
  (mezzano.lap.arm64:add :sp :x29 0)
  (:gc :frame :multiple-values 0)
  (mezzano.lap.arm64:ldp :x29 :x30 (:post :sp 16))
  (:gc :no-frame :layout #* :multiple-values 0)
  (mezzano.lap.arm64:ret)
  ;; Special-case 0 values as it requires NIL in X0.
  ZERO-VALUES
  (:gc :frame)
  (mezzano.lap.arm64:orr :x0 :x26 :xzr)
  (mezzano.lap.arm64:orr :x5 :xzr :xzr)
  (mezzano.lap.arm64:b DONE)
  (:gc :frame)
  TYPE-ERROR
  (mezzano.lap.arm64:ldr :x1 (:constant simple-vector))
  (mezzano.lap.arm64:movz :x5 #.(ash 2 sys.int::+n-fixnum-bits+)) ; fixnum 2
  (mezzano.lap.arm64:named-call sys.int::raise-type-error)
  (mezzano.lap.arm64:hlt 0)
  TOO-MANY-VALUES
  (mezzano.lap.arm64:ldr :x0 (:constant "Too many values in simple-vector ~S."))
  (mezzano.lap.arm64:orr :x1 :xzr :x6)
  (mezzano.lap.arm64:movz :x5 #.(ash 2 sys.int::+n-fixnum-bits+)) ; fixnum 2
  (mezzano.lap.arm64:named-call error)
  (mezzano.lap.arm64:hlt 0)
  BAD-ARGUMENTS
  (:gc :no-frame :incoming-arguments :rcx)
  (mezzano.lap.arm64:adr :x6 (+ (- ENTRY-POINT 16) #.sys.int::+tag-object+))
  (mezzano.lap.arm64:ldr :x7 (:function sys.int::raise-invalid-argument-error))
  (mezzano.lap.arm64:ldr :x7 (:object :x7 #.sys.int::+fref-function+))
  (mezzano.lap.arm64:ldr :x9 (:object :x7 #.sys.int::+function-entry-point+))
  (mezzano.lap.arm64:br :x9))

(sys.int::define-lap-function %apply ()
  (:gc :no-frame :incoming-arguments :rcx :layout #*)
  (mezzano.lap.arm64:stp :x29 :x30 (:pre :sp -16))
  (:gc :no-frame :incoming-arguments :rcx :layout #*00)
  (mezzano.lap.arm64:add :x29 :sp :xzr)
  (:gc :frame)
  ;; Function goes in X6.
  (mezzano.lap.arm64:orr :x6 :xzr :x0)
  ;; Argument count.
  (mezzano.lap.arm64:orr :x5 :xzr :xzr)
  ;; Words pushed for alignment.
  (mezzano.lap.arm64:orr :x12 :xzr :xzr)
  ;; Check for no arguments.
  (mezzano.lap.arm64:subs :xzr :x1 :x26)
  (mezzano.lap.arm64:b.eq DO-CALL)
  ;; Unpack the list.
  ;; Known to have at least one cons, so we can drop directly into the body.
  (mezzano.lap.arm64:orr :x7 :xzr :x1)
  UNPACK-LOOP
  (:gc :frame :pushed-values-register :rcx)
  ;; Typecheck list, part 2. consp
  (mezzano.lap.arm64:and :x9 :x7 #b1111)
  (mezzano.lap.arm64:subs :xzr :x9 #.sys.int::+tag-cons+)
  (mezzano.lap.arm64:b.ne LIST-TYPE-ERROR)
  ;; Push car & increment arg count
  (mezzano.lap.arm64:ldr :x0 (:x7 #.(- #.sys.int::+tag-cons+)))
  (mezzano.lap.arm64:str :x0 (:pre :sp -8))
  (:gc :frame :pushed-values-register :rcx :pushed-values 1)
  (mezzano.lap.arm64:add :x5 :x5 #.(ash 1 sys.int::+n-fixnum-bits+)) ; fixnum 1
  (:gc :frame :pushed-values-register :rcx)
  ;; Advance.
  (mezzano.lap.arm64:ldr :x7 (:x7 #.(+ (- #.sys.int::+tag-cons+) 8)))
  ;; Typecheck list, part 1. null
  (mezzano.lap.arm64:subs :xzr :x7 :x26)
  (mezzano.lap.arm64:b.ne UNPACK-LOOP)
  ;; Arguments have been pushed on the stack in reverse.
  ;; Ensure the stack is misaligned.
  ;; Misalign because 5 registers will be popped off, leaving
  ;; the stack correctly aligned.
  (mezzano.lap.arm64:add :x9 :sp :xzr)
  (mezzano.lap.arm64:ands :xzr :x9 8)
  (mezzano.lap.arm64:b.ne STACK-ALIGNED)
  ;; Don't push anything extra if there are 5 or fewer args.
  ;; They will all be popped off.
  (mezzano.lap.arm64:subs :xzr :x5 #.(ash 5 sys.int::+n-fixnum-bits+)) ; fixnum 5
  (mezzano.lap.arm64:b.ls stack-aligned)
  ;; Reversing will put this at the end of the stack, out of the way.
  (mezzano.lap.arm64:str :xzr (:pre :sp -8))
  (:gc :frame :pushed-values-register :rcx :pushed-values 1)
  (mezzano.lap.arm64:add :x5 :x5 #.(ash 1 sys.int::+n-fixnum-bits+)) ; fixnum 1
  (:gc :frame :pushed-values-register :rcx)
  (mezzano.lap.arm64:add :x12 :x12 #.(ash 1 sys.int::+n-fixnum-bits+)) ; fixnum 1
  STACK-ALIGNED
  ;; X5 = n arguments. (fixnum)
  ;; X10 = left offset, X9 = right offset.
  (mezzano.lap.arm64:sub :x9 :x5 #.(- (ash -1 sys.int::+n-fixnum-bits+)))
  (mezzano.lap.arm64:add :x9 :xzr :x9 :lsr #.sys.int::+n-fixnum-bits+)
  (mezzano.lap.arm64:add :x9 :xzr :x9 :lsl 3) ; * 8
  (mezzano.lap.arm64:orr :x10 :xzr :xzr)
  (mezzano.lap.arm64:b REVERSE-TEST)
  REVERSE-LOOP
  ;; Swap stack+x9 & stack+x10
  (mezzano.lap.arm64:ldr :x0 (:sp :x9))
  (mezzano.lap.arm64:ldr :x1 (:sp :x10))
  (mezzano.lap.arm64:str :x1 (:sp :x9))
  (mezzano.lap.arm64:str :x0 (:sp :x10))
  ;; Advance offsets.
  (mezzano.lap.arm64:add :x10 :x10 8)
  (mezzano.lap.arm64:sub :x9 :x9 8)
  REVERSE-TEST
  ;; Stop when X10 > X9.
  (mezzano.lap.arm64:subs :xzr :x9 :x10)
  (mezzano.lap.arm64:b.hi REVERSE-LOOP)
  ;; Drop the word pushed for alignment (if any).
  (mezzano.lap.arm64:sub :x5 :x5 :x12)
  ;; Put arguments into registers.
  ;; Always at least one argument by this point.
  (mezzano.lap.arm64:ldr :x0 (:post :sp 8))
  (:gc :frame :pushed-values-register :rcx :pushed-values -1)
  (mezzano.lap.arm64:subs :xzr :x5 #.(ash 1 sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:b.eq do-call)
  (mezzano.lap.arm64:ldr :x1 (:post :sp 8))
  (:gc :frame :pushed-values-register :rcx :pushed-values -2)
  (mezzano.lap.arm64:subs :xzr :x5 #.(ash 2 sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:b.eq do-call)
  (mezzano.lap.arm64:ldr :x2 (:post :sp 8))
  (:gc :frame :pushed-values-register :rcx :pushed-values -3)
  (mezzano.lap.arm64:subs :xzr :x5 #.(ash 3 sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:b.eq do-call)
  (mezzano.lap.arm64:ldr :x3 (:post :sp 8))
  (:gc :frame :pushed-values-register :rcx :pushed-values -4)
  (mezzano.lap.arm64:subs :xzr :x5 #.(ash 4 sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:b.eq do-call)
  (mezzano.lap.arm64:ldr :x4 (:post :sp 8))
  (:gc :frame :pushed-values-register :rcx :pushed-values -5)
  ;; Everything is ready. Call the function!
  DO-CALL
  ;; If there are 5 or fewer arguments (ie, only register args) the function can be tail-called to.
  (mezzano.lap.arm64:subs :xzr :x5 #.(ash 5 sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:b.ls DO-TAIL-CALL)
  (mezzano.lap.arm64:ldr :x9 (:object :x6 0))
  (mezzano.lap.arm64:blr :x9)
  (:gc :frame)
  ;; Finish up & return.
  (mezzano.lap.arm64:add :sp :x29 0)
  (mezzano.lap.arm64:ldp :x29 :x30 (:post :sp 16))
  (:gc :no-frame :layout #*)
  (mezzano.lap.arm64:ret)
  DO-TAIL-CALL
  (:gc :frame)
  (mezzano.lap.arm64:add :sp :x29 0)
  (mezzano.lap.arm64:ldp :x29 :x30 (:post :sp 16))
  (:gc :no-frame :layout #*)
  (mezzano.lap.arm64:ldr :x9 (:object :x6 0))
  (mezzano.lap.arm64:br :x9)
  ;; X0 = function, X1 = arg-list.
  ;; (raise-type-error arg-list 'proper-list)
  LIST-TYPE-ERROR
  (:gc :frame)
  ;; Make sure that the stack is 16-byte aligned.
  ;; The list unpacking loop has been pushing values one by one.
  (mezzano.lap.arm64:add :x9 :sp :xzr)
  (mezzano.lap.arm64:and :x9 :x9 #.(lognot 15))
  (mezzano.lap.arm64:add :sp :x9 :xzr)
  (mezzano.lap.arm64:orr :x0 :xzr :x1)
  (mezzano.lap.arm64:ldr :x1 (:constant sys.int::proper-list))
  (mezzano.lap.arm64:movz :x5 #.(ash 2 sys.int::+n-fixnum-bits+)) ; fixnum 2
  (mezzano.lap.arm64:named-call sys.int::raise-type-error)
  (mezzano.lap.arm64:hlt 0))

(sys.int::define-lap-function eql ((x y))
  "Compare X and Y."
  ENTRY-POINT
  (:gc :no-frame :incoming-arguments :rcx :layout #*)
  ;; Check arg count.
  (mezzano.lap.arm64:subs :xzr :x5 #.(ash 2 sys.int::+n-fixnum-bits+)) ; fixnum 2
  (mezzano.lap.arm64:b.ne BAD-ARGUMENTS)
  (:gc :no-frame :layout #*)
  (:debug ((x :x0 :value) (y :x1 :value)))
  ;; EQ test.
  ;; This additionally covers fixnums, characters and single-floats.
  (mezzano.lap.arm64:subs :xzr :x0 :x1)
  (mezzano.lap.arm64:b.ne MAYBE-NUMBER-CASE)
  ;; Objects are EQ.
  (:debug ())
  OBJECTS-EQUAL
  (mezzano.lap.arm64:ldr :x0 (:constant t))
  (mezzano.lap.arm64:movz :x5 #.(ash 1 sys.int::+n-fixnum-bits+)) ; fixnum 1
  (mezzano.lap.arm64:ret)
  MAYBE-NUMBER-CASE
  (:debug ((x :r8 :value) (y :r9 :value)))
  ;; Not EQ.
  ;; Both must be objects.
  (mezzano.lap.arm64:sub :x9 :x0 #.sys.int::+tag-object+)
  (mezzano.lap.arm64:ands :xzr :x9 #b1111)
  (mezzano.lap.arm64:b.ne OBJECTS-UNEQUAL)
  (mezzano.lap.arm64:sub :x9 :x1 #.sys.int::+tag-object+)
  (mezzano.lap.arm64:ands :xzr :x9 #b1111)
  (mezzano.lap.arm64:b.ne OBJECTS-UNEQUAL)
  ;; Both are objects.
  ;; Test that both are the same kind of object.
  (mezzano.lap.arm64:ldrb :x9 (:object :x0 -1))
  (mezzano.lap.arm64:ldrb :x10 (:object :x1 -1))
  (mezzano.lap.arm64:subs :xzr :x9 :x10)
  (mezzano.lap.arm64:b.ne OBJECTS-UNEQUAL)
  ;; They must be numbers. Characters were handled above.
  (mezzano.lap.arm64:sub :x9 :x9 #.(ash sys.int::+first-numeric-object-tag+
                                        sys.int::+object-type-shift+))
  (mezzano.lap.arm64:subs :xzr :x9 #.(ash (- sys.int::+last-numeric-object-tag+
                                             sys.int::+first-numeric-object-tag+)
                                          sys.int::+object-type-shift+))
  (mezzano.lap.arm64:b.hi OBJECTS-UNEQUAL)
  ;; Both are numbers of the same type.
  ;; Handle short-floats and double-floats specifically. They have
  ;; different behaviour for negative 0.0 compared to =
  (mezzano.lap.arm64:subs :xzr :x9 #.(ash (- sys.int::+object-tag-double-float+
                                             sys.int::+first-numeric-object-tag+)
                                          sys.int::+object-type-shift+))
  (mezzano.lap.arm64:b.eq COMPARE-DOUBLE-FLOATS)
  (mezzano.lap.arm64:subs :xzr :x9 #.(ash (- sys.int::+object-tag-short-float+
                                             sys.int::+first-numeric-object-tag+)
                                          sys.int::+object-type-shift+))
  (mezzano.lap.arm64:b.eq COMPARE-SHORT-FLOATS)
  ;; Same for short floats
  ;; Tail-call to generic-=.
  ;; RCX was set to fixnum 2 on entry.
  (mezzano.lap.arm64:named-tail-call sys.int::generic-=)
  ;; Compare the two values directly.
  ;; This means +0.0 and -0.0 will be different and that NaNs can be EQL
  ;; if they have the same representation.
  COMPARE-SHORT-FLOATS
  (mezzano.lap.arm64:ldrh :x9 (:object :x0 0))
  (mezzano.lap.arm64:ldrh :x10 (:object :x1 0))
  (mezzano.lap.arm64:subs :xzr :x9 :x10)
  (mezzano.lap.arm64:b.eq OBJECTS-EQUAL)
  (mezzano.lap.arm64:b OBJECTS-UNEQUAL)
  COMPARE-DOUBLE-FLOATS
  (mezzano.lap.arm64:ldr :x9 (:object :x0 0))
  (mezzano.lap.arm64:ldr :x10 (:object :x1 0))
  (mezzano.lap.arm64:subs :xzr :x9 :x10)
  (mezzano.lap.arm64:b.eq OBJECTS-EQUAL)
  OBJECTS-UNEQUAL
  ;; Objects are not EQL.
  (:debug ())
  (mezzano.lap.arm64:orr :x0 :x26 :xzr)
  (mezzano.lap.arm64:movz :x5 #.(ash 1 sys.int::+n-fixnum-bits+)) ; fixnum 1
  (mezzano.lap.arm64:ret)
  BAD-ARGUMENTS
  (:gc :no-frame :layout #* :incoming-arguments :rcx)
  (mezzano.lap.arm64:adr :x6 (+ (- ENTRY-POINT 16) #.sys.int::+tag-object+))
  (mezzano.lap.arm64:ldr :x7 (:function sys.int::raise-invalid-argument-error))
  (mezzano.lap.arm64:ldr :x7 (:object :x7 #.sys.int::+fref-function+))
  (mezzano.lap.arm64:ldr :x9 (:object :x7 #.sys.int::+function-entry-point+))
  (mezzano.lap.arm64:br :x9))

(sys.int::define-lap-function %fixnum-left-shift ((integer count))
  (:gc :no-frame :layout #*)
  (mezzano.lap.arm64:subs :xzr :x1 #.(ash (- 63 sys.int::+n-fixnum-bits+)
                                          sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:b.hi DO-BIG-SHIFT)
  ;; Check for overflow.
  ;; Sign extend INTEGER into :X9.
  (mezzano.lap.arm64:asr :x9 :x0 63) ; x9=rdx (sign bits)
  ;; Unbox fixnum count, x5=rcx
  (mezzano.lap.arm64:asr :x10 :x1 #.sys.int::+n-fixnum-bits+)
  ;; Arithmetic shift integer right by 63 - fixnum-bits - count, so that the
  ;; to-be-shifted out bits are the only ones left, make sure it matches the
  ;; sign extended version.
  (mezzano.lap.arm64:asr :x11 :x0 #.sys.int::+n-fixnum-bits+)
  (mezzano.lap.arm64:movz :x12 #.(- 63 sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:sub :x12 :x12 :x10)
  (mezzano.lap.arm64:asr :x11 :x11 :x12)
  ;; Compare with sign bits, if both the same then we're good.
  (mezzano.lap.arm64:subs :xzr :x9 :x11)
  ;; TODO: Could be a bit clever and construct the bignum result directly here.
  (mezzano.lap.arm64:b.ne DO-BIG-SHIFT)
  ;; Finally do the shift.
  (mezzano.lap.arm64:lsl :x0 :x0 :x10)
  (mezzano.lap.arm64:movz :x5 #.(ash 1 sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:ret)
  ;; Bail out, call the helper.
  DO-BIG-SHIFT
  (mezzano.lap.arm64:named-tail-call %fixnum-left-shift-slow))

(defun %fixnum-left-shift-slow (integer count)
  (dotimes (i count integer)
    (setf integer (+ integer integer))))

(defun sys.int::%copy-words (destination-address source-address count)
  (dotimes (i count)
    (setf (sys.int::memref-t destination-address i)
          (sys.int::memref-t source-address i))))

(defun sys.int::%fill-words (destination-address value count)
  (dotimes (i count)
    (setf (sys.int::memref-t destination-address i) value)))

(sys.int::define-lap-function %allocate-from-general-area ((tag data words))
  (:gc :no-frame :layout #* :incoming-arguments :rcx)
  (mezzano.lap.arm64:stp :x29 :x30 (:pre :sp -16))
  (:gc :no-frame :layout #*00 :incoming-arguments :rcx)
  ;; Attempt to quickly allocate from the general area. Will call
  ;; %SLOW-ALLOCATE-FROM-GENERAL-AREA if things get too hairy.
  ;; R8 = tag; R9 = data; R10 = words
  ;; Check argument count.
  (mezzano.lap.arm64:subs :xzr :x5 #.(ash 3 #.sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:b.ne SLOW-PATH-BAD-ARGS)
  (:gc :no-frame :layout #*00)
  ;; Update allocation meter.
  ;; *BYTES-CONSED* is updated elsewhere.
  (mezzano.lap.arm64:ldr :x6 (:symbol-global-cell *general-allocation-count*))
  ;; FIXME: Should be atomic add.
  (mezzano.lap.arm64:ldr :x9 (:object :x6 #.sys.int::+symbol-value-cell-value+))
  (mezzano.lap.arm64:add :x9 :x9 #.(ash 1 sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:str :x9 (:object :x6 #.sys.int::+symbol-value-cell-value+))
  ;; Check *ENABLE-ALLOCATION-PROFILING*
  ;; FIXME: This only tests the global value.
  (mezzano.lap.arm64:ldr :x6 (:symbol-global-cell *enable-allocation-profiling*))
  (mezzano.lap.arm64:ldr :x4 (:object :x6 #.sys.int::+symbol-value-cell-value+))
  (mezzano.lap.arm64:subs :xzr :x4 :x26)
  (mezzano.lap.arm64:b.ne SLOW-PATH)
  ;; Check *GC-IN-PROGRESS*.
  (mezzano.lap.arm64:ldr :x6 (:symbol-global-cell sys.int::*gc-in-progress*))
  (mezzano.lap.arm64:ldr :x4 (:object :x6 #.sys.int::+symbol-value-cell-value+))
  (mezzano.lap.arm64:subs :xzr :x4 :x26)
  (mezzano.lap.arm64:b.ne SLOW-PATH)
  ;; Try the real fast allocator.
  (mezzano.lap.arm64:named-call %do-allocate-from-general-area)
  (mezzano.lap.arm64:subs :xzr :x5 #.(ash 1 #.sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:b.ne SLOW-PATH)
  ;; Done. Return everything.
  (mezzano.lap.arm64:ldr :x6 (:symbol-global-cell *general-fast-path-hits*))
  ;; FIXME: Should be atomic add.
  (mezzano.lap.arm64:ldr :x9 (:object :x6 #.sys.int::+symbol-value-cell-value+))
  (mezzano.lap.arm64:add :x9 :x9 #.(ash 1 sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:str :x9 (:object :x6 #.sys.int::+symbol-value-cell-value+))
  (mezzano.lap.arm64:movz :x5 #.(ash 1 #.sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:ldp :x29 :x30 (:post :sp 16))
  (:gc :no-frame :layout #*)
  (mezzano.lap.arm64:ret)
  SLOW-PATH
  (:gc :no-frame :layout #*00)
  ;; Tail call into %SLOW-ALLOCATE-FROM-GENERAL-AREA.
  (mezzano.lap.arm64:movz :x5 #.(ash 3 #.sys.int::+n-fixnum-bits+))
  SLOW-PATH-BAD-ARGS
  (mezzano.lap.arm64:ldp :x29 :x30 (:post :sp 16))
  (:gc :no-frame :layout #* :incoming-arguments :rcx)
  (mezzano.lap.arm64:named-tail-call %slow-allocate-from-general-area))

(sys.int::define-lap-function %do-allocate-from-general-area ((tag data words))
  (:gc :no-frame :layout #*)
  ;; Attempt to quickly allocate from the general area.
  ;; Returns (values tag data words t) on failure, just the object on success.
  ;; X0 = tag; X1 = data; X2 = words.
  ;; Fetch symbol value cells.
  (mezzano.lap.arm64:ldr :x7 (:symbol-global-cell sys.int::*general-area-young-gen-bump*))
  (mezzano.lap.arm64:ldr :x4 (:symbol-global-cell sys.int::*young-gen-newspace-bit-raw*))
  (mezzano.lap.arm64:ldr :x3 (:symbol-global-cell sys.int::*general-area-young-gen-limit*))
  ;; X7 = bump. X4 = newspace-bit. X3 = limit.
  ;; Assemble the final header value in X12.
  (mezzano.lap.arm64:add :x12 :xzr :x0 :lsl #.(- sys.int::+object-type-shift+ sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:add :x12 :x12 :x1 :lsl #.(- sys.int::+object-data-shift+ sys.int::+n-fixnum-bits+))
  ;; If a garbage collection occurs, it must rewind IP back here.
  (:gc :no-frame :layout #* :restart t)
  ;; Fetch and increment the current bump pointer.
  (mezzano.lap.arm64:add :x6 :xzr :x2 :lsl 3) ; words * 8
  ;; Address generation.
  ;; Linked GC mode is not needed as this will be repeated due to the restart region.
  (mezzano.lap.arm64:add :x9 :x7 #.(+ (- sys.int::+tag-object+) 8 (* sys.int::+symbol-value-cell-value+ 8)))
  ;; Atomic add. Blech, load/store linked suck.
  ATOMIC-RETRY
  (mezzano.lap.arm64:ldaxr :x10 (:x9))
  (mezzano.lap.arm64:add :x11 :x10 :x6)
  (mezzano.lap.arm64:orr :x6 :xzr :x10)
  (mezzano.lap.arm64:stlxr :w10 :x11 (:x9))
  (mezzano.lap.arm64:cbnz :x10 ATOMIC-RETRY)
  ;; X6 is old bump pointer, the address of the cons.
  ;; X11 is the new bump pointer.
  ;; Test against limit.
  (mezzano.lap.arm64:ldr :x10 (:object :x3 #.sys.int::+symbol-value-cell-value+))
  (mezzano.lap.arm64:subs :xzr :x11 :x10)
  (mezzano.lap.arm64:b.hi SLOW-PATH)
  ;; Generate the object.
  ;; Unfixnumize address. This still looks like a fixnum due to alignment.
  (mezzano.lap.arm64:add :x6 :xzr :x6 :lsr #.sys.int::+n-fixnum-bits+)
  ;; Set address bits and the tag bits.
  ;; Set address bits, tag bits, and the mark bit.
  (mezzano.lap.arm64:ldr :x9 (:pc general-address-object-tag))
  (mezzano.lap.arm64:orr :x6 :x6 :x9)
  (mezzano.lap.arm64:ldr :x9 (:object :x4 #.sys.int::+symbol-value-cell-value+))
  (mezzano.lap.arm64:orr :x6 :x6 :x9)
  ;; RBX now points to a 0-element simple-vector, followed by however much empty space is required.
  ;; The gc metadata at this point has :restart t, so if a GC occurs before
  ;; writing the final header, this process will be restarted from the beginning.
  ;; This is required as the GC will only copy 2 words, leaving the rest of the memory in an invalid state.
  ;; Write back the header.
  ;; This must be done in a single write so the GC always sees a correct header.
  (mezzano.lap.arm64:str :x12 (:object :x6 -1))
  ;; Leave restart region.
  (:gc :no-frame :layout #*)
  ;; Done. Return everything.
  (mezzano.lap.arm64:orr :x0 :xzr :x6)
  (mezzano.lap.arm64:movz :x5 #.(ash 1 #.sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:ret)
  SLOW-PATH
  (mezzano.lap.arm64:ldr :x3 (:constant t))
  (mezzano.lap.arm64:movz :x5 #.(ash 4 #.sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:ret)
  (:align 16)
  general-address-object-tag
  (:d64/le #.(logior (ash sys.int::+address-tag-general+ sys.int::+address-tag-shift+)
                     sys.int::+tag-object+)))

(sys.int::define-lap-function do-cons ((car cdr))
  (:gc :no-frame :layout #*)
  ;; Attempt to quickly allocate a cons.
  ;; Returns (values car cdr t) on failure, just the cons on success.
  ;; R8 = car; R9 = cdr
  ;; Fetch symbol value cells.
  (mezzano.lap.arm64:ldr :x7 (:symbol-global-cell sys.int::*cons-area-young-gen-bump*))
  (mezzano.lap.arm64:ldr :x4 (:symbol-global-cell sys.int::*young-gen-newspace-bit-raw*))
  (mezzano.lap.arm64:ldr :x3 (:symbol-global-cell sys.int::*cons-area-young-gen-limit*))
  ;; R13 = bump. R11 = limit. R12 = mark.
  (:gc :no-frame :layout #* :restart t)
  ;; Fetch and increment the current bump pointer.
  (mezzano.lap.arm64:movz :x6 #.(ash 16 #.sys.int::+n-fixnum-bits+)) ; 16, size of cons
  ;; Address generation.
  ;; Linked GC mode is not needed as this will be repeated due to the restart region.
  (mezzano.lap.arm64:add :x9 :x7 #.(+ (- sys.int::+tag-object+) 8 (* sys.int::+symbol-value-cell-value+ 8)))
  ;; Atomic add. Blech, load/store linked suck.
  ATOMIC-RETRY
  (mezzano.lap.arm64:ldaxr :x6 (:x9))
  (mezzano.lap.arm64:add :x11 :x6 #.(ash 16 #.sys.int::+n-fixnum-bits+)) ; 16, size of cons
  (mezzano.lap.arm64:stlxr :w10 :x11 (:x9))
  (mezzano.lap.arm64:cbnz :x10 ATOMIC-RETRY)
  ;; RBX is old bump pointer, the address of the cons.
  ;; X11 is the new bump pointer.
  ;; Test against limit.
  (mezzano.lap.arm64:ldr :x10 (:object :x3 #.sys.int::+symbol-value-cell-value+))
  (mezzano.lap.arm64:subs :xzr :x11 :x10)
  (mezzano.lap.arm64:b.hi SLOW-PATH)
  ;; Generate the cons object.
  ;; Unfixnumize address. This still looks like a fixnum due to alignment.
  (mezzano.lap.arm64:add :x6 :xzr :x6 :lsr #.sys.int::+n-fixnum-bits+)
  ;; Set address bits, tag bits, and the mark bit.
  (mezzano.lap.arm64:ldr :x9 (:pc CONS-ADDRESS-CONS-TAG))
  (mezzano.lap.arm64:orr :x6 :x6 :x9)
  (mezzano.lap.arm64:ldr :x9 (:object :x4 #.sys.int::+symbol-value-cell-value+))
  (mezzano.lap.arm64:orr :x6 :x6 :x9)
  ;; RBX now holds a valid cons, with the CAR and CDR set to zero.
  ;; It is safe to leave the restart region.
  (:gc :no-frame :layout #*)
  ;; Initialize the CAR & CDR outside the restart region to minimise the potential restarts.
  (mezzano.lap.arm64:str :x0 (:car :x6))
  (mezzano.lap.arm64:str :x1 (:cdr :x6))
  ;; Done. Return everything.
  (mezzano.lap.arm64:orr :x0 :xzr :x6)
  (mezzano.lap.arm64:movz :x5 #.(ash 1 #.sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:ret)
  SLOW-PATH
  (mezzano.lap.arm64:ldr :x2 (:constant t))
  (mezzano.lap.arm64:movz :x5 #.(ash 3 #.sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:ret)
  (:align 16)
  CONS-ADDRESS-CONS-TAG
  (:d64/le #.(logior (ash sys.int::+address-tag-cons+ sys.int::+address-tag-shift+)
                     sys.int::+tag-cons+)))

(sys.int::define-lap-function cons ((car cdr))
  (:gc :no-frame :layout #* :incoming-arguments :rcx)
  (mezzano.lap.arm64:stp :x29 :x30 (:pre :sp -16))
  (:gc :no-frame :layout #*00 :incoming-arguments :rcx)
  ;; Attempt to quickly allocate a cons. Will call SLOW-CONS if things get too hairy.
  ;; R8 = car; R9 = cdr
  ;; Check argument count.
  (mezzano.lap.arm64:subs :xzr :x5 #.(ash 2 #.sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:b.ne SLOW-PATH-BAD-ARGS)
  (:gc :no-frame :layout #*00)
  ;; Update allocation meter.
  ;; FIXME: Should be atomic add.
  (mezzano.lap.arm64:ldr :x6 (:symbol-global-cell *cons-allocation-count*))
  (mezzano.lap.arm64:ldr :x9 (:object :x6 #.sys.int::+symbol-value-cell-value+))
  (mezzano.lap.arm64:add :x9 :x9 #.(ash 1 sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:str :x9 (:object :x6 #.sys.int::+symbol-value-cell-value+))
  (mezzano.lap.arm64:ldr :x6 (:symbol-global-cell *bytes-consed*))
  (mezzano.lap.arm64:ldr :x9 (:object :x6 #.sys.int::+symbol-value-cell-value+))
  (mezzano.lap.arm64:add :x9 :x9 #.(ash 16 sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:str :x9 (:object :x6 #.sys.int::+symbol-value-cell-value+))
  ;; Check *ENABLE-ALLOCATION-PROFILING*
  ;; FIXME: This only tests the global value.
  #| Logging every cons tends to explode the profile buffer & exhaust memory.
  (mezzano.lap.arm64:ldr :x6 (:symbol-global-cell *enable-allocation-profiling*))
  (mezzano.lap.arm64:ldr :x6 (:object :x6 #.sys.int::+symbol-value-cell-value+))
  (mezzano.lap.arm64:subs :xzr :x6 :x26)
  (mezzano.lap.arm64:b.ne SLOW-PATH)
  |#
  ;; Check *GC-IN-PROGRESS*.
  (mezzano.lap.arm64:ldr :x6 (:symbol-global-cell sys.int::*gc-in-progress*))
  (mezzano.lap.arm64:ldr :x6 (:object :x6 #.sys.int::+symbol-value-cell-value+))
  (mezzano.lap.arm64:subs :xzr :x6 :x26)
  (mezzano.lap.arm64:b.ne SLOW-PATH)
  ;; Try the real fast allocator.
  (mezzano.lap.arm64:named-call do-cons)
  (mezzano.lap.arm64:subs :xzr :x5 #.(ash 1 #.sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:b.ne SLOW-PATH)
  ;; Done. Return everything.
  (mezzano.lap.arm64:ldr :x6 (:symbol-global-cell *cons-fast-path-hits*))
  (mezzano.lap.arm64:ldr :x9 (:object :x6 #.sys.int::+symbol-value-cell-value+))
  (mezzano.lap.arm64:add :x9 :x9 #.(ash 1 sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:str :x9 (:object :x6 #.sys.int::+symbol-value-cell-value+))
  (mezzano.lap.arm64:movz :x5 #.(ash 1 #.sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:ldp :x29 :x30 (:post :sp 16))
  (:gc :no-frame :layout #*)
  (mezzano.lap.arm64:ret)
  SLOW-PATH
  (:gc :no-frame :layout #*00)
  ;; Tail call into SLOW-CONS.
  (mezzano.lap.arm64:movz :x5 #.(ash 2 #.sys.int::+n-fixnum-bits+))
  SLOW-PATH-BAD-ARGS
  (mezzano.lap.arm64:ldp :x29 :x30 (:post :sp 16))
  (:gc :no-frame :layout #* :incoming-arguments :rcx)
  (mezzano.lap.arm64:named-tail-call slow-cons))

(sys.int::define-lap-function %%make-signed-byte-64-x10 ()
  (:gc :no-frame :layout #*)
  ;; Convert to fixnum & check for unsigned overflow.
  ;; Assumes fixnum size of 1!
  (mezzano.lap.arm64:adds :x0 :x10 :x10)
  (mezzano.lap.arm64:b.vs OVERFLOW)
  ;; It's a fixnum.
  ;; Single-value return.
  (mezzano.lap.arm64:movz :x5 #.(ash 1 sys.int::+n-fixnum-bits+)) ; fixnum 1
  (mezzano.lap.arm64:ret)
  OVERFLOW
  ;; Call out to bignum builder.
  ;; Build bignum.
  (mezzano.lap.arm64:named-tail-call sys.int::%%make-bignum-64-x10))

(sys.int::define-lap-function %%make-unsigned-byte-64-x10 ()
  (:gc :no-frame :layout #*)
  ;; Convert to fixnum & check for unsigned overflow.
  ;; Assumes fixnum size of 1!
  (mezzano.lap.arm64:adds :x0 :x10 :x10)
  (mezzano.lap.arm64:b.cs OVERFLOW)
  (mezzano.lap.arm64:b.vs OVERFLOW)
  ;; It's a fixnum.
  ;; Single-value return.
  (mezzano.lap.arm64:movz :x5 #.(ash 1 sys.int::+n-fixnum-bits+)) ; fixnum 1
  (mezzano.lap.arm64:ret)
  OVERFLOW
  ;; Call out to bignum builder.
  ;; Prod the sign flag.
  (mezzano.lap.arm64:ands :xzr :x10 :x10)
  ;; Build bignum.
  ;; Result needs a 128-bit bignum when the high bit is set.
  (mezzano.lap.arm64:b.mi BIGNUM128)
  (mezzano.lap.arm64:named-tail-call sys.int::%%make-bignum-64-x10)
  BIGNUM128
  (mezzano.lap.arm64:orr :x11 :xzr :xzr)
  (mezzano.lap.arm64:named-tail-call sys.int::%%make-bignum-128-x10-x11))

;; Avoid a trip through FUNCTION-REFERENCE.
(sys.int::define-lap-function sys.int::get-raise-undefined-function-fref (())
  (:gc :no-frame :layout #*)
  (mezzano.lap.arm64:ldr :x0 (:function sys.int::raise-undefined-function))
  (mezzano.lap.arm64:movz :x5 #.(ash 1 sys.int::+n-fixnum-bits+)) ; fixnum 1
  (mezzano.lap.arm64:ret))

(sys.int::define-lap-function sys.int::%dcas-object ((object offset old-1 old-2 new-1 new-2))
  ;; object = x0
  ;; offset = x1
  ;; old-1 = x2
  ;; old-2 = x3
  ;; new-1 = x4
  ;; new-2 = [sp 0]
  (:gc :no-frame :layout #*)
  ;; Convert offset to unboxed integer (scaled appropriately), with tag adjustment.
  (mezzano.lap.arm64:add :x9 :xzr :x1 :lsl #.(- 3 sys.int::+n-fixnum-bits+))
  (mezzano.lap.arm64:add-imm :x9 :x9 #.(- 8 sys.int::+tag-object+)) ; offset of first slot
  ;; Load new-2 out of the argument area
  (mezzano.lap.arm64:ldr :x1 (:sp))
  ;; Spill new-1 and new-2, need the registers.
  (mezzano.lap.arm64:stp :x4 :x1 (:pre :sp -16))
  (:gc :no-frame :layout #*11)
  ;; Generate the address.
  ;; object must be in x1 for the gc
  (mezzano.lap.arm64:orr :x1 :xzr :x0)
  (mezzano.lap.arm64:add :x9 :x1 :x9)
  ;; Move to linked gc mode.
  ;; x9 is interior pointer into x1.
  (:gc :no-frame :layout #*11 :extra-registers :rax)
  ;; x0 = free (will be cur-1)
  ;; x1 = object
  ;; x2 = old-1
  ;; x3 = old-2
  ;; x4 = free (will be cur-2)
  ;; x9 = slot-address (linked to x1)
  ;; [sp 0] = new-1
  ;; [sp 8] = new-2
  LOOP
  ;; Load current values
  (mezzano.lap.arm64:ldaxp :x0 :x4 (:x9))
  ;; Compare values.
  (mezzano.lap.arm64:subs :xzr :x0 :x2)
  (mezzano.lap.arm64:b.ne FAIL)
  (mezzano.lap.arm64:subs :xzr :x4 :x3)
  (mezzano.lap.arm64:b.ne FAIL)
  ;; Success! Reload the new values
  (mezzano.lap.arm64:ldp :x4 :x1 (:sp))
  ;; Store linked new value, status in X10.
  (mezzano.lap.arm64:stlxp :w10 :x4 :x1 (:x9))
  ;; Retry on failure.
  (mezzano.lap.arm64:cbnz :x10 LOOP)
  ;; Success!
  (mezzano.lap.arm64:ldr :x0 (:constant t)) ; first return value, T
  (mezzano.lap.arm64:orr :x1 :xzr :x2) ; second return value, old-1
  (mezzano.lap.arm64:orr :x2 :xzr :x3) ; third return value, old-2
  (mezzano.lap.arm64:movz :x5 #.(ash 3 sys.int::+n-fixnum-bits+)) ; three return values
  ;; pop saved new values
  (mezzano.lap.arm64:add :sp :sp 16)
  (:gc :no-frame :layout #*)
  (mezzano.lap.arm64:ret)
  FAIL
  (:gc :no-frame :layout #*11)
  (mezzano.lap.arm64:orr :x0 :xzr :x26) ; first return value, NIL
  (mezzano.lap.arm64:orr :x1 :xzr :x0) ; second return value, cur-1
  (mezzano.lap.arm64:orr :x2 :xzr :x4) ; third return value, cur-2
  (mezzano.lap.arm64:movz :x5 #.(ash 3 sys.int::+n-fixnum-bits+)) ; three return values
  ;; pop saved new values
  (mezzano.lap.arm64:add :sp :sp 16)
  (:gc :no-frame :layout #*)
  (mezzano.lap.arm64:ret))

(defun %ub64-= (x y) (eql x y))
(defun %ub64-< (x y) (< x y))
(defun %fast-ub64-+ (x y) (+ x y))
(defun %fast-ub64-- (x y) (- x y))
(defun %fast-ub64-* (x y) (* x y))
(defun %fast-ub64-truncate (x y) (truncate x y))
(defun %fast-ub64-logior (x y) (logior t x y))
(defun %fast-ub64-logxor (x y) (logxor t x y))
(defun %fast-ub64-logand (x y) (logand t x y))
(defun %ub64-right-shift-in-limits (x y) (ash x (- y)))

(defun %sb64-= (x y) (eql x y))
(defun %sb64-< (x y) (< x y))
(defun %fast-sb64-+ (x y) (+ x y))
(defun %fast-sb64-- (x y) (- x y))
(defun %fast-sb64-* (x y) (* x y))
(defun %fast-sb64-truncate (x y) (truncate x y))
(defun %fast-sb64-logior (x y) (logior t x y))
(defun %fast-sb64-logxor (x y) (logxor t x y))
(defun %fast-sb64-logand (x y) (logand t x y))
(defun %sb64-right-shift-in-limits (x y) (ash x (- y)))
