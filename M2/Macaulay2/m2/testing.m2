needs "packages.m2"
needs "code.m2"
needs "run.m2"

-----------------------------------------------------------------------------
-- Local utilities
-----------------------------------------------------------------------------

sourceFileStamp = (filename, linenum) -> concatenate(
    pos := new FilePosition from (toAbsolutePath filename, linenum, 1);
    concatenate("--", toString pos, ": location of test code"));

-----------------------------------------------------------------------------
-- TestInput
-----------------------------------------------------------------------------
TestInput = new SelfInitializingType of HashTable
new TestInput from Sequence := (T, S) -> TestInput {
    "filename" => S_0,
    "line number" => S_1,
    "code" => concatenate(sourceFileStamp(S_0, S_1), newline, S_2)}
TestInput.synonym = "test input"

code TestInput := T -> T#"code"
locate TestInput := T -> new FilePosition from (T#"filename",
    T#"line number" - depth net code T, 1,
    T#"line number", 1,,)
toString TestInput := toString @@ locate
net TestInput := T -> "-*TestInput[" | toString T | "]*-"
editMethod TestInput := editMethod @@ locate

-----------------------------------------------------------------------------
-- TEST
-----------------------------------------------------------------------------

TEST = method(Options => {FileName => false})
TEST List   := opts -> testlist   -> apply(testlist, test -> TEST(test, opts))
TEST String := opts -> teststring -> (
    n := currentPackage#"test number";
    currentPackage#"test inputs"#n = TestInput if opts.FileName then (
        testCode := get teststring;
        (minimizeFilename teststring, depth net testCode + 1, testCode)
        ) else
        (minimizeFilename currentFileName, currentRowNumber(), teststring);
    currentPackage#"test number" = n + 1;)
-- TODO: support test titles
TEST(String, String) := (title, teststring) -> (
    n := currentPackage#"test number"; () -> check(n - 1, currentPackage))

-----------------------------------------------------------------------------
-- check
-----------------------------------------------------------------------------

checkmsg := (verb, desc) ->
    stderr << commentize pad(pad(verb, 10) | desc, 72) << flush;

captureTestResult := (desc, teststring, pkg, usermode) -> (
    stdio << flush; -- just in case previous timing information hasn't been flushed yet
    if match("no-check-flag", teststring) then (
	checkmsg("skipping", desc);
	return true);
    -- TODO: remove this when capture uses ArgQ
    if usermode === not noinitfile then
    -- try capturing in the same process
    if isCapturable(teststring, pkg, true) then (
	checkmsg("capturing", desc);
	-- TODO: adjust and pass argumentMode, instead. This can be done earlier, too.
	-- Note: UserMode option of capture is not related to UserMode option of check
	(err, output) := capture(teststring, PackageExports => pkg, UserMode => false);
	if err then printerr "capture failed; retrying ..." else return true);
    -- fallback to using an external process
    checkmsg("running", desc);
    runString(teststring, pkg, usermode))

loadTestDir := pkg -> (
    -- TODO: prioritize reading the tests from topSrcdir | "Macaulay2/tests/normal" instead
    testDir := pkg#"package prefix" |
        replace("PKG", pkg#"pkgname", currentLayout#"packagetests");
    pkg#"test directory loaded" =
    if fileExists testDir then (
        tmp := currentPackage;
        currentPackage = pkg;
        TEST(sort apply(select(readDirectory testDir, file ->
            match("\\.m2$", file)), test -> testDir | test),
            FileName => true);
        currentPackage = tmp;
        true) else false)

tests = method()
tests Package := pkg -> (
    if not pkg#?"test directory loaded" then loadTestDir pkg;
    if pkg#?"documentation not loaded" then pkg = loadPackage(pkg#"pkgname", LoadDocumentation => true, Reload => true);
    previousMethodsFound = new HashTable from pkg#"test inputs"
    )
tests String := pkg -> tests needsPackage(pkg, LoadDocumentation => true)
tests(ZZ, Package) := tests(ZZ, String) := (i, pkg) -> (tests pkg)#i

check = method(Options => {UserMode => null, Verbose => false})
check String  :=
check Package := opts -> pkg -> check({}, pkg, opts)
check(ZZ, String)  :=
check(ZZ, Package) := opts -> (n, pkg) -> check({n}, pkg, opts)
check(List, String)  := opts -> (L, pkg) -> check(L, needsPackage (pkg, LoadDocumentation => true), opts)
check(List, Package) := opts -> (L, pkg) -> (
    if not pkg.Options.OptionalComponentsPresent then (
	printerr("warning: skipping tests; ", toString pkg, " requires optional components"); return);
    usermode := if opts.UserMode === null then not noinitfile else opts.UserMode;
    --
    use pkg;
    tmp := previousMethodsFound;
    inputs := tests pkg;
    previousMethodsFound = tmp;
    testKeys := if L == {} then keys inputs else L;
    if #testKeys == 0 then printerr("warning: ", toString pkg,  " has no tests");
    --
    errorList := for k in testKeys list (
	    if not inputs#?k then error(pkg, " has no test #", k);
	    teststring := code inputs#k;
	    desc := "check(" | toString k | ", " | format pkg#"pkgname" | ")";
	    ret := elapsedTime captureTestResult(desc, teststring, pkg, usermode);
	    if not ret then (k, temporaryFilenameCounter - 2) else continue);
    outfile := errfile -> temporaryDirectory() | errfile | ".tmp";
    if #errorList > 0 then (
	if opts.Verbose then apply(errorList, (k, errfile) -> (
		stderr << toString inputs#k << " error:" << endl;
		printerr getErrors(outfile errfile)));
	error("test(s) #", demark(", ", toString \ first \ errorList), " of package ", toString pkg, " failed.")))

checkAllPackages = () -> (
    tmp := argumentMode;
    argumentMode = defaultMode - SetCaptureErr - SetUlimit -
	if noinitfile then 0 else ArgQ;
    fails := for pkg in sort separate(" ", version#"packages") list (
	stderr << HEADER1 pkg << endl;
	if runString("check(" | format pkg | ", Verbose => true)",
	    Core, false) then continue else pkg) do stderr << endl;
    argumentMode = tmp;
    if #fails > 0 then printerr("package(s) with failing tests: ",
	demark(", ", fails));
    #fails)
