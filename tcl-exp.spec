Name:         tcl-exp
Version:      1.0
Release:      alt1
BuildArch:    noarch

Summary:      TCL/TK programs for experimental work
Group:        System
License:      GPL

Packager:     Vladislav Zavjalov <slazav@altlinux.org>

Source:       %name-%version.tar

%description
TCL/TK programs for experimental work

%prep
%setup -q

%install
mkdir -p %buildroot%_bindir
mkdir -p %buildroot/%_tcldatadir/Exp
%__install -m 755 $(find bin -maxdepth 1 -type f -executable) %buildroot%_bindir
%__install lib/*.tcl %buildroot/%_tcldatadir/Exp

%files
%_bindir/*
%_tcldatadir/Exp/*

%changelog
* Mon Nov 27 2023 Vladislav Zavjalov <slazav@altlinux.org> 1.0-alt1
- v1.0. Start versioning, it was a long modification history before this
