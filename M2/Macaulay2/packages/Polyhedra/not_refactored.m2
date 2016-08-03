-- The following contains methods that have only been partially refactored because:
-- * They were too long.
-- * We did not know what they do or
-- * We did not know how they work.
-- * We had no way of testing them at this point.
-- These methods have been fixed to work with the new setup. Use at own risk.


-- PURPOSE : Computing the state polytope of the ideal 'I'
--   INPUT : 'I',  a homogeneous ideal with resect to some strictly psoitive grading
--  OUTPUT : The state polytope as a polyhedron
statePolytope = method(TypicalValue => Polyhedron)
statePolytope Ideal := I -> (
   -- Check if there exists a strictly positive grading such that 'I' is homogeneous with
   -- respect to this grading
   homogeneityCheck := I -> (
      -- Generate the matrix 'M' that spans the space of the differeneces of the 
      -- exponent vectors of the generators of 'I'
      L := flatten entries gens I;
      lt := apply(L, leadTerm);
      M := matrix flatten apply(#L, i -> apply(exponents L#i, e -> (flatten exponents lt#i)-e));
      -- intersect the span of 'M' with the positive orthant
      C := intersection(map(source M,source M,1),M);
      -- Check if an interior vector is strictly positive
      v := interiorVector C;
      (all(flatten entries v, e -> e > 0),v)
   );
   -- Compute the Groebner cone
   gCone := (g,lt) -> (
      -- for a given groebner basis compute the reduced Groebner basis
      -- note: might be obsolete, but until now (Jan2009) groebner bases appear to be not reduced
      g = apply(flatten entries gens g, l -> ((l-leadTerm(l))% g)+leadTerm(l));
      -- collect the differences of the exponent vectors of the groebner basis
      lt = flatten entries lt;
      L := matrix flatten apply(#g, i -> apply(exponents g#i, e -> (flatten exponents lt#i)-e));
      -- intersect the differences
      intersection L
   );
   wLeadTerm := (w,I) -> (
      -- Compute the Groebner basis and their leading terms of 'I' with respect to the weight 'w'
      R := ring I;
      -- Resize w to a primitive vector in ZZ
      w = flatten entries substitute((1 / abs gcd flatten entries w) * w,ZZ);
      -- generate the new ring with weight 'w'
      S := (coefficientRing R)[gens R, MonomialOrder => {Weights => w}, Global => false];
      f := map(S,R);
      -- map 'I' into 'S' and compute Groebner basis and leadterm
      I1 := f I;
      g := gb I1;
      lt := leadTerm I1;
      gbRemove I1;
      (g,lt)
   );
   makePositive := (w,posv) -> (
      w = flatten entries w;
      posv = flatten entries posv;
      j := min(apply(#w, i -> w#i/posv#i));
      if j <= 0 then j = 1 - floor j else j = 0;
      matrix transpose{w + j * posv}
   );
   -- computes the symmetric difference of the two lists
   sortIn := (L1,L2) -> ((a,b) := (set apply(L1,first),set apply(L2,first)); join(select(L1,i->not b#?(i#0)),select(L2,i->not a#?(i#0))));
   --Checking for homogeneity
   (noError,posv) := homogeneityCheck I;
   if not noError then error("The ideal must be homogeneous w.r.t. some strictly positive grading");
   -- Compute a first Groebner basis to start with
   g := gb I;
   lt := leadTerm I;
   -- Compute the Groebner cone
   C := gCone(g,lt);
   gbRemove I;
   -- Generate all facets of 'C'
   -- Save each facet by an interior vector of it, the facet itself and the cone from 
   -- which it has been computed
   raysC := rays C;
   triplets := C -> (
      raysC := rays C;
      linC := linealitySpace C;
      apply(faces(1,C), 
         f -> (
            fCone := posHull(raysC_f, linealitySpace C);
            (interiorVector fCone,fCone,C)
         )
      )
   );
   facets := triplets C;
   --Save the leading terms as the first vertex
   verts := {lt};
   -- Scan the facets
   while facets != {} do (
      local omega';
      local f;
      (omega',f,C) = facets#0;
      -- compute an interior vector of the big cone 'C' and take a small 'eps'
      omega := promote(interiorVector C,QQ);
      eps := 1/10;
      omega1 := omega'-(eps*omega);
      (g,lt) = wLeadTerm(makePositive(omega1,posv),I);
      C' := gCone(g,lt);
      -- reduce 'eps' until the Groebner cone generated by omega'-(eps*omega) is 
      -- adjacent to the big cone 'C'
      while intersection(C,C') != f do (
          eps = eps * 1/10;
          omega1 = omega'-(eps*omega);
          (g,lt) = wLeadTerm(makePositive(omega1,posv),I);
          C' = gCone(g,lt)
      );
      C = C';
      -- save the new leadterms as a new vertex
      verts = append(verts,lt);
      -- Compute the facets of the new Groebner cone and save them in the same way as before
      newfacets := triplets C;
      -- Save the symmetric difference into 'facets'
      facets = sortIn(facets,newfacets)
   );
   posv = substitute(posv,ZZ);
   R := ring I;
   -- generate a new ring with the strictly positive grading computed by the homogeneity check
   S := QQ[gens R, Degrees => entries posv];
   -- map the vertices into the new ring 'S'
   verts = apply(verts, el -> (map(S,ring el)) el);
   -- Compute the maximal degree of the vertices
   L := flatten apply(verts, l -> flatten entries l);
   d := (max apply(flatten L, degree))#0;
   -- compute the vertices of the state polytope
   vertmatrix := transpose matrix apply(verts, v -> (
       VI := ideal flatten entries v;
       SI := S/VI;
       v = flatten apply(d, i -> flatten entries basis(i+1,SI));
       flatten sum apply(v,exponents))
   );
   -- Compute the state polytope
   P := convexHull vertmatrix;
   (verts,P)
);


-- PURPOSE : Computing the closest point of a polyhedron to a given point
--   INPUT : (p,P),  where 'p' is a point given by a one column matrix over ZZ or QQ and
--                   'P' is a Polyhedron
--  OUTPUT : the point in 'P' with the minimal euclidian distance to 'p'
proximum = method(TypicalValue => Matrix)
proximum (Matrix,Polyhedron) := (p,P) -> (
     -- Checking for input errors
     if numColumns p =!= 1 or numRows p =!= ambDim(P) then error("The point must lie in the same space");
     if isEmpty P then error("The polyhedron must not be empty");
     -- Defining local variables
     local Flist;
     d := ambDim P;
     c := 0;
     prox := {};
     -- Checking if 'p' is contained in 'P'
     if contains(P,p) then p
     else (
	  V := vertices P;
	  R := promote(rays P,QQ);
	  -- Distinguish between full dimensional polyhedra and not full dimensional ones
	  if dim P == d then (
	       -- Continue as long as the proximum has not been found
	       while instance(prox,List) do (
		    -- Take the faces of next lower dimension of P
		    c = c+1;
		    if c == dim P then (
			 Vdist := apply(numColumns V, j -> ((transpose(V_{j}-p))*(V_{j}-p))_(0,0));
			 pos := min Vdist;
			 pos = position(Vdist, j -> j == pos);
			 prox = V_{pos})
		    else (
			 Flist = faces(c,P);
			 -- Search through the faces
			 any(Flist, (v, r) -> (
               F := convexHull((vertices P)_v, (rays P)_r, linealitySpace P);
				   -- Take the inward pointing normal cone with respect to P
				   (vL,bL) := hyperplanes F;
				   -- Check for each ray if it is pointing inward
				   vL = matrix apply(numRows vL, i -> (
					     v := vL^{i};
					     b := first flatten entries bL^{i};
					     if all(flatten entries (v*(V | R)), e -> e >= b) then flatten entries v
					     else flatten entries(-v)));
				   -- Take the polyhedron spanned by the inward pointing normal cone 
				   -- and 'p' and intersect it with the face
				   Q := intersection(F,convexHull(p,transpose vL));
				   -- If this intersection is not empty, it contains exactly one point, 
				   -- the proximum
				   if not isEmpty Q then (
					prox = vertices Q;
					true)
				   else false))));
	       prox)
	  else (
	       -- For not full dimensional polyhedra the hyperplanes of 'P' have to be considered also
	       while instance(prox,List) do (
		    if c == dim P then (
			 Vdist1 := apply(numColumns V, j -> ((transpose(V_{j}-p))*(V_{j}-p))_(0,0));
			 pos1 := min Vdist1;
			 pos1 = position(Vdist1, j -> j == pos1);
			 prox = V_{pos1})
		    else (
			 Flist = faces(c,P);
			 -- Search through the faces
			 any(Flist, (v, r) -> (
               F := convexHull((vertices P)_v, (rays P)_r, linealitySpace P);
				   -- Take the inward pointing normal cone with respect to P
				   (vL,bL) := hyperplanes F;
				   vL = matrix apply(numRows vL, i -> (
					     v := vL^{i};
					     b := first flatten entries bL^{i};
					     entryList := flatten entries (v*(V | R));
					     -- the first two ifs find the vectors not in the hyperspace
					     -- of 'P'
					     if any(entryList, e -> e > b) then flatten entries v
					     else if any(entryList, e -> e < b) then flatten entries(-v)
					     -- If it is an original hyperplane than take the direction from 
					     -- 'p' to the polyhedron
					     else (
						  bCheck := first flatten entries (v*p);
						  if bCheck < b then flatten entries v
						  else flatten entries(-v))));
				   Q := intersection(F,convexHull(p,transpose vL));
				   if not isEmpty Q then (
					prox = vertices Q;
					true)
				   else false)));
		    c = c+1);
	       prox)))


--   INPUT : (p,C),  where 'p' is a point given by a one column matrix over ZZ or QQ and
--                   'C' is a Cone
--  OUTPUT : the point in 'C' with the minimal euclidian distance to 'p'
proximum (Matrix,Cone) := (p,C) -> proximum(p,polyhedron C)



-- PURPOSE : Tests if a Fan is projective
--   INPUT : 'F'  a Fan
--  OUTPUT : a Polyhedron, which has 'F' as normal fan, if 'F' is projective or the empty polyhedron
compute#Fan#polytopal = method(TypicalValue => Boolean)
compute#Fan#polytopal Fan := F -> (
   -- First of all the fan must be complete
   if isComplete F then (
      -- Extracting the generating cones, the ambient dimension, the codim 1 
      -- cones (corresponding to the edges of the polytope if it exists)
      i := 0;
      L := hashTable apply(getProperty(F, honestMaxObjects), l -> (i=i+1; i=>l));
      n := ambDim(F);
      edges := cones(n-1,F);
      raysF := rays F;
      linF := linealitySpace F;
      edges = apply(edges, e -> posHull(raysF_e, linF));
      -- Making a table that indicates in which generating cones each 'edge' is contained
      edgeTCTable := hashTable apply(edges, e -> select(1..#L, j -> contains(L#j,e)) => e);
      i = 0;
      -- Making a table of all the edges where each entry consists of the pair of top cones corr. to
      -- this edge, the codim 1 cone, an index number i, and the edge direction from the first to the
      -- second top Cone
      edgeTable := apply(pairs edgeTCTable, 
         e -> (i=i+1; 
            v := transpose hyperplanes e#1;
            if not contains(dualCone L#((e#0)#0),v) then v = -v;
            (e#0, e#1, i, v)
         )
      );
      edgeTCNoTable := hashTable apply(edgeTable, e -> e#0 => (e#2,e#3));
      edgeTable = hashTable apply(edgeTable, e -> e#1 => (e#2,e#3));
      -- Computing the list of correspondencies, i.e. for each codim 2 cone ( corresponding to 2dim-faces of the polytope) save 
      -- the indeces of the top cones containing it
      corrList := hashTable {};
      scan(keys L, 
         j -> (
            raysL := rays L#j;
            linL := linealitySpace L#j;
            corrList = merge(corrList,hashTable apply(faces(2,L#j), C -> (raysL_C, linL) => {j}),join)
         )
      );
      corrList = pairs corrList;
      --  Generating the 0 matrix for collecting the conditions on the edges
      m := #(keys edgeTable);
      -- for each entry of corrlist another matrix is added to hyperplanesTmp
      hyperplanesTmp := flatten apply(#corrList, 
         j -> (
            v := corrList#j#1;
            hyperplanesTmpnew := map(ZZ^n,ZZ^m,0);
            -- Scanning trough the top cones containing the active codim2 cone and order them in a circle by their 
            -- connecting edges
            v = apply(v, e -> L#e);
            C := v#0;
            v = drop(v,1);
            C1 := C;
            nv := #v;
            scan(nv, 
               i -> (
                  i = position(v, e -> dim intersection(C1,e) == n-1);
                  C2 := v#i;
                  v = drop(v,{i,i});
                  abpos := position(keys edgeTable, k -> k == intersection(C1,C2));
                  abkey := (keys edgeTable)#abpos;
                  (a,b) := edgeTable#abkey;
                  if not contains(dualCone C2,b) then b = -b;
                  -- 'b' is the edge direction inserted in column 'a', the index of this edge
                  hyperplanesTmpnew = hyperplanesTmpnew_{0..a-2} | b | hyperplanesTmpnew_{a..m-1};
                  C1 = C2
               )
            );
            C3 := intersection(C,C1);
            abpos := position(keys edgeTable, k -> k == C3);
            abkey := (keys edgeTable)#abpos;
            (a,b) := edgeTable#abkey;
            if not contains(dualCone C,b) then b = -b;
            -- 'b' is the edge direction inserted in column 'a', the index of this edge
            -- the new restriction is that the edges ''around'' this codim2 Cone must add up to 0
            entries(hyperplanesTmpnew_{0..a-2} | b | hyperplanesTmpnew_{a..m-1})
         )
      );
      if hyperplanesTmp != {} then hyperplanesTmp = matrix hyperplanesTmp
      else hyperplanesTmp = map(ZZ^0,ZZ^m,0);
      -- Find an interior vector in the cone of all positive vectors satisfying the restrictions
      v := flatten entries interiorVector intersection(id_(ZZ^m),hyperplanesTmp);
      M := {};
      -- If the vector is strictly positive then there is a polytope with 'F' as normalFan
      if all(v, e -> e > 0) then (
         -- Construct the polytope
         i = 1;
         -- Start with the origin
         p := map(ZZ^n,ZZ^1,0);
         M = {p};
         Lyes := {};
         Lno := {};
         vlist := apply(keys edgeTCTable,toList);
         -- Walk along all edges recursively
         edgerecursion := (i,p,vertexlist,Mvertices) -> (
            vLyes := {};
            vLno := {};
            -- Sorting those edges into 'vLyes' who emerge from vertex 'i' and the rest in 'vLno'
            vertexlist = partition(w -> member(i,w),vertexlist);
            if vertexlist#?true then vLyes = vertexlist#true;
            if vertexlist#?false then vLno = vertexlist#false;
            -- Going along the edges in 'vLyes' with the length given in 'v' and calling edgerecursion again with the new index of the new 
            -- top Cone, the new computed vertex, the remaining edges in 'vLno' and the extended matrix of vertices
            scan(vLyes, 
               w -> (
                  w = toSequence w;
                  j := edgeTCNoTable#w;
                  if w#0 == i then (
                     (vLno,Mvertices) = edgerecursion(w#1,p+(j#1)*(v#((j#0)-1)),vLno,append(Mvertices,p+(j#1)*(v#((j#0)-1))))
                  )
                  else (
                     (vLno,Mvertices) = edgerecursion(w#0,p-(j#1)*(v#((j#0)-1)),vLno,append(Mvertices,p-(j#1)*(v#((j#0)-1))))
                  )
               )
            );
            (vLno,Mvertices)
         );
         -- Start the recursion with vertex '1', the origin, all edges and the vertexmatrix containing already the origin
         M = unique ((edgerecursion(i,p,vlist,M))#1);
         M = matrix transpose apply(M, m -> flatten entries m);
         -- Computing the convex hull
         setProperty(F, computedPolytope, convexHull M);
         return true
      )
   );
   return false
)


compute#Fan#computedPolytope = method()
compute#Fan#computedPolytope Fan := F -> (
   if not isPolytopal F then error("Fan is not polytopal")
   else polytope F
)


-- PURPOSE : Computes the mixed volume of n polytopes in n-space
--   INPUT : 'L'  a list of n polytopes in n-space
--  OUTPUT : the mixed volume
-- COMMENT : Note that at the moment the input is NOT checked!
mixedVolume = method()
mixedVolume List := L -> (
   n := #L;
   if not all(L, isCompact) then error("Polyhedra must be compact.");
   EdgeList := apply(L, 
      P -> (
         vertP := vertices P;
         apply(faces(dim P -1,P), f -> vertP_(f#0))
      )
   );
   liftings := apply(n, i -> map(ZZ^n,ZZ^n,1)||matrix{apply(n, j -> random 25)});
   Qlist := apply(n, i -> affineImage(liftings#i,L#i));
   local Qsum;
   Qsums := apply(n, i -> if i == 0 then Qsum = Qlist#0 else Qsum = Qsum + Qlist#i);
   mV := 0;
   EdgeList = apply(n, i -> apply(EdgeList#i, e -> (e,(liftings#i)*e)));
   E1 := EdgeList#0;
   EdgeList = drop(EdgeList,1);
   center := matrix{{1/2},{1/2}};
   edgeTuple := {};
   k := 0;
   selectRecursion := (E1,edgeTuple,EdgeList,mV,Qsums,Qlist,k) -> (
      for e1 in E1 do (
         Elocal := EdgeList;
         if Elocal == {} then mV = mV + (volume sum apply(edgeTuple|{e1}, et -> convexHull first et))
         else (
            Elocal = for i from 0 to #Elocal-1 list (
               P := Qsums#k + Qlist#(k+i+1);
               hyperplanesTmp := halfspaces(P);
               hyperplanesTmp = for j from 0 to numRows(hyperplanesTmp#0)-1 list 
                  if (hyperplanesTmp#0)_(j,n) < 0 then ((hyperplanesTmp#0)^{j},(hyperplanesTmp#1)^{j}) 
                  else continue;
               returnE := select(Elocal#i, 
                  e -> (
                     p := (sum apply(edgeTuple|{e1}, et -> et#1 * center)) + (e#1 * center);
                     any(hyperplanesTmp, pair -> (pair#0)*p - pair#1 == 0)
                  )
               );
               --if returnE == {} then break{};
               returnE
            );
            mV = selectRecursion(Elocal#0,edgeTuple|{e1},drop(Elocal,1),mV,Qsums,Qlist,k+1)
         )
      );
      mV
   );
   selectRecursion(E1,edgeTuple,EdgeList,mV,Qsums,Qlist,k)
)
