APP_VERSION=0.1.8
LINUX_RUNTIME=./tclkit-8.6.3-rhel5-ix86
WINDOWS_RUNTIME=tclkit-8.5.8-win32.upx.exe
LINUX_TCLKITSH=./tclkitsh-8.5.9-linux-ix86

all:	exe

manual:
	m4 --define=APP_VERSION=$(APP_VERSION) doc/title.tex.m4 > doc/title.tex
	cd doc; pdflatex manual.tex

kit:
	$(LINUX_TCLKITSH) sdx.kit wrap sm-erm.kit

exe:
	$(LINUX_TCLKITSH) sdx.kit wrap sm-erm.exe -runtime $(WINDOWS_RUNTIME)
	$(LINUX_TCLKITSH) sdx.kit wrap sm-erm -runtime $(LINUX_RUNTIME)

dist: kit exe manual
	rm -f sm-erm-$(APP_VERSION).zip
	zip -j sm-erm-$(APP_VERSION).zip sm-erm.kit
	zip -j sm-erm-$(APP_VERSION).zip doc/manual.pdf
	rm -f sm-erm-$(APP_VERSION)-win32.zip
	zip -j sm-erm-$(APP_VERSION)-win32.zip sm-erm.exe
	zip -j sm-erm-$(APP_VERSION)-win32.zip doc/manual.pdf
	rm -f sm-erm-$(APP_VERSION)-linux32.zip
	zip -j sm-erm-$(APP_VERSION)-linux32.zip sm-erm
	zip -j sm-erm-$(APP_VERSION)-linux32.zip doc/manual.pdf

