#!/usr/bin/bc -l
scale=10000

num_iters = 3
a=1
b=1/sqrt(2)
t=1/4
p=1

for (i = 1; i <= num_iters; i++) {
  an = (a + b) / 2
  bn = sqrt(a * b)
  tn = t - p * (a - an) * (a - an)
  pn = 2 * p
  
  a = an
  b = bn
  t = tn
  p = pn
}

pi = (a + b) * (a + b) / (4 * t)
print "pi = ", pi, "\n"

