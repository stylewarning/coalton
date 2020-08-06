;;; library.lisp

(cl:in-package #:coalton-user)

(coalton-toplevel
  ;; Defined in early-types.lisp
  #+ignore
  (define-type Unit
    Unit)

  #+ignore
  (define-type Void)

  (define-type coalton:Boolean
    coalton:True
    coalton:False)

  (define-type (Maybe t)
    Nothing
    (Just t))

  (define-type (Either a b)
    (Left a)
    (Right b))

  (define-type (Liszt t)
    Knil
    (Kons t (Liszt t)))

  (define-type (Binary-Tree s t)
    (Leaf s)
    (Branch t (Binary-Tree s t) (Binary-Tree s t))))

(cl:defmacro Liszt (cl:&rest list-elements)
  (cl:reduce (cl:lambda (x acc)
               `(Kons ,x ,acc))
             list-elements
             :from-end cl:t
             :initial-value 'Knil))

(cl:defmacro coalton:if (expr then else)
  `(match ,expr
     (True ,then)
     (False ,else)))

(cl:defmacro coalton:cond ((clause-a then-a) cl:&rest clauses)
  (cl:if (cl:not (cl:endp clauses))
         `(if ,clause-a
              ,then-a
              (cond ,@clauses))
         (cl:progn
           (cl:assert (cl:eq 'else clause-a) () "COALTON:COND must have an ELSE clause.")
           then-a)))

(cl:declaim (cl:inline lisp-boolean-to-coalton-boolean))
(cl:defun lisp-boolean-to-coalton-boolean (x)
  (cl:if x True False))


;;; Erroring
(coalton-toplevel
 (declare error (fn String -> t))
 (define (error str)
   (lisp t (cl:error "~A" str))))

;;; Combinators
(coalton-toplevel
  (define (ignore x)     Unit)
  (define (identity x)   x)
  (define (constantly x) (fn (y) x))
  (define (flip f)       (fn (x y) (f y x)))
  (define (compose f g)  (fn (x) (f (g x))))
  (define (curry f)      (fn (x) (fn (y) (f x y)))))

;;; Boolean
(coalton-toplevel
  (define (not x)          (if x False True))
  (define (binary-and x y) (if x y False))
  (define (binary-or x y)  (if x True y))
  (define (complement f)   (compose not f)))

(cl:defmacro and (x cl:&rest xs)
  (cl:reduce (cl:lambda (x acc)
               `(binary-and ,x ,acc))
             (cl:cons x xs)
             :from-end cl:t))

(cl:defmacro or (x cl:&rest xs)
  (cl:reduce (cl:lambda (x acc)
               `(binary-or ,x ,acc))
             (cl:cons x xs)
             :from-end cl:t))

;;; Strings
(coalton-toplevel
  (declare concat (fn String String -> String))
  (define (concat a b) (lisp String
                         (cl:concatenate 'cl:string a b)))

  (declare string-length (fn String -> Integer))
  (define (string-length s) (lisp Integer (cl:length s))))

;;; Comparators and Predicates
(cl:macrolet ((define-comparators (cl:&rest names)
                `(coalton-toplevel
                   ,@(cl:loop
                        :for op :in names
                        :for clop := (cl:intern (cl:symbol-name op) :cl)
                        :append (cl:list
                                 `(declare ,op (fn Integer Integer -> Boolean))
                                 `(define (,op x y) (lisp Boolean
                                                      (lisp-boolean-to-coalton-boolean
                                                       (,clop x y))))))))
              (define-predicates (cl:&rest names)
                `(coalton-toplevel
                   ,@(cl:loop
                        :for op :in names
                        :for clop := (cl:intern (cl:symbol-name op) :cl)
                        :append (cl:list
                                 `(declare ,op (fn Integer -> Boolean))
                                 `(define (,op x) (lisp Boolean
                                                    (lisp-boolean-to-coalton-boolean
                                                     (,clop x)))))))))
  (define-comparators = /= > < >= <=)
  (define-predicates evenp oddp plusp minusp zerop))


#+igno
(coalton-toplevel
  (define-class (Eq a)
    (== (fn a a -> Boolean)))

  ;; (fn (Eq a) => a a -> Boolean)
  (define (/= a b) (not (== a b)))

  (define-instance (Eq Boolean)
    (define (== a b)
      (or (and a       b)
          (and (not a) (not b)))))

  (define-instance ((Eq a) => (Eq (Maybe a)))
    (define (== a b)
      (match a
        ((Just x) (match b
                    ((Just y) (== x y))
                    (Nothing  coalton:False)))
        (Nothing  (match b
                    ((Just _) coalton:False)
                    (Nothing  coalton:True)))))))

;;; Arithmetic
(coalton-toplevel
  (declare + (fn Integer Integer -> Integer))
  (define (+ x y) (lisp Integer (cl:+ x y)))
  (define (1+ x) (+ 1 x))

  (declare - (fn Integer Integer -> Integer))
  (define (- x y) (lisp Integer (cl:- x y)))
  (define (1- x) (- x 1))
  (define (~ x) (- 0 x))                ; ML-ism

  (declare * (fn Integer Integer -> Integer))
  (define (* x y) (lisp Integer (cl:* x y)))
  (define (double n) (* n 2))

  (declare / (fn Integer Integer -> Integer))
  (define (/ x y) (lisp Integer (cl:values (cl:floor x y))))
  (define (half n) (/ n 2))

  (define (safe-/ x y) (if (zerop y)
                           Nothing
                           (Just (/ x y)))))

;;; Mutable Cells
(coalton-toplevel
  (define-type (Ref t)
    (Ref t))

  (declare mutate-cell (fn (Ref t) t -> Unit))
  (define (mutate-cell r v)
    (lisp Unit
      (cl:progn
        (cl:setf (cl:svref (cl:slot-value r 'coalton-impl::value) 0) v)
        Unit))))

(coalton-toplevel
  (define (gcd u v)
    (cond ((= u v)   u)
          ((zerop u) v)
          ((zerop v) u)
          ((evenp u) (if (evenp v)
                         (double (gcd (half u) (half v)))
                         (gcd (half u) v)))
          (else      (cond ((evenp v) (gcd u (half v)))
                           ((> u v)   (gcd (half (- u v)) v))
                           (else      (gcd (half (- v u)) u)))))))

;;; Random examples
(coalton-toplevel
  (define (fact1 n)
    (letrec ((%fact (fn (n answer)
                      (if (zerop n)
                          answer
                          (%fact (1- n) (* n answer))))))
      (%fact n 1)))

  (define (car x)
    (match x
      (Knil       (error "Can't take CAR of KNIL"))
      ((Kons a b) a)))

  (define (cdr x)
    (match x
      (Knil       Knil)
      ((Kons a b) b)))

  ;; (define (length l)  (fold (fn (x acc) (1+ acc)) 0 l))
  (define (length l)
    (letrec ((%length
              (fn (l n)
                (match l
                  (Knil       n)
                  ((Kons a b) (%length b (1+ n)))))))
      (%length l 0)))

  (define (map f x)
    (match x
      (Knil       Knil)
      ((Kons x xs) (Kons (f x) (map f xs)))))

  (define (mapper f) (fn x (map f x)))

  (define (fold f init l)
    (match l
      (Knil        init)
      ((Kons x xs) (fold f (f x init) xs))))

  (define (tabulate f n)
    (letrec ((%tabulate
              (fn (n l)
                (if (zerop n)
                    l
                    (%tabulate (1- n)
                               (Kons (f (1- n)) l))))))
      (%tabulate n Knil)))

  (define (range a b)
    (cond
      ((>= a b) Knil)
      (else
       (tabulate ((curry +) a) (- b a))))))

(coalton-toplevel
  (define (reverse l) (fold Kons Knil l))
  (define (sum l)     (fold + 0 l))
  (define (product l) (fold * 1 l))

  (define (keep-if f l)                 ; AKA filter
    (fold (fn (x acc)
            (if (f x)
                (Kons x acc)
                acc))
          Knil
          l))

  (define (remove-if f l) (keep-if (complement f) l))

  (define (replicate x n) (tabulate (constantly x) n))
  (define (iota n) (tabulate identity n))
  (define (range a b) (tabulate ((curry +) a) (- b a)))

  (define (fact2 n) (product (range 1 (1+ n)))))

;; Grab Bag
(coalton-toplevel
  (declare integer-name (fn Integer -> String))
  (define (integer-name n)
    (lisp String
      (cl:format cl:nil "~R" n))))
