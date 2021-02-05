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

(load-shared-object "/usr/lib/libc.so.6")
(define fork (foreign-procedure #f "fork" () unsigned))
;(define waitpid (foreign-procedure #f "waitpid" (unsigned uptr unsigned) integer-32))
(define wait (foreign-procedure #f "wait" (uptr) integer-32))
(define mmap (foreign-procedure #f "mmap" (uptr unsigned integer-32 integer-32 integer-32 unsigned) uptr))
(define shmem (mmap 0 8 3 33 -1 0))

(define tt-run
  (lambda (pid)
    (if (> pid 0) (begin
      (wait 0)
      (foreign-ref 'integer-64 shmem 0)
    ) 'temporary-timeline)))
(define tt-send (lambda (x) (begin
  (foreign-set! 'integer-64 shmem 0 3)
  (exit))))
(define tt-recv (lambda () (tt-run (fork))))

(set! strategized 0)
(set! running 0)
(define apiomemetics
  (lambda (x y)
    (if (null? x)
        (if (= running 0) (let ((ttr (tt-recv))) (if (eq? ttr 'temporary-timeline)
          (begin (set! running 1) (display "temporary TL\n") 0)
          (begin (set! running 1) (display "primary TL, got result ") (display ttr) (newline) (set! strategized 1) 0))) 0)
        (if (= (length x) 99)
          (if (= strategized 0) (begin
            (display "end of game, reversing\n")
            (tt-send 3)
          ) (begin
            (set! running 0)
            (display "end of game in primary\n")
            0
          ))
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
    (define helper
      (lambda (y)
        (if (eqv? (car x) (car y))
            0
            (set! score (+ score (car (iter-prisond (cdr x) (cdr y) 100)))))))
    (map helper strategies)
    score))

(define get-all-scores
  (lambda ()
    (define helper
      (lambda (x)
        (write (list (car x) (get-strategy-scores x)))
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
(add-strategy 'apiomemetics apiomemetics)

(random-seed (time-second (current-time)))

(get-all-scores)
(exit)
