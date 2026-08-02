# SPDX-License-Identifier: GPL-3.0-or-later
# Makefile — instalação/remoção do Fox a partir de um git clone.
#
# Uso:
#   sudo make install
#   sudo make uninstall

PREFIX_LIB := /usr/lib/fox
PREFIX_BIN := /usr/bin/fox
PREFIX_ETC := /etc/fox
PREFIX_DOC := /usr/share/doc/fox
PREFIX_LICENSE := /usr/share/licenses/fox

.PHONY: install uninstall check-deps

check-deps:
	@for c in fzf yazi gpg tar; do \
		command -v $$c >/dev/null 2>&1 || { echo "faltando: $$c (pacman -S $$c)"; exit 1; }; \
	done

install: check-deps
	install -d -m 0755 $(PREFIX_LIB) $(PREFIX_ETC) $(PREFIX_DOC) $(PREFIX_LICENSE)
	install -m 0644 lib/*.bash $(PREFIX_LIB)/
	[ -f $(PREFIX_ETC)/fox.conf ] || install -m 0644 config/fox.conf.default $(PREFIX_ETC)/fox.conf
	install -m 0644 docs/CUSTOMIZATION.md README.md $(PREFIX_DOC)/
	install -m 0644 LICENSE $(PREFIX_LICENSE)/
	install -m 0755 fox $(PREFIX_BIN)
	@echo "Fox instalado em $(PREFIX_BIN)"

uninstall:
	rm -f $(PREFIX_BIN)
	rm -rf $(PREFIX_LIB)
	rm -rf $(PREFIX_ETC)
	rm -rf $(PREFIX_DOC)
	rm -rf $(PREFIX_LICENSE)
	@echo "Fox removido do sistema (config por usuário em ~/.config/fox/ preservada — remova à mão se quiser)."
