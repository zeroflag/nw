SRC = networth.lisp
TARGET = networth.fasl

SBCL = sbcl

all: $(TARGET)

$(TARGET): $(SRC)
	$(SBCL) --userinit init.lisp --sysinit ~/.sbclrc --eval '(compile-file "$(SRC)")' --quit

# Clean up generated .fasl file
clean:
	rm -f $(TARGET)

