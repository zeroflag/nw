SRC = networth.lisp
TARGET = networth.fasl

SBCL = sbcl

all: $(TARGET)

$(TARGET): $(SRC)
	$(SBCL) --userinit init.lisp --sysinit ~/.sbclrc --load holdings.lisp --eval '(compile-file "$(SRC)")' --quit

clean:
	rm -f *.fasl

