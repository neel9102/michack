# source: https://github.com/bpartridge/PyPhi # setting up for my machine

PY_VER = 2.7.3
SRC = $(shell readlink -f python)
MIC_PY_HOME = $(SRC)/_install
MIC_PY_PATH = $(MIC_PY_HOME)/lib/python2.7
CTYPES = $(SRC)/Modules/_ctypes
NP_UTILS = numpy/numpyxc.py numpy/setup.cfg numpy/site.cfg

all: $(MIC_PY_HOME) numpyxc scipyxc

install:
	@echo "To install, copy $(MIC_PY_HOME) where it can be accessed from the MIC card."
	$(error)

python.tgz:
	wget http://www.python.org/ftp/python/$(PY_VER)/Python-$(PY_VER).tgz -O $@

$(SRC): python.tgz
	mkdir -p $@
	tar -xf $< -C $@ --strip-components=1

$(SRC)/hostpython: | $(SRC)
	# TODO: fail if patched
	cd $(SRC) && ./configure && make
	cd $(SRC) && mv python hostpython && mv Parser/pgen Parser/hostpgen && make distclean

xcompile.patch:
	wget http://randomsplat.com/wp-content/uploads/2012/10/Python-$(PY_VER)-xcompile.patch -O $@

$(SRC)/patched: xcompile.patch $(SRC)/hostpython
	cd $(SRC) && patch -p1 < ../$<
	touch $@

$(SRC)/Makefile: $(SRC)/patched $(CTYPES)/.git
	# Must have unicode UCS4 to be compatible with Numpy on modern Linux systems
	cd $(SRC) && ./configure CC="icc -mmic" CXX="icpc -mmic" --host=x86_64 --without-gcc --enable-unicode=ucs4

$(CTYPES)/.git: | $(SRC)
	mv $(CTYPES) $(CTYPES).orig
	git clone https://github.com/bpartridge/xeon_phi_ctypes.git $(CTYPES)

$(MIC_PY_HOME): $(SRC)/Makefile $(SRC)/patched $(CTYPES)/.git
	sed -e "s/-OPT:Olimit=0//g" -i.backup $(SRC)/Makefile
	cd $(SRC) && make HOSTPYTHON=./hostpython HOSTPGEN=./Parser/hostpgen \
		CROSS_COMPILE=k1om- CROSS_COMPILE_TARGET=yes HOSTARCH=x86_64 BUILDARCH=x86_64-linux-gnu \
		EXTRA_CFLAGS="-fp-model precise -shared -fPIC" LDFLAGS=""
	mkdir -p $(MIC_PY_HOME)
	cd $(SRC) && make install HOSTPYTHON=./hostpython CROSS_COMPILE_TARGET=yes prefix=$(MIC_PY_HOME)

micclean: miccleanobjs
	rm $(SRC)/Makefile

miccleanobjs:
	rm -rvf $(SRC)/**/*.o
	rm -rf $(SRC)/build
	rm -rf $(MIC_PY_HOME)
