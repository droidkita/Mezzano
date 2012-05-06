(in-package #:sys.int)

(defconstant +vbe-dispi-max-xres+              1600)
(defconstant +vbe-dispi-max-yres+              1200)
(defconstant +vbe-dispi-max-bpp+               32)

(defconstant +vbe-dispi-ioport-index+          #x01CE)
(defconstant +vbe-dispi-ioport-data+           #x01CF)

(defconstant +vbe-dispi-index-id+              0)
(defconstant +vbe-dispi-index-xres+            1)
(defconstant +vbe-dispi-index-yres+            2)
(defconstant +vbe-dispi-index-bpp+             3)
(defconstant +vbe-dispi-index-enable+          4)
(defconstant +vbe-dispi-index-bank+            5)
(defconstant +vbe-dispi-index-virt-width+      6)
(defconstant +vbe-dispi-index-virt-height+     7)
(defconstant +vbe-dispi-index-x-offset+        8)
(defconstant +vbe-dispi-index-y-offset+        9)
(defconstant +vbe-dispi-index-video-memory+    10)

(defconstant +vbe-dispi-id0+                   #xB0C0)
(defconstant +vbe-dispi-id1+                   #xB0C1)
(defconstant +vbe-dispi-id2+                   #xB0C2)
(defconstant +vbe-dispi-id3+                   #xB0C3)
(defconstant +vbe-dispi-id4+                   #xB0C4)
(defconstant +vbe-dispi-id5+                   #xB0C5)

(defconstant +vbe-dispi-disabled+              #x00)
(defconstant +vbe-dispi-enabled+               #x01)
(defconstant +vbe-dispi-getcaps+               #x02)
(defconstant +vbe-dispi-8bit-dac+              #x20)
(defconstant +vbe-dispi-lfb-enabled+           #x40)
(defconstant +vbe-dispi-noclearmem+            #x80)

(defconstant +vbe-dispi-lfb-physical-address+  #xE0000000)
(defvar *bochs-vbe-framebuffer-address* nil)

(defun write-vbe-reg (index value)
  (setf (io-port/16 +vbe-dispi-ioport-index+) index
	(io-port/16 +vbe-dispi-ioport-data+) value))

(defun read-vbe-reg (index)
  (setf (io-port/16 +vbe-dispi-ioport-index+) index)
  (io-port/16 +vbe-dispi-ioport-data+))

(defun probe-bochs-vbe ()
  (write-vbe-reg +vbe-dispi-index-id+ +vbe-dispi-id0+)
  (write-vbe-reg +vbe-dispi-index-id+ +vbe-dispi-id1+)
  (write-vbe-reg +vbe-dispi-index-id+ +vbe-dispi-id2+)
  (write-vbe-reg +vbe-dispi-index-id+ +vbe-dispi-id3+)
  (write-vbe-reg +vbe-dispi-index-id+ +vbe-dispi-id4+)
  (write-vbe-reg +vbe-dispi-index-id+ +vbe-dispi-id5+)
  (let ((id (read-vbe-reg +vbe-dispi-index-id+)))
    (when (= (logand id #xfff0) #xb0c0)
      (format t "Bochs VBE adaptor present. Version ~S~%" (logand id #xf))
      (when (>= id +vbe-dispi-id3+)
	(write-vbe-reg +vbe-dispi-index-enable+ +vbe-dispi-getcaps+)
	(format t " Maximum resolution: ~Sx~Sx~S~%"
		(read-vbe-reg +vbe-dispi-index-xres+)
		(read-vbe-reg +vbe-dispi-index-yres+)
		(read-vbe-reg +vbe-dispi-index-bpp+)))
      (let ((framebuffer (pci-get-lfb-addr #x1234 #x1111)))
	(if framebuffer
	  (setf *bochs-vbe-framebuffer-address* framebuffer)
	  (setf *bochs-vbe-framebuffer-address* +vbe-dispi-lfb-physical-address+)))
      (format t " Framebuffer at #x~X~%" *bochs-vbe-framebuffer-address*)
      t)))

(defun set-bochs-vbe-mode (xres yres bpp)
  (write-vbe-reg +vbe-dispi-index-enable+ +vbe-dispi-disabled+)
  (write-vbe-reg +vbe-dispi-index-xres+ xres)
  (write-vbe-reg +vbe-dispi-index-yres+ yres)
  (write-vbe-reg +vbe-dispi-index-bpp+ bpp)
  (write-vbe-reg +vbe-dispi-index-enable+ (logior +vbe-dispi-enabled+ +vbe-dispi-lfb-enabled+)))

(defun pci-get-lfb-addr (vendor-id device-id)
  (dolist (dev *pci-devices*)
    (when (and (eql (pci-device-vendor-id dev) vendor-id)
	       (eql (pci-device-device-id dev) device-id))
      (let ((data (pci-bar dev 0)))
	(when (not (eql (logand data #xFFF1) 0))
	  (return nil))
	(return (logand data #xFFFF0000))))))

(defvar *bochs-framebuffer* nil)

(defun set-gc-light ()
  (when (and (boundp '*bochs-framebuffer*)
             *bochs-framebuffer*)
    (dotimes (i 8)
      (setf (aref *bochs-framebuffer* 0 i) (ldb (byte 24 0) (lognot (aref *bochs-framebuffer* 0 i)))))))

(defun clear-gc-light ()
  (when (and (boundp '*bochs-framebuffer*)
             *bochs-framebuffer*)
    (dotimes (i 8)
      (setf (aref *bochs-framebuffer* 0 i) (ldb (byte 24 0) (lognot (aref *bochs-framebuffer* 0 i)))))))

(add-hook '*initialize-hook*
          #'(lambda ()
              (when (probe-bochs-vbe)
                (set-bochs-vbe-mode 800 600 32)
                (setf *bochs-framebuffer* (make-array '(600 800)
                                                :element-type '(unsigned-byte 32)
                                                :memory (+ #x8000000000 *bochs-vbe-framebuffer-address*))
                      *terminal-io* (make-instance 'framebuffer-stream
                                                   :framebuffer *bochs-framebuffer*)))))
