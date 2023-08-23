Name:         tcl-exp-gui
Version:      1.0
Release:      alt1
BuildArch:    noarch

Summary:      TCL/TK based GUI for experimental work
Group:        System
License:      GPL

Packager:     Vladislav Zavjalov <slazav@altlinux.org>

Source:       %name-%version.tar

%description
TCL/TK based GUI for experimental work

%prep
%setup -q

%install
mkdir -p %buildroot%_bindir
mkdir -p %buildroot/%_tcldatadir/Exp
%__install $(find bin -maxdepth 1 -type f -perm 755) %buildroot%_bindir
%__install lib/*.tcl %buildroot/%_tcldatadir/Exp

%files
%_bindir/*
%_tcldatadir/Exp/*

%changelog
