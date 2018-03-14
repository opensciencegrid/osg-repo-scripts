Name:		osg-repo-scripts
Version:	0.1
Release:	0.1%{?dist}
Summary:	rpm repo update scripts for osg repo servers

Group:		System Environment/Tools
License:	ASL 2.0
URL:		https://github.com/opensciencegrid/mash-scripts
Source0:	%{name}-%{version}.tar.gz
BuildArch:	noarch

#BuildRequires:	
Requires:	mash

%description
%{summary}

%prep
%setup -q

#%build

%install
install -d $RPM_BUILD_ROOT%{_bindir}/
install -d $RPM_BUILD_ROOT%{_sysconfdir}/cron.d/
install -d $RPM_BUILD_ROOT%{_sysconfdir}/mash/
install -d $RPM_BUILD_ROOT%{_sysconfdir}/osg-koji-tags/
install -d $RPM_BUILD_ROOT%{_datadir}/repo/

install -m 0755 bin/new_mashfile.sh     $RPM_BUILD_ROOT%{_bindir}/
install -m 0755 bin/update_all_repos.sh $RPM_BUILD_ROOT%{_bindir}/
install -m 0755 bin/update_mashfiles.sh $RPM_BUILD_ROOT%{_bindir}/
install -m 0755 bin/update_mirror.py    $RPM_BUILD_ROOT%{_bindir}/
install -m 0755 bin/update_repo.sh      $RPM_BUILD_ROOT%{_bindir}/

install -m 0644 etc/cron.d/repo      $RPM_BUILD_ROOT%{_sysconfdir}/cron.d/
install -m 0644 etc/mash_koji_config $RPM_BUILD_ROOT%{_sysconfdir}/
install -m 0644 etc/rsyncd.conf      $RPM_BUILD_ROOT%{_sysconfdir}/
install -m 0644 etc/osg-koji-tags/osg-tags.exclude \
                       $RPM_BUILD_ROOT%{_sysconfdir}/osg-koji-tags/

# populated by update_mashfiles.sh
touch $RPM_BUILD_ROOT%{_sysconfdir}/osg-koji-tags/osg-tags

install -m 0644 etc/mash/mash.conf       $RPM_BUILD_ROOT%{_datadir}/repo/
install -m 0644 share/repo/mash.template $RPM_BUILD_ROOT%{_datadir}/repo/

%files
#%doc
%{_bindir}/new_mashfile.sh
%{_bindir}/update_all_repos.sh
%{_bindir}/update_mashfiles.sh
%{_bindir}/update_mirror.py
%{_bindir}/update_repo.sh
%{_datadir}/repo/mash.conf
%{_datadir}/repo/mash.template
%config(noreplace) %{_sysconfdir}/cron.d/repo
%config(noreplace) %{_sysconfdir}/mash_koji_config
%config(noreplace) %{_sysconfdir}/rsyncd.conf
%config(noreplace) %{_sysconfdir}/osg-koji-tags/osg-tags.exclude
%ghost             %{_sysconfdir}/osg-koji-tags/osg-tags

%changelog
* Mon Feb 19 2018 Carl Edquist <edquist@cs.wisc.edu> - 0.1-0.1
- Initial rpm packaging

