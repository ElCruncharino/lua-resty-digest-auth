# Makefile for lua-resty-digest-auth

PREFIX ?= /usr/local/openresty
LUALIB = $(PREFIX)/lualib
INSTALL = install

.PHONY: all install clean test

all:

install:
	$(INSTALL) -d $(LUALIB)/resty
	$(INSTALL) lib/resty/digest_auth.lua $(LUALIB)/resty/

clean:
	rm -f *.o *.so

test:
	@echo "Running tests..."
	@echo "No tests implemented yet"

uninstall:
	rm -f $(LUALIB)/resty/digest_auth.lua

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  install   - Install the module to $(LUALIB)"
	@echo "  uninstall - Remove the module from $(LUALIB)"
	@echo "  clean     - Clean build artifacts"
	@echo "  test      - Run tests (not implemented)"
	@echo "  help      - Show this help message" 