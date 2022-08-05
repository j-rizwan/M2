-- subalgebraBasis returns a matrix of sagbi generators
-- of a given subring, matrix, or list.
-- Since this doesn't return a computation object,
-- an intermediate state cannot be stored.

subalgebraBasis = method(
    TypicalValue => Matrix,
    Options => {
	AutoSubduce => true,
        ReduceNewGenerators => true, -- applys gaussian elimination to sagbiGens before adding them
	StorePending => true,
        -- FullSubduct => true,
        -- DegreeLimitedSubduction => false,
        Strategy => "Master", -- Master (default), DegreeByDegree, Incremental
        SubductionMethod => "Top", -- top or engine
    	Limit => 100,
	AutoSubduceOnPartialCompletion => false, -- applies autosubduction to the sagbiGens the first time no new terms are added
    	PrintLevel => 0,
	Recompute => false,
	RenewOptions => false
	}
);

subalgebraBasis(Matrix) := opts -> M -> (
    local sagbiInput;
    
    if M.cache#?"SAGBIBasis" then (
	sagbiInput = M.cache#"SAGBIBasis";
	) else (
	sagbiInput = subring M;
	);
    
    SB := sagbi(opts, sagbiInput);
    output := gens SB;
    output.cache#"SAGBIBasis" = SB;
    output
);

subalgebraBasis(List) := opts -> L -> (
    SB := sagbi(opts, L);
    gens SB
    );

subalgebraBasis(Matrix) := opts -> M -> (
    SB := sagbi(opts, M);
    gens SB
    );

subalgebraBasis(Subring) := opts -> S -> (
    SB := sagbi(opts, S);
    gens SB
    );

-- sagbi returns a computation object
-- of a given subring, matrix, or list
-- Since the return is a computation object,
-- the computation can pick up where it left off.
-- PrintLevel > 0: Print some information each loop (don't print any polynomials):
--                 computation degree, number of SPairs, number of new generators, termination conditions.
-- PrintLevel > 1: Print basic polynomials: SPairs and new sagbiGens.
-- PrintLevel > 2: Print extra polynomials: reductionIdeal gens, zeroGens, current sagbiGens
-- PrintLevel > 3: Print the input and output of each subduction.
-- PrintLevel > 4: Print processPending data and Master Strategy choices (for debugging)
-- PrintLevel > 5: Print subductionTopLevel intermediate steps (for debugging)
--
-- On the behaviour of RenewOptions and Recompute:
--   if RenewOptions is false and Recompute is true
--     the computation will be renewed using the options of the previous computaiton
--   if RenewOptions is true and Recompute is false
--     the computation will resume all current options except:
--     if the previous options has Recompute set to be true
--        then the computation will be started from new **
--   if both are true or both are false then it does what is expected
--
-- ** the only way this happens is if the SAGBIBasis object was
--    created from a isSAGBI call. In this case we MUST recompute
--

sagbi = method(
    TypicalValue => Subring,
    Options => {
	AutoSubduce => true,
        ReduceNewGenerators => true, -- applys gaussian elimination to sagbiGens before adding them
	StorePending => true,
        -- FullSubduct => true,
        -- DegreeLimitedSubduction => false,
        Strategy => "Master", -- Master (default), DegreeByDegree, Incremental
        SubductionMethod => "Top", -- top or engine
    	Limit => 10, -- change back to 100
	AutoSubduceOnPartialCompletion => false, -- applies autosubduction to the sagbiGens the first time no new terms are added
    	PrintLevel => 0,
	Recompute => false, -- restart the computation (ignored by RenewOptions)
	RenewOptions => false -- use only the supplied options
    	}
);

sagbi(Matrix) := opts -> M -> (
    B := sagbi(opts, sagbiBasis subring M);
    M.cache#"Subring" = B#"data"#"subring";
    B
);

sagbi(List) := opts -> L -> (
    sagbi(opts, subring L)
);

sagbi(Subring) := opts -> S -> (
    local SB;
    if S.cache#?"SAGBIBasis" and not opts.Recompute then (
	SB = S.cache#"SAGBIBasis";
	) else (
    	SB = sagbiBasis(opts, S);
	);
    newSB := sagbi(opts, SB);
    S.cache#"SAGBIBasis" = newSB;
    newSB
);

