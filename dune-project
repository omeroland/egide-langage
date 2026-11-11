(lang dune 3.14)
(using menhir 2.1)

(name egide)
(version 0.0.1)
(generate_opam_files true)

(source (github omeroland/egide-langage))
(license Apache-2.0)
(authors "Omeroland" "The Égide contributors")
(maintainers "Omeroland")

(package
 (name egide)
 (synopsis "Égide: a secure-by-default programming language")
 (description "egidec, the bootstrap compiler and toolchain for the Égide language.")
 (depends
  (ocaml (>= 5.2))
  (dune (>= 3.14))
  (menhir (>= 20231231))
  (sedlex (>= 3.2))
  (ppx_deriving (>= 6.0))
  (ppx_expect :with-test)
  (alcotest :with-test)
  (qcheck-core :with-test)
  (ocamlformat (and :with-dev-setup (= 0.28.1)))))
