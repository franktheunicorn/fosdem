(define Y
  (lambda (f)
    ((lambda (g) (g g))
     (lambda (g)       
       (f  (lambda a (apply (g g) a))))))) 
       
(define wat
  (Y (lambda (expr)
       (lambda (env)
    (pmatch expr
      [`,x (guard (symbol? x))
        (env x)]
      [`(lambda (,x) ,body)
        (lambda (arg)
          (eval-expr body (lambda (y)
                            (if (eq? x y)
                                arg
                                (env y)))))]
      [`(,rator ,rand)
       ((eval-expr rator env)
        (eval-expr rand env))]))
       )))
