;; pd2.scm - iterated prisoner's dilemma simulation but you know your opponent's strategy
;; by matt
;; this program is in the public domain

(import (chicken random))

(define strategies '())

(define iters 0)

(define add-strategy
  (lambda (x y)
    (set! strategies (cons (cons x y) strategies))))

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
              (set! current-moves (list (x moves-x moves-y y) (y moves-y moves-x x)))
              (set! moves-x (cons (cadr current-moves) moves-x))
              (set! moves-y (cons (car current-moves) moves-y))
              (set! scores (map + scores (prisond (car current-moves) (cadr current-moves))))
              (helper x y (- z 1)))))) (helper x y z)))

(define get-strategy-scores
  (lambda (x)
    (define score 0)
    (define helper
      (lambda (y)
        (if (eqv? (car x) (car y))
            0
            (set! score (+ score (car (iter-prisond (cdr x) (cdr y) (+ 100 iters))))))))
    (map helper strategies)
    score))

(define get-all-scores
  (lambda ()
    (define helper
      (lambda (x)
        (write (list (car x) (get-strategy-scores x)))
        (newline)))
  (map helper strategies)))

(define angel
  (lambda (x y z)
    0))

(define devil
  (lambda (x y z)
    1))

(define tit-for-tat
  (lambda (x y z)
    (if (null? x)
        0
        (car x))))

(define grudger
  (lambda (x y z)
    (if (memq 1 y)
        1
        0)))

(add-strategy 'angel angel)
(add-strategy 'devil devil)
(add-strategy 'tit-for-tat tit-for-tat)
(add-strategy 'grudger grudger)

(set-pseudo-random-seed! (random-bytes))
(set! iters (pseudo-random-integer 50))

(get-all-scores)