sagbi(SAGBIBasis) := opts -> SB -> (
    local S;
    -- if Recomputing then create a new SAGBIBasis object
    if opts.Recompute or SB#"options"#Recompute then (
	S = sagbiBasis(opts, SB#"data"#"subring"); 
	) else (
	S = SB;
	);
    
    if (S#"data"#"limit" > opts.Limit) or (isSAGBI S) then return S;

    -- Should also be able to initialize when pending doesn't exist.
    -- This case isn't taken care of yet.
    compTable := initializeCompTable(S,opts);
    processFirstStep(compTable);
    
    local SPairs;

    while (compTable#"data"#"degree" <= opts.Limit) and
          (not compTable#"data"#"sagbiDone") do (
    		
        SPairs = collectSPairs(compTable);
	SPairs = compSubduction(compTable, SPairs);
	
	-- update and process the new sagbi generators
	-- update pending returns true if new sagbiGenerators were added and false otherwise
	-- if new sagbiGenerators were added then updatePending
	--    sets the compTable#"data"#"degree" to the lowest degree of a new generator
	-- if no new sagbiGenerators were added then check for termination conditions
	if not updatePending(compTable, SPairs) then (
	    checkTermination(compTable);
	    );
	
	-- move on to the next degree
	compTable#"data"#"degree" = compTable#"data"#"degree" + 1;
	
	if compTable#"options"#PrintLevel > 2 then(
	    print("-- [main] sagbiGenerators are currently: ");
	    print(transpose compTable#"data"#"sagbiGenerators");
	    );
	
    );

    sagbiBasis compTable
)


-- #################################################
-- ## remove: intervalVerifySagbi and verifySagbi ##
-- #################################################


-- internal verify sagbi is a version of verifySabi just for SAGBIBasis objects
-- it returns a SAGBIBasis object with its SB#"data"#"sagbiDone" flag correctly set
-- it is used as an intermediate step for verifySagbi since matrices and subrings
--   are handled slightly differently
-- 

internalVerifySagbi = method(
    TypicalValue => SAGBIBasis,
    Options => {
	-- FullSubduct => true,
        Strategy => "Master", -- Master (default), DegreeByDegree, Incremental
        SubductionMethod => "Top", -- top or engine
	Limit => 100,
	PrintLevel => 0 -- see print level for sagbi
    	}
    );


internalVerifySagbi(SAGBIBasis) := opts -> SB -> (
    compTable := initializeCompTable(SB, opts);
    
    -- Get the SPairs
    sagbiGB := gb(compTable#"ideals"#"reductionIdeal");
    k := rawMonoidNumberOfBlocks(raw monoid (compTable#"rings"#"tensorRing")) - 2;
    zeroGens := selectInSubring(k, gens sagbiGB);
    SPairs := compTable#"maps"#"fullSubstitution"(zeroGens) % compTable#"ideals"#"I";
    
    -- Reduce the SPairs
    reducedSPairs := compSubduction(compTable, SPairs);
    
    -- if all the reduced SPairs are zero then we have a sagbiBasis
    compTable#"data"#"sagbiDone" = zero(reducedSPairs);
    sagbiBasis compTable
    );

-- checks whether or not the generators of a subring S form a sagbi basis wrt the given term order
-- 
-- the method uses the code from inside the method that collects SPairs to find them
-- the method uses the subduction fuction so setting the option SubductionMethod will change the strategy
-- print level will be called inside of subduction so it can be used to perform subduction 
--
-- the resulting SAGBIBasis object SB will have SB#"data"#"sagbiDone" updated appropriately
-- the function then returns true or false depending on whether the generating set is a SAGBIBasis 
--

verifySagbi = method(
    TypicalValue => Subring,
    Options => {
	-- FullSubduct => true,
        Strategy => "Master", -- Master (default), DegreeByDegree, Incremental
        SubductionMethod => "Top", -- top or engine
	Limit => 100,
	PrintLevel => 0 -- see print level for sagbi
    	}
);

verifySagbi(Subring) := opts -> S -> (
    local SB;
    
    if (S#cache#?"SAGBIBasis") and (S#cache#"SAGBIBasis"#"data"#"sagbiGenerators" == gens S) then (
	-- S has a sagbi basis so use this object as a compTable
	SB = S#cache#"SAGBIBasis";
	) else (
	SB = initializeCompTable(sagbiBasis S, opts);
	-- add the generators to the sagbiGenerators
	SB#"data"#"sagbiGenerators" = gens S;
	updateComputation(SB);
	SB = sagbiBasis SB;
	);
    
    SB = internalVerifySagbi(opts, SB);
    S.cache#"SAGBIBasis" = SB;
    isSAGBI S
    )

verifySagbi(Matrix) := opts -> M -> (
    local SB;
    
    if (M#cache#?"SAGBIBasis") and (M#cache#"SAGBIBasis"#"data"#"sagbiGenerators" == M) then (
	-- S has a sagbi basis so use this object as a compTable
	SB = M#cache#"SAGBIBasis";
	) else (
	SB = initializeCompTable(sagbiBasis M, opts);
	-- add the generators to the sagbiGenerators
	SB#"data"#"sagbiGenerators" = M;
	updateComputation(SB);
	SB = sagbiBasis SB;
	);
    
    SB = internalVerifySagbi(opts, SB);
    M.cache#"SAGBIBasis" = SB;
    isSAGBI M
    )

-- A list does not have a cache, so verifySagbi on a list 
--   is only checking whether it forms a sagbi basis
--   the SAGBIBasis object becomes inaccessible

verifySagbi(List) := opts -> L -> (
    verifySagbi(opts, subring L)
    )





end --

-- PrintLevel > 0: Print some information each loop, but don't print any polynomials.
-- PrintLevel > 1: Print new Sagbi gens.
sagbi(SAGBIBasis) := o -> S -> (


    while compTable#"stoppingData"#"degree" <= o.Limit and not compTable#"sagbiDone" do (
    	
	-- [NOW IN: collectSPairs()]
	-- Have we previously found any syzygies of degree currDegree?
        if compTable#"pending"#?(compTable#"stoppingData"#"degree") then (
            syzygyPairs = syzygyPairs |
                compTable#"presentation"#"inclusionAmbient"(matrix{toList compTable#"pending"#(compTable#"stoppingData"#"degree")});
            remove(compTable#"pending", compTable#"stoppingData"#"degree");
            );

	if o.PrintLevel > 0 then(
    	    print("-- Performing subduction on S-polys... ");
	        print("-- Num. S-polys before subduction: " | toString(numcols syzygyPairs));
	    );
    ----------------
    
    subducted = internalSubduction(compTable#"presentation", syzygyPairs);
    
    
    if numcols subducted != 0 then (
	    newElements = compress ((compTable#"presentation"#"projectionAmbient")(subducted));
            ) else (
	    newElements = subducted;
	    );

    if o.PrintLevel > 0 then(
	    print("-- Num. S-polys after subduction: " | toString(numcols newElements));
	    );

    if o.PrintLevel > 1 then(
	    print("-- New generators:");
	    if(numcols newElements == 0) then(
		-- It has to treat this as a special case because zero matrices are special.
		    print("| 0 |");
		    )else(
		    debugPrintMat(newElements);
		    );
    );

	if numcols newElements > 0 then (
	    insertPending(compTable, newElements);
    	    processPending(compTable);
	    if not lowestDegree(compTable) == infinity then
                 compTable#"stoppingData"#"degree" = lowestDegree(compTable)
                 else
                 compTable#"stoppingData"#"degree" = compTable#"stoppingData"#"degree" + 1;
        ) else (

        terminationCondition0 = #(compTable#"pending") == 0;
        terminationCondition1 = rawStatus1 raw sagbiGB == 6;
        terminationCondition2 = compTable#"stoppingData"#"degree" > max flatten (degrees compTable#"subringGenerators")_1;

        if o.PrintLevel > 0 then(
		print("-- No new generators found. ");
		print("-- Stopping conditions:");
		print("--    No higher degree candidates: "|toString(terminationCondition0));
		print("--    S-poly ideal GB completed:   "|toString(terminationCondition1));
		print("--    Degree lower bound:          "|toString(terminationCondition2));
		);

        if terminationCondition0 and terminationCondition1 and terminationCondition2 then (
            compTable#"sagbiDone" = true;
            );
	
        compTable#"stoppingData"#"degree" = compTable#"stoppingData"#"degree" + 1;
        );
    
    );
    
    if o.PrintLevel > 0 then(
    	if not compTable#"sagbiDone" then (
            print("-- Limit was reached before a finite SAGBI basis was found.");
    	    )else(
            print("-- Finite Sagbi basis was found.");
            );
    	);
    
    -- We return a new instance of subring instead of the generators themselves so that we can say whether or not a Subring instance
    -- IS a Sagbi basis, not whether or not it HAS a Sagbi basis. (The latter is unacceptable because the cache should not effect
    -- the value of a function.)
    
    -- If subalgebraBasis is called on a Subring instance with a previously computed Sagbi basis that is not itself a Sagbi basis,
    -- a new subring instance will be constructed from its cached SagbiGens. This is OK because different instances of the same
    -- subring will still be equal if we calculate equality based on the mathematical equality of the subalgebras they generate.
    -----------------------------------------------------------------------------------------------------
    -- subR.cache.SagbiDone: Indicates whether or not the Subring instance has a cached Sagbi basis.
    -- subR.isSagbi        : Indicates whether or not (gens subR) itself is a Sagbi basis.
    -----------------------------------------------------------------------------------------------------
    -- The correct way to implement a function that requires a Subring instance that is a Sagbi basis is to check that
    -- (subR.isSagbi == true). If (subR.isSagbi == false) and (subR.cache.SagbiDone == true), an error should still be thrown.
    
    sagbiBasis(storePending => o.storePending,compTable)
);

end --

debug Core -- gets rid of "raw" error during installation. probably a better way...

-- Performs subduction using matrix of generators, M.
-- currently does not require the generators to be a Sagbi basis.

subduction = method(TypicalValue => RingElement)
subduction(Matrix, RingElement) := (M, f) -> (
    pres := makePresRing(ring M, M);
    result := pres#"fullSubstitution" internalSubduction(pres, f);
    result
    )
subduction(Matrix, Matrix) := (M, N) -> (
    pres := makePresRing(ring M, M);	
    ents := for i from 0 to (numcols N)-1 list(
    	pres#"fullSubstitution" internalSubduction(pres, N_(0,i))
	);
    matrix({ents})
    );

internalSubduction = method(TypicalValue => RingElement)
internalSubduction(PresRing, RingElement) := (pres, f) -> (
    tense := pres#"tensorRing";
    if ring f === tense then (
	f = (pres#"fullSubstitution")(f);
	)else if ring f =!= source pres#"inclusionAmbient" then (
	error "f must be from ambR or tensorRing.";
	);
        
    -- It is possible for ring f === ambient to be true but f is still from a different ring 
    -- than pres#"tensorRing". In this case, it shouldn't try to prevent an error by using "sub"
    -- or something. Instead, the following line will deliberately throw an error:
    -- (This is done because otherwise there is potential for a segfault.)
    throwError := f - 1_(source pres#"inclusionAmbient");   
    
    -- Use the same pres ring as much as possible.  
    -- M2 will automatically cache the gb calculation 
    -- as long as the pres ring is not reconstructed.
    J := gb (pres#"syzygyIdeal");
        
    F := pres#"substitution";
    M := monoid source pres#"inclusionAmbient";
    numblocks := rawMonoidNumberOfBlocks raw M;
    fMat := matrix({{pres#"inclusionAmbient"(f)}});    
    result := rawSubduction(numblocks, raw fMat, raw F, raw J);
    result = promote(result_(0,0), tense);    
    
    result
    );

-- The C++ implementation of rawSubduction could be improved.
-- Here is the code path that it takes:
-- (M2) subduction(Matrix) -> (M2) subduction(RingElement) -> (C++) rawSubduction(Matrix) -> (C++) subduction(RingElement)
-- If we deleted the C++ rawSubduction(Matrix) function and made rawSubduction take a RingElement, we could have:
-- (M2) subduction(Matrix) -> (M2) subduction(RingElement) -> (C++) subduction(RingElement)
internalSubduction(PresRing, Matrix) := (pres, M) -> (	
    ents := for i from 0 to (numcols M)-1 list(
    	internalSubduction(pres, M_(0,i))
	);
    matrix({ents})
    );


-- checks whether or not the generators form a sagbi basis wrt the given term order
verifySagbi = method();
verifySagbi Subring := S -> (
    presS := S#"presentation";
    IA := presS#"syzygyIdeal";
    GBIA := gens gb IA;
    monomialSyzygies := selectInSubring(1, GBIA);
    remainders := compress subduction(gens S, presS#"fullSubstitution" monomialSyzygies);
    -- If true,
    -- Create a new SAGBIBasis object that is set to done (like forceGB)
    -- Add this to the cache.
    numcols remainders == 0
--    HT := new MutableHashTable from S;
--    HT#"isSAGBI" = (numcols remainders == 0)--;
--    new Subring from HT
    )
verifySagbi Matrix := M -> verifySagbi subring M
verifySagbi List := L -> verifySagbi subring L
