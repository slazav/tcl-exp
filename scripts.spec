Name:         scripts
Version:      1.0
Release:      alt1

Summary:      Local scripts for my computer
Group:        System
License:      GPL

Packager:     Vladislav Zavjalov <slazav@altlinux.org>

Source:       %name-%version.tar

%description
Local scripts for my computer

%prep
%setup -q

%build
mkdir -p %buildroot%_bindir %buildroot%_datadir/octave/site/m
%__install bin/*    %buildroot%_bindir
%__install octave/* %buildroot%_datadir/octave/site/m

%files
%_bindir/*
%_datadir/octave/site/m/*

%changelog
