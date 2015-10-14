needsPackage "NumericalSchubertCalculus"
setRandomSeed 2

--Problem X^2X11^2X21 in G(3,6)
 --a problem with 4 solutions
SchPblm = randomSchubertProblemInstance(
  rsort{ {1},{1},{1, 1},{1, 1},{2, 1}},3,6);
time S = solveSchubertProblem(SchPblm, 3,6);
assert all(S,s->checkIncidenceSolution(s, SchPblm))

 end
 ------

restart
load "NumericalSchubertCalculus/EXA/ProblemsG36/21x11e2x1e2-G36.m2"
 ------