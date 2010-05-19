#ifndef __dpoly_h_
#define __dpoly_h_
// Code for univariate polynomials over algebraic extensions of QQ
// and over finite fields

// The basic operations:
//   "monic gcd mod p" over extension fields
//   modular gcd algorithm
// Later, we will extend this to multivariate polynomials and function fields

#include <cstdio>
#include <strstream>
#include "ringelem.hpp"
#include "buffer.hpp"

class Tower;

typedef struct poly_struct * poly;
typedef const struct poly_struct * const_poly;
struct poly_struct {
  unsigned long deg;
  unsigned long len;
  union {
    long *ints;  // array of integers.  at level == 0
    poly *polys; // array of more ptrs to poly structs, at level > 0
  } arr;
};

class DPoly {
  int nvars;
  int nlevels; // #vars is nlevels+1
  poly *extensions;
  long charac;

private:
  void initialize(long p, int nvars0, const_poly *ext0);

  void reset_degree_0(poly &f); // possibly sets f to 0
  void reset_degree_n(int level, poly &f); // ditto

  void mult_by_coeff_0(poly &f, long b);
  void mult_by_coeff_n(int level, poly &f, poly b);
  // f *= b.  b should have level 'level-1'.

  void make_monic_0(poly & f, long &result_multiplier);
  void make_monic_n(int level, poly & f, poly &result_multiplier);

  static poly read_poly_0(char * &str);
  static poly read_poly_n(char * &str, int level);

  void add_in_place_0(poly &f, const poly g);
  void add_in_place_n(int level, poly &f, const poly g);

  void subtract_in_place_0(poly &f, const poly g);
  void subtract_in_place_n(int level, poly &f, const poly g);

  poly mult_0(const poly f, const poly g, bool reduce_by_extension);
  poly mult_n(int level, const poly f, const poly g, bool reduce_by_extension);

  poly random_0(int deg);
  poly random_n(int level, int deg);
public:
  int degree_of_extension(int level); // if negative, then that variable is transcendental over lower vars
  bool down_level(int newlevel, int oldlevel, poly &f);

  static void increase_size_0(int newdeg, poly &f);
  static void increase_size_n(int newdeg, poly &f);
  static poly alloc_poly_n(long deg, poly *elems=0);
  static poly alloc_poly_0(long deg, long *elems=0);
  static void dealloc_poly(poly &f);

  static void display_poly(FILE *fil, int level, const poly f);
  static poly read_poly(char * &str, int level);
  static std::ostream& append_to_stream(std::ostream &o, int level, const poly f);
  static char *to_string(int level, const poly f);

  static bool is_equal(int level, const poly f, const poly g);
  static poly copy(int level, const_poly f);
  
  static poly from_int(int level, long c);  // c should be reduced mod p
  static bool is_one(int level, poly f);

  static bool is_zero(poly f) { return f == 0; }

  void remove(int level, poly &f);

  int compare(int level, const poly f, const poly g); // this is a total order

  poly random(int level, int deg);
  poly random(int level); // obtains a random element, using only variables which are algebraic over the base

  poly var(int level, int v); // make the variable v (but at level 'level')

  void negate_in_place(int level, poly &f);
  void add_in_place(int level, poly &f, const poly g);
  void subtract_in_place(int level, poly &f, const poly g);
  poly mult(int level, const poly f, const poly g, bool reduce_by_extension);
  void remainder(int level, poly &f, const poly g);
  poly division_in_place_monic(int level, poly & f, const poly g);
  bool division_in_place(int level, poly & f, const poly g, poly &result_quot);
  poly gcd(int level, const poly f, const poly g);
  poly gcd_coefficients(int level, const poly f, const poly g, 
			       poly &result_u, poly &result_v);
  void make_monic(int level, poly  &f);
  poly invert(int level, const poly a);

  void normal_form(int level, poly &f); // hmmm, I need to think this one through...

  void subtract_multiple_to(int level, poly &f, long a, int i, poly g);

  // DPoly management
  ~DPoly() {}
  DPoly(long p, int nvars0, const_poly *extensions=0);
};

