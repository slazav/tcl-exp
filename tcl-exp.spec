Name:         exp_scripts
Version:      1.0
Release:      alt1
BuildArch:    noarch

Summary:      Useful scripts for my experimental setup and data processing
Group:        System
License:      GPL

Packager:     Vladislav Zavjalov <slazav@altlinux.org>

Source:       %name-%version.tar

%description
Local scripts for my computer

%prep
%setup -q

%install
mkdir -p %buildroot%_bindir %buildroot%_datadir/octave/site/m
mkdir -p %buildroot/%_tcldatadir/Exp
%__install bin/*    %buildroot%_bindir
%__install octave/* %buildroot%_datadir/octave/site/m
%__install exp/*    %buildroot%_bindir
%__install exp_tcl/*.tcl %buildroot/%_tcldatadir/Exp

%files
%_bindir/*
%_datadir/octave/site/m/*
%_tcldatadir/Exp/*

%changelog

