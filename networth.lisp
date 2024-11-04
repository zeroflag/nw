(defpackage :networth
  (:use :cl)
  (:import-from :dexador)
  (:import-from :com.inuoe.jzon)
  (:export :wealth :main))

(require :groupby)

(load "holdings.lisp")

(defparameter ENDPOINT "https://query1.finance.yahoo.com/v8/finance/chart")

(defun build-url (base path)
  (concatenate 'string base "/" path))

(defun stock-url (ticker)
  (build-url ENDPOINT ticker))

(defun fetch (url)
  (let ((retry-request (dex:retry-request 2 :interval 1)))
    (handler-bind ((dex:http-request-failed retry-request))
      (dex:get url :verbose nil))))

(defun extract-price (json)
  (let* ((chart    (gethash "chart" json))
         (result   (gethash "result" chart))
         (data     (aref result 0))
         (meta     (gethash "meta" data))
         (price    (gethash "regularMarketPrice" meta))
         (currency (gethash "currency" meta)))
    (if (string= "GBp" currency)
        (values (/ price 100) currency)
        (values price currency))))

(defun stock-price (ticker)
  (handler-case
      (extract-price
       (com.inuoe.jzon:parse
        (fetch (stock-url ticker))))
    (dex:http-request-failed (e)
      (format *error-output*
              "Error: ~D for ticker: ~s"
              (dex:response-status e)
              ticker)
      (values nil nil))))

(defun with-price (pair)
  (let ((ticker (car pair))
        (amount (cdr pair)))
    (multiple-value-bind (price currency)
        (stock-price ticker)
      (if (and price currency)
          (list ticker (* amount price) currency)
          (list ticker nil nil)))))

(defun with-prices (alist) (mapcar 'with-price alist))

(defun portfolio ()
  (concatenate 'list (with-prices *stock-holdings*) *bond-holdings*))

(defun sum-by-currency (same-currency-group)
  (let* ((currency (first same-currency-group))
         (sum      (apply '+ (mapcar 'second (second same-currency-group)))))
    (list currency sum)))

(defun memoize (fn)
  (let ((cache (make-hash-table :test #'equal)))
    (lambda (&rest args)
      (or (gethash args cache)
          (setf (gethash args cache) (apply fn args))))))

(defun xchg-rate (source target)
  (nth-value 0 (stock-price (concatenate 'string source target "=X"))))

(defparameter *memoized-xchg-rate* (memoize #'xchg-rate))

(defun convert (target-currency money)
  (let ((currency (first money))
        (amount   (second money)))
    (if (string= currency target-currency)
        money
        (list target-currency
              (/ amount (xchg-rate target-currency currency))))))

(defun wealth (&optional (currency "EUR"))
  (let*
      ((all-holdings       (portfolio))
       (currency-group     (gb:groupby 'third all-holdings :test 'equal))
       (summed-by-currency (mapcar 'sum-by-currency currency-group)))
    (format t "All: ~A~%" all-holdings)
    (format t "Groups: ~A~%" currency-group)
    (format t "Sums: ~A~%" summed-by-currency)
    (apply '+
           (mapcar
            (lambda (each) (second (convert currency each)))
            summed-by-currency))))

(defun main ()
  (format t "Calculating net worth...~%")
  (format t "Total net worth: ~:d EUR~%" (round (wealth "EUR"))))
