# Makefile for lua-resty-digest-auth

PREFIX ?= /usr/local/openresty
LUALIB = $(PREFIX)/lualib
INSTALL = install

.PHONY: all install clean test format

all:

install:
	$(INSTALL) -d $(LUALIB)/resty
	$(INSTALL) lib/resty/digest_auth.lua $(LUALIB)/resty/

clean:
	rm -f *.o *.so

test:
	@echo "Running tests via Docker..."
	@cd test && docker-compose up --build -d
	@echo "Waiting for services to start..."
	@sleep 3
	@docker exec lua-resty-digest-auth-test /usr/local/bin/basic_auth_test || true
	@echo "\nCleaning up..."
	@cd test && docker-compose down

uninstall:
	rm -f $(LUALIB)/resty/digest_auth.lua

format:
	@which stylua > /dev/null || (echo "Error: stylua not found. Install from: https://github.com/JohnnyMorganz/StyLua" && exit 1)
	@echo "Formatting Lua files with StyLua..."
	@stylua lib/

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  install   - Install the module to $(LUALIB)"
	@echo "  uninstall - Remove the module from $(LUALIB)"
	@echo "  clean     - Clean build artifacts"
	@echo "  test      - Run tests via Docker"
	@echo "  format    - Format Lua code with StyLua"
	@echo "  help      - Show this help message" 