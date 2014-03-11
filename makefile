prefix = /usr/local/
exec_prefix = $(prefix)
bindir = $(exec_prefix)/bin
sysconfdir = $(prefix)/etc

install:
	install -Dm644 freecheck.cfg "$(sysconfdir)/freecheck/freecheck.cfg"
	install -Dm755 freecheck "$(bindir)/freecheck"
