WITH RECURSIVE c(x)AS(VALUES(99)UNION ALL SELECT x-1 FROM c WHERE x>0),a(x, s)AS(SELECT x,SUBSTR(' bottles',1,(x<>1)+7)||' of beer'FROM c)SELECT PRINTF('%d%s on the wall
%d%s
Take one down, pass it around
%d%s on the wall',a.x,a.s,a.x,a.s,a.x-1,b.s)FROM a JOIN a AS b ON b.x=a.x-1;
