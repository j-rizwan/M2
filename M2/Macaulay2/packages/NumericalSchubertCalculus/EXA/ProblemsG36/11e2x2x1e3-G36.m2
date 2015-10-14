needsPackage "NumericalSchubertCalculus"
setRandomSeed 2

--Problem X^3X2X11^2 in G(3,6)
 --a problem with 5 solutions
SchPblm = randomSchubertProblemInstance(
  rsort{ {1},{1},{1},{2},{1, 1},{1, 1}},3,6);
time S = solveSchubertProblem(SchPblm, 3,6);
assert all(S,s->checkIncidenceSolution(s, SchPblm))
assert(#S==5)

 end
 ------


restart
load "NumericalSchubertCalculus/EXA/ProblemsG36/11e2x2x1e3-G36.m2"
 ------