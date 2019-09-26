# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit git-r3

DESCRIPTION="Useful scripts for experimental setup and data processing."
HOMEPAGE="https://github.com/slazav/${PN}"
EGIT_REPO_URI="https://github.com/suntar/${PN}.git"
LICENSE="GPL"
SLOT="0"
KEYWORDS=""
IUSE=""

DEPEND=""
RDEPEND="${DEPEND}"
BDEPEND=""

src_install() {
  dobin bin/*
  dobin $(find exp -maxdepth 1 -type f -perm 755)
  insinto /usr/$(get_libdir)/octave/site/m
  doins octave/*
  insinto /usr/$(get_libdir)/Exp
  doins exp_tcl/*.tcl
}
