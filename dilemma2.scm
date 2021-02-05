;; prisond.scm: iterated prisoner's dilemma simulation
;; by matt
;; this program is in the public domain

(define strategies '())

(define add-strategy
  (lambda (x y)
    (set! strategies (cons (cons x y) strategies))))

(define angel
  (lambda (x y) 0))

(define devil
  (lambda (x y) 1))

(define tat-for-tit
  (lambda (x y)
    (if (null? x)
        1
        (if (= (car x) 0)
            1
            0))))

(define tit-for-tat
  (lambda (x y)
    (if (null? x)
        0
        (car x))))

(define time-machine
  (lambda (x y)
    (if (> 3 (length x))
        0
        (caddr x))))

(define random-choice
  (lambda (x y)
    (random 2)))

(define grudger
  (lambda (x y)
    (if (memq 1 x)
        1
        0)))

(define angry-tit-for-tat
  (lambda (x y)
    (if (null? x)
        1
        (car x))))

(define apl
  (lambda (x y)
    (if (null? x)
        1
        (if (= ( car y) 0)
            1
            0))))

(define forgiving-grudge
  (lambda (x y) (let* (
    (defection-count (length (filter (lambda (m) (= m 1)) x)))
    (result (if (> defection-count 3) 1 0))
  ) result)))

(define (take n xs)
  (let loop ((n n) (xs xs) (zs (list)))
    (if (or (zero? n) (null? xs))
        (reverse zs)
        (loop (- n 1) (cdr xs)
              (cons (car xs) zs)))))

(define (zip . xss) (apply map list xss))

(define actually-forgiving-grudge
  (lambda (x y) (let* (
    (defection-count (length (filter (lambda (m) (= m 1)) x)))
    (lookback (+ 1 (inexact->exact (floor (expt 1.8 defection-count)))))
    (result (if (member '(1 0) (take lookback (zip x y))) 1 0))
  ) result)))

(define apiomemetics
  (lambda (x y) (random-seed 334278294) ; NOTE TO SELF: 3227883998 (0/1)
    (if (null? x)
        (begin 0)
        (if (> (length x) 93)
            1
            (car x)))))

(define meapiometics
  (lambda (x y)
    (if (null? x)
        0
        (if (> (length x) 97)
            1
            (car x)))))

(define prisond
  (lambda (x y)
    (if (= x y)
        (if (= x 1)
            '(-2 -2)
            '(-1 -1))
        (if (= x 1)
            '(0 -3)
            '(-3 0)))))

(define iter-prisond
  (lambda (x y z)
    (define scores '(0 0))
    (define moves-x '())
    (define moves-y '())
    (define current-moves '())
    (define helper
      (lambda (x y z)
        (if (= z 0)
            scores
            (begin
              (set! current-moves (list (x moves-x moves-y) (y moves-y moves-x)))
              (set! moves-x (cons (cadr current-moves) moves-x))
              (set! moves-y (cons (car current-moves) moves-y))
              (set! scores (map + scores (prisond (car current-moves) (cadr current-moves))))
              (helper x y (- z 1)))))) (helper x y z)))

(define get-strategy-scores
  (lambda (x)
    (define score 0)
    (define iters (+ 100 (random 50)))
    (define helper
      (lambda (y)
        (if (eqv? (car x) (car y))
            0
            (set! score (+ score (car (iter-prisond (cdr x) (cdr y) iters)))))))
    (map helper strategies)
    score))

(define get-repeated-score
  (lambda (strategy accumulator counter)
    (if (= counter 0) accumulator 
      (get-repeated-score strategy 
        (+ accumulator (get-strategy-scores strategy))
        (- counter 1)))))

(define get-all-scores
  (lambda ()
    (define helper
      (lambda (x)
        (write (list (car x) (get-repeated-score x 0 50)))
        (newline)))
    (map helper strategies)))

(add-strategy 'angel angel)
(add-strategy 'devil devil)
(add-strategy 'tit-for-tat tit-for-tat)
(add-strategy 'tat-for-tit tat-for-tit)
(add-strategy 'time-machine time-machine)
(add-strategy 'random-choice random-choice)
(add-strategy 'grudger grudger)
(add-strategy 'angry-tit-for-tat angry-tit-for-tat)
(add-strategy 'apl apl)
(add-strategy 'meapiometics meapiometics)
(add-strategy 'apiomemetics apiomemetics)
(add-strategy 'forgiving-grudge forgiving-grudge)
(add-strategy 'actually-forgiving-grudge actually-forgiving-grudge)

(random-seed (time-second (current-time)))

(get-all-scores)
(exit)
