# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit git-r3

DESCRIPTION="TCL/TK programs for experimental work"
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
  dobin $(find bin -maxdepth 1 -type f -perm 755)
  insinto /usr/$(get_libdir)/Exp
  doins lib*.tcl
}