class DRing
{
  int level;
  mutable DPoly D;
  long P;

  DRing(long charac, int nvars, const_poly *exts);
public:
  typedef Tower ring_type;
  typedef poly elem;

  static DRing * create(long p, int nvars0, const_poly *ext0);
  // ext0 should be an array of poly's of level 'nvars0'? 0..nvars0-1

  void init_set(elem &result, elem a) const { result = a; }

  void set_zero(elem &result) const { result = 0; }

  void set(elem &result, elem a) const { D.remove(level, result); result = a; }

  bool is_zero(elem result) const { return result == 0; }

  bool invert(elem &result, elem a) const
  // returns true if invertible.  Returns true if not, and then result is set to 0.
  {
    result = D.invert(level, a);
    return result != 0;
  }


  void add(elem &result, elem a, elem b) const
  {
    if (a == 0) result = b;
    else if (b == 0) result = a;
    else
      {
	poly a1 = D.copy(level, a);
	D.add_in_place(level, a1, b);
	result = a1;
      }
  }

  void subtract(elem &result, elem a, elem b) const
  {
    poly a1 = D.copy(level, a);
    D.subtract_in_place(level, a1, b);
    result = a1;
  }

  void subtract_multiple(elem &result, elem a, elem b) const
  {
    if (a == 0 || b == 0) return;
    elem ab = D.mult(level,a,b,true);
    D.subtract_in_place(level, result, ab);
  }

  void mult(elem &result, elem a, elem b) const
  {
    if (a == 0 || b == 0) 
      result = 0;
    else
      result = D.mult(level, a, b, true);
  }

  void divide(elem &result, elem a, elem b) const
  {
    if (a == 0 || b == 0) 
      result = 0;
    else
      {
	result = D.mult(level, a, b, true);
      }
  }

  void to_ring_elem(ring_elem &result, const elem a) const
  {
    poly h = D.copy(level, a);
    result = TOWER_RINGELEM(h);
  }

  void from_ring_elem(elem &result, const ring_elem &a) const
  {
    poly a1 = TOWER_VAL(a);
    result = D.copy(level, a1);
  }

  void swap(elem &a, elem &b) const
  {
    elem tmp = a;
    a = b;
    b = tmp;
  }

  bool is_one(const poly f) { return D.is_one(level, f); }

  bool is_equal(const poly f, const poly g) { return D.is_equal(level, f, g); }

  bool compare(const poly f, const poly g) { return D.compare(level, f, g); }

  bool is_unit(const poly g); // what does this really do?

  void set_var(poly &result, int n) {
    // n from 0..nvars-1, sets result to 0 f n is out of range
    result = D.var(level,n);
  }

  void set_from_int(poly &result, long r) {
    r = r % P;
    if (r < 0) r += P;
    result = D.from_int(level, r);
  }

  void set_from_int(poly &result, mpz_ptr r); // written

  bool set_from_rational(poly &result, mpq_ptr r); // written

  void set_random(poly &result) { result = D.random(level); }

  void elem_text_out(buffer &o, 
		     const poly f,
		     bool p_one,
		     bool p_plus, 
		     bool p_parens) const;
};

// Format for polynomials in a file:
//  [[,,[,,1,2]],,[1,3,4,,8]]

// write following functions:
//  read_poly, read_polys
//  write_poly, write_polys
//  add, subtract

#if 0
  mpz_t result;
  mpz_init(result);
  mpz_mod_ui(result, n, P);
  int m = static_cast<int>(mpz_get_si(result));
  if (m < 0) m += P;
  //TODO: finish


  
  poly f1 = TOWER_VAL(f);
  poly g1 = TOWER_VAL(g);

  poly h = D->invert(level,g1);
  if (D->is_zero(h)) 
    ERROR("element not invertible");
  else
    {
      poly h1 = D->mult(level, f1, h, true);
      D->remove(level, h);
      h = h1;
    }

  return TOWER_RINGELEM(h);
#endif

#endif

// Local Variables:
// compile-command: "make -C $M2BUILDDIR/Macaulay2/e "
// End:
