(in-package #:tpd2.webapp)

#+use-ps-console.log
(pushnew :use-ps-console.log *features*)

(ps:defpsmacro debug-log (&rest args)
  (declare (ignorable args))
  #+use-ps-console.log 
  `(when (and (~ window console) (~ console log))
     (! (console log) ,@args)))

(ps:defpsmacro ! ((&rest object-paths) &rest args )
  `(funcall (~ ,@object-paths) ,@args))

(ps:defpsmacro ~ (&rest object-paths)
  (let ((slot (first (last object-paths)))
	(object-paths (butlast object-paths)))
    (cond ((not object-paths)
	   slot)
	  (t
	   `(slot-value 
	     ,(if (rest object-paths)
		 `(~ ,@object-paths)
		 (first object-paths))
	     ',slot)))))

(ps:defpsmacro eq (a b)
  `(ps:=== ,a ,b))
(ps:defpsmacro equal (a b)
  `(ps:== ,a ,b))

(ps:defpsmacro ignore-errors (&body body)
  `(ps:try (progn 
	  ,@body) 
	(:catch (e) 		    
	  (debug-log "IGNORING ERROR" e))))

(defun js-library ()
  (read-only-load-time-value 
   (force-byte-vector 
    (js-html-script
      (defvar *alive* nil)
      (defvar *channels-url*)
      (defvar *active-request*)

      (defun find-element (element-id)
	(return (! (document get-element-by-id) element-id)))

      (defun handle-special-elements (parent)
	(dolist (element (! (parent get-elements-by-tag-name) "a"))
	  (when (equal (~ element class-name) (unquote +action-link-class+))
	    (setf (~ element href) (+ "javascript:asyncSubmitLinkHref(\'" (~ element href) "\')"))))
	(dolist (element (! (parent get-elements-by-tag-name) "div"))
	  (when (equal (~ element class-name) (unquote +html-class-scroll-to-bottom+))
	    (setf (~ element scroll-top) (~ element scroll-height)))
	  (when (equal (~ element class-name) (unquote +html-class-collapsed+))
	    (toggle-hiding element))))

      (defun reset-element (element content)
	(setf (~ element inner-h-t-m-l) content)
	(handle-special-elements element)
	(dolist (script (! (element get-elements-by-tag-name) "script"))
	  (eval (~ script inner-h-t-m-l))))

      (defun reset-element-id (element-id content)
	(reset-element (find-element element-id) content))

      (defun append-element-id (element-id content)
	(let ((element (find-element element-id)))
	  (+= (~ element inner-h-t-m-l) content)))

      (defun make-xml-http-request ()
	(if (~ window *X-M-L-Http-Request)
	    (return (new *X-M-L-Http-Request))
	    (return (new (*Active-X-Object "Microsoft.XMLHTTP")))))

      (defun channels-get-param ()
	(let ((lines (make-array)))
	  (ps:for-in (channel *channels*)
		     (! (lines push) (+ (encode-U-R-I-component channel) "|" (aref *channels* channel))))
	  (return (+ ".channels.=" (! (lines join) ";")))))

      (defun add-params-to-url-for-get (url &optional (params ""))
	(return (+ url (if (equal -1 (! (url search) "\\?")) "?" "&") params)))

      (defun fetch-channels ()
	(when (and *channels* (not (= 0 (~ *channels* size))))
	  (async-request (add-params-to-url-for-get *channels-url* (channels-get-param))
			 nil)))

      (defun maybe-fetch-channels ()
	(unless *active-request*
	  (fetch-channels)))

      (defun async-request-done (req url)
	(debug-log "async request received" req)
	(unless (eq req *active-request*)
	  (return))
	(set-async-status nil)
	(setf *active-request* nil)

	(let ((success nil))
	  (ignore-errors
	    (setf success (and req (= 200 (~ req status)) (~ req response-text))))

	  (cond (success
		 (debug-log "async request completed okay" req)
		 (ignore-errors
		   (eval (~ req response-text))
		   (debug-log "safely evaluated response" req (~ req response-text)))
		 (maybe-fetch-channels))
		(t
		 (debug-log "async request unsuccessful" req)
		 (if (~ req tpd2-retry)
		     (ps:do-set-timeout (500)
		       (async-request url "Retrying"))
		     (maybe-fetch-channels))))))

      (defun now ()
	(return (ps:new *Date)))

      (defun async-request (url initial-status)
	(setf *alive* (now))
	(debug-log "requesting" url initial-status)
	(ps:try
	 (progn
	   (let ((tmp *active-request*))
	     (setf *active-request* nil)
	     (when tmp
	       (debug-log "to achieve the request, first aborting" tmp)
	       (ignore-errors
		 (! (tmp abort)))))
	 
	   (set-async-status initial-status)

	   (let ((req (make-xml-http-request)))
	     (when initial-status
	       (setf (~ req tpd2-retry) t))

	     (setf *active-request* req)
	   
	     (setf (~ req onreadystatechange) 
		   (lambda ()
		     (case (~ req ready-state)
		       (4 
			(async-request-done req url)))))

	     (! (req open) "GET" url t)
	     (! (req send) "")))
	 (:catch (e)
	   (debug-log "async request was not started" url initial-status e)
	   (return -1)))
	(return 0))

      (defun async-submit-form (form)
	(let ((inputs (~ form elements))
	      (params (make-array)))
	  (dolist (input inputs)
	    (when (and (~ input name) (~ input value))
	      (! (params push) (+ (encode-U-R-I-component (~ input name)) "=" (encode-U-R-I-component (~ input value))))))
	  (return (async-submit-link (add-params-to-url-for-get (~ form action) (! (params join) "&"))))))

      (defun async-submit-link (link)
	(if (async-request (add-params-to-url-for-get link (+ ".javascript.=t&"
							      (channels-get-param))) "sending")
	    (return true) ; error occurred so actually submit the form normally
	    (return false)))

      (defun async-submit-link-href (link)
	(when (async-submit-link link)
	  (setf (~ window location) link)))

      (defvar *channels*)
      (unless *channels* (setf *channels* (ps:new *object)))
   
      (defun channel (name counter)
	(setf (aref *channels* name) (max (if (aref *channels* name) (aref *channels* name) 0) counter)))

      (defun set-async-status (status)
	(let ((element))
	  (ignore-errors (setf element (find-element (unquote +html-id-async-status+))))
	  (when element
	    (cond ((not status)
		   (setf (~ element style display) "none"))
		  (t
		   (setf (~ element style display) ""
			 (~ element inner-h-t-m-l) status))))))

      (defun toggle-hiding (element)
	(setf (~ element style display)
	      (if (equal "none" (~ element style display))
		  ""
		  "none")))))))

(defun js-library-footer ()
  (js-html-script
    (handle-special-elements (~ document body))

    (defun watchdog ()
      (debug-log "watchdog" (now) *alive* *active-request*)
      (unless (and *active-request* (>= (~ *active-request* ready-state) 1) (< (~ *active-request* ready-state) 4))
	(let ((a *alive*))
	  (setf *alive* nil)
	  (debug-log "watchdog reseting" 
		     a 
		     (if a (~ *active-request* ready-state)))
	  (unless a
	   (fetch-channels))))
      (ps:do-set-timeout (15000) 
	(watchdog)))

    (watchdog)))

